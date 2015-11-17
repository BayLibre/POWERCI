#/!bin/bash
LAVA_HOST=192.168.1.73
lava-tool submit-job https://$USER@$LAVA_HOST/RPC2/ $1
