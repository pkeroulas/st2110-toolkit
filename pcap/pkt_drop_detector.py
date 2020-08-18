#!/usr/bin/python
#
# Author "Patrick Keroulas" <patrick.keroulas@radio-canada.ca>
#
# Count packets and drops for every (src/dst) IP pair found a given pcap.
# The method is based on `Sequence Number` jump detection, assuming no
# packet reordering.

import sys
from array import array
import pprint
import StringIO
from scapy.all import *

if (len(sys.argv) < 2):
    print(sys.argv[0] + ' <pcap file>')
    exit(-1)

pcap = sys.argv[1]
filter =''

def showProgess(progress):
    sys.stdout.write("packets: %d      \r" % (progress) )
    sys.stdout.flush()

"""
RTP header:

       0                   1                   2                   3
       0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
       +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
       |V=2|P|X| CC    |M|    PT       |        sequence number        |
       +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
       |                           timestamp                           |
       +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
       |           synchronization source (SSRC) identifier            |
       +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
       |   Extended Sequence Number    |           Length=32           |
       +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
        ............
"""

counters = {}
index = 0
def checkSeqNum(pkt):
    global counters, index
    showProgess(index)
    index +=1

    # notes:
    #print(pkt.getlayer(IP).dst)
    #print(pkt[TCP].sport)

    # init streams udp payload: RTP
    buf = StringIO.StringIO(pkt.load).getvalue()
    # read RTP sequence number
    ts = (ord(buf[2]) << 8 ) + ord(buf[3])

    desc = pkt.summary()
    if desc not in counters.keys():
        print("\nNew: " + desc)
        counters[desc] = {'pkt': 1, 'drop': 0 , 'old_ts': ts }
        return

    old_ts = counters[desc]['old_ts']
    if (old_ts != None) and ((old_ts + 1) != ts) and not ((old_ts == 65535) and (ts == 0)):
        drop = (ts - old_ts)
        print(desc + '('+ str(old_ts) + '...' + str(ts) + ') = ' + str(drop) + 'drops!')
        counters[desc]['drop'] += drop;

    counters[desc]['pkt'] += 1;
    counters[desc]['old_ts'] = ts


# GO!
print('Filter dst IP: \'' + filter + '\'')
print('Processing...')

sniff(offline=pcap, filter=filter, store = 0, prn = checkSeqNum)
print('Done.                  ')
print("Pkts counters:")
pprint.pprint(counters)
