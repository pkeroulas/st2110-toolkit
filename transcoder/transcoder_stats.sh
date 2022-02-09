#!/bin/bash

clear

PROCESS="ffmpeg"

show () {
    printf  "%-20.20s %-20.20s %s \n" "$1" "$2" "$3"
}

show_all () {
    pid=$(pidof $PROCESS)

    if [ -z $pid ]; then
        echo $PROCESS not running, exit.
        exit 1
    fi
    process_stat=$(ps -p $pid -o comm,pcpu,pmem,etimes,etime,args)
    uptime_sec=$(echo "$process_stat" | tail -n1 | tr -s ' ' | cut -d ' ' -f 4)
    echo "$process_stat"

    socket_stat=$(ss -uampn | grep $PROCESS -A1 -m 1 | tr -s ' ')
    recvQ=$(echo $socket_stat | head -1 | cut -d ' ' -f2)
    alloc=$(echo $socket_stat | tail -1 | sed 's/^.*(r\(.*\),rb.*/\1/')
    alloc_max=$(echo $socket_stat | tail -1 | sed 's/^.*,rb\(.*\),t0.*/\1/')
    drop=$(echo $socket_stat | tail -1 | sed 's/^.*,d\(.*\)).*/\1/')
    drop_per_sec=$(echo $drop/$uptime_sec | bc)

    show "Recv-Q"    "$recvQ"        "B"
    show "alloc"     "$alloc"        "B"
    show "alloc max" "$alloc_max"    "B"
    show "drop"      "$drop"         "B"
    show "drop/s"    "$drop_per_sec" "B/s"
}

 while true; do
     sleep 1
     tput cup 0 0
     show_all
 done
