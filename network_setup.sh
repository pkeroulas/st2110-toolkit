#!/bin/bash

usage(){
    echo "Usage: $0 interface"
}

if [ -z $1 ]; then
    usage
    exit -1
fi

ETH=$1
GATEWAY=$(sed -n 's/GATEWAY=\(.*\)/\1/p' /etc/sysconfig/network-scripts/ifcfg-$ETH)

# access source unicast IP through the gateway
# this is necessary for the reverse path resolution
# of the source during multicast join
SOURCE_IP=172.30.64.160
SOURCE_MASK=27
MULTICAST=225.16.0.1
ip route add $SOURCE_IP/$SOURCE_MASK via $GATEWAY dev $ETH
ip route add $MULTICAST dev $ETH

# allow multicast
if iptables -C INPUT -d 224.0.0.0/4 -j ACCEPT 2> /dev/null
then
    echo "iptable rule for multicast rule already exists"
else
    iptables -I INPUT 1 -d 224.0.0.0/4 -j ACCEPT
fi

# disable reverse path filtering
# sysctl -w net.ipv4.conf.all.rp_filter=0
# sysctl -w net.ipv4.conf.$ETH.rp_filter=0

# input buffer
size=671088640
sysctl net.core.rmem_max=$size
sysctl net.core.rmem_default=$size

# NIC settings
ethtool -G $ETH rx 4096 # ring buffer
ethtool -K $ETH rx off # don't compute checksum
ethtool -C $ETH rx-usecs 48 # coalescence: interrupt moderation
