#!/bin/bash

show () {
    printf  "%-20.20s %s \n" "$1" "$2"
}

show_all () {
    socket_stat=$(ss -uamp | grep ffmpeg -A1 -m 1 | tr -s ' ')

    recvQ=$(echo $socket_stat | head -1 | cut -d ' ' -f2)
    alloc=$(echo $socket_stat | tail -1 | sed 's/^.*(r\(.*\),rb.*/\1/')
    alloc_max=$(echo $socket_stat | tail -1 | sed 's/^.*,rb\(.*\),t0.*/\1/')
    drop=$(echo $socket_stat | tail -1 | sed 's/^.*,d\(.*\)).*/\1/')

    show "Recv-Q" "$recvQ"
    show "alloc" "$alloc"
    show "alloc max" "$alloc_max"
    show "drop" "$drop"
}


 while true; do
     sleep 0.2
     tput cup 0 0
     show_all
 done
