# POWERCI Power Oriented Continuous Integration - Internals #

## Introduction and Modus Operandi  ##

### Purpose of PowerCI ###

The purpose of POWERCI is to help Linux kernel maintainers and Embedded Device software (BSP) providers
to monitor the 'goodness' of kernel commits in regard of power consumption:

- _"Does this change or kernel config worsen the power consumption or energy during a specific test ?"_
- _"Is this board or SoC more leaky than another with this specific test ?"_
- _"Which git commit made thing worse (bisect) ?"_

### MO ###

POWERCI is inspired and partly based and contributed to [KernelCI](www.kernelci.org)

the current MO is: 

- check for new build in the KCI storage
- generate power-related jobs using lava-ci and the power templates.
- post jobs to LAVA, [lab-baylibre](lava.baylibre.com:10080)
- pull the job results and post to PowerCI

### GUIs and APIs ###

GUI Features are: 

- search and filter results amongst {board, Arch, Kernel-tree, Kernel-version, Test-case}
- select a Key Performance Indicator within { energy, power min/max/avg, current min/max, voltage min/max }
- zoomable/walkable/exportable temporal charts of Power metrics for a given test/job.
- regression curves over the history of a test job, for the difference metrics.

APIs are (WIP):

- KernelCI's /test API
- KernelCI's /boot API

## Installation and Usage ##

This repo contains the setup sources (fs-overlay), scripts and documentation to re-create the baylibre LAVA instance from scratch, as well as the scripts and makefiles for the POWERCI flow, especially lava-ci.

This is meant to being deployed on lava.baylibre.com for the LAVA part and powerci.org for the lava-ci part.

**The README section related to Lava-baylibre creation are now located [here](lava-baylibre-setup.md)**

this is meant to be pulled to /home/powerci, and operated mainly by user powerci.

### Getting started ###

* make help will display the up-to-date flow (may change compared to this doc)

example of complete flow: 

* Edit Makefile, to specify the kernel tag of interest, currently it is picked for the kernelci storage
* make jobs
* make runner
* make powerci

done. 

## KernelCI POST /boot API implementation ##

the changes described below are located in branch "boot-api-mod"
in git@github.com:BayLibre/lava-ci.git.

WIP: THIS MAY BE OBSOLETE as we are looking in using the TEST API.

### Original Payload ###

```
    payload = {
        "version": "1.0",
        "lab_name": "lab-name-00",
        "kernel": "next-20141118",
        "job": "next",
        "defconfig": "arm-omap2plus_defconfig",
        "board": "omap4-panda",
        "boot_result": "PASS",
        "boot_time": 10.4,
        "boot_warnings": 1,
        "endian": "little",
        "git_branch": "local/master",
        "git_commit": "fad15b648058ee5ea4b352888afa9030e0092f1b",
        "git_describe": "next-20141118"
    }
```

those fields match the optional parameters of the lava job JSON: 

```
        {
            "command": "deploy_linaro_kernel",
            "metadata": {
                "image.type": "kernel-ci",
                "image.url": "http://storage.kernelci.org/mainline/v4.4-rc5/arm-omap2plus_defconfig/",
                "kernel.tree": "mainline",
                "kernel.version": "v4.4-rc5",
                "device.tree": "am335x-boneblack.dtb",
                "kernel.endian": "little",
                "kernel.defconfig": "arm-omap2plus_defconfig",
                "platform.fastboot": "false",
                "test.plan": "boot"
            },
```

### Optional fields additions ###

We are adding a new test plan to lava-ci called "power". This implies:

* creating a job template folder for the power related plan, used during job generation
* extening the "POST" API payload with the mention of the test-plan, to handle specific data.

we add the following key:

```
	"test_plan": "power",
```

In the case of a 'power' test plan, the front-end will seek after
a list of unit test reports. This list is called "power_stats".
Each unit-test in the list is a dictionary of power statistics
to be displayed or charted if "title" and "data" allow to build a path
to a usable attached CSV file.

A unit test report as described above matches a test_case_id report
the in a LAVA job bundle.

```
        "power_stats": [{
                "power_min": "1425.00",
                "current_min": "279.00",
                "title": "data.csv",
                "energy": "290.78",
                "current_max": "353.00",
                "power_avg": "1435.59",
                "power_max": "1800.00",
                "voltage_max": "5125.00",
                "data": "c762a5ed"
        }],
```

These fields must be optionnal since not all labs will support them.

