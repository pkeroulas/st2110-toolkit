#!/usr/bin/env python2.7
import sys
import json
import hashlib
import time
from common_api import *
import os.path

def usage():
    print("""
node_poller.py - this script polls the NOMS connection API of a
\treceiver to get active connections and start ffmpeg transcoder to join
\tthe same multicast group.

Usage:
\tnode_poller.py <node_ip>

""")

def poll(ip_address):
    print("-" * 72)
    base_url = get_connection_receiver_url(ip_address)

    try:
       connection_list = get_from_url(base_url)
    except:
        print("Unable to parse json of active connection")
        return

    for connection_id in connection_list:
        url = base_url + str(connection_id) + "active/"
        connection = get_from_url(url)
        if not connection['master_enable'] or not connection['activation']['mode']:
            print(str(connection_id) + ": active=False")
            continue

        #print(json.dumps(connection, indent=1))
        raw_sdp = connection['transport_file']['data']
        if raw_sdp == None:
            print(str(connection_id) + ": SDP=None")
            continue
        else:
            print(str(connection_id) + ": SDP=OK")

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
        poll(sys.argv[1])
        time.sleep(2)

if __name__ == "__main__":
    main()
