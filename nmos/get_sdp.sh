#!/bin/bash
# get all SDP file through NMOS API for a given IP
# SDP are in the redundant format

IP=$1

if [ -z $1 ]; then
    echo "Provide IP, exit"
    exit 1
fi

if ! ping -c 1 $IP; then
    echo "Not pingable, exit."
    exit 1
fi

base_url="http:/$IP/x-nmos/connection/v1.0/single/senders/"

echo "Get NMOS senders @ $base_url"
list=$(curl $base_url 2>/dev/null | jq | sed -n 's/^  "\(.*\)".*/\1/p')

for id in $list; do
    url=${base_url}${id}transportfile
    sdp=$(curl $url 2>/dev/null )
    sdpfile=$(echo "$sdp" | sed -n 's/^s=\(.*\)/\1/p' | sed 's/\r$//').sdp
    echo "New sdp file: $sdpfile"
    echo "$sdp" > ${sdpfile}
done
