#!/bin/sh

FFMPEG=ffmpeg
SERVER=mkvserver
LOG=/tmp/ffmpeg.log
DIR=$(dirname $0)
SCRIPT=$(basename $0)

if ! which $FFMPEG > /dev/null 2>&1
then
	echo "$FFMPEG is not installed, see install.sh"
	exit -1
fi

if ! which $SERVER > /dev/null 2>&1
then
	echo "$SERVER is not installed, see install.sh"
	exit -1
fi

help() {
	echo -e "
$SCRIPT opens multiple instances of ffmpeg transcoders.
Each of them reads an SDP file decode a specific SMPTE ST 2110
stream, re-encodes it to h264. All the streams are redirected to the
same destination but with different ports.

Usage:
\t$SCRIPT help
\t$SCRIPT setup <interface_name> <sdp_file>
\t$SCRIPT start [--soft|--gpu] <sdp_file1> [<sdp_file2> ... <sdp_fileN>]
\t$SCRIPT log
\t$SCRIPT stop"
}

FFMPEG_SOFT_SCALE_OPTIONS="scale=1280:720"
FFMPEG_SOFT_ENCODE_OPTIONS="libx264 -preset ultrafast -pass 1"

FFMPEG_GPU_SCALE_OPTIONS="format=yuv420p,hwupload_cuda,scale_npp=w=1080:h=720:format=yuv420p:interp_algo=lanczos,hwdownload,format=yuv420p"
FFMPEG_GPU_ENCODE_OPTIONS="h264_nvenc -preset slow -cq 10 -bf 2 -g 150"

start() {
	sdp=$1
	echo "Transcoding from $sdp"

	# input buffer size: maximum value permitted by setsockopt
	buffer_size=671088640
	fifo_size=1000000000
	proxy_port=500$2

	if [ $3 = "soft" ]; then
		scale_option=$FFMPEG_SOFT_SCALE_OPTIONS
		encode_option=$FFMPEG_SOFT_ENCODE_OPTIONS
	elif [ $3 = "gpu" ]; then
		scale_option=$FFMPEG_GPU_SCALE_OPTIONS
		encode_option=$FFMPEG_GPU_ENCODE_OPTIONS
	else
		echo "Encoding not supported: $3"
		return 1
	fi
	echo "Scaling and encoding is $3."

	FFREPORT=file=$LOG:level=48 \
	$FFMPEG \
		-strict experimental \
		-threads 2 \
		-buffer_size $buffer_size \
		-protocol_whitelist 'file,udp,rtp' \
		-i $sdp -fifo_size $fifo_size \
		-smpte2110_timestamp 1 \
		-vf yadif=0:-1:0,$scale_option \
		-c:v $encode_option \
		-c:a libfdk_aac -ac 2 \
		-f mpegts udp://localhost:$proxy_port \
		> /dev/null 2> /dev/null \
		&

	nc -l -p $proxy_port | $SERVER > /dev/null &
	echo "Stream available on port 8080 (harcoded in $SERVER)"
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
		if [ $# -lt 1 ]; then
			help
			exit 1
		fi

		if [ $1 = "--gpu" ]; then
			encode="gpu"
			shift
		elif [ $1 = "--soft" ]; then
			encode="soft"
			shift
		else
			encode="soft"
		fi

		echo "==================== Start $(date) ===================="
		i=0
		for sdp in $@; do
			start $sdp $i $encode
			i=$((i+1))
		done
		;;
	stop)
		echo "==================== Stop $(date) ===================="
		killall $FFMPEG
		killall $SERVER
		killall nc
		;;
	log)
		tail -n 500 -f $LOG
		;;
	*)
		help
		exit 1
esac
