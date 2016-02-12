#!/bin/sh
#root_dir=/home/powerci/POWERCI

#mv  $root_dir/fs-overlay/etc/lava-dispatcher/devices /tmp/old-devices
#mkdir -p $root_dir/fs-overlay/etc/lava-dispatcher/devices

#/usr/share/lava-server/add_device.py

#sudo ./add_baylibre_device.py qemu-arm qemu0
#sudo ./add_baylibre_device.py kvm kvm01
sudo ./add_baylibre_device.py beaglebone-black beaglebone-black_0  -t 2000 -p 1  -b
sudo ./add_baylibre_device.py panda-es panda-es_0 -t 2001 -p 2
#sudo ./add_baylibre_device.py juno dut2-juno -t 2002 -p 3
#sudo ./add_baylibre_device.py jetson-tk1 dut2-jetson-tk1 -t 2002 -p 3
sudo ./add_baylibre_device.py rpi-zero rpi-zero_0 -t 2003
sudo ./add_baylibre_device.py meson8b-odroidc1 meson8b-odroidc1_0 -t 2004

#sudo service lava-server restart
#sudo service apache2 restart

echo "check for the following:"
echo "sudo ln -s ~/POWERCI/fs-overlay/etc/lava-dispatcher/devices /etc/lava-dispatcher/devices"

echo "if acme is not yet integrated as a pdudaemon device, you may have to manually set the"
echo "following commands:"
echo " hard_reset_command = ssh -t root@baylibre-acme.local dut-hard-reset 1"
echo " power_off_cmd = ssh -t root@baylibre-acme.local dut-switch-off 1"

echo "if acme is integrated into pdudaemon, then setup lavapdu.conf with 'pdu' as acme type"
