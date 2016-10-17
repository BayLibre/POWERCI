# LAB Setup #

## Baylibre PowerCI Lab setup script ##

see the scripts located under :
> POWERCI/scripts/lab-setup

## Setup serial/ssh access ##

Serial access is done via conmux, a console access multiplexor. This is a telnet like tool but it permit multiple accesses to device at same time.

more information on conmux: <http://autotest.readthedocs.io/en/latest/main/remote/Conmux-OriginalDocumentation.html>

The pre-requisite element is a device-type config in lava-dispatcher/device-types
As per <http://127.0.1.1/static/docs/known-devices.html>

To setup the serial/ssh access with the needed config file automatically created, just launch 
```
$ create-conmux.sh -c
```
-c option will clear the ttyUSB devices connected. It will ask you to unplug every ttyUSB before processing.

After a while and some question, if process end successfully, you should have:

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

  * check connection to acme and dut:

```
$ conmux-console --status acme
connected
```

```
$ conmux-console --status am335x-boneblack
connected
```

  * SSH connection done from lab, acme and dut


Here are some usage of create-conmux.sh

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
USB and devices connected (2):
  /dev/ttyUSB0    acme
  /dev/ttyUSB1    am335x-boneblack

Check if conmux config is started for each devices
[sudo] password for test-lava: 
  acme:              status=connected     started=YES  config_file=/etc/conmux/acme.cf              pid=17612  TCP=*:33910(LISTEN)
  am335x-boneblack:  status=disconnected  started=YES  config_file=/etc/conmux/am335x-boneblack.cf  pid=17615  TCP=*:35183(LISTEN)

ACME Probe connected:
  Probe_1
  Probe_2

Devices address found:
acme:  root@baylibre-acme-lab  IP=192.168.1.38
acme:              root@baylibre-acme-lab  IP=192.168.1.38
am335x-boneblack:  None                    IP=None

SSH status:
* LAB testlava-server to ACME (acme):
  baylibre-acme-lab        not     pingable
  baylibre-acme-lab.local  OK
  192.168.1.38             OK
* LAB testlava-server to DUT (am335x-boneblack): FAIL
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

Create SSH connection between lab(testlava-server), acme and dut
    Copy testlava-server public key to baylibre-acme-lab
    => Check ssh connection from testlava-server to baylibre-acme-lab
Check ssh connection to:
 - baylibre-acme-lab => not pingable
 - baylibre-acme-lab.local => OK
 - 192.168.1.38 => OK
    => Copy local /home/test-lava/.ssh/id_rsa.pub key via 'ssh' to root@192.168.1.38
id_rsa.pub                                                                                      100%  407     0.4KB/s   00:00    
    => Check if baylibre-acme-lab (192.168.1.38) is restarted
.
    => Check ssh connection from testlava-server to baylibre-acme-lab after key copy
Check ssh connection to:
 - baylibre-acme-lab => not pingable
 - baylibre-acme-lab.local => OK
 - 192.168.1.38 => OK
    Done copy testlava-server public key to baylibre-acme-lab
    Copy testlava-server public key to am335x-boneblack
    => Check ssh connection from testlava-server to am335x-boneblack
Check ssh connection to:
 - am335x-boneblack => not pingable
 - am335x-boneblack.local => not pingable
 - 192.168.1.59 => not pingable
    => Copy local /home/test-lava/.ssh/id_rsa.pub key via 'conmux-console' to am335x-boneblack
    => Check if am335x-boneblack (192.168.1.59) is restarted
.
    => Check ssh connection from testlava-server to am335x-boneblack after key copy
Check ssh connection to:
 - am335x-boneblack => OK
 - am335x-boneblack.local => OK
 - 192.168.1.59 => OK
    Done copy testlava-server public key to am335x-boneblack
    Copy am335x-boneblack public key to acme
    => Check ssh connection from testlava-server to am335x-boneblack
Check ssh connection to:
 - am335x-boneblack => OK
 - am335x-boneblack.local => OK
 - 192.168.1.59 => OK
    => Check ssh connection from testlava-server to baylibre-acme-lab
Check ssh connection to:
 - baylibre-acme-lab => not pingable
 - baylibre-acme-lab.local => OK
 - 192.168.1.38 => OK
    => Copy .ssh/id_rsa.pub key via 'ssh' to 'root@192.168.1.38'
id_rsa.pub                                                                                      100%  403     0.4KB/s   00:00    
root@192.168.1.59_id_rsa.pub                                                                    100%  403     0.4KB/s   00:00    
    => Check if baylibre-acme-lab (192.168.1.38) is restarted
.
    => Check if am335x-boneblack (192.168.1.59) is restarted
.....
    => Check ssh connection from testlava-server to baylibre-acme-lab after key copy
Check ssh connection to:
 - baylibre-acme-lab => not pingable
 - baylibre-acme-lab.local => OK
 - 192.168.1.38 => OK
    => Check ssh connection from testlava-server to am335x-boneblack after key copy
Check ssh connection to:
 - am335x-boneblack => OK
 - am335x-boneblack.local => OK
 - 192.168.1.59 => OK
    => Check ssh connection from am335x-boneblack to baylibre-acme-lab after key copy
check-ssh.sh                                                                                    100% 2176     2.1KB/s   00:00    
    Done copy testlava-server public key to am335x-boneblack
Cleaning /etc/lava-dispatcher/devices
Create ACME conmux config
Create conmux conf of am335x-boneblack
conmux stop/waiting
conmux start/running, process 26460
Create lava conf of am335x-boneblack
Installed 2 object(s) from 1 fixture(s)
if acme is integrated into pdudaemon, then setup lavapdu.conf with 'pdu' as acme type
```









