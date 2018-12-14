#!/bin/bash

# const
CAPTURE=tmp.pcap
MAX_COUNT=100000
SCRIPT=$(basename $0)

help() {
	echo "
$SCRIPT joins multicast groups and captures the incoming traffic in the
file: <date>_<hostname>_<source_ip>.pcap
Usage:
    $SCRIPT <network_interface> <mgroup> <port> <duration(sec)>"
}

if [ $# -lt 4 ]; then
    help
    exit 1
fi

IFACE=$1
DURATION=$4
# TODO get this from SDP given sender's unicast @
mgroup=$2 #239.0.0.15
port=$3  #20000

tcpdump -vvv -j adapter -i $IFACE -n "multicast" -c $MAX_COUNT -w $CAPTURE &
tcpdump_pid=$!
socat -u UDP4-RECV:$port,ip-add-membership=$mgroup:$IFACE /dev/null &
socat_pid=$!

for i in $(seq $DURATION); do
    echo "$i sec"
    sleep 1
done

kill -0 $tcpdump_pid && kill $tcpdump_pid
kill -0 $socat_pid && kill $socat_pid

if [ ! -f $CAPTURE ]; then
    echo "No capture file."
    exit 1
fi

FILENAME="$(date +%F_%T)_$(hostname)_$(echo $SOURCE | tr . _).pcap"
mv $CAPTURE $FILENAME

echo "Outputfile: $FILENAME"
