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
\t$SCRIPT help      # show this message
\t$SCRIPT log       # show live ffmpeg output
\t$SCRIPT monitor   # show resource usage
\t$SCRIPT setup <interface_name> <sdp_file>
\t\t                  # generate conf from sdp and interface
\t$SCRIPT start [-e <cpu|gpu>] [-a <aac|ac3>] <sdp_file1> [<sdp_file2> ... <sdp_fileN>]
\t\t                  # start ffmpeg instances
\t$SCRIPT stop      # stop ffmpeg instances
"
}

TRANSCODER_LOGLEVEL=debug
# input buffer size: maximum value permitted by setsockopt
TRANSCODER_BUFFER_SIZE=671088640
TRANSCODER_FIFO_SIZE=1000000000

# video
TRANSCODER_VIDEO_CPU_SCALE_OPTIONS="scale=1280:720"
# Sunday recommendation for IPTV
#TRANSCODER_VIDEO_CPU_ENCODE_OPTIONS="-pix_fmt yuv420p \
#	-c:v libx264 -profile:v main -preset fast -level:v 3.1 \
#	-b:v 2500k -bufsize:v 7000k -maxrate:v 2500k \
#	-g 30 -keyint_min 16 -b-pyramid""
TRANSCODER_VIDEO_CPU_ENCODE_OPTIONS="-pix_fmt yuv420p \
	-c:v libx264 -profile:v main -preset fast -level:v 3.1 \
	-b:v 2500k -bufsize:v 7000k -maxrate:v 2500k \
	-x264-params b-pyramid=1 \
	-g 30 -keyint_min 16 -pass 1 -refs 6"
# 48% cpu, 21% mem, stable

TRANSCODER_VIDEO_GPU_SCALE_OPTIONS="format=yuv420p,hwupload_cuda,scale_npp=w=1280:h=720:format=yuv420p:interp_algo=lanczos,hwdownload,format=yuv420p"
TRANSCODER_VIDEO_GPU_ENCODE_OPTIONS=" \
	-c:v h264_nvenc -rc cbr_hq -preset:v fast -profile:v main -level:v 4.1 \
	-b:v 2500k -bufsize:v 7000k -maxrate:v 2500k \
	-g 30 -keyint_min 16 -pass 1 -refs 6"
# cbr doesn't work. measure=1-10Mbps
# -level 3.1 not accepted
# 35% cpu, 21% mem, stable

# audio
TRANSCODER_AUDIO_ENCODE_AC3="-c:a ac3 -ac 6 -b:a 340k"
TRANSCODER_AUDIO_ENCODE_AAC="-c:a libfdk_aac -ac 2 -b:a 128k"

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
	id=$2
	encode=$3
	audio=$4
	echo "Transcoding from $sdp"

	# increment port num for each output
	dst_port=$(($TRANSCODER_DST_PORT+$id))

	if [ $encode = "cpu" ]; then
		video_scale_options=$TRANSCODER_VIDEO_CPU_SCALE_OPTIONS
		video_encode_options=$TRANSCODER_VIDEO_CPU_ENCODE_OPTIONS
	elif [ $encode = "gpu" ]; then
		video_scale_options=$TRANSCODER_VIDEO_GPU_SCALE_OPTIONS
		video_encode_options=$TRANSCODER_VIDEO_GPU_ENCODE_OPTIONS
	else
		echo "Encoding not supported: $encode"
		return 1
	fi
	echo "Scaling and encoding is $encode."

	if [ $audio = "aac" ]; then
		audio_encode_options=$TRANSCODER_AUDIO_ENCODE_AAC
	elif [ $audio = "ac3" ]; then
		audio_encode_options=$TRANSCODER_AUDIO_ENCODE_AAC
	else
		echo "Audio codec not supported: $audio"
		return 1
	fi
	echo "Audio codec is $audio."

	cmd="$FFMPEG \
		-loglevel $TRANSCODER_LOGLEVEL \
		-strict experimental \
		-threads 2 \
		-buffer_size $TRANSCODER_BUFFER_SIZE \
		-protocol_whitelist file,udp,rtp \
		-i $sdp \
		-fifo_size $TRANSCODER_FIFO_SIZE \
		-smpte2110_timestamp 1 \
		-vf yadif=0:-1:0,$video_scale_options \
		$video_encode_options \
		$audio_encode_options \
		-f mpegts \
		udp://$TRANSCODER_DST_IP:$dst_port?pkt_size=$TRANSCODER_DST_PKT_SIZE \
	"

	echo "Command:\n$cmd" | sed 's/\t//g'
	tmux new-session -d -s transcoder "$cmd 2>&1 | tee "$LOG"; sleep 100"
	if [ $? -eq 0 ]; then
		echo "Stream available to $TRANSCODER_DST_IP:$dst_port"
	fi
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

		# parse options
		encode=cpu
		audio=aac
		while getopts ":e:a:" o; do
			case "${o}" in
				e)
					encode=${OPTARG}
					;;
				a)
					audio=${OPTARG}
					;;
				*)
					help
					exit 1
					;;
			esac
		done
		shift $((OPTIND-1))

		echo "==================== Start $(date) ====================" | tee $LOG
		i=0
		for sdp in $@; do
			start $sdp $i $encode $audio
			i=$((i+1))
		done
		;;
	stop)
		killall -INT $(basename $FFMPEG)
		tmux kill-session -t transcoder
		echo "==================== Stop $(date) ====================" | tee $LOG
		# cleanup log file
		sed -i -e 's///g' $LOG
		;;
	log)
		tmux attach -t transcoder
		if [ ! $? -eq 0 ]; then
			tail -100 $LOG
		fi
		;;
	monitor)
		glances
		;;
	*)
		help
		exit 1
esac
