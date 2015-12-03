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

` repo sync`

## Lava installation ##

### Adding the repository ###

According to the documentation, do the following:

` sudo apt-get upgrade`
` wget http://images.validation.linaro.org/trusty-repo/trusty-repo.key.asc`
` sudo apt-key add trusty-repo.key.asc`
` sudo apt-get update`

### Installint the lava full set ###

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

 This section is aimed on the dispatcher and Lab configuration.
 
 This dispatcher may be on a different machine, physically connected to the boards.

 See [setup-lab.md](docs/setup-lab.md)

# Postting Jobs, using LAVA #

 This section is about using scripts and lava-tools to posting jobs.

 This requires the dispatcher to be setup, and will describe what to do as a user.

 See [user-jobs.md](docs/user-jobs.md)

# Misc #

## Postgress notes ##

sudo pg_lsclusters
cat /var/log/postgresql/postgresql-9.4-main.log
