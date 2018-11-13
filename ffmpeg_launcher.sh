#!/bin/sh
#
# This initscript opens multiple instances of ffmpeg transcoders.
# Each of them reads an SDP file decode a specific SMPTE ST 2110
# stream, re-encodes it to h264. All the streams are redirected to the
# same destination but with different ports.

FFMPEG=ffmpeg

if ! which $FFMPEG > /dev/null 2>&1
then
    echo "$FFMPEG is not installed"
    exit -1
fi

# input buffer size: maximum value permitted by setsockopt
BUF_SIZE=671088640
FIFO_SIZE=1000000000

usage() {
	echo "$0 <start|stop> target_ip:target_port [<sdp_file1> <sdp_file2> ... <sdp_fileN>]"
}

launch() {
	sdp=$1
	ip=$2
	port=$3
	echo "streaming to destination = $ip:$port"

	$FFMPEG \
		-strict experimental \
		-threads 2 \
		-buffer_size $BUF_SIZE \
		-protocol_whitelist 'file,udp,rtp' \
		-i $sdp -fifo_size $FIFO_SIZE \
		-vf yadif=0:-1:0,scale=1280:720 \
		-c:v libx264 -preset ultrafast -pass 1 \
		-c:a libfdk_aac -ac 2 \
		-f mpegts udp://$ip:$port \
		&
}

cmd=$1
shift

case $cmd in
	start)
		if [ $# -lt 1 ]; then
			usage
			exit 1
		fi

		destination_ip=$(echo $1 | cut -d : -f 1)
		destination_port=$(echo $1 | cut -d : -f 2)
		if [ -z $destination_ip -o -z $destination_port ]; then
			usage
			exit -1
		fi
		shift

		for i in $@; do
			launch $i $destination_ip $destination_port
			destination_port=$((destination_port+1))
		done
		;;
	stop)
		killall $FFMPEG
		;;
	*)
		usage
		exit 1
esac
