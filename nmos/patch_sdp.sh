#!/bin/bash

if [ $# -lt 4 ]; then
    echo "Usage: $0 <receiver IP[:port]> <receiver ID> <SDP file> <on|off>"
    exit 1
fi

# args
ip=$1
id=$2
sdp=$3
if [ $4 = "on" ]; then
    activate=true
else
    activate=false
fi

# sdp to json
dos2unix $sdp
transport_file=$(sed ':a;N;$!ba;s/\n/\\n/g' $sdp) # replace newlines with '\\n'
json_on='{"sender_id":null,"activation":{"mode":"activate_immediate","requested_time":null},"master_enable":'$activate',"transport_file":{"data":"'$transport_file'","type":"application/sdp"}}'
echo $json_on > $sdp.json

# sent to nmos uri
uri="http://${ip}/x-nmos/connection/v1.0/single/receivers/${id}/staged"
#echo "=== PATCH $json > $uri"
curl \
    -w "@$(dirname $0)/curl-format.txt" \
    --header "Content-Type: application/json" \
    -X PATCH \
    --data @"$sdp.json" \
    $uri
