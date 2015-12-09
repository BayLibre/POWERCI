#/!bin/bash

. ./lava-env.inc

lava-tool submit-job $LAVA_RPC_LOGIN $1
