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

Following is an example of execution if create-conmux.sh
```
$ ./create-conmux.sh
USB devices connected (2):
/dev/ttyUSB0
/dev/ttyUSB1

Devices connected to ttyUSB (2)
acme -> ttyUSB0
am335x-boneblack -> ttyUSB1

Do you want to add device(s)? (Y/n) 
n
Do you want to remove device(s)? (Y/n) 
n
What is the baud rate used to connect to acme? (Default=115200)
What is the baud rate used to connect to am335x-boneblack? (Default=115200)
conmux stop/waiting
conmux start/running, process 6104
Check if conmux config is started for each devices
yes: conmux started /etc/conmux/acme.cf pid=6110 TCP= *:35714 (LISTEN)
yes: conmux started /etc/conmux/am335x-boneblack.cf pid=6114 TCP= *:33058 (LISTEN)
ACME address is set to:
root@baylibre-acme-fab.local
Correct? (Y|n): 
BOARDS list set to:

NAME              TYPE              ACME_PORT  BAUD_RATE
am335x-boneblack  beaglebone-black  1          115200

Is it correct (Y|n): 
Cleaning /etc/lava-dispatcher/devices
Create ACME conmux config
Create conmux conf of am335x-boneblack
Create lava conf of am335x-boneblack
Installed 2 object(s) from 1 fixture(s)
if acme is integrated into pdudaemon, then setup lavapdu.conf with 'pdu' as acme type
conmux stop/waiting
conmux start/running, process 6596
```








