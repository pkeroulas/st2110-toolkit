#!/bin/bash
#
# DPDK wrapper: translate tcpdump option to
# 1) smcroute (multicast join)
# 2) dpdk (ipacket capture)

echo "------------------------------------------
Parse args:"

#  typical cmdline to be translated:
#  $ tcpdump -i interfaceName --time-stamp-precision=nano \
#   -j adapter_unsynced\--snapshot-length=N -w pcap \
#   dst 192.168.1.1 or dst 192.168.1.2

while getopts ":i:w:" o; do
    case "${o}" in
        i | interface)
            iface=${OPTARG}
            ;;
        j)
            ;;
        -)
            case ${OPTARG} in
                time-stamp-precision*)
                    ;;
                snapshot-length*)
                    ;;
            esac
            ;;
        w)
            pcap=${OPTARG}
            ;;
        *)
            echo  "unsupported option"
            ;;
    esac
done
shift $((OPTIND-1))

if [ -z $iface -o -z $pcap ]; then
    echo "Missing argument"
    exit 1
fi

filter=$@
IPs=$(echo $filter | sed 's/dst//g; s/or//g' | tr -s ' ' '\n')

echo "iface: $iface
pcap: $pcap
filter: $filter"

echo "------------------------------------------
Check interface $iface"

if [ ! -d /sys/class/net/$iface ]; then
	echo "$iface doesn't exist, exit."
	exit 1
fi
if [ $(cat /sys/class/net/$iface/operstate) != "up" ]; then
	echo "$iface is not up, exit."
	exit 1
fi

echo "------------------------------------------
Joining mcast: $IPs"

if ! smcroutectl show > /dev/null; then
    smcrouted
fi

for ip in $IPs; do
	smcroutectl join $iface $ip
	if ! netstat -ng | grep -q "$iface.*$ip"; then
		echo "Can't joint $ip"
	fi
done

netstat -ng | grep $iface

# TODO: create filter

duration=2
# dpdk
echo "------------------------------------------
Capturing"
/home/ebulist/src/st2110-toolkit/capture/dpdk/dpdk-testpmd-pdump.sh \
    -v -i $iface -w $pcap -t $duration

echo "------------------------------------------
Leaving mcast"

for ip in $IPs; do
	smcroutectl leave $iface $ip
done
