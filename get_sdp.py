#!/usr/bin/env python2.7

import sys
import json
import urllib2
import re

def usage():
    print("""
getsdp.py - helper script to fetch SDP file from Embrionix sender and
\tkeep the 1st video, audio and anc essences.

Usage:
\tgetsdp.py <sender_ip>
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
    print("{}".format(sdp))

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

    sdp_filtered=""
    got_description = False
    # Let's keep the 1st video, audio and anc sections
    # See README.md:'Embrionix flows' for details
    sdp_indexes = [0, 2, 18]
    for s in sdp_indexes:
        url = get_sdp_url(ip_address) + str(sdp_list[s])
        sdp = str(get_from_url(url)+'\n')

        if not got_description:
            # 1st flow: keep description but add a separator
            expr = re.compile(r'(^t=.*\n)', re.MULTILINE)
            sdp = re.sub(expr, r'\1\n', sdp)
        else:
            # other flows: skip description
            expr = re.compile(r'^o=.*\n|^v=.*\n|s=.*\n|t=.*\n', re.MULTILINE)
            sdp = re.sub(expr, '', sdp)

        sdp_filtered += sdp
        got_description = True

    write_sdp_file(sdp_filtered)

if __name__ == "__main__":
    main()
