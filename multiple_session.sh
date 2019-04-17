#!/bin/bash
#
# This helper script aims at using multiple hosts in //
# using tmux

N=2

workflow_bash()
{
    for i in $(seq 0 $N); do
        tmux split -h ssh transcoder_$i
    done

    tmux select-layout even-horizontal
    # tmux setw synchronize-panes on

    exit
}

workflow_scp()
{
    set -x
    for i in $(seq 0 $N); do
        scp $1 transcoder_$i:$2
    done
    set +x
}

workflow_ffplay()
{
    for i in $(seq 0 $N); do
        tmux split -h ffplay udp://localhost:500$i
    done

    tmux select-layout even-horizontal
    exit
}
