#!/bin/sh
#sudo ./add_baylibre_device.py meson8b-odroidc1 meson8b-odroidc1_0 -t 2004 -p 4 -a $ACME_CMD
cp /home/powerci/POWERCI/SRC/lava-dispatcher/lava_dispatcher/default-config/lava-dispatcher/device-types/apq8016-sbc.conf /home/powerci/POWERCI/fs-overlay/etc/lava-dispatcher/device-types

sudo ./add_baylibre_device.py  apq8016-sbc  apq8016-sbc0 -t 2004 -p 4 -a "ssh -t root@lab-baylibre-acme.local"

sudo service lava-server restart
sudo service apache2 restart
