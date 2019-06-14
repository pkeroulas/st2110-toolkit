#!/usr/bin/env python2.7
import json
import urllib2

class NmosNode:
    def __init__(self, ip):
        self.ip = ip

    def get_connection_receiver_url(self):
        return "http://" + self.ip + "/x-nmos/connection/v1.0/single/receivers/"

    def get_node_receiver_url(self):
        return "http://" + self.ip + "/x-nmos/node/v1.3/receivers/"

    def get_receiver_ids(self):
        res = []
        try:
           res = self.get_from_url(self.get_connection_receiver_url())
        except Exception as e:
            print(e)
            print("Unable to get id for ip:" + str(self.ip))
        return res

    def get_media_type(self, id):
        res = ''
        try:
            receiver_list = self.get_from_url(self.get_node_receiver_url())
            for receiver in receiver_list:
                if receiver['id']+'/' == id:
                    res = receiver['caps']['media_types'][0]
        except Exception as e:
            print(e)
            print("Unable to get media type id:" + str(id))
        return res

    def get_connection_status(self, id):
        res = True
        try:
            connection = self.get_from_url(self.get_connection_receiver_url() + str(id) + "active/")
            if not connection['master_enable'] or not connection['activation']['mode']:
                res = False
        except Exception as e:
            print(e)
            print("Unable to get connection status for id:" + str(id))
        return res

    def get_connection_sdp(self, id):
        res = None
        try:
            connection = self.get_from_url(self.get_connection_receiver_url() + str(id) + "active/")
            #print(json.dumps(connection, indent=1))
            res = connection['transport_file']['data']
        except Exception as e:
            print(e)
            print("Unable to get connection sdp for id:" + str(id))
        return res

    def get_from_url(self, url):
        try:
            content = urllib2.urlopen(url, timeout=1).read()
            return json.loads(content)
        except urllib2.HTTPError as e:
            print(e.code)
            print(e.url)
            return e.read()
        except Exception as e:
            print(e)
            return None

def patch_url(url, patch):
    try:
        request = urllib2.Request(url, json.dumps(patch))
        request.get_method = lambda: 'PATCH'
        request.add_header('Content-Type', 'application/json')
        content = urllib2.urlopen(request).read()
        return json.loads(content)
    except urllib2.HTTPError as e:
        return e.read()
    except Exception as e:
        print(e)
        return None
