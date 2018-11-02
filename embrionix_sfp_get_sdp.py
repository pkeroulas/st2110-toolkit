#!/usr/bin/env python2.7

import sys
import json
import urllib2

def usage():
    print("""
embrionix_sfp_sdp.py - helper script to fetch SDP file from Embrionix sender
Usage:
\tembrionix_sfp_sdp.py <sender_ip>
""")

def get_sdp_url(ip):
    return "http://" + ip + "/emsfp/node/v1/sdp/"

def get_from_url(url):
    try:
        read = urllib2.urlopen(url).read()
        print(read)
    except urllib2.HTTPError:
        print("Unable to fetch SDP")
    finally:
        print("-" * 25)

    return read

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

    for i, id in enumerate(sdp_list, start=1):
        sdp_url = get_sdp_url(ip_address) + id
        print("{}/{} <{}>".format(i, len(sdp_list), sdp_url))
        get_from_url(sdp_url)

if __name__ == "__main__":
    main()
