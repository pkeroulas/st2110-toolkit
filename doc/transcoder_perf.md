# Live Transcoding performance

## Setup

* Centos 7 virtualized
* 4 x Intel(R) Xeon(R) Gold 6142 CPU @ 2.60GHz
* memory 4GB
* GPU Model: Nvidia Quadro P4000, PassThrough
* Network adapter: VMXNET 3, DirectPath I/O

## Load

Input: 1 or 2 streams @ 1080i 60 fps (1.23Gb/s) + 2 audio channels

Output: 720p @ 30 fps (2.5Mpbs) + 2 audio channels

## Measuring CPU and GPU utilization

```sh
$ vmstat -n 1 # check "us" (user) column
$ nvidia-smi dmon -i 0 # check "enc" column
```

## CPU encoding (libx264)

### 1 stream

```
# ./transcode start -e cpu ../sdp/emb_176_explora.sdp
/usr/local/bin/ffmpeg -loglevel info -strict experimental -threads 2 -buffer_size 671088640 -protocol_whitelist file,udp,rtp -i ../sdp/emb_176_explora.sdp -fifo_size 1000000000 -smpte2110_timestamp 1 -r 30 -vf yadif=0:-1:0 -s 1280x720 -pix_fmt yuv420p -c:v libx264 -profile:v main -preset fast -level:v 3.1 -b:v 2500k -x264-params b-pyramid=1 -g 30 -keyint_min 16 -refs 6 -c:a libfdk_aac -ac 2 -b:a 128k -f tee -map 0:v -map 0:a "[f=mpegts]udp://10.177.45.127:5001?pkt_size=1316"
```

* CPU: 70% (user=30%, sys=10%), Mem: 24%

### 2 streams

* CPU: 97% (user=60%, sys=6%), Mem: 16%
* packet drops after a few sec.
* stable with 8 CPUs instead of 4

## GPU encoding (h264_nvenc)

### 1 stream

```
# ./transcode start -e gpu ../sdp/emb_176_explora.sdp
/usr/local/bin/ffmpeg -loglevel info -strict experimental -threads 2 -buffer_size 671088640 -protocol_whitelist file,udp,rtp -i ../sdp/emb_176_explora.sdp -fifo_size 1000000000 -smpte2110_timestamp 1 -r 30 -vf yadif=0:-1:0,format=yuv420p,hwupload_cuda,scale_npp=w=1280:h=720:format=yuv420p:interp_algo=lanczos,hwdownload,format=yuv420p -c:v h264_nvenc -rc cbr_hq -preset:v fast -profile:v main -level:v 4.1 -b:v 2500k -bufsize:v 7000k -maxrate:v 2500k -g 30 -keyint_min 16 -pass 1 -refs 6 -c:a libfdk_aac -ac 2 -b:a 128k -f tee -map 0:v -map 0:a "[f=mpegts]udp://10.177.45.127:5001?pkt_size=1316"
```

* CPU: 33% (user: 23%, sys: 8%), Mem: 16%
* GPU: 4%, 211MiB / 8119MiB
* note that this command contains old '-pass 1' option

### 2 streams

* CPU: 76% (user=52%, sys=20%), Mem: 30%
* GPU: 8%, 413MiB / 8119MiB
* jerky, slow, and packet drop after a few minutes
* stable with 6 CPUs instead of 4

## GPU encoding 1 source @ mutlitple resolutions/bitrates

Since CPU encoding is quite limited let's focuse on GPU for multiple
output.

Multiple FFmpeg instances is not adequate because they all read from the
same socket, i.e. there is only one multicast IGMP join, and they all
fight for the data. Use one FFmpeg instance to transcode one feed into
multiple resolution/bitrate output (3500k, 2500k, 1200k, 800k, 500,
400k, 250k) is prefered.

