# Transcode

## Use case

The primary goal is to decode a large format uncompressed video signal
(SMPTE ST 2110-20) along with raw audio (SMPTE ST 2110-30); the stream
synchronization being based on PTP (SMPTE ST 2110-10). After the AV
content is reconstructed, FFmpeg re-encodes the signal for storage or
streaming. The project also aims at evaluating the limitation in terms
of bandwidth, especially when additional streams are provided.

```
+-----------------------+            +-------------------+              +------------+
| Source:               |            | Transcoder:       |              | Monitor:   |
+-----------------------+            +-------------------+              +------------+
| exple: Gstreamer or HW|            | ffmpeg            |              | vlc, ffplay|
+-----------------------+            +-------------------+              +------------+
| generate rtp streams  |-- video -->| depacketize,      |   h264       |            |
|                       |  RFC 4175  | reconstruct,      |-- mpeg-ts -->| playback   |
|                       |-- audio -->| encode and stream |   udp/srt    |            |
+-----------------------+   AES67    +-------------------+              +------------+
```

Other tools like Gstreamer may be used as a transcoder but the following
study focuses on ffmpeg.

## Install ffmpeg and dependencies

From top directory,

```
sudo -i
./install.sh common       # gcc, libtool, tar etc.
./install.sh transcoder   # depencies (yasm, nasm, x264, fdkaac, mp3, srt) and ffmpeg
```

## Get a SMPTE 2110 source

If you don't have any source, consider using a [sofware-based source](../doc/SW_source.md)
for testing.

A SMPTE 2110 streams are described by an individual SDP file for each
essence: video, audio, ancillary. However, ffmpeg hardly takes multiple
SDP files as input. A hack consists in combining the essence
descriptions in one single SDP. See [example](../doc/sdp.sample), where
audio is declared before video to ensure that ffmpeg process this
lighter stream first. Note that network redundancy (SMPTE 2022-7) is not
supported.

## Simple test

Transcode AV streams to h264 low res file:

```sh
ffmpeg -loglevel debug \
    -buffer_size 671088640 -protocol_whitelist file,udp,rtp -i <sdp_file> \
    -fifo_size 1000000000 \
    -c:a libfdk_aac -ac 2 \
    -vf scale=640:480 \
    -c:v libx264 -preset ultrafast -pass 1 \
    output.mp4
```

Decode interlaced and re-stream to h264 @ 2.5Mbps over mpegts:

```sh
ffmpeg -loglevel debug \
    -buffer_size 671088640 -protocol_whitelist file,udp,rtp -i <sdp_file> \
    -fifo_size 1000000000 -passlogfile /tmp/ffmpeg2pass \
    -c:a libfdk_aac -ac 2 -b:a 128k \
    -r 30 -vf yadif=0:-1:0 \
    -s 1280x720 -pix_fmt yuv420p -c:v libx264 -profile:v main -preset fast \
    -level:v 3.1 -b:v 2500k -x264-params b-pyramid=1 -g 30 -keyint_min 16 -pass 1 -refs 6 \
    -f mpegts udp://<monitor_IP>:5000
```

On a monitoring host:

```sh
ffplay udp://@0.0.0.0:5000
vlc --network-caching 4000  udp://@0.0.0.0:5000
```

If no packets are received, refer to the [troubleshoot guide](../doc/troubleshoot.md).

## RTP packet drops

`ffmpeg` may complain about RTP discontinuity with messages including:

```
jitter buffer full
RTP: missed ******* packets
Missed previous RTP Marker
RTP: dropping old packet received too late
```

First thing to do is to strip the command to bare minimum:

```
ffmpeg -y -loglevel verbose -buffer_size 671088640 -protocol_whitelist 'file,udp,rtp' -i mysdp.sdp  -f null /dev/null
```

If no more packet drops, then the transcoding creates a bottleneck that
prevents ffpmeg from reading the incomming packets fast enough. Here are
some of the knobs you can try to adjust:
- image resolution
- CPU, see [performance analysis](../doc/transcoder_perf.md)
- force multithread by applying this [patch](transcoder/ffmpeg-force-input-threading.patch)

You can also check that your NIC ring buffer is the largest as possible:

```
sudo ethtool -g <iface>
sudo ethtool -G <iface> 8192
```

And consider increasing Kernel Rx buffer:

```
sysctl net.core.rmem_max=671088640
sysctl net.core.rmem_default=671088640
echo 10000 > /proc/sys/net/core/netdev_max_backlog
```

Verify the memory usage of your receiving socket:

```
ss -uamp | grep -A1 ffmpeg

UNCONN    1119285120    0   225.164.14.100:20000     0.0.0.0:*          users:(("ffmpeg",pid
    #     ^ bytes of data have been received by the kernel but haven’t yet been copied by the process
    skmem:(r1016405760,rb1342177280,t0,tb212992,f256,w0,o112,bl0,d75818)
    #      ^            ^max                                     ^pkt drops
    #      | current, should ideally be 0
```

Use `./transcoder/transcoder_stats.sh` for complete stats.

## Start as a service

Once the process is stable, you can start it as a background task.
Use ./transcode.sh to start the transcoding service in background from
one or multiple SDP files, then show logs and, finally stop the service.

```sh
$ ./transcoder.sh help
[...]
$ ./transcoder.sh start file.sdp
==================== Start ... ====================
Transcoding from file.sdp
Scaling and encoding: cpu.
Audio codec is aac.
[...]
$ ./transcoder.sh log
[...]
$ ./transcoder.sh stop
==================== Stop ... ====================
```

Script constants, like destination IP, can be overridden by conf file,
i.e. `/etc/st2110.conf`. See sample `./config/st2110.conf` for details.

## FFmpeg options

Without '-pass 1', the CPU usage is way higher and the audio breaks
after a few seconds, at least for rtmp output. The 1st con of the option is
that the output bitrate might less precise. And the generated passlog
file is quite large (~10GB/day). The 'monitor' function of the transcoder
checks the size of this file and restarts ffmpeg if needed.

## Hardware acceleration for transcoding

[Nvidia setup.](../doc/hw_encoding.md)

## Transcoding performance

[Measurements](../doc/transcoder_perf.md) with CPU vs GPU.

## Trancoding ancillary data (SMPTE ST 2110-40)

ffmpeg shows some limitations in [transcoding closed
caption](../doc/closed_captions.md).

Here are some guidelines for [SCTE-35](../doc/scte_104_to_35.md).
