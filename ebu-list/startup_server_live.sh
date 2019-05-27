#!/bin/bash

DIR="$(dirname $(readlink -f $0))"

source /etc/st2110.conf
# fill config template

echo "Generate server config from template + master config:"
echo ""
IP=$(ip addr show $MGMT_IFACE | tr -s ' ' | sed -n 's/ inet \(.*\)\/.*/\1/p')
sed "s,\(folder:\).*,\1 $DATA_FOLDER,;
    s,\(webappDomain:\).*,\1 http://$IP:8080,;
    s,\(  interfaceName:\).*,\1 $MEDIA_IFACE,;
    " ./config.yml.template | tee $DIR/apps/listwebserver/config.yml

echo "Start mongo and influx"
cd $DIR/apps/external/
docker-compose up -d
cd $DIR

echo "Start the UI"
cd $DIR/apps/gui/
npm start &
cd $DIR

echo "Start the server"
LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/usr/local/lib
cd $DIR/apps/listwebserver
nodemon ./server.js -- config.yml.dev --dev --live
