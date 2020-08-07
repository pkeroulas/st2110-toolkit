#!/bin/bash
#
# DPDK wrapper: translate tcpdump option to
# 1) smcroute (multicast join)
# 2) dpdk (ipacket capture)

timeout=2

wrapper_log(){
    echo "wrapper: $@"
}

wrapper_log "Parse args: ------------------------------------------ "

#  typical cmdline to be translated:
#  $ tcpdump -i interfaceName --time-stamp-precision=nano \
#   -j adapter_unsynced\--snapshot-length=N -w pcap -G 2 -W 1 \
#   dst 192.168.1.1 or dst 192.168.1.2
while getopts ":i:w:G:W:" o; do
    case "${o}" in
        i | interface)
            iface=${OPTARG}
            ;;
        j)
            ;;
        #-)
        #    case ${OPTARG} in
        #        time-stamp-precision*)
        #            ;;
        #        snapshot-length*)
        #            ;;
        #    esac
        #    ;;
        w)
            pcap=${OPTARG}
            ;;
        G)
            timeout=${OPTARG}
            ;;
        W)
            #ignore file number
            ;;
        *)
            wrapper_log  "unsupported option ${o}"
            ;;
    esac
done
shift $((OPTIND-1))

if [ -z $iface -o -z $pcap ]; then
    wrapper_log "Missing argument"
    exit 1
fi

filter=$@
IPs=$(echo $filter | sed 's/dst//g; s/or//g' | tr -s ' ' '\n')

wrapper_log "iface: $iface
pcap: $pcap
filter: $filter
timeout: $timeout"

wrapper_log "Checking interface: $iface ------------------------------------------ "

if [ ! -d /sys/class/net/$iface ]; then
	wrapper_log "$iface doesn\'t exist, exit."
	exit 1
fi
if [ $(cat /sys/class/net/$iface/operstate) != "up" ]; then
	wrapper_log "$iface is not up, exit."
	exit 1
fi

wrapper_log "Joining mcast: $IPs ------------------------------------------ "

if ! smcroutectl show > /dev/null; then
    smcrouted
fi

for ip in $IPs; do
	smcroutectl join $iface $ip
	if ! netstat -ng | grep -q "$iface.*$ip"; then
		wrapper_log "Can\'t joint $ip"
	fi
done

netstat -ng | grep $iface

# dpdk
wrapper_log "Capturing------------------------------------------"

dpdk-testpmd-pdump.sh \
    -v -i $iface -w $pcap -t $timeout

wrapper_log "Leaving mcast ------------------------------------------"

for ip in $IPs; do
	smcroutectl leave $iface $ip
done
