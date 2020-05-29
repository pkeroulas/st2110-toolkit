#!/usr/bin/python
#
# Author "Patrick Keroulas" <patrick.keroulas@radio-canada.ca>
#
# Role: detect any packet drop in a RTP stream for given pcap file and a
# multicast stream. The method is based on `Sequence Number` jump
# detection, assuming no packet reordering.

import sys
from array import array
import StringIO
from scapy.all import *

if (len(sys.argv) < 3):
    print(sys.argv[0] + ' <pcap file> <dst IP filter>')
    exit(-1)

pcap = sys.argv[1]
filter = 'dst ' + sys.argv[2]

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

old_ts = None
drop_count = 0
index = 0
def checkSeqNum(pkt):
    global old_ts, drop_count, index
    showProgess(index)

    # notes:
    #print(pkt.getlayer(IP).dst)
    #print(pkt[TCP].sport)

    # init streams udp payload: RTP
    buf = StringIO.StringIO(pkt.load).getvalue()
    # read RTP sequence number
    ts = (ord(buf[2]) << 8 ) + ord(buf[3])

    if (old_ts != None) and ((old_ts + 1) != ts) and not ((old_ts == 65535) and (ts == 0)):
        print(str(old_ts) + ' -> ' + str(ts) + '=> drop!')
        drop_count += 1
    old_ts = ts
    index +=1

# GO!
print('Filter dst IP: \'' + filter + '\'')
print('Processing...')

sniff(offline=pcap, filter=filter, store = 0, prn = checkSeqNum)
print('Done.                  ')
print('Drop count: ' + str(drop_count) + '/' + str(index) + ' pkts')
