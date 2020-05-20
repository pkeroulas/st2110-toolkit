#!/usr/bin/python
#
# Author "Patrick Keroulas" <patrick.keroulas@radio-canada.ca>
#
# Extracts payload of ST 2110-20 packets given dst mcast IP and writes
# out 'output.yuv'
#
# At CBC, pix format commonly found in RFC4175 payload is packed YUV
# 4:2:2 10-bit/component but none of this not support by ffmpeg.
# Two conversions are possible:
# 1) packet 4:2:2 8-bit  > FFmpeg: "uyvy422"
# 2) planar 4:2:2 10-bit > FFmpeg: "yuv42210be"
#
# More info about YUV pixel formats:
# http://www.fourcc.org/yuv.php#UYVY
# $ ffmpeg -pix_fmts
# FFmpeg/libavutil/pixfmt.h
#
# playback:
# $ ffplay -f rawvideo -vcodec rawvideo -s 1920*540 -pix_fmt uyvy422 -i output.yuv

import sys
from array import array
import StringIO
import io
from scapy.all import *
import shutil
from collections import namedtuple
from bitstruct import *

if (len(sys.argv) < 3):
    print(sys.argv[0] + ' <pcap file> <dst IP filter>\n\
    output: output.yuv (uyvy422)')
    exit(-1)

pcap = sys.argv[1]
filter = 'dst ' + sys.argv[2]

def showProgess(progress):
    sys.stdout.write("%s                                          \r" % (progress) )
    sys.stdout.flush()

"""
       0                   1                   2                   3
       0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1
      +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
      | V |P|X|   CC  |M|    PT       |       Sequence Number         |
      +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
      |                           Time Stamp                          |
      +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
      |                             SSRC                              |
      +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
      |   Extended Sequence Number    |            Length             |
      +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
      |F|          Line No            |C|           Offset            |
      +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
      |            Length             |F|          Line No            |
      +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
      |C|           Offset            |                               .
      +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+                               .
      .                                                               .
      .                 Two (partial) lines of video data             .
      .                                                               .
      +---------------------------------------------------------------+
"""

yuv = open('output.yuv', mode='wb')
recording = False
frame_counter = 0
frame = []
def extractPayload(pkt):
    global recording, yuv, frame_counter, writer, frame
    i_stream = StringIO.StringIO(pkt.load)
    buf = i_stream.getvalue()

    header = [ord(i) for i in buf[0:20]]
    marker = (header[1] >> 7) & 0x01;
    if marker == 1:
        # 1st end of frame
        if not recording:
            recording = True
            return
    if not recording:
        return
    length = (header[14] << 8) + header[15]
    line = ((header[16] & 0x7F) << 8) + header[17]
    showProgess("frame="+str(frame_counter)+", line="+str(line))

    i_stream.seek(20)

    # pixel group extracting
    PGroup = namedtuple('pgroup', ['u', 'y0', 'v', 'y1'])
    cf = compile('u10u10u10u10')
    NBytes = 5
    i = 0
    while i < length:
        i += NBytes
        unpacked = cf.unpack(i_stream.read(NBytes))
        p = PGroup(*unpacked)
        # uyvy422, 8-bit
        frame += [n>>2 for n in [p.u, p.y0, p.v, p.y1]]

    if marker == 1:
        b = io.BytesIO(bytearray(frame))
        shutil.copyfileobj(b, yuv, 4)
        frame_counter += 1
        frame = []

# GO!
print('Filter dst IP: \'' + filter + '\'')
print('Processing...')

sniff(offline=pcap, filter=filter, store = 0, prn = extractPayload)
yuv.close()
print('Done.                  ')

