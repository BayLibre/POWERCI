#!/bin/bash

echo "Checklist:"
echo "jack power-probe for 96boards  for apq8016-sbc is connected on PROBE4 on the CAPE."
echo "apq8016-sbc is powered, its console is properly setup in ser2net, using port 2004"
echo "apq8016-sbc: its target USB is connected, for ADB access"


# requires sudoing

apt-get install android-tools-adb
echo 'SUBSYSTEM=="usb", ATTR{idVendor}=="05c6", MODE="0666", GROUP="plugdev"' >  /etc/udev/rules.d/51-android.rules
chmod a+r /etc/udev/rules.d/51-android.rules

# add apq8016-sbc to django DB

## prepare device-type template.
cp /home/powerci/POWERCI/SRC/lava-dispatcher/lava_dispatcher/default-config/lava-dispatcher/device-types/apq8016-sbc.conf /home/powerci/POWERCI/fs-overlay/etc/lava-dispatcher/device-types

## create the deviec conf file, setup the connectivity, the ACME board is assumed to be acme-demo.local
/home/powerci/POWERCI/scripts/lab-setup/add_baylibre_device.py apq8016-sbc  apq8016-sbc0 -t 2004 -p 4 -a "ssh -t root@acme-demo.local"


sudo service lava-server restart
sudo service apache2 restart


# Check adb connectivity (sudoing)

source ./adb-fixup.sh

