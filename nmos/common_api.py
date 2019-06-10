#!/usr/bin/env python2.7
import json
import urllib2

def get_connection_receiver_url(ip):
    return "http://" + ip + "/x-nmos/connection/v1.0/single/receivers/"

def get_from_url(url):
    try:
        content = urllib2.urlopen(url, timeout=1).read()
    except urllib2.HTTPError as e:
        print(e.code)
        print(e.url)
        print(e.read())
    return json.loads(content)

def patch_url(url, patch):
    try:
        request = urllib2.Request(url, json.dumps(patch))
        request.get_method = lambda: 'PATCH'
        request.add_header('Content-Type', 'application/json')
        content = urllib2.urlopen(request).read()
        return json.loads(content)
    except urllib2.HTTPError as e:
        return e.read()
