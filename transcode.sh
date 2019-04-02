#!/bin/sh

PATH=$PATH:/usr/local/bin/
FFMPEG=$(which ffmpeg)
DIR=$(dirname $0)
SCRIPT=$(basename $0)
ST2110_CONF_FILE=/etc/st2110.conf
LOG_FILE=/tmp/ffmpeg.log
PASS_FILE=/tmp/ffmpeg2pass

log() {
	# Shoot to terminal, logfile and syslog
	echo $@ | tee -a $LOG_FILE
	logger -t "st2110-transcoder" "$@"
}

if ! which $FFMPEG > /dev/null 2>&1
then
	log "$FFMPEG is not installed, see install.sh"
	exit -1
fi

help() {
	echo -e "
$SCRIPT opens multiple instances of ffmpeg transcoders.
Each of them reads an SDP file decode a specific SMPTE ST 2110
stream, re-encodes it to h264. All the streams are redirected to the
same destination but with different ports.

Usage:
\t$SCRIPT help      # show this message
\t$SCRIPT log       # show live ffmpeg output
\t$SCRIPT monitor   # show resource usage
\t$SCRIPT setup <interface_name> <sdp_file>
\t\t                  # generate conf from sdp and interface
\t$SCRIPT start [-e <cpu|gpu>] [-a <aac|ac3>] [-o <ts|rtmp|multi>] <sdp_file>
\t\t                  # start ffmpeg instances
\t$SCRIPT stop      # stop ffmpeg instances
\t$SCRIPT monitor   # check log size and restart if needed
"
}

TRANSCODER_LOGLEVEL=info
# input buffer size: maximum value permitted by setsockopt
TRANSCODER_BUFFER_SIZE=671088640
TRANSCODER_FIFO_SIZE=1000000000

# h264 profile recommendation for IPTV

# video encode options for CPU
TRANSCODER_VIDEO_CPU_ENCODE_OPTIONS_720_3500="-s 1280x720 -pix_fmt yuv420p -c:v libx264 -profile:v main -preset fast -level:v 3.1 -b:v 3500k -bufsize:v 7000k -maxrate:v 3500k -x264-params b-pyramid=1 -g 30 -keyint_min 16 -pass 1 -refs 6"
TRANSCODER_VIDEO_CPU_ENCODE_OPTIONS_720_2500="-s 1280x720 -pix_fmt yuv420p -c:v libx264 -profile:v main -preset fast -level:v 3.1 -b:v 2500k -bufsize:v 5000k -maxrate:v 2500k -x264-params b-pyramid=1 -g 30 -keyint_min 16 -pass 1 -refs 6"
TRANSCODER_VIDEO_CPU_ENCODE_OPTIONS_480_1200="-s 852x480  -pix_fmt yuv420p -c:v libx264 -profile:v main -preset fast -level:v 3.1 -b:v 1200k -bufsize:v 2500k -maxrate:v 1200k -x264-params b-pyramid=1 -g 30 -keyint_min 16 -pass 1 -refs 6"
TRANSCODER_VIDEO_CPU_ENCODE_OPTIONS_360_800="-s 640x360 -pix_fmt yuv420p -c:v libx264 -profile:v baseline -preset fast -level:v 2.1 -b:v 800k -bufsize:v 1600k -maxrate:v 800k -x264-params b-pyramid=1 -g 30 -keyint_min 16 -pass 1 -refs 6"
TRANSCODER_VIDEO_CPU_ENCODE_OPTIONS_360_500="-s 640x360 -pix_fmt yuv420p -c:v libx264 -profile:v baseline -preset fast -level:v 2.1 -b:v 500k -bufsize:v 1200k -maxrate:v 500k -x264-params b-pyramid=1 -g 30 -keyint_min 16 -pass 1 -refs 6"
TRANSCODER_VIDEO_CPU_ENCODE_OPTIONS_270_400="-s 480x270 -pix_fmt yuv420p -c:v libx264 -profile:v baseline -preset fast -level:v 2.1 -b:v 400k -bufsize:v 800k -maxrate:v 400k -x264-params b-pyramid=1 -g 30 -keyint_min 16 -pass 1 -refs 6"
TRANSCODER_VIDEO_CPU_ENCODE_OPTIONS_270_250="-s 480x270 -pix_fmt yuv420p -c:v libx264 -profile:v baseline -preset fast -level:v 2.1 -b:v 250k -bufsize:v 500k -maxrate:v 250k -x264-params b-pyramid=1 -g 30 -keyint_min 16 -pass 1 -refs 6"

