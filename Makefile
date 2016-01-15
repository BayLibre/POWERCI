
## User specific, but this is the user we use...
#
export LAVA_USER=powerci
export BUNDLE_STREAM=/anonymous/powerci
export LAVA_TOKEN=bm6p0a2q9w0sytib04bjacx0dlcdhnfo10qni24np8j5sk2tfxxqf65hygcpq13mzhaprf03dciec55ykpn0yr55k900i81ix0i5005y9fgk34x7j1eaq5k3pb6t2gdt

TAG=mainline/v4.4-rc5

RESULTS=lab-baylibre-$(subst /,_,$(TAG)).json

export LAVA_SERVER_IP=lava.baylibre.com
export LAVA_SERVER=http://lava.baylibre.com:10080/RPC2/

export LAVA_JOBS?=/home/powerci/POWERCI/jobs-$(subst /,_,$(TAG))

LAB_BAYLIBRE_TARGETS=beaglebone-black panda-es jetson-tk1

POWERCI_TOKEN=3caf9787-2521-4276-ad2e-af2c64d19707
POWERCI_API=http://powerci.org:8888

KERNELCI_TOKEN=bb4d438a-f412-4c65-9f7c-9daefd253ee7
KERNELCI_API=http://api.kernelci.org

help: $(HOME)/.lavarc
	@clear
	@echo
	@echo "LAVACI / PowerCI tasks:"
	@echo "		jobs		create jobs json files, based on selected kernel tag"
	@echo "		runner		invoke lava-ci runner with jobs repo"
	@echo "		powerci		push last results to powerci.org"
	@echo "		kernelci	push last results to kernelci.org"
	@echo "		clean		remove jobs and results"
	@echo
	@echo "Current LAVA config:"
	@cat -n ~/.lavarc
	@echo
	@echo "LAVA Setup & test tasks:"
	@echo "		auth		register user token with keyring (do once)"
	@echo "		stream		create /anonymous/LAVA_USER/ bundle stream (do once)"
	@echo "		fix-jobs	hack json files to use directly with lava-tool"
	@echo "		iio		build and install IIO power capture tools"
	@echo


## CREATE JOBS
#
jobs: ${LAVA_JOBS} $(HOME)/.lavarc

${LAVA_JOBS}:
	cd scripts/lava-ci && ./lava-kernel-ci-job-creator.py --section baylibre http://storage.kernelci.org/$(TAG) \
 	--plans boot \
	--targets $(LAB_BAYLIBRE_TARGETS) \
	--arch arm

scripts/lava-ci/$(RESULTS): runner
	-@mkdir -p archive
	-@cp -rf scripts/lava-ci/$(RESULTS) archive
	-@cp -f $(LAVA_JOBS) archive/$(RESULTS)

runner:	${LAVA_JOBS}
	cd scripts/lava-ci && ./lava-job-runner.py  --section baylibre  --poll $(RESULTS)

## SUBMIT
#
powerci:
	cd scripts/lava-ci && ./lava-report.py --boot results/$(RESULTS) --lab lab-baylibre --token ${POWERCI_TOKEN} --api ${POWERCI_API}

kernelci: scripts/lava-ci/$(RESULTS)
	cd scripts/lava-ci && ./lava-report.py --boot results/$(RESULTS) --lab lab-baylibre --token ${KERNELCI_TOKEN} --api ${KERNELCI_API}

## CLEANUP
#
clean:
	-@rm -rf jobs $(LAVA_JOBS)
	-@rm -rf jetson

## SETUP
#
$(HOME)/.lavarc:
	@echo "[baylibre]" > $@
	@echo "server: "$(LAVA_SERVER) >> $@
	@echo "token: "$(LAVA_TOKEN) >> $@
	@echo "stream: "$(BUNDLE_STREAM) >> $@
	@echo "username: powerci" >> $@
	@echo "jobs:" >> $@

## LAVA ADMINISTRATION SECTION, setting up the user ##
#
auth:
	echo $(LAVA_TOKEN) >  scripts/.$(LAVA_USER).tok
	lava-tool auth-add --token-file  scripts/.$(LAVA_USER).tok $(LAVA_SERVER)

scripts/.$(LAVA_USER).tok: auth

stream: scripts/.$(LAVA_USER).tok
	lava-tool make-stream --dashboard-url $(LAVA_SERVER) $(BUNDLE_STREAM)
	date -I > scripts/.$(BUNDLE_STREAM)

fix-jobs:
	-@rm -rf fixed-jobs
	@mkdir -p fixed-jobs
	@find $(LAVA_JOBS) -name *.json | xargs sed 's#LAVA_SERVER_IP#'"$LAVA_SERVER_IP"'#' -in-place=.fixed.json
	@find $(LAVA_JOBS) -name *.json | xargs sed 's#LAVA_SERVER#'"$LAVA_SERVER"'#' -in-place=.fixed.json
	@find $(LAVA_JOBS) -name *.json | xargs sed 's#BUNDLE_STREAM#'"$BUNDLE_STREAM"'#' -in-place=.fixed.json
	@find $(LAVA_JOBS) -name *.json | xargs sed 's#LAVA_RPC_LOGIN#'"$LAVA_RPC_LOGIN"'#' -in-place=.fixed.json
	mv $(LAVA_JOBS)/*.fixed.json fixed-jobs

iio:
	# build libiio
	@echo "Cmake may require a whole bunch of stuff:"
	@echo "sudo apt-get install libxml2-dev doxygen bison flex"
	cd SRC/libiio && cmake .
	make -C SRC/libiio
	sudo make -C SRC/libiio install
	# build capture and pos-processing app

## LAB DEBUG ##
#
### Post one job for debug
#
post:
	lava-tool submit-job http://powerci@lava.baylibre.com:10080/RPC2/ $(MYJOB)

jetson:
	cd scripts/lava-ci && LAVA_JOBS=$(shell pwd)/jetson ./lava-kernel-ci-job-creator.py --section baylibre http://storage.kernelci.org/$(TAG) \
	--plans boot --targets jetson-tk1 --arch arm
