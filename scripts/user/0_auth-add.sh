#!/bin/sh
set -x 

LAVA_HOST=127.0.1.1

lava-tool auth-add http://powerci@$LAVA_HOST/RPC2/

