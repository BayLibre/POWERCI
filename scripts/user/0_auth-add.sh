#!/bin/sh
set -x 

echo "usage: setup the gnome keyring with the LAVA token for this user"
echo "make sure to log into $LAVA_SERVER_IP, got to API and request a token"
echo "make sure to properly tune lava-env.inc for your user."
echo "In peculiar, the LAVA_RPC_LOGIN path and protocol must be consistent"

lava-tool auth-add $LAVA_RPC_LOGIN

