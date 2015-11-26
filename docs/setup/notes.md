# Initial Machine Setup #

> This applies to the LAVA infrastructure i.e. Dispatcher and Scheduler

> As for the KernelCI/PowerCI FrontEnd, a different virtual machine could be considered.

> We herein assume the host machine (virtual or not) is Ubuntu 14+

## preliminary packages and services installation ##

` sudo apt-get install vim gitk git-gui pandoc lynx terminator conmux minicom`

some required packages like ser2net and tftp-hpa are part of
the lava macro package.

## Repo init ##

` repo init -u git@github.com:mtitinger/powerci-manifests.git`
` Repo sync`

## Lava installation ##

` sudo apt-get install lava`

 * NFS          is installed by the lava pkg, with exports defaulting to /var/lib/lava/dispatcher/tmp
 * TFTP-HPA     is installed by the lava pkg, with exports defaulting to /var/lib/lava/dispatcher/tmp
(see /etc/default/tftpd-hpa)

### Interactive installation option ###
 * standalone server
 * Name "powerci-lava"
 * Postgres port 5432
 * internet site config for email
 * fully qualified domain name: powerci.org

## PowerCI-lava fs-overlays ##

Some standard LAVA-debian files needs being simlinked to this repo, like for instance:

` sudo ln -s ~/POWERCI/fs-overlay/etc/lava-dispatcher/device-types /etc/lava-dispatcher/device-types`

check in fs-overlay to not miss anything, for instance:

### General server branding ###

 * /etc/lava-server/settings.conf
 * /etc/lava-server/instance.conf
 * /etc/apache2/sites-available/powerci.conf

### Dispatcher Population ###

 * /etc/ser2net.conf
 * /etc/lava-dispatcher/device-types

# LAB Setup #

## Howto populate the Devices ##

As per <http://127.0.1.1/static/docs/known-devices.html>

  * check that the device-type exists in lava-dispatcher/device-types
  * use the helper to add each board
  * the ser2net port must be allocated, and match ser2net.conf (option -t)
  * the pdudaemon port ditto (option -p)
  * option -b will create the lab health bundle /anonymous/lab-health

## Baylibre PowerCI Lab setup script ##

run the script located under:

> POWERCI/scripts/lab-setup/add-boards-baylibre.sh

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

## Setting up the boot process ##

### TFTP support requirement ###

Check that your /etc/default/tftpd-hpa file references /var/lib/lava/dispatcher/tmp, or sudo cp /usr/share/lava-dispatcher/tftpd-hpa /etc/default/tftpd-hpa


# Post Jobs #

## Setup user and Test definitions ##

### Django ###

` sudo lava-server manage createsuperuser --username default --email=$EMAIL`

# Misc #

## Postgress notes ##

sudo pg_lsclusters
cat /var/log/postgresql/postgresql-9.4-main.log
