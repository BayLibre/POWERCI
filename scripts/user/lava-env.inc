export LAVA_SERVER_IP=`hostname -i`
export LAVA_PROXY=""

# This must be consistent with the auth in all steps or 
# it _will_ fail.
#
export LAVA_HTTP=http
export LAVA_RPC_LOGIN="$LAVA_HTTP://$USER@powerci-lava-disp.local/RPC2/"
export MY_BUNDLE_STREAM="/anonymous/$USER/"

export PATH=$PATH:~/LAVA-scripts

# probably not a good idea, used only once anyway.
#
export MY_TOKEN=iaxzkp204fu9t5c4c6p0dw63j7g5x5jlt063oh8t7zp0xl8bozzgcs0njh930n00hki6n80qiycduza1wzju0rgze3nk0dxjxjboe73lemfx8zca97b9ln5d02300pux
