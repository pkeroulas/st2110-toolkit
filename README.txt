This collection of tools performs tasks that can't be integrated in
FFmpeg for ST 2110 transcoding:

* install all the FFmpeg dependencies
* setup network:
  - route for multicast streams
  - route for unicast source
  - NIC buffer size...
* analyse stream content like ptp clock

-------------------------------------------------------------------
Install ffmpeg and dependencies
-------------------------------------------------------------------

Install everything (tools, FFmpeg and all the dependencies) on Centos 7
using the install scrip:

 $ ./install.sh install_all

Or you cant install a single component:

 $ ./install.sh install_ffmpeg

-------------------------------------------------------------------
Network
-------------------------------------------------------------------

Find your live media interface name and execute:

 $ ./network_setup.sh <interface>

You can validate the reception of the multicast join with the socket reader:

 $ gcc -o socket_reader  -std=c99 socket_reader.c
 $./socket_reader -g 225.16.0.1 -p 20000 -i 172.30.64.118

-------------------------------------------------------------------
Get an SDP file:
-------------------------------------------------------------------

FFmpeg needs an SDP file for stream description. A python script grabs
the SDP from an Embrionix encapsulator:

 $ ./embrionix_sfp_get_sdp.py 172.30.64.161

Make an SDP file from the entire or the partial output.

-------------------------------------------------------------------
Execute
-------------------------------------------------------------------

Use ./ffmpeg_launcher.sh to start the transcoder by giving the monitor
IP:port:

 $ ./ffmpeg_launcher.sh start 192.168.1.1:5000 ~/sdp/my.sdp

 $ ./ffmpeg_launcher.sh stop

-------------------------------------------------------------------
Additional resources
-------------------------------------------------------------------

Fox Network provides Wireshark dissectors:
* https://github.com/FOXNEOAdvancedTechnology/smpte2110-20-dissector
* https://github.com/FOXNEOAdvancedTechnology/smpte2110-40-dissector

And EBU and CBC provides pcap analyser: Live IP Sowtware Toolkit
* https://github.com/ebu/pi-list
* http://list.ebu.io/login
