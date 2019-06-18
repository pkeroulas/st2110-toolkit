#!/usr/bin/env python2.7
import sys
import json
import hashlib
import time
from nmos_node import NmosNode
import os.path
import subprocess

def usage():
    print("""
node_poller.py - this script polls the NOMS connection API of a
\treceiver to get active connections and start ffmpeg transcoder to join
\tthe same multicast group.

Usage:
\tnode_poller.py <node_ip>

""")


def transcode(active, sdp_file):
    user=os.environ['ST2110_USER']
    transcoder='/home/'+user+'/st2110_toolkit/transcode.sh'
    if not active:
        res = subprocess.check_output([transcoder, 'stop'])
    else:
        res = subprocess.check_output([transcoder, 'start', sdp_file])
    print res

def poll(node):
    sdp_filename = "/tmp/sdp.sdp"
    os.remove(sdp_filename)
    previous_connection_status = False

    while True:
        time.sleep(2)
        print("-" * 72)
        for rx_id in node.get_ids():
            # get media type
            media_type = node.get_media_type(rx_id)
            msg = str(rx_id) + "(" + str(media_type) + ")"

            # get connection status
            connection_status = node.get_connection_status(rx_id)
            msg += ": active=" + str(connection_status)
            if not connection_status:
                print(msg)
                if previous_connection_status:
                    previous_connection_status = connection_status
                    transcode(False, 'dummy')
                    os.remove(sdp_filename)
                continue

            raw_sdp = node.get_connection_sdp(rx_id)
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
            if os.path.exists(sdp_filename):
                if (tmp_md5 == hashlib.md5(open(sdp_filename,'rb').read()).hexdigest()):
                    continue
                else:
                    print("SDP file updated: " + sdp_filename)
            else:
                print("New SDP file created: " + sdp_filename)
            os.rename(tmp_filename, sdp_filename)

            # restart transcoder
            transcode(False, 'dummy')
            transcode(True, sdp_filename)
            previous_connection_status = connection_status

def main():
    if len(sys.argv) < 2:
        usage()
        return

    node = NmosNode(sys.argv[1])
    poll(node)

if __name__ == "__main__":
    main()
