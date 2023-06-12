#!/usr/bin/python
#
# Author "Patrick Keroulas" <patrick.keroulas@radio-canada.ca>
#
# Extracts AES 67 payload from pcap and suggest ffmpeg cmd to convert to
# wav. Note that you need to give audio params (from the SDP) for the
# conversion.

import sys
from scapy.all import *
import io
import shutil

if len(sys.argv) < 3:
    print(sys.argv[0] + ' <pcap file> <dst IP filter>\n\
\n\
    output: output.raw \n\
\n\
Exple: \n\
    $ ' + sys.argv[0] + ' st2110-30-capture.pcap 225.0.0.1')
    exit(-1)

pcap = sys.argv[1]
filter = 'dst ' + sys.argv[2]
raw_filename = 'output.raw'
raw_file = open(raw_filename, mode='wb')
pkt_counter = 0

# In the RTP header:
# Skip Flags and Payload type (2), Seq num(2), Timestamp(4), SSRC(4),
# Assume there is no Ext Seq Num(2)
OFFSET=12

def showProgess(progress):
    sys.stdout.write("%s          \r" % (progress) )
    sys.stdout.flush()

def extractPayload(pkt):
    global pkt_counter
    global raw_file

    raw_file.write(pkt.load[OFFSET:])

    showProgess("pkt="+str(pkt_counter))
    pkt_counter += 1

print('Filter dst IP: \'' + filter + '\'')
print('Processing...')
sniff(offline=pcap, filter=filter, store = 0, prn = extractPayload)

raw_file.close()

print('Done')
print('Output: ' + raw_filename )
print("Suggestions:\n\
- convert to wav, using audio param from SDP file:\n\
    ffmpeg -hide_banner -y -f s24be -ar 48k -ac 16 -i output.raw output.wav")
