# User workstation tools installation #

` sudo apt-get install lava-tool`

# Posting Jobs #

see README in scripts.

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

### Django ###

` sudo lava-server manage createsuperuser --username default --email=$EMAIL`
