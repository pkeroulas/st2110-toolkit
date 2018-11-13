#!/bin/bash

usage(){
    echo "Usage: $0 interface"
}

if [ -z $1 ]; then
    usage
    exit -1
fi
ETH=$1

echo "Setup interface $ETH"
GATEWAY=$(sed -n 's/GATEWAY=\(.*\)/\1/p' /etc/sysconfig/network-scripts/ifcfg-$ETH)

# join multicast through the media gateway
MULTICAST=225.16.0.16
ip route add $MULTICAST dev $ETH

# source unicast IP should be accessible through the gateway
# this is necessary for the reverse path resolution
# of the source during multicast join
SOURCE_SUBNET_IP=172.30.64.160
SOURCE_MASK=27
ip route add $SOURCE_SUBNET_IP/$SOURCE_MASK via $GATEWAY dev $ETH

# disable reverse path filtering, not necessary if reverse path are already routed
# sysctl -w net.ipv4.conf.all.rp_filter=0
# sysctl -w net.ipv4.conf.$ETH.rp_filter=0

# allow incoming multicast
if iptables -C INPUT -d 224.0.0.0/4 -j ACCEPT 2> /dev/null
then
    echo "iptable rule for multicast rule already exists"
else
    iptables -I INPUT 1 -d 224.0.0.0/4 -j ACCEPT
fi

# input buffer
size=671088640
sysctl net.core.rmem_max=$size
sysctl net.core.rmem_default=$size

# NIC settings
ethtool -G $ETH rx 4096 # ring buffer
ethtool -K $ETH rx off # don't compute checksum
ethtool -C $ETH rx-usecs 48 # coalescence: interrupt moderation
