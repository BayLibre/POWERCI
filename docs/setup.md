# Initial Machine Setup #

> This applies to the LAVA infrastructure i.e. Dispatcher and Scheduler

> As for the KernelCI/PowerCI FrontEnd, a different virtual machine could be considered.

> We herein assume the host machine (virtual or not) is Ubuntu 14+, with a sudoer user powerci, and a configured static IP address.

> The machine name shall be lava-baylibre

Note that since we will be using different ports on server side (80/443) or client side (10080/10443)
It is mandatory to define on each machine an alias in /etc/hosts:

 * Server Side
```
lava.baylibre.com:80	lava-baylibre
```

 * Client Side
```
lava.baylibre.com:10080    lava-baylibre
```

## preliminary packages and services installation ##

` sudo apt-get install openssh-server vim gitk git-gui pandoc lynx terminator conmux minicom repo qemu gcc-arm-linux-gnueabi tree meld`

some required packages like ser2net and tftp-hpa are part of
the lava macro package.

Re-instate vim as the standard editor with:

` sudo update-alternatives --config editor`


## Repo init ##

Make sure to create an ssh id_rsa.pub key for the powerci user, and add it to the various git repos used (baylibre and github)

` mkdir -p /home/powerci/POWERCI && cd POWERCI`

` repo init -u git@github.com:mtitinger/powerci-manifests.git`

` repo sync`

## Lava installation ##

### Adding the repository ###

According to the documentation, do the following:

` sudo apt-get upgrade`

` wget http://images.validation.linaro.org/trusty-repo/trusty-repo.key.asc`

` sudo apt-key add trusty-repo.key.asc`

` sudo apt-get update`

### Installing the LAVA "full set" ###

` sudo apt-get install lava`

 * NFS          is installed by the lava pkg, with exports defaulting to /var/lib/lava/dispatcher/tmp
 * TFTP-HPA     is installed by the lava pkg, with exports defaulting to /var/lib/lava/dispatcher/tmp
(see /etc/default/tftpd-hpa)

### Interactive installation option ###
 * standalone server
 * Name "lab-baylibre"
 * Postgres port 5432
 * internet site config for email
 * fully qualified domain name: baylibre.com

##  LAVA fs-overlays ##

Some standard LAVA-debian files needs being simlinked to this repo, like for instance:

` sudo ln -s ~/POWERCI/fs-overlay/etc/lava-dispatcher/device-types /etc/lava-dispatcher/device-types`

check in fs-overlay to not miss anything, for instance:

### General server branding ###

 * /etc/lava-server/settings.conf
 * /etc/apache2/sites-available/powerci.conf

### Dispatcher Population ###

 * /etc/ser2net.conf
 * /etc/lava-dispatcher/device-types
 * /etc/lava-dispatcher/devices

## Initial LAVA Server Administration ##

### Apache site enabling

Query the active site with:

<code>
powerci@lab-baylibre:~$ sudo a2query -s
000-default (enabled by site administrator)
</code>

You may now disable the default site, and enable the lava instance:

> sudo a2dissite 000-default

> sudo a2ensite lava-server.conf

> sudo service apache2 restart

### Create the LAVA superuser account ###

> sudo lava-server manage createsuperuser --username lab-admin --email=lab-admin@baylibre.com

> password: powerci

for debug only, it is recommended to settings the log level for the server
to 'debug', in file /etc/init.d/lava-server

### Users and Groups ###

see <https://wiki.debian.org/LAVA>

# LAB Setup #

 This section is aimed on the dispatcher and Lab configuration.
 
 This dispatcher may be on a different machine, physically connected to the boards.

 See [setup-lab.md](docs/setup-lab.md)

# Posting Jobs, using LAVA #

 This section is about using scripts and lava-tools to posting jobs.

 This requires the dispatcher to be setup, and will describe what to do as a user.

 See [user-jobs.md](docs/user-jobs.md)

