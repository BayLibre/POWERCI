#!/bin/bash
LAVA_HOST=127.0.1.1
lava-tool make-stream --dashboard-url http://$LAVA_HOST/RPC2/ /anonymous/$USER
