#!/usr/bin/env python2.7
import json
import urllib
from urllib.request import urlopen
import urllib.error as urlerror

class NmosNode:
    def __init__(self, ip = '127.0.0.1', type = 'rx'):
        if not type == 'rx' and not type == 'tx':
            raise("Node must be type 'rx' or 'tx'")
        self.ip = ip
        self.type = 'receivers' if type == 'rx' else 'senders'

        # get latest node version
        self.node_version = self.get_from_url("http://" + self.ip + "/x-nmos/node/")[-1]
        self.connection_version = self.get_from_url("http://" + self.ip + "/x-nmos/connection/")[-1]

    def log(self, msg):
        print("     [node]:" + str(msg))

    def get_connection_url(self):
        return "http://" + self.ip + "/x-nmos/connection/" + self.connection_version + "single/" + self.type + "/"

    def get_node_url(self):
        return "http://" + self.ip + "/x-nmos/node/" + self.node_version + self.type + "/"

    def get_receiver_ids(self):
        res = []
        try:
           res = self.get_from_url(self.get_connection_url())
        except Exception as e:
            self.log(e)
            self.log("Unable to get rx id for ip:" + str(self.ip))
        return res

    def get_ids(self):
        res = []
        try:
           res = self.get_from_url(self.get_connection_url())
        except Exception as e:
            self.log(e)
            self.log("Unable to get tx id for ip:" + str(self.ip))
        return [i.replace('/','') for i in res]

    def get_video_id(self):
        res = None
        for id in self.get_ids():
            if 'video' in self.get_media_type(id):
                res = id
                break
        return res

    def get_audio_id(self):
        res = None
        for id in self.get_ids():
            if 'audio' in self.get_media_type(id):
                res = id
                break
        return res

    def get_media_type(self, id):
        res = 'unknown'
        url = self.get_node_url()
        try:
            for receiver in self.get_from_url(url):
                if receiver['id'] == id:
                    res = receiver['caps']['media_types'][0]
        except Exception as e:
            self.log(e)
            self.log("Unable to get media type url: " + url + id)
        return res

    def get_sdp(self, id):
        res = 'unknown'
        url = self.get_node_url()
        try:
            for receiver in self.get_from_url(url):
                if receiver['id'] == id:
                    sdp_url = receiver['manifest_href']
                    res = self.get_from_url(sdp_url)
        except Exception as e:
            self.log(e)
            self.log("Unable to get sdp from url: " + url + id)
        return res

    def activate_all(self, active):
        ids = self.get_ids()
        for connection_id in ids:
            self.activate(active, connection_id)

    def activate(self, active, id):
        url = self.get_connection_url() + str(id) + "/staged/"
        patch = {"activation":{"mode":"activate_immediate"},"master_enable":active}
        self.patch_url(url, patch)
        media_type = self.get_media_type(id)
        self.log(self.type + "/" + str(id) + "(" + media_type + "): active=" + str(active))

    def get_connection_status(self, id):
        res = True
        url = self.get_connection_url() + str(id) + "/active/"
        try:
            connection = self.get_from_url(url)
            if not connection['master_enable'] or not connection['activation']['mode']:
                res = False
        except Exception as e:
            self.log(e)
            self.log("Unable to get connection status for url:" + url)
        return res

    def get_connection_sdp(self, id):
        res = None
        url = self.get_connection_url() + str(id) + "/active/"
        try:
            connection = self.get_from_url(url)
            #self.log(json.dumps(connection, indent=1))
            res = connection['transport_file']['data']
        except Exception as e:
            self.log(e)
            self.log("Unable to set connection status for url:" + url)
        return res

    def set_connection_sdp(self, rx_id, tx_id, sdp):
        url = self.get_connection_url() + str(rx_id) + "/staged/"
        patch = {"sender_id":tx_id,"transport_file":{"data":str(sdp),"type":"application/sdp"}}
        media_type = self.get_media_type(rx_id)
        try:
            self.patch_url(url, patch)
        except Exception as e:
            self.log(e)
            self.log("Unable to set connection status for id:" + url + id)
        self.log(self.type + "/" + str(rx_id) + "(" + media_type + "): sdp=" + str(sdp)[:200] + "...")

    def get_from_url(self, url):
        res = None
        try:
            content = urlopen(url, timeout=1).read()
            try:
                res = json.loads(content)
            except:
                res = content
        except urlerror.HTTPError as e:
            self.log(e.code)
            self.log(e.url)
            return e.read()
        except Exception as e:
            self.log(e)
        return res

    def patch_url(self, url, patch):
        try:
            #self.log("patch url:" + url)
            #self.log(json.dumps(patch, indent = 1))
            data = urllib.parse.urlencode(patch).encode("utf-8")
            request = urllib.request.Request(url, data=data, method='PATCH')
            request.add_header('Content-Type', 'application/json')
            content = urlopen(request).read()
            return json.loads(content)
        except urlerror.HTTPError as e:
            return e.read()
        except Exception as e:
            self.log(e)
            return None
