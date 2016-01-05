export LAVA_SERVER_IP=lava.baylibre.com
export LAVA_PROXY=""

# This must be consistent with the auth in all steps or it _will_ fail.
#
export LAVA_SERVER="http://$USER@lava.baylibre.com:10080/RPC2/"
export LAVA_USER=$USER
export LAVA_TOKEN=`cat ./token-files/$USER.tok`
export BUNDLE_STREAM="/anonymous/$USER/"

export PATH=$PATH:~/LAVA-scripts

echo "using LAVA_USER=$LAVA_USER"
echo "using LAVA_SERVER_IP=$LAVA_SERVER_IP"
echo "using LAVA_SERVER=$LAVA_SERVER"
echo "Using BUNDLE_STREAM=$BUNDLE_STREAM"
