#!/bin/bash

usage()
{
    echo "Get all SDP file through NMOS Connection API for a given 'IP:port'
$0 [-w] r|s IP[:port]
    -w      write to file, write to stdout by default
    r|s     get receivers OR senders
    IP      node IP
"
}

if [ $1 == "-w" ]; then
    WRITE=true
    shift
fi

direction=''
if [ $1 == "r" ]; then
    direction="receivers"
elif [ $1 == "s" ]; then
    direction="senders"
else
    usage
    exit 1
fi
shift

if [ -z $1 ]; then
    usage
    exit 1
fi

IP=$1
base_url="http:/$IP/x-nmos/connection/v1.1/single/$direction/"

echo "Get NMOS SDP @ $base_url"
list=$(curl $base_url 2>/dev/null | jq | sed -n 's/^  "\(.*\)".*/\1/p')

for id in $list; do
    url=${base_url}${id}active
    echo "---------------------------------"
    echo $id
    echo $url
    sdp=$(curl $url 2>/dev/null )

    if [ ! -n $WRITE ]; then
        sdpfile=$(echo "$sdp" | sed -n 's/^s=\(.*\)/\1/p' | sed 's/\r$//').sdp
        echo "New sdp file: $sdpfile"
        echo "$sdp" > ${sdpfile}
    else
        echo "$sdp"
    fi
done
