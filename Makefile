## Default lab
export LAB=lab-baylibre
export LAVA_USER=powerci
export LAVA_SERVER_IP=lava.baylibre.com
export LAVA_TOKEN=n4q5ksdmahr600i5aa4h38taobfexu939gg1c53xgz89iuce25cc98pouy06iypqm0kk8l58luu4ukgzsnkf6fef4afma3f38qijw0lcfnxgz4wtdx152j90a6r0hqxu
export LAVA_SERVER=http://$(LAVA_SERVER_IP):10080/RPC2/

## Lab associated
ifeq ($(LAB),lab-baylibre)
  export LAVA_USER=powerci
  export LAVA_SERVER_IP=lava.baylibre.com
  export LAVA_TOKEN=n4q5ksdmahr600i5aa4h38taobfexu939gg1c53xgz89iuce25cc98pouy06iypqm0kk8l58luu4ukgzsnkf6fef4afma3f38qijw0lcfnxgz4wtdx152j90a6r0hqxu
  export LAVA_SERVER=http://$(LAVA_SERVER_IP):10080/RPC2/
else
ifeq ($(LAB),baylibre-nuc)
  export LAVA_USER=lavademo
  export LAVA_SERVER_IP=baylibre-nuc.local
  export LAVA_TOKEN=1yynsllg58f5z77fp5l02a2w2y2bha3n0yfaxlabbbwmcrggqbpocowhwpr05k924xlt0fkmt1p3fl22e9qn09cbhciks2fowem0no0iwl5q0t1qp493w4mdee0h3djo
  export LAVA_SERVER=http://$(LAVA_SERVER_IP):10080/RPC2/
endif
endif


## User specific, but this is the user we use...
#
# Note that if you create you own ~/.lavarc it should be used instead.
#
LAVA_CI_USER=powerci
export TOPDIR=/home/$(LAVA_CI_USER)/POWERCI

## This is where we store the attached files for each job.
#  This is used by lava-ci
#
export ATTACHMENTS=/var/www/html/kernel-ci/attachments

## Define this as the root dir for lava-ci
#
export WORKSPACE=$(TOPDIR)/SRC

export BUNDLE_STREAM=/anonymous/$(LAVA_USER)/

export TAG?=mainline/v4.6-rc7

#export TAG?=next/next-20160401
#export TAG?=broonie-regmap/v4.6-rc1-5-gdcb05f2c7eee
#export TAG?=stable/v4.4.6
#export TAG?=omap/v4.6-rc1-29-g6de37509e43d

RESULTS=lab-baylibre-$(subst /,_,$(TAG)).json


export LAB_BAYLIBRE_TARGETS?=beaglebone-black panda-es
#LAB_BAYLIBRE_TARGETS_64=juno

## API PHP ##
#POWERCI_TOKEN=8rf46sd53c-621f-4a02-80d6-f5ds4qfc15
#POWERCI_API=http://powerci.org:9999

## API Python ##
POWERCI_TOKEN=3caf9787-2521-4276-ad2e-af2c64d19707
POWERCI_API=http://powerci.org:8888

POWERCI_PLAN=power
#POWERCI_PLAN=ltp-mm

KERNELCI_TOKEN=bb4d438a-f412-4c65-9f7c-9daefd253ee7
KERNELCI_API=http://api.kernelci.org
KERNELCI_PLAN=boot

export TEST_PLAN?=$(POWERCI_PLAN)
export LAVA_JOBS?=$(TOPDIR)/jobs-$(subst /,_,$(TAG))-$(TEST_PLAN)

LAVA_CONFIG_FULL= --server $(LAVA_SERVER) --token $(LAVA_TOKEN) --stream $(BUNDLE_STREAM)

help: $(HOME)/.lavarc
	@clear
	@echo
	@echo "== PowerCI (new) FLOW =="
	@echo "		jobs		create jobs json files, based on selected kernel tag"
	@echo "		submit		post jobs to lava and exit"
	@echo "		matching	pull results from LAVA matching the current TAG"
	@echo "		pushtest	push last test/json results to powerci.org"
	@echo "		pushboot	push last boot/json results to kernelci.org"
	@echo "		clean		remove jobs and results"
	@echo "" 
	@echo "== LAVACI / PowerCI FLOW (on powerci.org) =="
	@echo "		jobs		create jobs json files, based on selected kernel tag"
	@echo "		runner		invoke lava-ci runner with jobs repo"
	@echo "		powerci		push last results to powerci.org"
	@echo "		kernelci	push last results to kernelci.org"
	@echo "		clean		remove jobs and results"
	@echo
	@echo "Current LAVA config:"
	@cat -n ~/.lavarc
	@echo
	@echo "Using TEST_PLAN=$(TEST_PLAN), change with $$>TEST_PLAN=new make jobs"
	@echo
	@echo "== LAVA Setup & test FLOW (on $(LAB)) =="
	@echo "		auth		register user token with keyring (do once)"
	@echo "		stream		create /anonymous/$(LAVA_USER)/ bundle stream (do once)"
	@echo "		fix-jobs	hack json files to use directly with lava-tool"
	@echo "		iio		build and install IIO power capture tools"
	@echo


