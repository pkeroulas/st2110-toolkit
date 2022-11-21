#!/bin/bash

ST2110_CONF_FILE=/etc/st2110.conf
if [ -f $ST2110_CONF_FILE ]; then
    . $ST2110_CONF_FILE
fi
MGMT_IP=$(ip addr show $MGMT_IFACE | tr -s ' ' | sed -n 's/ inet \(.*\)\/.*/\1/p')

list_server=http://$MGMT_IP
list_user=asd@asd.com
list_pass=asd
logname_prefix=/tmp/list_freerun_$(date | tr ' ' '_')
duration=60

mcast=225.0.0.1 #put your comma-separated stuff here

cd $LIST_PATH/third_party/ebu-list-sdk/demos/
#npm run start -- live-capture -b $list_server -u $list_user -p $list_pass -m $mcast
npm run start -- live-capture -f -b $list_server -u $list_user -p $list_pass -m $mcast -d $duration 2>${logname_prefix}_err1.txt | tee ${logname_prefix}_out1.txt &
#sleep $duration
#npm run start -- live-capture -f -b $list_server -u $list_user -p $list_pass -m $mcast -d $duration 2>${logname_prefix}_err2.txt | tee ${logname_prefix}_out2.txt &
