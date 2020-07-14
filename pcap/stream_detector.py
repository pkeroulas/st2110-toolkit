#!/usr/bin/python
#
# Author "Patrick Keroulas" <patrick.keroulas@radio-canada.ca>
#
# Count every (src/dst) IP pair for a given pcap file

import sys
from scapy.all import *
import shutil
import pprint

if (len(sys.argv) < 2):
    print(sys.argv[0] + ' <pcap file>')
    exit(-1)

pcap = sys.argv[1]
pkt_counter = 0
counters = {}

def showProgess(progress):
    sys.stdout.write("%s                                          \r" % (progress) )
    sys.stdout.flush()

def streamDetect(pkt):
    global counters, pkt_counter
    pkt_counter += 1
    showProgess("pkts: " + str(pkt_counter))
    desc = pkt.summary()

    if desc not in counters.keys():
        print("\nNew: " + desc)
        counters[desc] = 1
    else:
        counters[desc] += 1

sniff(offline=pcap, store = 0, prn =streamDetect)

print("Pkts counters:")
pprint.pprint(counters)
