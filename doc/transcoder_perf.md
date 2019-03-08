# Transcoding performance

## Setup

* Centos 7 virtualized
* 4 x Intel(R) Xeon(R) Gold 6142 CPU @ 2.60GHz
* memory 4GB
* GPU Model: Nvidia Quadro P4000 using DirectPathIO

## Measuring CPU and GPU utilization

```sh
$ vmstat -n 1 # check "us" (user) column
$ nvidia-smi dmon -i 0 # check "enc" column
```

## CPU encoding (libx264)

```
TRANSCODER_VIDEO_CPU_SCALE_OPTIONS="scale=1280:720"
TRANSCODER_VIDEO_CPU_ENCODE_OPTIONS="-pix_fmt yuv420p \
	-c:v libx264 -profile:v main -preset fast -level:v 3.1 \
	-b:v 2500k -bufsize:v 7000k -maxrate:v 2500k \
	-x264-params b-pyramid=1 \
	-g 30 -keyint_min 16 -pass 1 -refs 6"
```

CPU: 48% (user=36%, sys=12%), Mem 21% mem

## GPU encoding (h264_nvenc)

```
TRANSCODER_VIDEO_GPU_SCALE_OPTIONS="format=yuv420p,hwupload_cuda,scale_npp=w=1280:h=720:format=yuv420p:interp_algo=lanczos,hwdownload,format=yuv420p"
TRANSCODER_VIDEO_GPU_ENCODE_OPTIONS=" \
	-c:v h264_nvenc -rc cbr_hq -preset:v fast -profile:v main -level:v 4.1 \
	-b:v 2500k -bufsize:v 7000k -maxrate:v 2500k \
	-g 30 -keyint_min 16 -pass 1 -refs 6"
# cbr doesn't work. measure=1-10Mbps
# -level 3.1 not accepted
```

CPU: 35% (user: 23%, sys: 12%), Mem: 21%, GPU: 4%
