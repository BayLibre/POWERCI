# LAB Setup #

## Baylibre PowerCI Lab setup script ##

see the scripts located under :
> POWERCI/scripts/lab-setup

## Setup Conmux ##

As per <http://127.0.1.1/static/docs/known-devices.html>

Check that the device-type exists in lava-dispatcher/device-types

Launch the script create-conmux.sh and answer to the questions.
After that, you should have:

  * [your board].conf under /etc/lava-dispatcher/devices/
  * [your board].cf under /etc/conmux/
  * cu-loop script under /usr/local/bin
  * check that your boards are detected as usb device
  * link acme and board under tests to right ttyUSB devices.
  * /etc/hosts modified with hostname.local
  * conmux well started with our devices:

```
$ sudo conmux-console --list
acme baylibre-nuc.local:41622
am335x-boneblack baylibre-nuc.local:37067
```

  * check connection to acme and [your board]:

```
$ conmux-console --status acme
connected
```
```
$ conmux-console --status am335x-boneblack
connected
```

create-conmux.sh usage:
```
./create-conmux.sh -h
usage: create-conmux.sh [OPTION]

[OPTION]
    -h | --help:        Print this usage
    --version:          Print version
    -c | --clear:       Clear all existing configuration and proceed
    -v | --verbose:     Debug traces
    -s | --status:      Get status
    -l | --logfile:     Logfile to use
```

conmux current status
```
$ ./create-conmux.sh --status
USB devices connected (2):
/dev/ttyUSB2
/dev/ttyUSB3

Boards connected to ttyUSB (2)
  acme attached to ttyUSB2
  am335x-boneblack attached to ttyUSB3
```

remove a board, and add a new one:
```
$ ./create-conmux.sh
USB devices connected (2):
/dev/ttyUSB2
/dev/ttyUSB3

Boards connected to ttyUSB (2)
  acme attached to ttyUSB2
  am335x-boneblack attached to ttyUSB3

Do you want to remove device(s)? (Y/n) 

1. acme
2. am335x-boneblack
3. all
4. none
Please, enter your choice [1-4] (space separated if multi): 2
Please, unplug am335x-boneblack connected to ttyUSB3
.......-.You unplug the wrong ttyUSB, please reconnect it       => unplug the wrong usb is well detected
....+.Please, unplug am335x-boneblack connected to ttyUSB3
....-. 
  => Done
Do you want to add device(s)? (Y/n) 

Enter the name of the device to add: am335x-boneblack
Connect device am335x-boneblack to USB port
......+.    => Connected to ttyUSB1
    => OK symlink done, rule added
Another one? (Y/n) 
n
What is the baud rate used to connect to am335x-boneblack? (Default=115200)
conmux stop/waiting
conmux start/running, process 15534
Check if conmux config is started for each devices
yes: conmux started /etc/conmux/acme.cf pid=15540 TCP= *:45430 (LISTEN)
yes: conmux started /etc/conmux/am335x-boneblack.cf pid=15544 TCP= *:44186 (LISTEN)
Get address of acme
conmux-console connection to acme
  => conmux-console connection ok
Address read in acme is set to:
root@baylibre-acme-lab (192.168.1.38)
Correct? (Y|n): 
Define device type associated to each devices
Choose device type associated to am335x-boneblack
1. apq8016-sbc                                         => list created from /et/lava-dispatcher/device_types
2. bcm2835-rpi-b-plus
3. beaglebone-black
4. jetson-tk1
5. juno-bootloader
6. juno
7. kvm
8. meson8b-odroidc1
9. meson-gxbb-p200
10. omap5-uevm
11. panda-es
12. qemu-aarch64
13. qemu-arm
14. qemu-arm-cortex-a15
15. qemu-arm-cortex-a9
16. qemu
17. qemu-mips
18. qemu-ppc
19. rpi-zero
20. rtsm_ve-armv8
21. x86
Please, enter your choice [1-21] : 3
Enter ACME port connected to this device (From 1 to 8): 
1
ReStart am335x-boneblack:ttyUSB1:1-2.3:115200
conmux-console connection to acme
  => conmux-console connection ok
..............................                               => wait 30 sec... no polling yet
Get address of am335x-boneblack
conmux-console connection to am335x-boneblack
  => conmux-console connection ok
Address read in am335x-boneblack is set to:
root@am335x-boneblack (192.168.1.59)
Correct? (Y|n): 
BOARDS list set to:

NAME              TYPE              TTY      ACME_PORT  BAUD_RATE  ADDR                    IP
acme              beaglebone-black  ttyUSB0  -          115200     root@baylibre-acme-lab  192.168.1.38
am335x-boneblack  beaglebone-black  ttyUSB1  1          115200     root@am335x-boneblack   192.168.1.59

Create SSH connection between lab(baylibre-nuc), acme and dut
    Copy baylibre-nuc public key to baylibre-acme-lab
    => Check if baylibre-acme-lab is pingable
    => Check ssh connection from baylibre-nuc to 192.168.1.38 already exist
    => Copy /home/lavademo/.ssh/id_rsa.pub key via 'ssh' to 'root@baylibre-acme-lab.local'
    => Check ssh connection from baylibre-nuc to baylibre-acme-lab after key copy
    Done copy baylibre-nuc public key to baylibre-acme-lab
    Copy baylibre-nuc public key to am335x-boneblack
    => Check if am335x-boneblack is pingable
    => Check ssh connection from baylibre-nuc to 192.168.1.59 already exist
    => Copy /home/lavademo/.ssh/id_rsa.pub key via 'ssh' to 'root@am335x-boneblack'
    => Check ssh connection from baylibre-nuc to am335x-boneblack after key copy
    Done copy baylibre-nuc public key to am335x-boneblack
    Copy am335x-boneblack public key to acme
    => Check and Create pub key of am335x-boneblack
    => Get pub key from am335x-boneblack
id_rsa.pub                                                                              100%  403     0.4KB/s   00:00    
    => Copy pub key onto acme
    => Check if baylibre-acme-lab is pingable
    => Check ssh connection from baylibre-nuc to 192.168.1.38 already exist
    => Copy am335x-boneblack_id_rsa.pub key via 'ssh' to 'root@baylibre-acme-lab.local'
    => Check ssh connection from baylibre-nuc to baylibre-acme-lab after key copy
expect_exec_cmd.py                                                                      100%   15KB  14.5KB/s   00:00    
    => Check ssh connection from am335x-boneblack to acme
    Done copy am335x-boneblack public key to baylibre-acme-lab

Cleaning /etc/lava-dispatcher/devices
Create ACME conmux config
Create conmux conf of am335x-boneblack
conmux stop/waiting
conmux start/running, process 21048
Create lava conf of am335x-boneblack
Installed 2 object(s) from 1 fixture(s)
if acme is integrated into pdudaemon, then setup lavapdu.conf with 'pdu' as acme type

```









