#!/usr/bin/python
#
# This script reads a watchfolder and push to a secured webdav server in
# AWS MediaPackage

# sudo yum install python-pip
# sudo pip install webdavclient
# sudo pip install webdavclient3

# import webdav.client as wc
import webdav3.client as wc
import os
import pyinotify
import subprocess

local_path = "/tmp/hls"

remote_path_a = "/in/v2/fe644b6164324dbeb802c5466cf47567/fe644b6164324dbeb802c5466cf47567"
options_a = {
 'webdav_hostname': "https://a12d12520616dd39.mediapackage.us-east-1.amazonaws.com",
 'webdav_login':    "2eea824eeeaa4bcebef384d77da4e49e",
 'webdav_password': "",
 'verbose': True
}

remote_path_b = "/in/v2/fe644b6164324dbeb802c5466cf47567/2d735efa1336487cbd5f8ed7f24329fc"
options_b = {
 'webdav_hostname': "https://259f677efd9ce80a.mediapackage.us-east-1.amazonaws.com",
 'webdav_login':    "962a0662e0a74c95b7f784f3fd8881d2",
 'webdav_password': "",
 'verbose': True
}

client_a = wc.Client(options_a)
client_b = wc.Client(options_b)
if not client_a.valid() or not client_b.valid():
    print "Not valid!!!!!!!"

print "-------------------------------upload"
filename = local_path+"/"+"channel_360p.m3u8"
client_a.upload_sync(remote_path=remote_path_a+"/"+os.path.basename(filename), local_path=filename)
client_b.upload_sync(remote_path=remote_path_b+"/"+os.path.basename(filename), local_path=filename)
exit(0)

class ProcessNewFile(pyinotify.ProcessEvent):
    def __init__(self, client_a, client_b):
        self.webdav_client_a = client_a
        self.webdav_client_b = client_b

    def process_IN_CLOSE_WRITE(self, event):
        if ".tmp" in event.pathname:
            return

        print '\t', event.pathname, ' -> written'
        self.webdav_client_a.upload_sync(remote_path=remote_path_a+"/"+os.path.basename(event.pathname), local_path=event.pathname)
        self.webdav_client_b.upload_sync(remote_path=remote_path_b+"/"+os.path.basename(event.pathname), local_path=event.pathname)

    def process_default(self, event):
        # Implicitely IN_CREATE and IN_DELETE are watched too. You can
        # ignore them and provide an empty process_default or you can
        # process them, either with process_default or their dedicated
        # method (process_IN_CREATE, process_IN_DELETE) which would
        # override process_default.
        print 'default: ', event.maskname

wm = pyinotify.WatchManager()
handler = ProcessNewFile(client_a, client_b)
notifier = pyinotify.Notifier(wm, default_proc_fun=handler)
wm.add_watch(local_path, pyinotify.ALL_EVENTS, rec=True, auto_add=True)
print '==> Start monitoring %s (type c^c to exit)' % local_path
notifier.loop()
