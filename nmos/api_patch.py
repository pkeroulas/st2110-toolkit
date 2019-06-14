#!/usr/bin/env python2.7
import sys
import json
import urllib2
from nmos_node import *

def usage():
    print("""
api_path.py - this script polls the NOMS connection API of a
\treceiver to get active connections and start ffmpeg transcoder to join
\tthe same multicast group.

Usage:
\api_path.py <url> <json file>

""")

def main():
    if len(sys.argv) < 3:
        usage()
        return

    url = sys.argv[1]
    filename = sys.argv[2]
    with open(filename, 'r') as f:
        patch = json.load(f)
        print(">>>")
        print(json.dumps(patch, indent=1))
        content = patch_url(url, patch)
        print("<<<")
        print(json.dumps(content, indent=1))

if __name__ == "__main__":
    main()
