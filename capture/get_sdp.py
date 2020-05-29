#!/usr/bin/env python2.7

import sys
import json
import urllib2
import re

def usage():
    print("""
get_sdp.py - helper script to fetch SDP file from Embrionix sender and
\tand select multiple flows.

Usage:
\tget_sdp.py <sender_ip> [flow indexes]

examples:
\t$ ./get_sdp.py 192.168.1.10 # keep the flows from 1 SDI input: 0-19
\t$ ./get_sdp.py 192.168.1.10 0 2 18 # typically 1st video, 1st audio and 1st anc

See flow mapping in ../doc/embrionix.md
""")

def get_sdp_url(ip):
    return "http://" + ip + "/emsfp/node/v1/sdp/"

def get_from_url(url):
    try:
        sdp = urllib2.urlopen(url, timeout=1).read()
    except urllib2.HTTPError:
        print("Unable to fetch SDP")

    return sdp

def write_sdp_file(sdp):
    # get last digit of sender IP
    lines = re.findall(r'o=.*', sdp)
    source_ip = re.findall(r'[0-9]+(?:\.[0-9]+){3}', lines[0])[0]
    filename="emb_encap_" + source_ip.split(".")[3] + ".sdp"

    file = open(filename, 'w')
    file.write(sdp)
    file.close()

    print("-" * 72)
    print("SDP written to " + filename)

def main():
    if len(sys.argv) < 2:
        usage()
        return

    ip_address = sys.argv[1]
    url = get_sdp_url(ip_address)
    content = get_from_url(url)

    sdp_list = ""
    try:
        sdp_list = json.loads(content)
    except:
        print("Unable to parse json")
        return

    if sys.argv[2:]:
        flow_indexes = [int(i) for i in sys.argv[2:]];
    else:
        flow_indexes = [i for i in range(20)];

    print("-" * 72)
    print("Go fetch flows: {}".format(flow_indexes))
    sdp_filtered=""
    got_description = False
    for i in flow_indexes:
        url = get_sdp_url(ip_address) + str(sdp_list[i])
        sdp = str(get_from_url(url)) + '\n'

        if not got_description:
            # 1st flow: keep description but add a separator
            expr = re.compile(r'(^t=.*\n)', re.MULTILINE)
            sdp = re.sub(expr, r'\1\n', sdp)
        else:
            # other flows: skip description
            expr = re.compile(r'^o=.*\n|^v=.*\n|s=.*\n|t=.*\n', re.MULTILINE)
            sdp = re.sub(expr, '', sdp)

        print("-" * 72)
        print("Flow:{}\n{}".format(i,sdp))
        sdp_filtered += sdp
        got_description = True

    write_sdp_file(sdp_filtered)

if __name__ == "__main__":
    main()
