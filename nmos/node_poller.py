#!/usr/bin/env python2.7

import sys
import json
import urllib2
import hashlib
import sleep

def usage():
    print("""
nmos_node_poller.py - this script polls the NOMS connection API of a
\treceiver to get active connections and start ffmpeg transcoder to join
\tthe same multicast group.

Usage:
\nmos_node_poller.py <node_ip>

""")

def get_connection_url(ip):
    return "http://" + ip + "/x-nmos/connection/v1.0/single/receivers/"

def get_from_url(url):
    try:
        content = urllib2.urlopen(url, timeout=1).read()
    except urllib2.HTTPError:
        print("Unable to fetch connection")

    return content


def poll(ip_address):
    url = get_connection_url(ip_address)
    content = get_from_url(url)

    try:
       connection_list =  json.loads(content)
    except:
        print("Unable to parse json of active connection")
        return

    for connection_id in connection_list:
        print("-" * 72)
        url = get_connection_url(ip_address) + str(connection_id) + "active/"
        content = get_from_url(url)
        connection = json.loads(content)
        if not connection['master_enable'] or not connection['activation']['mode']:
            continue

        print(json.dumps(connection, indent=1))
        raw_sdp = connection['transport_file']['data']

        delimiter='m='
        sdp_chunks = [delimiter+e for e in raw_sdp.split(delimiter) if e]

        sdp_chunks[0] = sdp_chunks[0][len(delimiter):]

        # open file and write sdp chunk with 'primary' string inside
        tmp_filename = "/tmp/tmp.sdp"
        file = open(tmp_filename, 'w')
        for c in sdp_chunks:
            if 'primary' in c:
                print("-"*8)
                print c
                file.write(c)

        file.close()
        tmp_md5 = hashlib.md5(open(tmp_filename,'rb').read()).hexdigest()
        print("Tmp SDP file written: " + tmp_filename + "; md5: " + tmp_md5)

        filename = "/tmp/sdp.sdp"
        md5 = hashlib.md5(open(filename,'rb').read()).hexdigest()
        if (tmp_md5 != md5):
            os.rename(tmp_filename, filename)
            print("SDP file written: " + filename + "; md5: " + md5)
        #TODO write to tmp, compare md5, mv if diff restart ffmpeg

def main():
    if len(sys.argv) < 2:
        usage()
        return

    while true:
        poll(sys.argv[1])
        time.sleep(2)

if __name__ == "__main__":
    main()
