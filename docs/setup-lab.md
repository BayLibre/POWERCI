# LAB Setup #

## Howto populate the Devices ##

This is done with script: 

> POWERCI/scripts/lab-setup/create-boards-conf.sh

**The README section related to device creation is now located [here](../scripts/lab-setup/lab-setup.md)**

### Healthcheck jobs ###

* Healthcheck jobs are located in the test-definitions sub git pulled from <https://github.com/baylibre/lava-test-definitions>
* Those tests can be added fro the device-type admin django page.

## Setting up the boot process ##

### Adding a board, creating master images ###

the following link is useful <https://validation.linaro.org/static/docs/lava-image-creation.html#preparing-a-master-image>

### Power Cycling the boards ###

#### ACME Controlled DUTs ####
until ACME is supported in PDUDaemon, the test JSON files can be adapted to log into ACME and switch the power probes GPIOs.
The script "acme_0#>/usr/bin/dut-switch-on 2" for instance will power on the DUT connected to PROBE2.
the following scripts must be deployed on the ACME image create with buildroot, the are currently available in the git <blah>

> dut-switch-on {1..8}		enable gpio to power up PROBE{1..8}

> dut-switch-off {1..8}		disable gpio to power down PROBE{1..8}

> dut-hard-reset {1..8}		cycle gpio to reboot PROBE{1..8}

Those commands are used in the devices/{device}.conf files:

```
	POWERCI/fs-overlay/etc/lava-dispatcher/devices$ cat dut0-bbb.conf

		device_type = beaglebone-black
		hostname = dut0-bbb
		connection_command = telnet localhost 2000
		hard_reset_command = ssh -t root@acme_0.local dut-hard-reset 1
		power_off_cmd = ssh -t root@acme_0.local dut-switch-off 1
```

#### Energenie LAN PDU ####

A small control applet is located under SRC/egctl
It uses a config file in /etc/egtab, the current model owned by BayLibre
will respond to the following setting:

```
# /etc/egtab: egctl configuration file
#
# Name      Protocol IP              Port    Password
# --------- -------- --------------- ------- --------
egpm2     pms21    192.168.1.195    5000    1
```
a typical command line will be:

* switch off the second socket (others unchanged): /egctl egpm2 left off left left
* switch on  the second socket (others unchanged): /egctl egpm2 left on left left
* resetting a board: today it will require putting a sequence into a script.

### Power Stats Recording Tool ###

Compile and intall the capture tool:

```
make -C SRC/iio-capture install
```

### Setting Up the Client type ###

All device settings default to values defined in 

/usr/lib/python2.7/dist-packages/lava_dispatcher/default-config/lava-dispatcher/device-defaults.conf

unless they are overwritten by the specific device type file

>  (device-types/${TYPE}.conf) or the specific device file

>  (devices/${DEVICE}.conf)

In peculiar, when a board can be simply power-cycled and reboot to use the current
master file system, i.e. there is no need to reflash a boot loader and boot/rootfs
partitions, then the "client_type" parameter can be set to "master"

When partition labels are needed, for instance to flash a testboot and testrootfs partition when client_type=bootloader, an offset is added to the existing partitions 

### TFTP support requirement ###

Check that your /etc/default/tftpd-hpa file references /var/lib/lava/dispatcher/tmp, or sudo cp /usr/share/lava-dispatcher/tftpd-hpa /etc/default/tftpd-hpa

### Boards setup ###

## ACME (power switch) ##

See ACME repo: https://github.com/BayLibre/ACME

## BeagleBone-Black ##

Create an sdcard from linaro master images

## Panda es ##

create a new SDCard with a recent u-boot, so that command 'bootz' is avail.
Change the prompt in the device-types/panda-es.json accordingly

For instance:
bootloader_prompt= =>

## Jteson-TK1 ##

Adding u-boot instead of the prop BL from out-of-the-box: 
see https://github.com/NVIDIA/tegra-uboot-flasher-scripts/blob/master/README-developer.txt

console trouble: ser2net seems to disconnect after boot, to prevent this issue, the
device config file may use the following alternative command:

`connection_command = sg dialout "cu -l /dev/ttyUSB2 -s 115200"`
