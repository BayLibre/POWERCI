#/!bin/bash

. ./lava-env.inc

lava-tool submit-job $LAVA_SERVER $1
