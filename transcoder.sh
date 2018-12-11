#!/bin/sh

FFMPEG=ffmpeg
LOG=/tmp/ffmpeg.log
DIR=$(dirname $0)
SCRIPT=$(basename $0)

if ! which $FFMPEG > /dev/null 2>&1
then
	echo "$FFMPEG is not installed"
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
  $SCRIPT start <target_ip:target_port> <sdp_file1> [<sdp_file2> ... <sdp_fileN>]
  $SCRIPT log
  $SCRIPT stop"
}

start() {
	sdp=$1
	ip=$2
	port=$3
	echo "streaming to destination = $ip:$port"

	# input buffer size: maximum value permitted by setsockopt
	buffer_size=671088640
	fifo_size=1000000000

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
		-f mpegts udp://$ip:$port \
		> /dev/null 2> /dev/null \
		&
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
		if [ $# -lt 2 ]; then
			help
			exit 1
		fi

		destination_ip=$(echo $1 | cut -d : -f 1)
		destination_port=$(echo $1 | cut -d : -f 2)
		if [ -z $destination_ip -o -z $destination_port ]; then
			help
			exit -1
		fi
		shift

		echo "==================== $(date) ===================="
		for i in $@; do
			start $i $destination_ip $destination_port
			destination_port=$((destination_port+1))
		done
		;;
	stop)
		echo "==================== $(date) ===================="
		killall $FFMPEG
		;;
	log)
		tail -n 500 -f $LOG
		;;
	*)
		help
		exit 1
esac
