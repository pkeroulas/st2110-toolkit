#!/bin/sh

FFMPEG=$(which ffmpeg)
LOG=/tmp/ffmpeg.log
DIR=$(dirname $0)
SCRIPT=$(basename $0)
ST2110_CONF_FILE=/etc/st2110.conf

if ! which $FFMPEG > /dev/null 2>&1
then
	echo "$FFMPEG is not installed, see install.sh"
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

# video
FFMPEG_SOFT_SCALE_OPTIONS="scale=1280:720"
# Sunday recommendation for IPTV
#FFMPEG_SOFT_VIDEO_ENCODE_OPTIONS="-pix_fmt yuv420p \
#	-c:v libx264 -profile:v main -preset fast -level:v 3.1 \
#	-b:v 2500k -bufsize:v 7000k -maxrate:v 2500k \
#	-g 30 -keyint_min 16 -b-pyramid""
FFMPEG_SOFT_VIDEO_ENCODE_OPTIONS="-pix_fmt yuv420p \
	-c:v libx264 -profile:v main -preset fast -level:v 3.1 \
	-b:v 2500k -bufsize:v 7000k -maxrate:v 2500k \
	-x264-params b-pyramid=1 \
	-g 30 -keyint_min 16 -pass 1 -refs 6"

# audio
FFMPEG_GPU_SCALE_OPTIONS="format=yuv420p,hwupload_cuda,scale_npp=w=1280:h=720:format=yuv420p:interp_algo=lanczos,hwdownload,format=yuv420p"
FFMPEG_GPU_VIDEO_ENCODE_OPTIONS="-c:v h264_nvenc -preset slow -cq 10 -bf 2 -g 150"

# output
TRANSCODER_DST_IP=localhost
TRANSCODER_DST_PORT=5000
TRANSCODER_DST_PKT_SIZE=1492

#  override params with possibly existing conf file
if [ -f $ST2110_CONF_FILE ]; then
	source $ST2110_CONF_FILE
fi

start() {
	sdp=$1
	echo "Transcoding from $sdp"

	# input buffer size: maximum value permitted by setsockopt
	buffer_size=671088640
	fifo_size=1000000000

	# increment port num for each output
    dst_port=$(($TRANSCODER_DST_PORT+$2))

	if [ $3 = "soft" ]; then
		scale_option=$FFMPEG_SOFT_SCALE_OPTIONS
		video_encode_option=$FFMPEG_SOFT_VIDEO_ENCODE_OPTIONS
	elif [ $3 = "gpu" ]; then
		scale_option=$FFMPEG_GPU_SCALE_OPTIONS
		video_encode_option=$FFMPEG_GPU_VIDEO_ENCODE_OPTIONS
	else
		echo "Encoding not supported: $3"
		return 1
	fi
	echo "Scaling and encoding is $3."

	cmd="$FFMPEG \
		-loglevel 48 \
		-strict experimental \
		-threads 2 \
		-buffer_size $buffer_size \
		-protocol_whitelist file,udp,rtp \
		-i $sdp \
		-fifo_size $fifo_size \
		-smpte2110_timestamp 1 \
		-vf yadif=0:-1:0,$scale_option \
		$video_encode_option \
		-c:a libfdk_aac -ac 2 -b:a 128k \
		-f mpegts udp://$TRANSCODER_DST_IP:$dst_port?pkt_size=$TRANSCODER_DST_PKT_SIZE \
	"

	echo "$cmd" | sed 's/\t//g'
	tmux new-session -d -s transcoder "$cmd ; sleep 100"

	echo "Stream available to $TRANSCODER_DST_IP:$dst_port"
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
		tmux kill-session -t transcoder
		;;
	log)
		tmux attach -t transcoder
		;;
	monitor)
		glances
		;;
	*)
		help
		exit 1
esac