# video rescaled by GPU
TRANSCODER_VIDEO_GPU_SCALE_OPTIONS_720="format=yuv420p,hwupload_cuda,scale_npp=w=1280:h=720:format=yuv420p:interp_algo=lanczos,hwdownload,format=yuv420p"
TRANSCODER_VIDEO_GPU_SCALE_OPTIONS_480="format=yuv420p,hwupload_cuda,scale_npp=w=852:h=480:format=yuv420p:interp_algo=lanczos,hwdownload,format=yuv420p"
TRANSCODER_VIDEO_GPU_SCALE_OPTIONS_360="format=yuv420p,hwupload_cuda,scale_npp=w=640:h=360:format=yuv420p:interp_algo=lanczos,hwdownload,format=yuv420p"
TRANSCODER_VIDEO_GPU_SCALE_OPTIONS_270="format=yuv420p,hwupload_cuda,scale_npp=w=480:h=270:format=yuv420p:interp_algo=lanczos,hwdownload,format=yuv420p"
TRANSCODER_VIDEO_GPU_ENCODE_OPTIONS_3500="-c:v h264_nvenc -rc cbr_hq -preset:v fast -profile:v main -level:v 4.1 -b:v 3500k -bufsize:v 7000k -maxrate:v 3500k -g 30 -keyint_min 16 -pass 1 -refs 6"
TRANSCODER_VIDEO_GPU_ENCODE_OPTIONS_2500="-c:v h264_nvenc -rc cbr_hq -preset:v fast -profile:v main -level:v 4.1 -b:v 2500k -bufsize:v 5000k -maxrate:v 2500k -g 30 -keyint_min 16 -pass 1 -refs 6"
TRANSCODER_VIDEO_GPU_ENCODE_OPTIONS_1200="-c:v h264_nvenc -rc cbr_hq -preset:v fast -profile:v main -level:v 4.1 -b:v 1200k -bufsize:v 2500k -maxrate:v 1200k -g 30 -keyint_min 16 -pass 1 -refs 6"
TRANSCODER_VIDEO_GPU_ENCODE_OPTIONS_800="-c:v h264_nvenc -rc cbr_hq -preset:v fast -profile:v baseline -level:v 4.1 -b:v 800k -bufsize:v 1600k -maxrate:v 800k -g 30 -keyint_min 16 -pass 1 -refs 6"
TRANSCODER_VIDEO_GPU_ENCODE_OPTIONS_500="-c:v h264_nvenc -rc cbr_hq -preset:v fast -profile:v baseline -level:v 4.1 -b:v 500k -bufsize:v 1000k -maxrate:v 500k -g 30 -keyint_min 16 -pass 1 -refs 6"
TRANSCODER_VIDEO_GPU_ENCODE_OPTIONS_400="-c:v h264_nvenc -rc cbr_hq -preset:v fast -profile:v baseline -level:v 3.1 -b:v 400k -bufsize:v 800k -maxrate:v 400k -g 30 -keyint_min 16 -pass 1 -refs 6"
TRANSCODER_VIDEO_GPU_ENCODE_OPTIONS_250="-c:v h264_nvenc -rc cbr_hq -preset:v fast -profile:v baseline -level:v 3.1 -b:v 250k -bufsize:v 800k -maxrate:v 250k -g 30 -keyint_min 16 -pass 1 -refs 6"
# cbr doesn't work. measure=1-10Mbps
# -level 3.1 not accepted

# audio
TRANSCODER_AUDIO_ENCODE_AC3="-c:a ac3 -ac 6 -b:a 340k"
TRANSCODER_AUDIO_ENCODE_AAC="-c:a libfdk_aac -ac 2 -b:a 128k"

# default unicast TS output
TRANSCODER_OUTPUT_TS_DST_IP=localhost
TRANSCODER_OUTPUT_TS_DST_PORT=5000
TRANSCODER_OUTPUT_TS_DST_PKT_SIZE=1492

