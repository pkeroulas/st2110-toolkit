#!/usr/bin/env python3
import sys
import json
from nmos_node import NmosNode
import time

def usage():
    print("""
node_connection.py - this script (dis)activates a sender or a receiver
node based on connection API (IS-05).

Usage:
\tnode_connection.py <sender_node_ip> <receiver_node_ip> <start|stop>

""")

def connection_log(msg):
    print("[connection] " + msg)

def main():
    if len(sys.argv) < 4:
        usage()
        return

    sender = NmosNode(ip = sys.argv[1], type = 'tx')
    receiver = NmosNode(ip = sys.argv[2], type = 'rx')
    state = True if sys.argv[3] == 'start' else False

    connection_log("Disactivate all rx")
    #receiver.activate_all(False)
    if not state:
        return

    # For Embrionix EMSFP: 1st is video and 2nd is audio
    for tx_id in sender.get_ids()[:2]:
        connection_log("*" * 72)
        connection_log("Activate tx id:" + tx_id)
        sender.activate(state, tx_id)

        connection_log("GET tx SDP from tx id:" + tx_id)
        sdp = sender.get_sdp(tx_id)
        if 'video' in sdp:
            connection_log("Video detected")
            rx_id = receiver.get_video_id()
        elif 'audio' in sdp:
            connection_log("Audio detected")
            rx_id = receiver.get_audio_id()
        else:
            connection_log("unknown media in sdp:" + sdp)
            return

        connection_log("PATCH rx id:" + rx_id)
        receiver.set_connection_sdp(rx_id, tx_id, sdp)
        connection_log("Activate rx id:" + rx_id)
        receiver.activate(state, rx_id)

        #connection_log("..............")
        #time.sleep(2)
        #connection_log(receiver.get_connection_status(rx_id))
        #connection_log(receiver.get_connection_sdp(rx_id))

if __name__ == "__main__":
    main()
    connection_log("Exit.")
