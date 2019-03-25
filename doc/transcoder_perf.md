# Transcoding performance

## Setup

* Centos 7 virtualized
* 4 x Intel(R) Xeon(R) Gold 6142 CPU @ 2.60GHz
* memory 4GB
* GPU Model: Nvidia Quadro P4000 using DirectPathIO

## Load

1 video stream @ 1080i 60 fps transcoded to 720p @ 30 fps, 2.5Mpbs.

## Measuring CPU and GPU utilization

```sh
$ vmstat -n 1 # check "us" (user) column
$ nvidia-smi dmon -i 0 # check "enc" column
```

## CPU encoding (libx264)

```
/usr/local/bin/ffmpeg -loglevel info -strict experimental -threads 2 -buffer_size 671088640 -protocol_whitelist file,udp,rtp -i ../sdp/emb_176_explora.sdp -fifo_size 1000000000 -smpte2110_timestamp 1 -r 30 -vf yadif=0:-1:0 -s 1280x720 -pix_fmt yuv420p -c:v libx264 -profile:v main -preset fast -level:v 3.1 -b:v 2500k -bufsize:v 7000k -maxrate:v 2500k -x264-params b-pyramid=1 -g 30 -keyint_min 16 -pass 1 -refs 6 -c:a libfdk_aac -ac 2 -b:a 128k -f tee -map 0:v -map 0:a "[f=mpegts]udp://10.177.45.127:5001?pkt_size=1316"
```

CPU: 48% (user=36%, sys=12%), Mem: 21%

## GPU encoding (h264_nvenc)

```
# /usr/local/bin/ffmpeg -loglevel info -strict experimental -threads 2 -buffer_size 671088640 -protocol_whitelist file,udp,rtp -i ../sdp/emb_176_explora.sdp -fifo_size 1000000000 -smpte2110_timestamp 1 -r 30 -vf yadif=0:-1:0,format=yuv420p,hwupload_cuda,scale_npp=w=1280:h=720:format=yuv420p:interp_algo=lanczos,hwdownload,format=yuv420p -c:v h264_nvenc -rc cbr_hq -preset:v fast -profile:v main -level:v 4.1 -b:v 2500k -bufsize:v 7000k -maxrate:v 2500k -g 30 -keyint_min 16 -pass 1 -refs 6 -c:a libfdk_aac -ac 2 -b:a 128k -f tee -map 0:v -map 0:a "[f=mpegts]udp://10.177.45.127:5001?pkt_size=1316"
```

CPU: 35% (user: 23%, sys: 12%), Mem: 21%
GPU: 4% (P0:46%, 211MiB /  8119MiB)
