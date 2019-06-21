#!/bin/bash

SCRIPT=$(basename $0)
ST2110_CONF_FILE=/etc/st2110.conf

usage (){
    echo -e "$SCRIPT create routes to accept multicast traffic on a
given interface. The user must have privileged rights.

\t$SCRIPT <sdp_file>"
}

# network functions
mask2cdr ()
{
   # Assumes there's no "255." after a non-255 byte in the mask
   local x=${1##*255.}
   set -- 0^^^128^192^224^240^248^252^254^ $(( (${#1} - ${#x})*2 )) ${x%%.*}
   x=${1%%$3*}
   echo $(( $2 + (${#x}/4) ))
}

subnet ()
{
    ip=$1
    mask=$2
    IFS=. read -r i1 i2 i3 i4 <<< $ip
    IFS=. read -r m1 m2 m3 m4 <<< $mask
    printf "%d.%d.%d.%d\n" "$((i1 & m1))" "$((i2 & m2))" "$((i3 & m3))" "$((i4 & m4))"
}

cdr2mask ()
{
    # Number of args to shift, 255..255, first non-255 byte, zeroes
    set -- $(( 5 - ($1 / 8) )) 255 255 255 255 $(( (255 << (8 - ($1 % 8))) & 255 )) 0 0 0
    [ $1 -gt 1 ] && shift $1 || shift
    echo ${1-0}.${2-0}.${3-0}.${4-0}
}

if [ $# -ne 1 ]; then
    usage
    exit 1
fi
sdp_file=$1

if [ ! -f $ST2110_CONF_FILE ]; then
    echo "Couldn't find conf file $ST2110_CONF_FILE"
    exit 1
fi
source $ST2110_CONF_FILE

echo "-------------------------------------------"
echo "Local info:"
# join multicast groups through the media gateway
ipaddr=$(ip addr show $MEDIA_IFACE | sed -n "s/.*inet \(.*\)\/.*/\1/p")
cidr=$(ip addr show $MEDIA_IFACE | sed -n 's/.*inet .*\/\(.*\) brd.*/\1/p')
gateway=$(ip route | sed -n 's/default via \(.*\) dev '""$(echo $MEDIA_IFACE | tr -d '\n')""' .*/\1/p')
netmask=$(cdr2mask $cidr)
subnet=$(subnet $ipaddr $netmask)

echo "Address: $ipaddr
Gateway: $gateway
Netmask: $netmask
Subnet:  $subnet"

if [ -z $gateway -o -z $ipaddr -o -z $subnet ]; then
    echo "Missing network info, exit."
    exit 1
fi

# The unicast IP of the source should be accessible through the gateway.
# This is necessary for the reverse path resolution of the source in
# order to accept traffic. Let's find source and media info in the SDP.
source_ip="$(sed -n 's/^o=.*IN IP4 \(.*\)$/\1/p' $sdp_file | sed 's/\r//')"
multicast_groups=$(sed -n 's/^c=IN IP4 \(.*\)\/.*/\1/p' $sdp_file)
# get the port of the last essence which is associated to the last
# multicast group, i.e. $gr
port=$(sed -n 's/^m=.* \(.*\) RTP.*/\1/p' $sdp_file | tail -1)

echo "-------------------------------------------"
echo "Source/Sender:"
echo "Address: $source_ip
Multicast Groups: " $multicast_groups

if [ -z "$source_ip" -o -z "$multicast_groups" ]; then
    echo "Missing info in $sdp_file"
    exit 1
fi

# ip route add $subnet/$cidr via $gateway dev $MEDIA_IFACE
if ! ping -W 1 -I $MEDIA_IFACE -c 1 -q $source_ip > /dev/null; then
    echo "Couln't ping source @ $source_ip, add a  route to source"
    ip route add $source_ip via $gateway dev $MEDIA_IFACE

    # disable reverse path filtering, useless if explicit route is added"
    # sysctl -w net.ipv4.conf.all.rp_filter=0
    # sysctl -w net.ipv4.conf.$MEDIA_IFACE.rp_filter=0

    if ! ping -W 1 -I $MEDIA_IFACE -c 1 -q $source_ip > /dev/null; then
        echo "Couln't ping source @ $source_ip, exit."
        exit 1
    fi
fi

for gr in $multicast_groups;do
    if ! ip route | grep -q "$gr dev $MEDIA_IFACE scope link"; then
        echo "Add route for $gr"
        ip route add $gr dev $MEDIA_IFACE
    else
        echo "Route for $gr already exists."
    fi
done

echo "-------------------------------------------"
echo "Firewall:"
if iptables -C INPUT -d 224.0.0.0/4 -j ACCEPT 2> /dev/null
then
    echo "iptable rule for multicast rule already exists"
else
    iptables -I INPUT 1 -d 224.0.0.0/4 -j ACCEPT
    echo "Add a rule in firewall to allow incoming multicast"
fi

echo "-------------------------------------------"
echo "Rx test:"

dumpfile=/tmp/dump.log
socat -u UDP4-RECV:$port,ip-add-membership=$gr:$MEDIA_IFACE $dumpfile &
pid=$!
sleep 1
kill $pid

if [ ! -f $dumpfile ]; then
    echo "No data received."
    exit 1
fi

size=$(stat $dumpfile | sed -n 's/.*Size: \(.*\)\tBlocks:.*/\1/p')
echo "Received $size bytes in 1 sec"
rm -rf $dumpfile

exit 0
