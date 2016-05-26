#!/bin/sh
ACME_CMD="ssh -t root@lab-baylibre-acme.local"

echo "## devices declared with conmux: ##"
ls -1 /etc/conmux/*.cf

# option -b : DO THE FIRST TIME TO CREATE THE BUNDLE 
#sudo ./add_baylibre_device.py beaglebone-black am335x-boneblack  -p 1  -a "$ACME_CMD" -b

sudo ./add_baylibre_device.py beaglebone-black am335x-boneblack  -p 1  -a "$ACME_CMD"
sudo ./add_baylibre_device.py panda-es omap4-panda-es -p 2 -a "$ACME_CMD"
sudo ./add_baylibre_device.py meson8b-odroidc1 meson8b-odroidc1 -p 4 -a "$ACME_CMD"

# TODO sudo ./add_baylibre_device.py meson-gxbb-odroidc2 meson-gxbb-odroidc2 -p 4 -a "$ACME_CMD"
# TODO sudo ./add_baylibre_device.py meson-gxbb-p200 meson-gxbb-p200 -p 4 -a "$ACME_CMD"
# TODO sudo ./add_baylibre_device.py r8a7795-salvator-x r8a7795-salvator-x -p 5 -a "$ACME_CMD"

# RETIRED sudo ./add_baylibre_device.py rpi-zero rpi-zero_0 -p 3 -a "$ACME_CMD"

echo "check for the following:"
echo "sudo ln -s ~/POWERCI/fs-overlay/etc/lava-dispatcher/devices /etc/lava-dispatcher/devices"

echo "if acme is not yet integrated as a pdudaemon device, you may have to manually set the"
echo "following commands:"
echo " hard_reset_command = ssh -t root@baylibre-acme.local dut-hard-reset 1"
echo " power_off_cmd = ssh -t root@baylibre-acme.local dut-switch-off 1"

echo "if acme is integrated into pdudaemon, then setup lavapdu.conf with 'pdu' as acme type"
