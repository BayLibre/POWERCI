# User workstation tools installation #

` sudo apt-get install lava-tool`

# Posting Jobs #

see README in scripts.

## User Setup and Test ##

* make sure that the Django user has been created for $USER using the admin link :<http://127.0.1.1/admin/auth/user/>
* copy and tune the lava-env.inc file

* retrieve the helper scripts in scripts/user, namely
```
	0_auth-add.sh		do only once to register the token into the keyring
	1_make-stream.sh	do only once to create the bundle stream
	2_post-job.sh		use to post jobs
```

### Django ###

` sudo lava-server manage createsuperuser --username default --email=$EMAIL`
