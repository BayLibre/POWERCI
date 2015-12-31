#/!bin/bash

. ./lava-env.inc

cat $1 | sed 's#BUNDLE_STREAM#'"$BUNDLE_STREAM"'#' >  /tmp/last.json
sed 's#LAVA_SERVER_IP#'"$LAVA_SERVER_IP"'#' -i  /tmp/last.json
sed 's#LAVA_SERVER#'"$LAVA_SERVER_IP"'#' -i  /tmp/last.json

lava-tool submit-job $LAVA_RPC_LOGIN /tmp/last.json
