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
	echo "
$SCRIPT opens multiple instances of ffmpeg transcoders.
Each of them reads an SDP file decode a specific SMPTE ST 2110
stream, re-encodes it to h264. All the streams are redirected to the
same destination but with different ports.

Usage:
  $SCRIPT help
  $SCRIPT setup <interface_name> <sdp_file>
  $SCRIPT start <sdp_file1> [<sdp_file2> ... <sdp_fileN>]
  $SCRIPT log
  $SCRIPT stop"
}

start() {
	sdp=$1
	echo "Transcoding from $sdp"

	# input buffer size: maximum value permitted by setsockopt
	buffer_size=671088640
	fifo_size=1000000000
	proxy_port=500$2

	FFREPORT=file=$LOG:level=48 \
	$FFMPEG \
		-strict experimental \
		-threads 2 \
		-buffer_size $buffer_size \
		-protocol_whitelist 'file,udp,rtp' \
		-i $sdp -fifo_size $fifo_size \
		-smpte2110_timestamp 1 \
		-vf yadif=0:-1:0,scale=1280:720 \
		-c:v libx264 -preset ultrafast -pass 1 \
		-c:a libfdk_aac -ac 2 \
		-f mpegts udp://localhost:$proxy_port \
		> /dev/null 2> /dev/null \
		&

	server_port=800$2
	echo "Stream available on port $server_port"
	nc -l -p $server_port | $SERVER &
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
		sudo $DIR/network_setup.sh $sdp $iface
		;;
	start)
		if [ $# -lt 1 ]; then
			help
			exit 1
		fi

		echo "==================== Start $(date) ===================="
		i=0
		for sdp in $@; do
			start $sdp $i
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
