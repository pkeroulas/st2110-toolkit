#!/usr/bin/env python2.7
import sys
import json
from time import sleep
from common_api import *

def usage():
    print("""
node_controller.py - this script (dis)activates a receiver node based on
connection API (IS-05).

Usage:
\tnode_controller.py <node_ip> <start|stop>

""")

def activate(ip_address, active):
    base_url = get_connection_receiver_url(ip_address)

    try:
       connection_list = get_from_url(base_url)
    except:
        print("Unable to parse connection")
        return

    for connection_id in connection_list:
        print("-" * 72)
        print(str(connection_id) + ": active=" + str(active))
        url = base_url + str(connection_id) + "staged/"
        patch = {"activation":{"mode":"activate_immediate"},"master_enable":active}
        patch_url(url, patch)

def main():
    if len(sys.argv) < 3:
        usage()
        return

    if sys.argv[2] == 'start':
        activate(sys.argv[1], True)
    elif sys.argv[2] == 'stop':
        activate(sys.argv[1], False)
    else:
        usage()

if __name__ == "__main__":
    main()
