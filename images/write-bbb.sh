#!/bin/bash

./check-disk $1
tar -xzf beaglebone-master.img.tgz
sudo dd bs=4M if=beaglebone-master.img of=$1
sync