# default rtmp destinations
TRANSCODER_OUTPUT_RTMP_DST_IP_A=localhost
TRANSCODER_OUTPUT_RTMP_DST_IP_B=localhost

# override default params with possibly existing conf file
if [ -f $ST2110_CONF_FILE ]; then
	source $ST2110_CONF_FILE
fi

TRANSCODER_OUTPUT_MPEGTS="[f=mpegts]udp://$TRANSCODER_OUTPUT_TS_DST_IP:$TRANSCODER_OUTPUT_TS_DST_PORT?pkt_size=$TRANSCODER_OUTPUT_TS_DST_PKT_SIZE"
TRANSCODER_OUTPUT_RTMP_DST_A="[f=flv]rtmp://$TRANSCODER_OUTPUT_RTMP_DST_IP_A:1935/live/smpte2110"
TRANSCODER_OUTPUT_RTMP_DST_B="[f=flv]rtmp://$TRANSCODER_OUTPUT_RTMP_DST_IP_B:1935/live/smpte2110"

start() {
	sdp=$1
	encode=$2
	audio=$3
	output=$4

	rm $LOG_FILE
	log "==================== Start $(date) ===================="
	log "Start args: $@"

	log "SDP file is $sdp."

	filter_options="-vf yadif=0:-1:0"
	if [ $encode = "cpu" ]; then
		video_encode_options=$TRANSCODER_VIDEO_CPU_ENCODE_OPTIONS_720_2500
	elif [ $encode = "gpu" ]; then
		# gpu can rescale
		filter_options="$filter_options,$TRANSCODER_VIDEO_GPU_SCALE_OPTIONS_720"
		video_encode_options=$TRANSCODER_VIDEO_GPU_ENCODE_OPTIONS_2500
	else
		log "Encoding not supported: $encode"
		return 1
	fi
	log "Scaling and encoding is $encode."

	if [ $audio = "aac" ]; then
		audio_encode_options=$TRANSCODER_AUDIO_ENCODE_AAC
	elif [ $audio = "ac3" ]; then
		audio_encode_options=$TRANSCODER_AUDIO_ENCODE_AAC
	else
		log "Audio codec not supported: $audio"
		return 1
	fi
	log "Audio codec is $audio."

	output_dest="-f tee"
	if grep -q "audio" $sdp; then
		output_dest="$output_dest -map 0:a"
	fi
	if grep -q "video" $sdp; then
		output_dest="$output_dest -map 0:v"
	fi

	if [ $output = "ts" ]; then
		# simple monitor
		output_dest="$output_dest \"$TRANSCODER_OUTPUT_MPEGTS\""
	elif [ $output = "rtmp" ]; then
		# fit audio bitstream (ADTS) to flv (ASC)
		audio_encode_options="$audio_encode_options -ar 44100 -bsf:a aac_adtstoasc"
		# ASC breaks audio TS, let's remove it for the monitoring
		output_dest="$output_dest \"[select=\'v:0\':f=mpegts]udp://$TRANSCODER_OUTPUT_TS_DST_IP:$TRANSCODER_OUTPUT_TS_DST_PORT?pkt_size=$TRANSCODER_OUTPUT_TS_DST_PKT_SIZE|
$TRANSCODER_OUTPUT_RTMP_DST_A|$TRANSCODER_OUTPUT_RTMP_DST_B\"
"
	elif [ $output = "multi" ]; then
		# one ffmpeg instance for multiple output/bitrates (unicast TS)
		# yadif is removed to make the graph not too complicated
		# hackish
		video_encode_options=""
		if [ $encode = "cpu" ]; then
			output_dest="\
$TRANSCODER_VIDEO_CPU_ENCODE_OPTIONS_720_3500 -f mpegts udp://$TRANSCODER_OUTPUT_TS_DST_IP:$((TRANSCODER_OUTPUT_TS_DST_PORT+0))?pkt_size=$TRANSCODER_OUTPUT_TS_DST_PKT_SIZE \
$TRANSCODER_VIDEO_CPU_ENCODE_OPTIONS_720_2500 -f mpegts udp://$TRANSCODER_OUTPUT_TS_DST_IP:$((TRANSCODER_OUTPUT_TS_DST_PORT+1))?pkt_size=$TRANSCODER_OUTPUT_TS_DST_PKT_SIZE \
$TRANSCODER_VIDEO_CPU_ENCODE_OPTIONS_480_1200 -f mpegts udp://$TRANSCODER_OUTPUT_TS_DST_IP:$((TRANSCODER_OUTPUT_TS_DST_PORT+2))?pkt_size=$TRANSCODER_OUTPUT_TS_DST_PKT_SIZE \
$TRANSCODER_VIDEO_CPU_ENCODE_OPTIONS_360_800  -f mpegts udp://$TRANSCODER_OUTPUT_TS_DST_IP:$((TRANSCODER_OUTPUT_TS_DST_PORT+3))?pkt_size=$TRANSCODER_OUTPUT_TS_DST_PKT_SIZE \
$TRANSCODER_VIDEO_CPU_ENCODE_OPTIONS_360_500  -f mpegts udp://$TRANSCODER_OUTPUT_TS_DST_IP:$((TRANSCODER_OUTPUT_TS_DST_PORT+4))?pkt_size=$TRANSCODER_OUTPUT_TS_DST_PKT_SIZE \
$TRANSCODER_VIDEO_CPU_ENCODE_OPTIONS_270_400  -f mpegts udp://$TRANSCODER_OUTPUT_TS_DST_IP:$((TRANSCODER_OUTPUT_TS_DST_PORT+5))?pkt_size=$TRANSCODER_OUTPUT_TS_DST_PKT_SIZE \
$TRANSCODER_VIDEO_CPU_ENCODE_OPTIONS_270_250  -f mpegts udp://$TRANSCODER_OUTPUT_TS_DST_IP:$((TRANSCODER_OUTPUT_TS_DST_PORT+6))?pkt_size=$TRANSCODER_OUTPUT_TS_DST_PKT_SIZE \
"
		elif [ $encode = "gpu" ]; then
			# combine scaling, encoding and ouput destination
			filter_options="-filter_complex '[0:v]split=4[in0][in1][in2][in3];\
[in0]$TRANSCODER_VIDEO_GPU_SCALE_OPTIONS_720,split=2[out0][out1];\
[in1]$TRANSCODER_VIDEO_GPU_SCALE_OPTIONS_480[out2];\
[in2]$TRANSCODER_VIDEO_GPU_SCALE_OPTIONS_360,split=2[out3][out4];\
[in3]$TRANSCODER_VIDEO_GPU_SCALE_OPTIONS_270,split=2[out5][out6]'"
			output_dest="\
-map [out0] $TRANSCODER_VIDEO_GPU_ENCODE_OPTIONS_3500 -f mpegts udp://$TRANSCODER_OUTPUT_TS_DST_IP:$((TRANSCODER_OUTPUT_TS_DST_PORT+0))?pkt_size=$TRANSCODER_OUTPUT_TS_DST_PKT_SIZE \
-map [out1] $TRANSCODER_VIDEO_GPU_ENCODE_OPTIONS_2500 -f mpegts udp://$TRANSCODER_OUTPUT_TS_DST_IP:$((TRANSCODER_OUTPUT_TS_DST_PORT+1))?pkt_size=$TRANSCODER_OUTPUT_TS_DST_PKT_SIZE \
-map [out2] $TRANSCODER_VIDEO_GPU_ENCODE_OPTIONS_1200 -f mpegts udp://$TRANSCODER_OUTPUT_TS_DST_IP:$((TRANSCODER_OUTPUT_TS_DST_PORT+2))?pkt_size=$TRANSCODER_OUTPUT_TS_DST_PKT_SIZE \
-map [out3] $TRANSCODER_VIDEO_GPU_ENCODE_OPTIONS_800  -f mpegts udp://$TRANSCODER_OUTPUT_TS_DST_IP:$((TRANSCODER_OUTPUT_TS_DST_PORT+3))?pkt_size=$TRANSCODER_OUTPUT_TS_DST_PKT_SIZE \
-map [out4] $TRANSCODER_VIDEO_GPU_ENCODE_OPTIONS_500  -f mpegts udp://$TRANSCODER_OUTPUT_TS_DST_IP:$((TRANSCODER_OUTPUT_TS_DST_PORT+4))?pkt_size=$TRANSCODER_OUTPUT_TS_DST_PKT_SIZE \
-map [out5] $TRANSCODER_VIDEO_GPU_ENCODE_OPTIONS_400  -f mpegts udp://$TRANSCODER_OUTPUT_TS_DST_IP:$((TRANSCODER_OUTPUT_TS_DST_PORT+5))?pkt_size=$TRANSCODER_OUTPUT_TS_DST_PKT_SIZE \
-map [out6] $TRANSCODER_VIDEO_GPU_ENCODE_OPTIONS_250  -f mpegts udp://$TRANSCODER_OUTPUT_TS_DST_IP:$((TRANSCODER_OUTPUT_TS_DST_PORT+6))?pkt_size=$TRANSCODER_OUTPUT_TS_DST_PKT_SIZE \
"
		fi
	else
		log "Output destination not recognized: $output"
		return 1
	fi
	log "Output destination is: $output"

	cmd="$FFMPEG \
		-loglevel $TRANSCODER_LOGLEVEL \
		-strict experimental \
		-threads 2 \
		-buffer_size $TRANSCODER_BUFFER_SIZE \
		-protocol_whitelist file,udp,rtp \
		-i $sdp \
		-fifo_size $TRANSCODER_FIFO_SIZE \
		-smpte2110_timestamp 1 \
		-passlogfile $PASS_FILE \
		$audio_encode_options \
		-r 30 \
		$filter_options \
		$video_encode_options \
		$output_dest"

	log "$(echo -e "Command:\n$cmd" | sed 's/\t//g')"
	# start ffmpeg in a tmux session
	tmux new-session -d -s transcoder \
"$cmd 2>&1 | tee -a $LOG_FILE;
date | tee -a $LOG_FILE;
sleep 100;"
}

