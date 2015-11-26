#!/bin/bash
lava-tool make-stream --dashboard-url $LAVA_HTTP://$LAVA_SERVER_IP/RPC2/ $MY_BUNDLE_STREAM -name $USER-bs