## CREATE JOBS
#
jobs: ${LAVA_JOBS} $(HOME)/.lavarc

${LAVA_JOBS}:
#	cd $(WORKSPACE)/lava-ci && ./lava-kernel-ci-job-creator.py --section baylibre \
	http://storage.kernelci.org/$(TAG) \
	--plans $(TEST_PLAN) \
	--targets $(LAB_BAYLIBRE_TARGETS_64) \
	--arch arm64
	cd $(WORKSPACE)/lava-ci && ./lava-kernel-ci-job-creator.py \
	http://storage.kernelci.org/$(TAG) \
	--plans $(TEST_PLAN) \
	--targets $(LAB_BAYLIBRE_TARGETS) \
	--arch arm --jobs $(LAVA_JOBS)

$(WORKSPACE)/lava-ci/$(RESULTS): runner
	-@mkdir -p archive
	-@cp -rf $(WORKSPACE)/lava-ci/$(RESULTS) archive
	-@cp -f $(LAVA_JOBS) archive/$(RESULTS)


# ======== NEW FLOW ==========

get-latest:
ifneq (,$(JOB))
ifneq (,$(LATEST_TAG))
	SRC/lava-ci/kci_get_latest.py --token $(KERNELCI_TOKEN) --api $(KERNELCI_API) --job $(JOB) --last $(LATEST_TAG)
else
	SRC/lava-ci/kci_get_latest.py --token $(KERNELCI_TOKEN) --api $(KERNELCI_API) --job $(JOB)
endif
else
ifneq (,$(LATEST_TAG))
	SRC/lava-ci/kci_get_latest.py --token $(KERNELCI_TOKEN) --api $(KERNELCI_API) --last $(LATEST_TAG)
else
	SRC/lava-ci/kci_get_latest.py --token $(KERNELCI_TOKEN) --api $(KERNELCI_API)
endif
endif

submit:
	cd $(WORKSPACE)/lava-ci && ./lava-job-runner.py  $(LAVA_CONFIG_FULL) --jobs ${LAVA_JOBS}

matching:
	cd $(WORKSPACE)/lava-ci && ./lava-matching-report.py --section baylibre --matching $(subst /,-,$(TAG))

pushboot: 
	cd $(WORKSPACE)/lava-ci && ./lava-report.py --boot $(WORKSPACE)/lava-ci/results/matching-boots.json --lab $(LAB) --token ${POWERCI_TOKEN} --api ${POWERCI_API}

pushtest:
	cd $(WORKSPACE)/lava-ci && ./lava-report.py --test $(WORKSPACE)/lava-ci/results/matching-boots.json --lab $(LAB) --token ${POWERCI_TOKEN} --api ${POWERCI_API}

# ======== OLD FLOW ==========

runner:	${LAVA_JOBS}
	cd $(WORKSPACE)/lava-ci && ./lava-job-runner.py  $(LAVA_CONFIG_FULL)  --poll $(RESULTS)

powerci: 
	cd $(WORKSPACE)/lava-ci && ./lava-report.py --boot results/$(RESULTS) --lab $(LAB) --token ${POWERCI_TOKEN} --api ${POWERCI_API}

kernelci:
	cd $(WORKSPACE)/lava-ci && ./lava-report.py --boot results/$(RESULTS) --lab $(LAB) --token ${KERNELCI_TOKEN} --api ${KERNELCI_API}

# ==== rebuild the data base ====

alljobs:
	cd $(WORKSPACE)/lava-ci && ./lava-matching-report.py  --section baylibre
	cd $(WORKSPACE)/lava-ci && ./lava-report.py --boot results/matching-boots.json --lab $(LAB) --token ${POWERCI_TOKEN} --api ${POWERCI_API}

## CLEANUP
#
clean:
	-@rm -rf jobs-*

## SETUP
#
$(HOME)/.lavarc:
	@echo "[baylibre]" > $@
	@echo "server: "$(LAVA_SERVER) >> $@
	@echo "token: "$(LAVA_TOKEN) >> $@
	@echo "stream: "$(BUNDLE_STREAM) >> $@
	@echo "username: $(LAVA_USER)" >> $@
	@echo "jobs:" >> $@
	@echo "[kernelci]" >> $@
	@echo "token: "$(KERNELCI_TOKEN) >> $@
	@echo "api: "$(KERNELCI_API) >> $@

## LAVA ADMINISTRATION SECTION, setting up the user ##
#
scripts/.$(LAVA_USER).tok:
	echo $(LAVA_TOKEN) >  scripts/.$(LAVA_USER).tok
	lava-tool auth-add --token-file  scripts/.$(LAVA_USER).tok $(LAVA_SERVER)

auth: scripts/.$(LAVA_USER).tok

stream: scripts/.$(LAVA_USER).tok
	-@lava-tool make-stream --dashboard-url $(LAVA_SERVER) $(BUNDLE_STREAM)

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
	lava-tool submit-job $(LAVA_SERVER) $(MYJOB)

jetson:
	cd $(WORKSPACE)/lava-ci && LAVA_JOBS=$(shell pwd)/jetson ./lava-kernel-ci-job-creator.py --section baylibre http://storage.kernelci.org/$(TAG) \
	--plans boot --targets jetson-tk1 --arch arm