### Example of resulting payload ###

The fileds are as per the output of iio-capture, see <https://github.com/BayLibre/iio-capture>

```
{
	"kernel": "v4.5-rc3",
	"boot_log": "boot-am335x-boneblack.txt",
	"initrd": null,
	"boot_result": "PASS",
	"loadaddr": "0x81000000",
	"power_stats": [{
		"power_min": "1425.00",
		"current_min": "279.00",
		"title": "data.csv",
		"energy": "290.78",
		"current_max": "353.00",
		"power_avg": "1435.59",
		"power_max": "1800.00",
		"voltage_max": "5125.00",
		"data": "c762a5ed"
	}],
	"fastboot": "false",
	"dtb_append": "False",
	"lab_name": "lab-baylibre",
	"version": "1.0",
	"board": "am335x-boneblack",
	"dtb_addr": "0x81f00000",
	"dt_test": null,
	"boot_warnings": null,
	"initrd_addr": "0x82000000",
	"kernel_image": "zImage",
	"board_instance": "dut0-bbb",
	"job": "mainline",
	"boot_time": "4.30",
	"arch": "arm",
	"mach": "omap2",
	"boot_log_html": "boot-am335x-boneblack.html",
	"retries": 0,
	"dtb": "dtbs/am335x-boneblack.dtb",
	"defconfig": "omap2plus_defconfig",
	"test_plan": "power",
	"endian": "little"
}
```

## Test cases description ##

Since we are hooking "lava-command" instead of "lava-test-shell" we need to add a dedicated meta-data
"test.desc" to name the test-case, for instance "MP3 Decode" or "suspend/Resume".

hence in the **POST /boot** payload, we add "test_desc" taking the value of the "test.desc" fron the LAVA result bundle json.

eventually, when using the **POST /test/suite** API we will be using the "test.desc" as the "test_suite_name".
Test names like "MP3 Decode" will turn into a test_suite_name "MP3-Decode" (slugify)


## KernelCI /POST /test/suite implementation ##

the changes described below are located in branch "test-api-baylibre" of git@github.com:BayLibre/lava-ci.git

We post a testsuite/testset/testcase request according to the "canned" schema, e.g.:

```
{"build_id": "56b9648659b514b7f6e41fac",
 "lab_name": "lab-baylibre",
 "name": "lava-command",
 "test_set": [
		{
		 "name": "power-set",
		 "test_case": [
			{"status": "pass",
			 "measurements": [
				{"units": "mV", "name": "vbus_max", "measure": "5143.75"},
				{"units": "mJ", "name": "Energy", "measure": "628.53"},
				{"units": "mW", "name": "power_min", "measure": "1425.00"},
				{"units": "mW", "name": "power_max", "measure": "1800.00"},
				{"units": "mW", "name": "power_avg", "measure": "1469.88"},
				{"units": "mA", "name": "current_min", "measure": "281.00"},
				{"units": "mA", "name": "current_max", "measure": "348.00"}
				],
			 "name": "sleep 10"
			}
		    	]
		   }
		]
}
```

## LAVA Power recording hooks ##

I am adding host_hook when entering/exitting lava_command_run.
The hooks are defined in either device.conf file, and in our case,
will call iio-capture tool.

The iio-capture tool will issue LAVA_SIGNAL_TEST_CASE entries in the job log:

```
<LAVA_SIGNAL_TESTCASE TEST_CASE_ID=vbus_max RESULT=pass UNITS=mV MEASUREMENT=5178.75

```
This line yields the power metrics, and can be parsed by lava-report.py into the JSON payload for the POST command towards PowerCI API.

### Power Metrics Processsing App ###

The power metrics are created by calling the scripts in SRC/iio-capture:

* iio-probe-start [probe number]
* iio-probe-stop [probe number]

Please visit <https://github.com/BayLibre/iio-capture> for more details.

the scripts and capture app uses the IIO connectivity with baylibre-acme.

see <https://github.com/BayLibre/ACME> and related wikis and READMEs for more info.


## LAVA-CI Test plan 'POWER' ##

I've added a template for a new test plan called power, based on the boot tests plan.
It will add a basic "lava_command_run" dispatcher action to create power measurements.

In future developments, it is advised to create specific lava_commands that will stimulate the power comsumption, for exempale:

* a video decod
* audio play/record
* suspend/resume cycle on pm_test mode.

See <https://github.com/BayLibre/lava-ci>
