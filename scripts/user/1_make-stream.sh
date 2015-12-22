#!/bin/bash

. ./lava-env.inc

lava-tool make-stream --dashboard-url $LAVA_RPC_LOGIN $MY_BUNDLE_STREAM
