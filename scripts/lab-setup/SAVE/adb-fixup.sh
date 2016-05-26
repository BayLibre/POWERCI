#!/bin/bash

# Check adb connectivity (sudoing)

udevadm --debug trigger
sudo adb kill-server 
sudo adb start-server

serial_number=`adb devices -l | grep msm8916 | sed -e 's/^\(\w*\)\s.*$/\1/g'`

# fixup device id matching a msm8916 

set -x
sed -i.bak '/serial_number/d' /etc/lava-dispatcher/devices/apq8016-sbc0.conf
echo "serial_number = $serial_number" >> /etc/lava-dispatcher/devices/apq8016-sbc0.conf
echo "adb_command = adb -s %(serial_number)s" >> /etc/lava-dispatcher/devices/apq8016-sbc0.conf
echo "fastboot_command = fastboot -s %(serial_number)s" >> /etc/lava-dispatcher/devices/apq8016-sbc0.conf





