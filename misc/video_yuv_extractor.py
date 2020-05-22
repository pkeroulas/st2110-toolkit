#!/usr/bin/python
#
# Author "Patrick Keroulas" <patrick.keroulas@radio-canada.ca>
#
# Extracts payload of ST 2110-20 packets given dst mcast IP and writes
# out 'output.yuv'
#
# At CBC, pix format commonly found in RFC4175 payload is packed YUV
# 4:2:2 10-bit/component but none of this not support by ffmpeg.
# These conversions are possible:
# 1) packet 4:2:2 8-bit  > FFmpeg: "uyvy422"
# 2) planar 4:2:2 8-bit  > FFmpeg: "yuv422p"
# 3) planar 4:2:2 10-bit > FFmpeg: "yuv422p10be" ?????????????????
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

yuv_file = open('output.yuv', mode='wb')
recording = False
frame_counter = 0
y_stream = io.BytesIO(bytes())
u_stream = io.BytesIO(bytes())
v_stream = io.BytesIO(bytes())
n_bytes = 0
def extractPayload(pkt):
    global recording, yuv_file, frame_counter, y_stream, u_stream, v_stream, n_bytes
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
    pgroup_size = 5
    i = 0
    while i < length:
        i += pgroup_size
        unpacked = cf.unpack(i_stream.read(pgroup_size))
        p = PGroup(*unpacked)

        # uyvy422
        #y_stream.write(pack('u8u8u8u8', p.u>>2, p.y0>>2, p.v>>2, p.y1>>2)) # less performant
        #y_stream.write(chr(p.u>>2) + chr(p.y0>>2) + chr(p.v>>2) + chr(p.y1>>2))

        # yuv422p
        y_stream.write(chr(p.y0>>2) + chr(p.y1>>2))
        u_stream.write(chr(p.u>>2))
        v_stream.write(chr(p.v>>2))

    if marker == 1:
        y_stream.seek(0)
        u_stream.seek(0)
        v_stream.seek(0)
        shutil.copyfileobj(y_stream, yuv_file)
        shutil.copyfileobj(u_stream, yuv_file)
        shutil.copyfileobj(v_stream, yuv_file)

        y_stream.seek(0)
        u_stream.seek(0)
        v_stream.seek(0)
        frame_counter += 1
        n_bytes = 0

# GO!
print('Filter dst IP: \'' + filter + '\'')
print('Processing...')

sniff(offline=pcap, filter=filter, store = 0, prn = extractPayload)
yuv_file.close()

print('Done.                  ')
