# LAB Setup #

## Howto populate the Devices ##

As per <http://127.0.1.1/static/docs/known-devices.html>

  * check that the device-type exists in lava-dispatcher/device-types
  * use the helper to add each board
  * the ser2net port must be allocated, and match ser2net.conf (option -t)
  * the pdudaemon port ditto (option -p)
  * option -b will create the lab health bundle /anonymous/lab-health

### Baylibre PowerCI Lab setup script ##

run the script located under:

> POWERCI/scripts/lab-setup/add-boards-baylibre.sh

i.e (see actual file): 
```
	sudo /usr/share/lava-server/add_device.py kvm kvm01
	sudo /usr/share/lava-server/add_device.py beaglebone-black dut0-bbb -t 2000 -p 100 -b
	sudo /usr/share/lava-server/add_device.py beaglebone-black dut1-bbb -t 2001 -p 101
	sudo /usr/share/lava-server/add_device.py juno dut2-juno -t 2010 -p 110
```

remember restarting those services

```
	sudo /etc/init.d/ser2net restart
	sudo service lava-server restart
	sudo service apache2 restart
```

### Healthcheck jobs ###

* Healthcheck jobs are located in the test-definitions sub git pulled from <https://github.com/baylibre/lava-test-definitions>
* Those tests can be added fro the device-type admin django page.

## Setting up the boot process ##

### Adding a board, creating master images ###

the following link is useful <https://validation.linaro.org/static/docs/lava-image-creation.html#preparing-a-master-image>

### Power Cycling the boards ###

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
