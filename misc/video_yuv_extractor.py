#!/usr/bin/python
#
# Author "Patrick Keroulas" <patrick.keroulas@radio-canada.ca>
#
# Extracts payload of ST 2110-20 packets given dst mcast IP and writes
# out 'output.yuv'
#
# At CBC, pix format commonly found in RFC4175 payload is packed YUV
# 4:2:2 10-bit/component but none of this not supported by ffmpeg.
#
# More info about YUV pixel formats:
# - http://www.fourcc.org/yuv.php#UYVY
# - FFmpeg/libavutil/pixfmt.h
# - $ ffmpeg -pix_fmts
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

if (len(sys.argv) < 4):
    print(sys.argv[0] + '<pcap file> <dst IP filter> <yuv_mode>\n\
    yuv_mode: 1 = packet 4:2:2 8-bit  > FFmpeg: "uyvy42u"\n\
              2 = planar 4:2:2 8-bit  > FFmpeg: "yuv422p"\n\
              3 = planar 4:2:2 10-bit > FFmpeg: "yuv422p10be"\n\
\n\
    output: output.yuv')
    exit(-1)

pcap = sys.argv[1]
filter = 'dst ' + sys.argv[2]
YUV_MODE = ['uyvy422', 'yuv422p', 'yuv422p10be']
yuv_mode = YUV_MODE[int(sys.argv[3])-1]
yuv_file = open('output.yuv', mode='wb')

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

recording = False
frame_counter = 0
y_stream = io.BytesIO(bytes())
u_stream = io.BytesIO(bytes())
v_stream = io.BytesIO(bytes())

def extractPayload(pkt):
    global recording, frame_counter
    global yuv_mode, yuv_file, y_stream, u_stream, v_stream
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

        if (yuv_mode == 'uyvy422'):
            #y_stream.write(pack('u8u8u8u8', p.u>>2, p.y0>>2, p.v>>2, p.y1>>2)) # less performant
            y_stream.write(chr(p.u>>2) + chr(p.y0>>2) + chr(p.v>>2) + chr(p.y1>>2))

        elif (yuv_mode == 'yuv422p'):
            y_stream.write(chr(p.y0>>2) + chr(p.y1>>2))
            u_stream.write(chr(p.u>>2))
            v_stream.write(chr(p.v>>2))

        elif (yuv_mode == 'yuv422p10be'):
            # TODO see if chr()... is faster
            y_stream.write(pack('u16u16', p.y0, p.y1))
            u_stream.write(pack('u16', p.u))
            v_stream.write(pack('u16', p.v))

    if marker == 1:
        y_stream.seek(0)
        shutil.copyfileobj(y_stream, yuv_file)
        y_stream.seek(0)

        if (not yuv_mode == 'uyvy422'):
            u_stream.seek(0)
            v_stream.seek(0)
            shutil.copyfileobj(u_stream, yuv_file)
            shutil.copyfileobj(v_stream, yuv_file)
            u_stream.seek(0)
            v_stream.seek(0)

        frame_counter += 1

# GO!
print('Filter dst IP: \'' + filter + '\'')
print('Processing...')

sniff(offline=pcap, filter=filter, store = 0, prn = extractPayload)
yuv_file.close()

print('Done.                                ')

# fix dimensions
print("Suggestion:\n\
        ffplay -f rawvideo -vcodec rawvideo -s 1920*540 -pix_fmt " + yuv_mode + " -i output.yuv")
