#!/bin/bash

. ./lava-env.inc

lava-tool make-stream --dashboard-url $LAVA_RPC_LOGIN $BUNDLE_STREAM
