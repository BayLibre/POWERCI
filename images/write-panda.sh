#!/bin/bash

./check-disk $1
tar -xzf panda-master-20150303.img.tgz
sudo dd bs=4M if=panda-master.img of=$1
sync


