export LAVA_SERVER_IP=lava.baylibre.com
export LAVA_PROXY=""

# This must be consistent with the auth in all steps or 
# it _will_ fail.
#
export LAVA_RPC_LOGIN="http://$USER@lava.baylibre.com:10080/RPC2/"
export MY_BUNDLE_STREAM="/anonymous/$USER/"

export PATH=$PATH:~/LAVA-scripts

echo "using LAVA_SERVER_IP=$LAVA_SERVER_IP"
echo "using LAVA_RPC_LOGIN=$LAVA_RPC_LOGIN"
