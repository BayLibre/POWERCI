#!/bin/bash

. ./lava-env.inc

lava-tool auth-add --token-file token-files/$USER.tok $LAVA_RPC_LOGIN