```
# ./transcode start -e gpu -o multi ../sdp/emb_176_explora.sdp
/usr/local/bin/ffmpeg -loglevel info -strict experimental -threads 2 -buffer_size 671088640 -protocol_whitelist file,udp,rtp -i ../sdp/emb_176_explora.sdp
	-fifo_size 1000000000 -smpte2110_timestamp 1 -c:a libfdk_aac -ac 2 -b:a 128k -r 30
	-filter_complex '[0:v]split=4[in0][in1][in2][in3];\
	[in0]format=yuv420p,hwupload_cuda,scale_npp=w=1280:h=720:format=yuv420p:interp_algo=lanczos,hwdownload,format=yuv420p,split=2[out0][out1];\
	[in1]format=yuv420p,hwupload_cuda,scale_npp=w=852:h=480:format=yuv420p:interp_algo=lanczos,hwdownload,format=yuv420p[out2];\
	[in2]format=yuv420p,hwupload_cuda,scale_npp=w=640:h=360:format=yuv420p:interp_algo=lanczos,hwdownload,format=yuv420p,split=2[out3][out4];\
	[in3]format=yuv420p,hwupload_cuda,scale_npp=w=480:h=270:format=yuv420p:interp_algo=lanczos,hwdownload,format=yuv420p,split=2[out5][out6]'\
	-map [out0] -c:v h264_nvenc -rc cbr_hq -preset:v fast -profile:v main -level:v 4.1 -b:v 3500k -bufsize:v 7000k -maxrate:v 3500k -g 30 -keyint_min 16 -pass 1 -refs 6 -f mpegts udp://10.177.45.127:5000?pkt_size=1316\
	-map [out1] -c:v h264_nvenc -rc cbr_hq -preset:v fast -profile:v main -level:v 4.1 -b:v 2500k -bufsize:v 5000k -maxrate:v 2500k -g 30 -keyint_min 16 -pass 1 -refs 6 -f mpegts udp://10.177.45.127:5001?pkt_size=1316\
	-map [out2] -c:v h264_nvenc -rc cbr_hq -preset:v fast -profile:v main -level:v 4.1 -b:v 1200k -bufsize:v 2500k -maxrate:v 1200k -g 30 -keyint_min 16 -pass 1 -refs 6 -f mpegts udp://10.177.45.127:5002?pkt_size=1316\
	-map [out3] -c:v h264_nvenc -rc cbr_hq -preset:v fast -profile:v baseline -level:v 4.1 -b:v 800k -bufsize:v 1600k -maxrate:v 800k -g 30 -keyint_min 16 -pass 1 -refs 6 -f mpegts udp://10.177.45.127:5003?pkt_size=1316 -map [out4] -c:v h264_nvenc -rc cbr_hq -preset:v fast -profile:v baseline -level:v 4.1 -b:v 500k -bufsize:v 1000k -maxrate:v 500k -g 30 -keyint_min 16 -pass 1 -refs 6 -f mpegts udp://10.177.45.127:5004?pkt_size=1316\
	-map [out5] -c:v h264_nvenc -rc cbr_hq -preset:v fast -profile:v baseline -level:v 3.1 -b:v 400k -bufsize:v 800k -maxrate:v 400k -g 30 -keyint_min 16 -pass 1 -refs 6 -f mpegts udp://10.177.45.127:5005?pkt_size=1316\
	-map [out6] -c:v h264_nvenc -rc cbr_hq -preset:v fast -profile:v baseline -level:v 3.1 -b:v 250k -bufsize:v 800k -maxrate:v 250k -g 30 -keyint_min 16 -pass 1 -refs 6 -f mpegts udp://10.177.45.127:5006?pkt_size=1316
```

* GPU 42% (user: 26%, 11%), Mem: 55%
* GPU: 10%, 1030MiB / 8119MiB
* some packet drops
* stable with 6 CPUs instead of 4
* command line is too long to run in tmux
* no yadif and no audio because it made the filter graph very complicated
