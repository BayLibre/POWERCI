#!/bin/bash

. ./lava-env.inc

lava-tool make-stream --dashboard-url $LAVA_SERVER $BUNDLE_STREAM
