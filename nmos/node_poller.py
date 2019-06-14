#!/usr/bin/env python2.7
import sys
import json
import hashlib
import time
from nmos_node import NmosNode
import os.path

def usage():
    print("""
node_poller.py - this script polls the NOMS connection API of a
\treceiver to get active connections and start ffmpeg transcoder to join
\tthe same multicast group.

Usage:
\tnode_poller.py <node_ip>

""")

def poll(node):
    print("-" * 72)
    receiver_id_list = node.get_receiver_ids()

    for receiver_id in receiver_id_list:
        # get media type
        media_type = node.get_media_type(receiver_id)
        msg = str(receiver_id) + "(" + str(media_type) + ")"

        # get connection status
        connection_status = node.get_connection_status(receiver_id)
        msg += ": active=" + str(connection_status)
        if not connection_status:
            print(msg)
            continue

        raw_sdp = node.get_connection_sdp(receiver_id)
        if raw_sdp == None:
            print(msg + ": SDP=None")
            continue
        else:
            print(msg + ": SDP=OK")

        # keep 'primary' part of SDP
        delimiter='m='
        sdp_chunks = [delimiter+e for e in raw_sdp.split(delimiter) if e]
        sdp_chunks[0] = sdp_chunks[0][len(delimiter):]

        # open file and write sdp chunk with 'primary' string inside
        tmp_filename = "/tmp/tmp.sdp"
        file = open(tmp_filename, 'w')
        for c in sdp_chunks:
            if 'primary' in c:
                file.write(c)
        file.close()
        tmp_md5 = hashlib.md5(open(tmp_filename,'rb').read()).hexdigest()
        #print("Tmp SDP file written: " + tmp_filename + "; md5: " + tmp_md5)

        # compare to previous
        filename = "/tmp/sdp.sdp"
        if os.path.exists(filename):
            md5 = hashlib.md5(open(filename,'rb').read()).hexdigest()
            if (tmp_md5 != md5):
                os.rename(tmp_filename, filename)
                print("SDP file updated: " + filename + "; md5: " + md5)
        else:
            print("New SDP file created: " + filename + "; md5: " + tmp_md5)
            os.rename(tmp_filename, filename)
        #TODO restart ffmpeg

def main():
    if len(sys.argv) < 2:
        usage()
        return

    while True:
        node = NmosNode(sys.argv[1])
        poll(node)
        time.sleep(2)

if __name__ == "__main__":
    main()
