export LAVA_SERVER_IP=`hostname -i`
export LAVA_PROXY=""

# This must be consistent with the auth in all steps or 
# it _will_ fail.
#
#export LAVA_RPC_LOGIN="https://$USER@lab-baylibre:443/RPC2/"
export LAVA_RPC_LOGIN="http://$USER@lab-baylibre.local/RPC2/"
export MY_BUNDLE_STREAM="/anonymous/$USER/"

export PATH=$PATH:~/LAVA-scripts

echo "using LAVA_SERVER_IP=$LAVA_SERVER_IP"
echo "using LAVA_RPC_LOGIN=$LAVA_RPC_LOGIN"
