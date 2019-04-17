#!/usr/bin/python
#
# This script uses "Connection" API of AMWA IS-05 to get the status of a
# receiver node and fetch the SDP file. Test with Sony's nmos-cpp node.

import time
import requests

NMOS_RX_NODE_IP="192.168.39.88:1080"
# TODO: constant: SDP file directory

url = "http://"+NMOS_RX_NODE_IP+"/x-nmos/connection/v1.0/single/receivers/8acd9c51-ec10-54e5-8a13-cc1420715dd6/active"
# TODO: get rx ID it changes at every restart
payload = ""
state=False

while True:
    response = requests.request("GET", url, data=payload)

    if response.json()['master_enable'] and not state:
        state=True
        print "Rx: On"
        sdp = response.json()['transport_file']["data"] # data missing for dummy device
        f = open('test.sdp', 'w')
        f.write(sdp)
        f.close
    elif not response.json()['master_enable'] and state:
        state=False
        print "Rx: Off"

    time.sleep(2)
