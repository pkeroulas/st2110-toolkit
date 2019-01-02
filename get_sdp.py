#!/usr/bin/env python2.7

import sys
import json
import urllib2
import re

def usage():
    print("""
getsdp.py - helper script to fetch SDP file from Embrionix sender and extract IP address
            for video, audio and anc and write to capture.conf that is used to do PCAP's

Usage:
\tgetsdp.py <sender_ip>
""")

def get_sdp_url(ip):
    return "http://" + ip + "/emsfp/node/v1/sdp/"

def get_from_url(url):
    try:
        sdp = urllib2.urlopen(url).read()
    except urllib2.HTTPError:
        print("Unable to fetch SDP")

    return sdp

def write_confile(sdp, filename):
    print("{}".format(sdp))
    # TODO: parse mcast properly
    mcip = re.findall(r'[0-9]+(?:\.[0-9]+){3}', sdp)

    # print("mcip:" + str(mcip))
    file = open(filename, 'w')

    file.write('# This is where you put the multicast ipaddresses you want to access.\n')
    file.write('# You can only put 3 IP addresses\n')
    file.write('# x.x.0.x = video\n')
    file.write('# x.x.1.x = audio\n')
    file.write('# x.x.17.x = anc\n')
    file.write('\n')
    file.write('#mcast IPs\n')
    file.write('MCAST_LIST="'+ mcip[2] + ' ' + mcip[6] + ' ' + mcip[10] + '"\n')
    file.write('\n')
    file.write('#SDP source IP\n')
    file.write('SOURCE_IP=' + mcip[0] + '\n')
    file.write('\n')
    file.write('# Media Interface\n')
    file.write('IFACE=enp101s0f1\n')
    file.write('# packet capture duration\n')
    file.write('DURATION=2\n')
    file.write('\n')
    file.write('#SDP content\n')
    file.write('SDP="' + sdp + '"')
    file.write('\n')
    file.close()

    print("""
-----------------------------------------------------------------------------

SDP IP addresses extracted and writen to capture.conf

""")

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

    # Let's keep the 1st video, audio and anc sections
    sdp_filtered=""
    sdp_indexes = [0, 2, 18]
    for s in sdp_indexes:
        url = get_sdp_url(ip_address) + str(sdp_list[s])
        sdp_filtered += get_from_url(url)+'\r\n'

    write_confile(sdp_filtered, 'capture.conf')

if __name__ == "__main__":
    main()
