#!/bin/bash

if [ ! -d "$1" ]
then
	echo "please provide the folder to process (template jobs)"
	exit -1
fi

echo "fixing jobs in folder "$1 "to folder" $USER-jobs

source lava-env.inc

mkdir -p $USER-jobs

cp $1/*.json $USER-jobs

find $USER-jobs -name *.json | xargs sed 's#LAVA_SERVER_IP#'"$LAVA_SERVER_IP"'#' -i
find $USER-jobs -name *.json | xargs sed 's#BUNDLE_STREAM#'"$BUNDLE_STREAM"'#' -i
find $USER-jobs -name *.json | xargs sed 's#LAVA_RPC_LOGIN#'"$LAVA_RPC_LOGIN"'#' -i

