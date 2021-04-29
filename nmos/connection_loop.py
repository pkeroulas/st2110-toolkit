#!/usr/bin/env python3

import sys
from nmos_node import NmosNode
import time

def usage():
    print("""
connection_loop.py - this script connects a sender to a receiver
node based on connection API (IS-05).

Usage:
\tconnection_loop.py <sender_node_ip> <receiver_node_ip>

""")

def active(tx, rx, state):
    tx.activate_all(tx_ch, state)
    rx.activate_all(rx_ch, state)

def patch_flow(name, tx, rx, tx_ch, rx_ch):
    connection_log('    {}[{}] -> {}[{}]'.format(name, tx_ch, name, rx_ch))
    rx.set_connection_sdp(rx.connections[rx_ch][name]['id'], tx.connections[tx_ch][name]['id'], tx.get_sdp(tx.connections[tx_ch][name]['id']))
    #TODO verify sdp

def patch_channel(tx, rx, tx_ch, rx_ch):
    connection_log('{}[{}] -> {}[{}]'.format(tx.ip, tx_ch, rx.ip, rx_ch))
    patch_flow('vid ', tx, rx, tx_ch, rx_ch)
    patch_flow('aud1', tx, rx, tx_ch, rx_ch)
    patch_flow('aud1', tx, rx, tx_ch, rx_ch)
    patch_flow('anc ', tx, rx, tx_ch, rx_ch)

def connection_log(msg):
    print("[connection] " + msg)

def main():
    if len(sys.argv) < 3:
        usage()
        return

    tx = NmosNode(ip = sys.argv[1], type = 'tx')
    rx = NmosNode(ip = sys.argv[2], type = 'rx')

    #TODO: add counter and timestampt
    while True:
        #TODO activate
        connection_log('*' * 72)
        tx.update_connections()
        rx.update_connections()
        patch_channel(tx,rx,0,0)
        patch_channel(tx,rx,1,1)
        time.sleep(2)
        patch_channel(tx,rx,0,1)
        patch_channel(tx,rx,1,0)
        time.sleep(2)

if __name__ == "__main__":
    main()
    connection_log("Exit.")
