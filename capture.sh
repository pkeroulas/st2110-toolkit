#!/bin/bash

# default param
DURATION=2 # in sec
IFACE=enp101s0f1 # media interface

# const
CAPTURE=tmp.pcap
MAX_COUNT=100000
SCRIPT=$(basename $0)
DIR=$(dirname $0)

help() {
	echo -e "
$SCRIPT joins multicast groups and captures the incoming traffic in
file: <date>_<hostname>_<source_ip>.pcap. The user must have
privileged rights.

Usage:
\t$SCRIPT help
\t$SCRIPT setup <interface_name> <sdp_file>
\t$SCRIPT sdp <sdp_file>
\t$SCRIPT manual <network_interface> <mgroup> <duration(sec)>"
}

if [ -z $1 ]; then
	help
	exit 1
fi
cmd=$1
shift

case $cmd in
	help)
		help
		exit 1
		;;
	setup)
		if [ $# -lt 2 ]; then
			help
			exit 1
		fi
		IFACE=$1
		sdp=$2
		sudo $DIR/network_setup.sh $IFACE $sdp
		exit $?
		;;
	sdp)
		if [ $# -eq 0 ]; then
			help
			exit 1
		fi

		sdp=$1
		if [ ! -f $sdp ]; then
			echo "$sdp is not a file"
			exit 1
		fi

		source_ip=$(sed -n 's/^o=.*IN IP4 \(.*\)$/\1/p' $sdp | head 1)
		mcast_ips=$(sed -n 's/^a=.*IN IP4 \(.*\) .*$/\1/p' $sdp)
		;;
	manual)
		if [ $# -lt 3 ]; then
			help
			exit 1
		fi

		IFACE=$1
		mcast_ips=$2
		DURATION=$3
		source_ip="unknown"
		;;
	*)
		help
		exit 1
		;;
esac

if [ -z $mcast_ips ]; then
	echo "Missing multicast group"
	exit 1
fi

if [ $(cat /sys/class/net/$IFACE/operstate) != "up" ]; then
    echo "$IFACE is not up, exit."
    exit 1
fi

echo "------------------------------------------
Mcast IPs:
$mcast_ips" | tr ' ' '\n'

echo "------------------------------------------
Joining"

for m in $mcast_ips; do
	sudo smcroute -j $IFACE $m
done

echo "------------------------------------------
Capturing"

tcpdump -vvv -j adapter -i $IFACE -n "multicast" -c $MAX_COUNT -w $CAPTURE &
tcpdump_pid=$!

for i in $(seq $DURATION); do
	echo "$i sec ..."
	sleep 1
done

kill -0 $tcpdump_pid 2>/dev/null && kill $tcpdump_pid

echo "------------------------------------------
Leaving"

for m in $mcast_ips; do
	sudo smcroute -l $IFACE $m
done

if [ ! -f $CAPTURE ]; then
	echo "No capture file."
	exit 1
fi

FILENAME="$(date +%F_%T)_$(hostname)_$(echo $source_ip | tr . _).pcap"
mv $CAPTURE $FILENAME

echo "------------------------------------------
Output file:
$(du -h $FILENAME)"
