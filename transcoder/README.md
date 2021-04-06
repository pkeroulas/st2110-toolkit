# Transcode

## Install

From top directory,

```
sudo -i
./install.sh common       # gcc, libtool, tar etc.
./install.sh transcoder   # yasm nasm x264 fdkaac mp3 ffmpeg
```

## Simple tests

FFmpeg takes a ST2110-defined SDP file as input.

Output to h264 low res file:

```sh
ffmpeg -loglevel debug -strict experimental -threads 2 \
    -buffer_size 671088640 -protocol_whitelist file,udp,rtp -i <sdp_file> \
    -fifo_size 1000000000 -smpte2110_timestamp 1 \
    -c:a libfdk_aac -ac 2 \
    -vf scale=640:480 \
    -c:v libx264 -preset ultrafast -pass 1 \
    output.mp4
```

Decode interlaced and re-stream to h264 @ 2.5Mbps over mpegts:

```sh
ffmpeg -loglevel debug -strict experimental -threads 2 \
    -buffer_size 671088640 -protocol_whitelist file,udp,rtp -i <sdp_file> \
    -fifo_size 1000000000 -smpte2110_timestamp 1 -passlogfile /tmp/ffmpeg2pass \
    -c:a libfdk_aac -ac 2 -b:a 128k \
    -r 30 -vf yadif=0:-1:0 \
    -s 1280x720 -pix_fmt yuv420p -c:v libx264 -profile:v main -preset fast \
    -level:v 3.1 -b:v 2500k -x264-params b-pyramid=1 -g 30 -keyint_min 16 -pass 1 -refs 6 \
    -f mpegts udp://<monitor_IP>:5000
```

On a monitoring host:

```sh
$ ffplay udp://@0.0.0.0:5000
$ vlc --network-caching 4000  udp://@0.0.0.0:5000
```

## Start as a service

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

If error message is returned, look at the actual ffmpeg command line at
the beginning of the log file or see 'Troubleshoot' section below.

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

[Measurments](../doc/transcoder_perf.md) with CPU vs GPU.

## Trancoding ancillary data (SMPTE ST 2110-40)

ffmpeg shows some limitations in [transcoding closed
caption](../doc/closed_captions.md).

Here are some guidelines for [SCTE-35](../doc/scte_104_to_35.md).
