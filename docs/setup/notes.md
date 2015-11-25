# Initial Machine Setup #

## preliminary packages installation ##

> sudo apt-get install vim gitk git-gui pandoc lynx terminator

some required packages like ser2net and tftp-hpa are part of
the lava macro package.

## Repo init ##

> repo init -u git@github.com:mtitinger/powerci-manifests.git

> Repo sync

## Lava installation ##

> sudo apt-get install lava

### Interactive installation option ###
 * standalone server
 * Name "powerci-lava"
 * Postgres port 5432
 * internet site config for email
 * fully qualified domain name: powerci.com

## PowerCI-lava fs-overlay ##

Some standard LAVA-debian files needs being simlinked to this repo

> sudo ln -s ~/POWERCI/fs-overlay/etc/lava-dispatcher/device-types /etc/lava-dispatcher/device-types

check in fs-overlay to not miss anything, for instance:

### General server branding ###

 * /etc/lava-server/settings.conf
 * /etc/lava-server/instance.conf
 * /etc/apache2/sites-available/powerci.conf

### Dispatcher Population / LAB setup ###

 * /etc/ser2net.conf
 * /etc/lava-dispatcher/devices
 * /etc/lava-dispatcher/device-types


remember restarting those services:
> sudo /etc/init.d/ser2net restart



Postgress
---------

sudo pg_lsclusters
cat /var/log/postgresql/postgresql-9.4-main.log

 https://git.linaro.org/lava/lavapdu.git 


TFTP support requirement
-------------------------

Check that your /etc/default/tftpd-hpa file references /var/lib/lava/dispatcher/tmp and continue as before.
sudo cp /usr/share/lava-dispatcher/tftpd-hpa /etc/default/tftpd-hpa

Django
-----

sudo lava-server manage createsuperuser --username default --email=$EMAIL

Addind a new board to the dispatcher
------------------------------------

a) check that the device-type exists in ava-dispatcher/device-types
b) create /etc/lava-dispatcher/devices/panda01.conf

   + device_type = panda
   + hostname = panda01
   + connection_command = telnet localhost 2000
   + #connection_command = sg dialout "cu -l /dev/ttyUSB0 -s 115200"

