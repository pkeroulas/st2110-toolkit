#!/usr/bin/env python2.7
import sys
import json
from time import sleep
from nmos_node import NmosNode

def usage():
    print("""
node_controller.py - this script (dis)activates a receiver node based on
connection API (IS-05).

Usage:
\tnode_controller.py <node_ip> <rx|tx> <start|stop>

""")

def main():
    if len(sys.argv) < 4:
        usage()
        return

    node = NmosNode(ip = sys.argv[1], type = sys.argv[2])
    node.activate(True if sys.argv[3] == 'start' else False)

if __name__ == "__main__":
    main()
