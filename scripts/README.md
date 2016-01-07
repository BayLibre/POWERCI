# LAVACI interface #

## prerequisites ##

* the lava-ci python scripts must be in the path
* the ~/.lavarc file must be up-to-date, see user/token-files/.lavarc

## usage ##

the following API can be used with our (future) jenkins

* use baylibre-job-creator to create the "jobs" folder for a given kernel tag.
* use baylibre-runner to push the jobs to lava-baylibre, and create the results
* use baylibre-submit-kernelci to push the result to kernelci.
* use baylibre-submit-powerci to push the  results to powerci

# lava tools test and validation scripts #

The following is for bringup of the LAVA instance only.

## Lava user scripts ##

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

