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
        self.channels = [0, 1]

        # get latest node version
        self.emsfp_version = self.get_from_url("http://" + self.ip + "/emsfp/node/")[-1]
        self.node_version = self.get_from_url("http://" + self.ip + "/x-nmos/node/")[-1]
        self.connection_version = self.get_from_url("http://" + self.ip + "/x-nmos/connection/")[-1]

        connection_ids = self.get_connection_ids()
        channel_length = int(len(connection_ids) / 2)
        self.connections = [ { 'vid ': {}, 'aud1': {} , 'aud2': {}, 'aud3': {}, 'aud4': {}, 'anc ' : {} }, \
                       { 'vid ': {}, 'aud1': {} , 'aud2': {}, 'aud3': {}, 'aud4': {}, 'anc ' : {} } ]
        # Embrionix EmSFP specific mapping
        for i in self.channels:
            self.connections[i]['vid ']  = self.fill_connection(connection_ids[i*channel_length+0])
            self.connections[i]['aud1'] = self.fill_connection(connection_ids[i*channel_length+1])
            self.connections[i]['aud2'] = self.fill_connection(connection_ids[i*channel_length+2])
            #self.connections[i]['aud3'] = self.fill_connection(connection_ids[i*channel_length+3])
            #self.connections[i]['aud4'] = self.fill_connection(connection_ids[i*channel_length+4])
            self.connections[i]['anc ']  = self.fill_connection(connection_ids[i*channel_length+channel_length-1])
        self.log(json.dumps(self.connections, indent=2))

    def log(self, msg):
        print("     [node]["+self.ip +"]["+self.type+"]:" + str(msg))

    def get_emsfp_connection_url(self):
        return "http://" + self.ip + "/emsfp/node/"+ self.emsfp_version + self.type + "/"

    def get_emsfp_flow_url(self):
        return "http://" + self.ip + "/emsfp/node/"+ self.emsfp_version + "/flows/"

    def get_connection_url(self):
        return "http://" + self.ip + "/x-nmos/connection/" + self.connection_version + "single/" + self.type + "/"

    def get_node_url(self):
        return "http://" + self.ip + "/x-nmos/node/" + self.node_version + self.type + "/"

    def get_connection_ids(self):
        res = []
        try:
           res = self.get_from_url(self.get_connection_url())
        except Exception as e:
            self.log(e)
            self.log("Unable to get tx id for ip:" + str(self.ip))
        return [i.replace('/','') for i in res]

    def fill_connection(self, connection):
        emsfp_connection = self.get_from_url(self.get_emsfp_connection_url()+connection+'/')
        flow_id = '' if 'flow_id' not in emsfp_connection.keys() else emsfp_connection['flow_id']
        media = '' if flow_id == '' else self.get_from_url(self.get_emsfp_flow_url()+flow_id[0])['format']['format_type'] # red only
        return { 'id': connection, 'flow' : flow_id, 'media': media, 'pkt_count' : ''}

    def update_connections(self):
        for i in self.channels:
            for j in self.connections[i]:
                if self.connections[i][j]:
                    pkt_count = self.get_pkt_count(self.connections[i][j]['flow'][0]) # just red
                    if pkt_count != self.connections[i][j]['pkt_count']:
                        self.connections[i][j]['pkt_count'] = pkt_count
                        self.log('ch[{}] - {} - pkt:{}'.format(i,j,pkt_count))
                    else:
                        self.log('ch[{}] - {} - pkt:{}'.format(i,j,'unchanged!!!!!!!!!!!!!!'))

    def get_pkt_count(self, flow_id):
        try:
            res = self.get_from_url(self.get_emsfp_flow_url()+flow_id+'/')
            return res['network']['pkt_cnt']
        except Exception as e:
            self.log(e)
            self.log("Unable to get tx id for ip:" + str(self.ip))

    def get_sdp(self, id):
        res = 'unknown'
        url = self.get_node_url()
        try:
            for slot in self.get_from_url(url):
                if slot['id'] == id:
                    sdp_url = slot['manifest_href']
                    res = self.get_from_url(sdp_url)
        except Exception as e:
            self.log(e)
            self.log("Unable to get sdp from url: " + url + id)
        return str(res)

    def activate_all(self, active):
        ids = self.get_ids()
        for connection_id in ids:
            self.activate(active, connection_id)

    def activate_ch(self, ch, active):
        for id in self.connections[ch]:
            self.activate(active, id)

    def activate(self, active, id):
        url = self.get_connection_url() + str(id) + "/staged/"
        patch = {"activation":{"mode":"activate_immediate"},"master_enable":active}
        self.patch_url(url, patch)
        self.log(self.type + "/" + str(id) + ": active=" + str(active))

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
            #self.log(json.dumps(connection, indent=2))
            res = connection['transport_file']['data']
        except Exception as e:
            self.log(e)
            self.log("Unable to set connection status for url:" + url)
        return res

    def set_connection_sdp(self, rx_id, tx_id, sdp):
        url = self.get_connection_url() + str(rx_id) + "/staged/"
        patch = {"sender_id":tx_id,"transport_file":{"data":str(sdp),"type":"application/sdp"}}
        try:
            self.patch_url(url, patch)
        except Exception as e:
            self.log(e)
            self.log("Unable to set connection status for id:" + url + id)
        #self.log(self.type + "/" + str(rx_id) + " sdp=" + str(sdp)[:200] + "...")

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
