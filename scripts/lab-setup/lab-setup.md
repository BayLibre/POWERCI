# LAB Setup #

## Baylibre PowerCI Lab setup script ##

see the scripts located under :
> POWERCI/scripts/lab-setup

Copy POWERCI/scripts/lab-setup/cu-loop script under /usr/local/bin

## Howto populate the Devices ##

As per <http://127.0.1.1/static/docs/known-devices.html>

  * check that the device-type exists in lava-dispatcher/device-types
  * launch the script create-boards-conf.sh and answer to the questions
    the script will create the /etc/conmux/<board>.cf as well as /etc/lava-dispatcher/devices/<board>.conf

```
$ sudo ./create-boards-conf.sh
[sudo] password for testlava: 
ACME address set to:
root@baylibre-acme-fab.local
-l Is it correct (Y|n): 

BOARDS list set to:
am335x-boneblack:beaglebone-black:1:115200
-l Is it correct (Y|n): 

List of ttyUSB connected
/dev/ttyUSB connected:
/dev/ttyUSB0 - Prolific_Technology_Inc._USB-Serial_Controller
/dev/ttyUSB1 - Prolific_Technology_Inc._USB-Serial_Controller

Cleaning /etc/conmux and /etc/lava-dispatcher/devices
Create ACME conmux config
Create conmux conf of am335x-boneblack
### WARNING ### /dev/am335x-boneblack does not exist
check that am335x-boneblack is connnected to a /dev/ttyUSB and link it to /dev/am335x-boneblack
Create lava conf of am335x-boneblack
Installed 2 object(s) from 1 fixture(s)
if acme is not yet integrated as a pdudaemon device, you may have to manually set the
following commands:
 hard_reset_command = ssh -t root@baylibre-acme-fab.local dut-hard-reset 1
 power_off_cmd = ssh -t root@baylibre-acme-fab.local dut-switch-off 1
if acme is integrated into pdudaemon, then setup lavapdu.conf with 'pdu' as acme type

```

## Setup Conmux ##

After previous step you should have:

  * [your board].conf under /etc/lava-dispatcher/devices/
  * [your board].cf under /etc/conmux/
  * cu-loop script under /usr/local/bin
  * check that your boards are detected as usb device
  * link acme and board to their devices.

```
$ ln -s /dev/ttyUSB0 /dev/acme
$ ln -s /dev/ttyUSB1 /dev/<your board>
```

  * assuming your hostname is lava-demo (result of command uname -n), Add lava-demo.local to /etc/hosts like:

```
127.0.0.1 localhost
127.0.1.1 lava-demo lava-demo.local
```

  * stop then start conmux

```
$ sudo stop conmux
$ sudo start conmux
```

   * check conmux starts well:

```
$ ps -aux | grep conmux
root 1360 0.0 0.0 37060 3588 ? Ss 14:22 0:00 /usr/bin/perl /usr/sbin/conmux-registry 63000 /var/run/conmux-registry
root 1550 0.0 0.0 55136 4704 ? Ss 14:22 0:00 /usr/bin/perl /usr/sbin/conmux /etc/conmux/acme.cf
root 1553 0.0 0.0 55140 4848 ? Ss 14:22 0:00 /usr/bin/perl /usr/sbin/conmux /etc/conmux/am335x-boneblack.cf
testlava 10962  0.0  0.0  15952  2260 pts/0    S+   17:24   0:00 grep --color=auto conmux
$ sudo lsof -nP -i | grep conmux
[sudo] password for testlava: 
conmux-re 1360            root    3u  IPv4  12574      0t0  TCP *:63000 (LISTEN)
conmux    1550            root    3u  IPv4  12591      0t0  TCP *:42514 (LISTEN)
conmux    1553            root    3u  IPv4  12659      0t0  TCP *:41040 (LISTEN)
```

  * check connection to acme and [your board]:

```
$ conmux-console acme
Connected to acme console [channel connected] (~$quit to exit)

# uname -a
Linux baylibre-acme-fab 4.5.0-acme+ #1 SMP Mon May 23 15:46:38 CEST 2016 armv7l GNU/Linux
# 
Command(acme console)> quit
Connection Closed (server)
```






