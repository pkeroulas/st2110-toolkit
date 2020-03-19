#!/bin/bash
SCRIPT=$(basename $0)
ST2110_CONF_FILE=/etc/st2110.conf

usage (){
    echo -e "$SCRIPT configure the NIC of the media port for optimization.
The user must have privileged rights.

\t$SCRIPT <media_interface>"

}

if [ $# -ne 1 ]; then
    usage
    exit 1
fi

media_iface=$1

echo "-------------------------------------------"
echo "Check interface:"

if [ ! -d /sys/class/net/$media_iface ]; then
    echo "$media_iface is not a network interface."
    exit 1
fi

if [ $(cat /sys/class/net/$media_iface/operstate) != "up" ]; then
    echo "$media_iface is not up, exit."
    exit 1
fi

echo "$media_iface: OK"

# save interface in the config
if [ ! -f $ST2110_CONF_FILE ]; then
    echo "MEDIA_IFACE=$media_iface" > $ST2110_CONF_FILE
elif grep -q "MEDIA_IFACE=.*" $ST2110_CONF_FILE; then
    sed -i 's/\(MEDIA_IFACE=\).*/\1'$media_iface'/' $ST2110_CONF_FILE
else
    echo "MEDIA_IFACE=$media_iface" >> $ST2110_CONF_FILE
fi


echo "-------------------------------------------"
echo "Setup input buffer:"
buffer_size=671088640
sysctl net.core.rmem_max=$buffer_size
sysctl net.core.rmem_default=$buffer_size

echo "-------------------------------------------"
echo "Setup interface $media_iface:"
ethtool -G $media_iface rx 4096 # ring buffer
ethtool -K $media_iface rx off # don't compute checksum
ethtool -C $media_iface rx-usecs 48 # coalescence: interrupt moderation

exit 0
