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
duration=30

###################################
#     NO BLUE OR WE LOOSE PTP     #
###################################
ref=239.172.126.149
mcast=$ref,239.172.4.120,239.172.132.120
#239.172.4.120, 239.172.132.120, \
#239.172.4.121, 239.172.132.121, \
#239.172.4.122, 239.172.132.122, \
#239.172.4.123, 239.172.132.123, \
#239.172.4.124, 239.172.132.124, \
#239.172.4.125, 239.172.132.125, \
#239.172.4.126, 239.172.132.126, \
#239.172.4.216, 239.172.132.216, \
#239.172.4.217, 239.172.132.217, \
#239.172.4.218, 239.172.132.218, \
#239.172.4.219, 239.172.132.219, \
#239.172.4.220, 239.172.132.220, \
#239.172.4.221, 239.172.132.221, \
#239.172.4.222, 239.172.132.222, \


cd $LIST_PATH/third_party/ebu-list-sdk/demos/
npm run start -- live-capture -b $list_server -u $list_user -p $list_pass -m $mcast
#npm run start -- live-capture -f -b $list_server -u $list_user -p $list_pass -m $mcast -d $duration 2>${logname_prefix}_err1.txt | tee ${logname_prefix}_out1.txt &
#sleep $duration
#npm run start -- live-capture -f -b $list_server -u $list_user -p $list_pass -m $mcast -d $duration 2>${logname_prefix}_err2.txt | tee ${logname_prefix}_out2.txt &
