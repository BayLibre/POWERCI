# User workstation tools installation #

The lava tools package may be installed on remote client machines:

` sudo apt-get install lava-tool`

Note that we will be using lava-ci on top of the lava-tools in order to generate the json jobs and to post to KernelCI or PowerCI APIs. Lava-ci is pulled into POWERCI/scripts/lava-ci by the repo manifest.

## Django ##

As a pre-requisite, th django superuseraccount must have been created, an each user (like powerci) added.

` sudo lava-server manage createsuperuser --username default --email=$EMAIL`

## User Setup and Test ##

* make sure that the Django user has been created for $USER using the admin link :<http://127.0.1.1/admin/auth/user/>
* you may have to tune the top-level Makefile in case you sue a different user than "powerci" etc...
* The do-once setup steps can be executed with 'make', here are the relevant targets:
```
LAVA Setup & test tasks:
		auth		register user token with keyring (do once)
		stream		create /anonymous/LAVA_USER/ bundle stream (do once)
```

* for later manual testing (out of the lava-ci context,substitutions can be done with "make fix-jobs" see the Makefile for details.

# Posting Jobs #

We are now using lava-ci to create json jobs, run them with lava, and submit the results to kernelci and/or powerci

see "make help"


