#!/bin/sh
#root_dir=/home/powerci/POWERCI

#mv  $root_dir/fs-overlay/etc/lava-dispatcher/devices /tmp/old-devices
#mkdir -p $root_dir/fs-overlay/etc/lava-dispatcher/devices

#/usr/share/lava-server/add_device.py

#sudo ./add_baylibre_device.py qemu-arm qemu0
#sudo ./add_baylibre_device.py kvm kvm01
ACME_CMD="ssh -t root@lab-baylibre-acme.local"

sudo ./add_baylibre_device.py beaglebone-black beaglebone-black_0  -t 2000 -p 1  -a $ACME_CMD -b
sudo ./add_baylibre_device.py panda-es panda-es_0 -t 2001 -p 2 -a $ACME_CMD
sudo ./add_baylibre_device.py rpi-zero rpi-zero_0 -t 2003 -p 3 -a $ACME_CMD
sudo ./add_baylibre_device.py meson8b-odroidc1 meson8b-odroidc1_0 -t 2004 -p 4 -a $ACME_CMD
sudo ./add_baylibre_device.py juno-bootloader juno_0 -t 2005 -p 5 -a "ssh -t root@lab-baylibre-acme.local"

#sudo service lava-server restart
#sudo service apache2 restart

echo "check for the following:"
echo "sudo ln -s ~/POWERCI/fs-overlay/etc/lava-dispatcher/devices /etc/lava-dispatcher/devices"

echo "if acme is not yet integrated as a pdudaemon device, you may have to manually set the"
echo "following commands:"
echo " hard_reset_command = ssh -t root@baylibre-acme.local dut-hard-reset 1"
echo " power_off_cmd = ssh -t root@baylibre-acme.local dut-switch-off 1"

echo "if acme is integrated into pdudaemon, then setup lavapdu.conf with 'pdu' as acme type"
