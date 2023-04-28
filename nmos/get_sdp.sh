#!/bin/bash

usage()
{
    echo "Get all SDP file through NMOS Connection API for a given
    'IP:port'. Works well only in both IS-04 and IS-05 run on the same
    port.
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
connection_base_url="http:/$IP/x-nmos/connection/v1.1/single/$direction/"
node_base_url="http:/$IP/x-nmos/node/v1.2/$direction/"

echo "Get NMOS SDP @ $connection_base_url"
curl $connection_base_url 2>/dev/null
list=$(curl $connection_base_url 2>/dev/null | jq | sed -n 's/^  "\(.*\)".*/\1/p') # remove leading spaces

for id in $list; do
    url=${connection_base_url}${id}active
    echo "---------------------------------"
    echo $url
    id_no_slash=$(echo $id | sed 's;\/;;') # remove '/'
    curl $node_base_url 2>/dev/null | jq ".[] | select( .id == \"$id_no_slash\").label"
    curl $node_base_url 2>/dev/null | jq ".[] | select( .id == \"$id_no_slash\").caps.media_types"
    sdp=$(curl $url 2>/dev/null )

    if [ ! -n $WRITE ]; then
        sdpfile=$(echo "$sdp" | sed -n 's/^s=\(.*\)/\1/p' | sed 's/\r$//').sdp
        echo "New sdp file: $sdpfile"
        echo "$sdp" > ${sdpfile}
    else
        echo "$sdp"
    fi
done
