# Initial Machine Setup #

> This applies to the LAVA infrastructure i.e. Dispatcher and Scheduler

> As for the KernelCI/PowerCI FrontEnd, a different virtual machine could be considered.

> We herein assume the host machine (virtual or not) is Ubuntu 14+, with a sudoer user powerci, and a configured static IP address.

> The machine name shall be lava-baylibre

Note that you will need to use the same port locally and remotely, for the apache virtualhost, for instance
10080. Also file /etc/lava-server/lava-dispatcher.conf will need to be changed, so that LAVA_IMAGE_URL contains the port number,
otherwise some test stances will default to port 80 and fail.


## preliminary packages and services installation ##

` sudo apt-get install openssh-server vim gitk git-gui pandoc lynx terminator conmux minicom repo qemu gcc-arm-linux-gnueabi tree meld`

some required packages like ser2net and tftp-hpa are part of
the lava macro package.

Re-instate vim as the standard editor with:

` sudo update-alternatives --config editor`


## Repo init ##

Make sure to create an ssh id_rsa.pub key for the powerci user, and add it to the various git repos used (baylibre and github)

` mkdir -p /home/[username]/POWERCI && cd POWERCI`

` repo init -u git@github.com:BayLibre/manifests.git -m powerci/default.xml`

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

this manual step might be necessary:

> sudo cp /usr/share/lava-dispatcher/tftpd-hpa /etc/default/tftpd-hpa

### Interactive installation option ###
 * standalone server
 * Name "lab-baylibre"
 * Postgres port 5432
 * internet site config for email
 * fully qualified domain name: baylibre.com

## Using Local changes to the lava-dispatcher

The power measurement hooks are currently located in a baylibre github branch.
THis branch is pulled by the manifest to SRC/lava-dispatcher. 

It can be used in place of the python packages installed by the debian package.
In lava-baylibre:/usr/lib/python2.7/dist-packages, create a symlink like:

> sudo ln -s /home/[username]/POWERCI/SRC/lava-dispatcher/lava_dispatcher lava_dispatcher  


##  LAVA fs-overlays ##

Some standard LAVA-debian files needs being simlinked to this repo, like for instance:

```
sudo ln -s ~/POWERCI/fs-overlay/etc/lava-dispatcher/devices /etc/lava-dispatcher/devices
sudo ln -s ~/POWERCI/fs-overlay/etc/lava-dispatcher/device-types /etc/lava-dispatcher/device-types
sudo ln -s ~/POWERCI/fs-overlay/etc/lava-dispatcher/lava-dispatcher.conf /home/[username]/POWERCI/fs-overlay/etc/lava-dispatcher/lava-dispatcher.conf
```

check in fs-overlay to not miss anything, for instance:

### General server branding ###

 * /etc/lava-server/settings.conf
 * /etc/apache2/sites-available/powerci.conf

### Dispatcher Population ###

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

for debug only, it is recommended to settings the log level for the server
to 'debug', in file /etc/init.d/lava-server

### Users and Groups ###

see <https://wiki.debian.org/LAVA>

# LAB Setup #

 This section is aimed on the dispatcher and Lab configuration.
 
 This dispatcher may be on a different machine, physically connected to the boards.

 See [setup-lab.md](setup-lab.md)

# Posting Jobs, using LAVA #

 This section is about using scripts and lava-tools to posting jobs.

 This requires the dispatcher to be setup, and will describe what to do as a user.

 See [user-jobs.md](user-jobs.md)

# PowerCI, power metrics #

This section is about the implementation of POWERCI, specifically
how the power metrics are acquired and reported.

See [powerci.md](powerci.md)