stop() {
	log "==================== Stop $(date) ===================="
	killall -INT $(basename $FFMPEG)
	tmux kill-session -t transcoder
	# cleanup log file
	sed -i -e 's///g' $LOG_FILE
}

cmd=$1
shift

case $cmd in
	help)
		help
		;;
	setup)
		if [ $# -lt 2 ]; then
			help
			exit 1
		fi
		iface=$1
		sdp=$2
		sudo $DIR/network_setup.sh $iface $sdp
		exit $?
		;;
	start)
		if pidof -s ffmpeg > /dev/null; then
			log "ffmpeg is running, stop it first"
			exit 1
		fi

		if [ $# -lt 1 ]; then
			help
			exit 1
		fi

		# parse options
		encode=cpu
		audio=aac
		output=ts
		while getopts ":e:a:o:" o; do
			case "${o}" in
				e)
					encode=${OPTARG}
					;;
				a)
					audio=${OPTARG}
					;;
				o)
					output=${OPTARG}
					;;
				*)
					help
					exit 1
					;;
			esac
		done
		shift $((OPTIND-1))
		if ! sdp=$(readlink -f $1); then
			log "Couldn't find SDP file $sdp"
			return 1
		fi

		start $sdp $encode $audio $output
		;;
	stop)
		stop
		;;
	log)
		# attach to tmux session, read-only, Ctrl-b + d to detach
		# Ctrl-b + Ctrl-b + d if tmux inside tmux
		tmux attach -r -t transcoder
		if [ ! $? -eq 0 ]; then
			tail -100 $LOG_FILE
		fi
		;;
	monitor)
		log "$(date) monitoring"
		# check the transcoder is running and restart if logfile is
		# getting too big
		if ! pidof -s ffmpeg > /dev/null; then
			log "ffmpeg is not running"
			exit 1
		fi
		log "ffmpeg is running"

		if [ ! -f "$PASS_FILE-0.log.mbtree.temp" ]; then
			exit 0
		fi

		size=$(du -m "$PASS_FILE-0.log.mbtree.temp" | cut -f 1)
		if [ $size -lt 1000 ]; then
			exit 0
		fi

		if [ ! -f $LOG_FILE ]; then
			log "couldn't find logfile $LOG_FILE"
			exit 1
		fi
		args=$(sed -n 's/^Start args: \(.*\)/\1/p' $LOG_FILE)

		stop
		start $args
		;;
	*)
		help
		exit 1
esac
