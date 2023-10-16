#!/bin/bash
# This script generates minimalistic conf files for nmos-cpp nodes
# It also generates the docker-compose file.
 
DESCRIPTION="CBC virt node "
DOMAIN=nmos-tb.org
DOCKERFILE=docker-compose.yml
 
if [ -z  $1 ]; then
    echo "Usage:
    $0 <N instances>"
    exit 1
else
    N=$1
fi

rm -rf node*.conf

echo  "version: '3.6'
services:" > $DOCKERFILE

for n in $(seq $N); do
    echo Gen conf for node \#$n

    port=$((8100 + $n))
    conf=node$n.conf
    echo "{
    \"http_port\": $port,
    \"logging_level\": 0,
    \"label\": \"$DESCRIPTION - $n\",
    \"description\": \"$DESCRIPTION - $n\",
    \"registry_version\": \"v1.3\",
    \"domain\": \"$DOMAIN\",
    \"query_paging_default\": 20
}" > $conf

    echo "  noms-virtnode-$n:
    image: rhastie/nmos-cpp:latest
    container_name: nmos-virtnode-$n
    hostname: cbc-nmos-virtnode-$n
    network_mode: \"host\"
    volumes:
    - \"./$conf:/home/node.json\"
    environment:
    - RUN_NODE=TRUE
" >> $DOCKERFILE

done

echo ============ $DOCKERFILE ===============
cat $DOCKERFILE

echo Suggestion: \"docker-compose up\"
