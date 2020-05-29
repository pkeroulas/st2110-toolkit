# Transcode

Use ./transcode.sh to start the transcoding service in back ground from
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
Without '-pass 1', the CPU usage is way higher and the audio breaks
$ ./transcoder.sh stop
==================== Stop ... ====================
```

If error message is returned, look at the actual ffmpeg command line at
the beginning of the log file or see 'Troubleshoot' section below.

Script constants, like destination IP, can be overridden by conf file,
i.e. `/etc/st2110.conf`. See sample `./config/st2110.conf` for details.

On a monitoring host:

```sh
$ ffplay udp://@0.0.0.0:5000
$ vlc --network-caching 4000  udp://@0.0.0.0:5000
```

## FFmpeg options

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
