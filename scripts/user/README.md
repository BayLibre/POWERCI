# Lava user scripts #

documented @ http://127.0.1.1/static/docs/overview.html#id7

## User setup ##

It is assumed that the user account on the lava server was created,
and that the user logged into lava-server to create a token (API menu).
Paste the token string into a file name like your user:

> token-files/${USER}.tok

* 0_auth-add.sh		run once to register the token to the keyring
* 1_make-stream.sh	run once to create the bundle stream

## Posting a job ##

* 2_post-job.sh		run to post a job (arg 1 is the json file name)

## Image creation and deployable contents ##

some of the reference jobs in this folder require locally built images,
you may want to pull from the ACME repo for instance to build those images.

see <https://github.com/mtitinger/acme-manifests/blob/master/README.md>

