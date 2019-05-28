#!/bin/bash

THIS_DIR="$(dirname $(readlink -f $0))"

2110_logger(){
    logger "st2110 - $@"
    echo $@
}

2110_logger "Generate server config from template + master config:"
source /etc/st2110.conf
IP=$(ip addr show $MGMT_IFACE | tr -s ' ' | sed -n 's/ inet \(.*\)\/.*/\1/p')
if ! ping -W 1 -c 1 -q $IP > /dev/null; then
    echo "Couln't ping $IP for interface $MGMT_IFACE, exit."
    exit 1
fi

sed "s,\(folder:\).*,\1 $DATA_FOLDER,;
    s,\(webappDomain:\).*,\1 http://$IP:8080,;
    s,\(  interfaceName:\).*,\1 $MEDIA_IFACE,;
    " ./config.yml.template | tee $THIS_DIR/apps/listwebserver/config.yml

2110_logger "Start mongo and influx"
cd $THIS_DIR/apps/external/
docker-compose up -d
cd $THIS_DIR

2110_logger "Start the UI"
cd $THIS_DIR/apps/gui/
npm start &
cd $THIS_DIR

2110_logger "Start the server"
export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:$THIS_DIR/build/lib/
cd $THIS_DIR/apps/listwebserver
nodemon ./server.js -- config.yml.dev --dev --live
2110_logger "Server stopped"
