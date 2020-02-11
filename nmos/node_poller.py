#!/usr/bin/env python2.7

import sys
import json
import hashlib
import time
from nmos_node import NmosNode
import os.path
import subprocess
import re

def usage():
    print("""
node_poller.py - this script polls the NOMS connection API (IS-05) of a
\treceiver to get active connections and start ffmpeg transcoder to join
\tthe same multicast group.

Usage:
\tnode_poller.py <node_ip>

""")

def poller_log(msg):
    print("[poller] " + msg)

def transcode(active, sdp_file):
    user=os.environ['ST2110_USER']
    transcoder='/home/'+user+'/st2110-toolkit/transcode.sh'
    if not active:
        res = subprocess.check_output([transcoder, 'stop'])
    else:
        res = subprocess.check_output([transcoder, 'start', sdp_file])
    poller_log(res)

def poll(node):
    sdp_filename = "/tmp/sdp.sdp"
    if os.path.exists(sdp_filename):
        os.remove(sdp_filename)

    ids = node.get_ids()
    state = {}

    old_sdp_filtered=""

    while True:
        time.sleep(2)
        poller_log("-" * 72)
        # process every receiver of the node
        for rx_id in ids:
            # get connection status and sdp
            state[rx_id] = {}
            state[rx_id]['connection_status'] = node.get_connection_status(rx_id)
            state[rx_id]['sdp'] = node.get_connection_sdp(rx_id)
            state[rx_id]['media_type'] = node.get_media_type(rx_id)
            poller_log(rx_id +"(" + state[rx_id]['media_type'] + "): active=" + str(state[rx_id]['connection_status']) + " SDP=" + ("None" if state[rx_id]['sdp'] == None else "OK"))

        # combine SDPs into a single one for ffmpeg
        sdp_filtered=""
        sdp_already_has_description = False
        for rx_id in ids:
            if not state[rx_id]['connection_status'] or not state[rx_id]['sdp']:
                continue
            sdp = state[rx_id]['sdp']

            # remove -7 redundant stream by keeping 'primary' part of SDP only
            delimiter='m='
            sdp_chunks = [delimiter+e for e in sdp.split(delimiter) if e]
            sdp_chunks[0] = sdp_chunks[0][len(delimiter):]
            sdp = "".join([ i for i in sdp_chunks if 'primary' in i ])

            if not sdp_already_has_description:
                # 1st flow: keep description but add a separator
                expr = re.compile(r'(^t=.*\n)', re.MULTILINE)
                sdp = re.sub(expr, r'\1\n', sdp)
                sdp_already_has_description = True
            else:
                # other flows: skip description
                expr = re.compile(r'^o=.*\n|^v=.*\n|s=.*\n|t=.*\n', re.MULTILINE)
                sdp = re.sub(expr, '', sdp)

            sdp_filtered += sdp

        # do nothing when content hasn't changed
        if old_sdp_filtered == sdp_filtered:
            continue

        if sdp_filtered == "":
            # all the receivers are disabled
            transcode(False, 'dummy')
        else:
            # write re-arranged sdp file
            poller_log("SDP:\n" + str(sdp_filtered))
            file = open(sdp_filename, 'w')
            file.write(sdp_filtered)
            file.close()
            # restart transcoder
            transcode(False, 'dummy')
            transcode(True, sdp_filename)

        old_sdp_filtered = sdp_filtered

        #TODO: ffmpeg status?

def main():
    if len(sys.argv) < 2:
        usage()
        return

    node = NmosNode(sys.argv[1])
    poll(node)

if __name__ == "__main__":
    main()
