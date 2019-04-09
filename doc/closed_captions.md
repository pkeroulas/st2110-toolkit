# Closed captions

## Definitions

[Best intro to closed captions.](https://www.adobe.com/content/dam/acom/en/devnet/video/pdfs/introduction_to_closed_captions.pdf)

### Input

SMPTE ST 2110-40 defines encapsulation scheme looks like:

```
udp > rtp > ancillary data (SMPTE ST 291M) > CC (EIA-608/708)
```

### Output

Closed captions can be conveyed as a **distinct stream** in containers:

* MPEG TS -> DVB teletext (DVB subtitles are bitmaps) (mostly used in EU)
* RTMP -> AMF messages
* MP4, MOV -> text
* MKV -> ass, srt
* HLS -> WebVTT (dedicated file)

608/708 captions can also be **embedded in H264 SEI NALU** according to SCTE-128 and ASTC A/53 (North America)

## FFmpeg capabilities and limitations

### Demuxing

The demuxing part doesn't exist but a draft was implemented ([*dev/cc/v0* git branch](https://github.com/cbcrc/FFmpeg/commits/dev/cc/v0))

### Decoding

The CC can easily be extracted to *srt* file, which validates the demuxer and EIA-608/708 decoder.

### Remuxing in container

As *srt*, *text* and *mov_text* CC codec work fine, ffmpeg is able to embed CC in **file-type containers**: MKV, MOV, MP4. WebVTT seems to be supported as well but it wasn't tested.

For DVB teletext, JEEB (IRC fellow) suggests to use *libzvbi* to write an encoder. So far, this library has been integrated for teletext decoding only (*libavcodec/libzvbi-teletextdec.c*).

[Devin H.](mailto:dheitmueller@kernellabs.com) from [Kernel Labs](http://www.kernellabs.com) also recommends the teletext approach like *libavdevice/decklink_dec.cpp*, which, btw, also relies on *libzbi*. However, he admits it wasn't tested for TS output.

For FLV/RTMP, AMF messages should be used to convey CC, more precisely *onCaptionInfo* or *onCuePoint* events. In ffmpeg, the flv decoder can handle such messsages but not the encoder. No relevant example could be found.

### Embed H264 in SEI data

ffmpeg can [preserve CC for H264 pass-through](https://trac.ffmpeg.org/ticket/1778]) but **hardly can merge a data track to a video track**.

Here are some suggestions collected:

* JEEB recommends to use libav API, which has more potentials than the ffmpeg tool, to implement a dedicated app.
* Kernel Labs:
> implement a decoder which takes the AVPackets containing
> CC data and creates AVFrames, and then create what ffmpeg refers to as
> a "multimedia" filter which takes in the video and data packets and
> outputs video packets that contain the side data.  Multimedia filters
> are what are used to do things like taking in audio and video AVFrames
> from two streams and burning audio bars into the resulting video.
> Architecturally this is probably the "right" approach, but would
> require some changes to the frameworks and ffmpeg.c because today
> libavfilter currently only supports audio and video AVFrames

## Misc

Tested command line:

```sh
./ffmpeg -y -loglevel info -strict experimental -threads 2 -buffer_size 671088640 -protocol_whitelist file,udp,rtp -i /home/transcoder/sdp/emb_176_explora_anc.sdp -fifo_size 1000000000 -smpte2110_timestamp 1 -passlogfile /tmp/ffmpeg2pass  -c:a libfdk_aac -ac 2 -b:a 128k -r 30 -vf yadif=0:-1:0 -s 1280x720 -pix_fmt yuv420p -c:v libx264 -profile:v main -preset fast -level:v 3.1 -b:v 2500k -bufsize:v 5000k -maxrate:v 2500k -a53cc 1 -x264-params b-pyramid=1 -g 30 -keyint_min 16 -pass 1 -refs 6 -scodec text -f tee -map 0:v -map 0:s -map 0:a "[f=mpegts]/tmp/toto.ts|[f=mpegts]udp://@10.177.45.127:5000|[select=\'s:0\']/tmp/toto.srt"
```

where *-scodec* option can take the following values.

```sh
ffmpeg -encoders | grep "^ S"
[...]
 S..... = Subtitle
 S..... ssa                  ASS (Advanced SubStation Alpha) subtitle (codec ass)
 S..... ass                  ASS (Advanced SubStation Alpha) subtitle
 S..... dvbsub               DVB subtitles (codec dvb_subtitle)
 S..... dvdsub               DVD subtitles (codec dvd_subtitle)
 S..... mov_text             3GPP Timed Text subtitle
 S..... srt                  SubRip subtitle (codec subrip)
 S..... subrip               SubRip subtitle
 S..... text                 Raw text subtitle
 S..... webvtt               WebVTT subtitle
 S..... xsub                 DivX subtitles (XSUB)
```

[AWS MediaLive](https://docs.aws.amazon.com/medialive/latest/ug/general-information-supported-formats.html) supports a couple of captions formats.

[Kernel Labs](http://www.kernellabs.com) developped [libklanc](https://github.com/stoth68000/libklvanc) as a codec for multitple types of ancillary. The decoding part is used in *libavdevice/decklink_dec.cpp*.

[This MXF use case](https://trac.ffmpeg.org/ticket/5362)(*libavformat/mxfdec.c*) is another example where CC is extracted but can't be injected in h264 or TS.
