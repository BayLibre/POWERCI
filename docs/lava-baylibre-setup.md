# Initial Machine Setup #

> This applies to the LAVA infrastructure i.e. Dispatcher and Scheduler

> As for the KernelCI/PowerCI FrontEnd, a different virtual machine could be considered.

> We herein assume the host machine (virtual or not) is Ubuntu 14+, with a sudoer user powerci, and a configured static IP address.

> The machine name shall be lava-baylibre

Note that you will need to use the same port locally and remotely, for the apache virtualhost, for instance
10080. Also file /etc/lava-server/lava-dispatcher.conf will need to be changed, so that LAVA_IMAGE_URL contains the port number,
otherwise some test stances will default to port 80 and fail.


## preliminary packages and services installation ##

` sudo apt-get install openssh-server vim git gitk gitg git-gui pandoc lynx terminator conmux minicom phablet-tools qemu gcc-arm-linux-gnueabi tree meld`

some required packages like ser2net and tftp-hpa are part of
the lava macro package.

Re-instate vim as the standard editor with:

` sudo update-alternatives --config editor`


## Repo init ##

Before proceeding next step, make sure to create an ssh id_rsa.pub key for `<username>`, and add it to the various git repos used (baylibre and github)

` mkdir -p /home/$USER/POWERCI && cd POWERCI`

` repo init -u git@github.com:BayLibre/manifests.git -m powerci/default.xml`

` repo sync`

## Lava installation ##

Launch: 

`lab-install.sh` 

And that's done !
The script will ask you some detail during the run

Mainly, it will:
* get and add repo from http://images.validation.linaro.org/trusty-repo/trusty-repo.key.asc

* install lava "full set"

  => This might need an interactive installation withou following detail

`  standalone server`

`  Name "lab-baylibre"`

`  Postgres port 5432`

`  internet site config for email`

`  fully qualified domain name: baylibre.com`

* Create symlink from /home/$USER/POWERCI/SRC/lava-dispatcher/lava_dispatcher -> /usr/lib/python2.7/dist-packages/lava_dispatcher

  The power measurement hooks are currently located in a baylibre github branch.

  This branch is pulled by the manifest to SRC/lava-dispatcher. 

  It can be used in place of the python packages installed by the debian package.

* Create following symlink for fs-overlay

`/etc/lava-dispatcher/devices -> /home/lavademo/POWERCI/fs-overlay/etc/lava-dispatcher/devices`

`/etc/lava-dispatcher/device-types -> /home/lavademo/POWERCI/fs-overlay/etc/lava-dispatcher/device-types`

`/etc/lava-dispatcher/lava-dispatcher.conf -> /home/$USER/POWERCI/fs-overlay/etc/lava-dispatcher/lava-dispatcher.conf`

* Check config file such as

`  /etc/lava-server/settings.conf`

`  /etc/apache2/sites-available/powerci.conf`

`  /etc/lava-dispatcher/device-types/*`

* Setup Apache

  Enable site conf lava-server.conf instead of default

  restart apache

* Create a superuser account for lava-server

  Note that for debug only, it is recommended to settings the log level for the server
to 'debug', in file /etc/init.d/lava-server

* Launch following script that will setup serial and ssh connection, and create needed config file for acme and DUT

` create-conmux.sh -c`

  See [lab-setup.md](../scripts/lab-setup/lab-setup.md)


## Initial LAVA Server Administration ##


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

