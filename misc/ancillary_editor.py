#!/usr/bin/python
#
# This scrip:
# - takes a pcap file
# - interpret packet as st2110-40 (RTP, ancillary data)
# - change the DID/SDID numberof Anciallary Time Code to 0x01 (unacceptable)
# - recalculate the checksum
# - write the ouput as a file
# - !!! works only for one Anc payload per packets !!!
#
# It can serve as a starting point for more complex editing

import sys
from array import array
import StringIO
from scapy.all import *

if (len(sys.argv) < 2):
    print(sys.argv[0] + ' <pcap file>')
    exit(-1)

CRC_MASK = 0x01ff

class BitWriter(object):
    def __init__(self, f):
        self.accumulator = 0
        self.bcount = 0
        self.out = f

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.flush()

    def __del__(self):
        try:
            self.flush()
        except ValueError:   # I/O operation on closed file.
            pass

    def _writebit(self, bit):
        if self.bcount == 8:
            self.flush()
        if bit > 0:
            self.accumulator |= 1 << 7-self.bcount
        self.bcount += 1

    def writebits(self, bits, n):
        while n > 0:
            self._writebit(bits & 1 << n-1)
            n -= 1

    def flush(self):
        self.out.write(bytearray([self.accumulator]))
        self.accumulator = 0
        self.bcount = 0


class BitReader(object):
    def __init__(self, f):
        self.input = f
        self.accumulator = 0
        self.bcount = 0
        self.read = 0

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        pass

    def _readbit(self):
        if not self.bcount:
            a = self.input.read(1)
            if a:
                self.accumulator = ord(a)
            self.bcount = 8
            self.read = len(a)
        rv = (self.accumulator & (1 << self.bcount-1)) >> self.bcount-1
        self.bcount -= 1
        return rv

    def readbits(self, n):
        v = 0
        while n > 0:
            v = (v << 1) | self._readbit()
            n -= 1
        return v

def get_parity(value):
    p = 0;
    for i in range(8):
        if value & 1:
            p += 1
        value >= 1
    print "parity: "+ str(p)
    return int(p & 1)

def editPayload(reader, writer):
    edited = 0
    tab=[]
    while True:
        tab.append(reader.readbits(10))
        if not reader.read:  # nothing read
            break

    old_crc = 0
    new_crc = 0
    data_count = 0
    for i, t in enumerate(tab):
        extra=""

        if i == 0:
            extra="DID = " + hex(t & 0xff)
            old_crc += t
            if ( (t & 0xff) == 0x60 ):
                print(" ... Ancillary Time Code edited 0x60 -> 0x01")
                edited = 1
                tab[i] = 1
            new_crc += tab[i]

        elif i == 1:
            extra="SDID = " + hex(t & 0xff)
            old_crc += t
            if edited:
                print(" ... edited 0xxx -> 0x101")
                tab[i] = 0x101
            new_crc += tab[i]

        elif i == 2:
            data_count = t & 0xff
            old_crc += t
            new_crc += t
            extra="data_count = " + str(data_count)

        elif i == data_count + 3: # this is checksum
            if edited:
                # compute new crc
                tab[i] = new_crc & CRC_MASK
                if not new_crc & 0x100:
                    new_crc = new_crc + 0x200

            extra="sum = " + hex(t & CRC_MASK) + ", crc = " + hex(old_crc & CRC_MASK) + ", new crc = " + hex(tab[i])

        elif i > data_count + 3: #this might not work for other paylaod
            extra="stuffing"

        else:
            old_crc += t
            new_crc += t
            extra="data = "+ str((t&0b1111111111) >> 2)

        if not extra == "":
            print("raw:" + hex(t)+ "->" + str(int(t)) + " " + extra)

        writer.writebits(tab[i],10)

"""
https://tools.ietf.org/id/draft-ietf-payload-rtp-ancillary-14.txt

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
       | ANC_Count=2   | F |                reserved                   |
       +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
       |C|   Line_Number=9     |   Horizontal_Offset   |S| StreamNum=0 |
       +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
       |         DID       |        SDID       |  Data_Count=0x84  |
       +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
        ............
"""

# open capture file
cap=rdpcap(sys.argv[1])
for pkt in cap:
    # init streams udp payload: RTP
    i_stream = StringIO.StringIO(pkt.load)
    o_stream = StringIO.StringIO(pkt.load)

    # init bit readers
    reader = BitReader(i_stream)
    writer = BitWriter(o_stream)
    print("=====================================")
    print("in: " + str([ord(i) for i in i_stream.getvalue()]))

    # jump to DID/SDID
    i_stream.seek(24)
    o_stream.seek(24)

    editPayload(reader, writer)

    print("out :" + str([ord(i) for i in o_stream.getvalue()]))
    pkt.load = o_stream.getvalue()

# write output file
print("Output file: /tmp/out.pcap")
wrpcap('/tmp/out.pcap', cap)
