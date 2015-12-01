#!/bin/sh
root_dir=/home/powerci/POWERCI

mkdir -p $root_dir/fs-overlay/etc/lava-dispatcher/devices

sudo /usr/share/lava-server/add_device.py kvm kvm01
sudo /usr/share/lava-server/add_device.py beaglebone-black dut0-bbb -t 2000  -b
sudo /usr/share/lava-server/add_device.py panda-es dut1-panda-es -t 2001 
sudo /usr/share/lava-server/add_device.py juno dut2-juno -t 2002 

sudo service lava-server restart
sudo service apache2 restart

echo "check for the following:"
echo "sudo ln -s ~/POWERCI/fs-overlay/etc/lava-dispatcher/devices /etc/lava-dispatcher/devices"

