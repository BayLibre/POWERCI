# POWERCI Power Metrics Reporting #

This repo contains:

- the lava-ci integration to interact with baylibre LAVA instance and KERNELCI or POWERCI
- the setup sources (fs-overlay), scripts and documentation to re-create the baylibre LAVA instance from scratch

This is meant to being deployed on lava.baylibre.com for the LAVA part and powerci.org for the lava-ci part.

this is meant to be pulled to /home/powerci, and operated mainly by user powerci.

## Repo init ##

` mkdir -p /home/powerci/POWERCI && cd POWERCI`

` repo init -u git@github.com:baylibre/manifests.git -m powerci/default.xml`

` repo sync`

## Getting started ##


* Edit Makefile, to specify the kernel tag of interest, currently it is picked for the kernelci storage
* make jobs
* make runner
* make powerci

done. 

## Introduction and principle ##

* PowerCI metrics are posted for a "boot" as understood for KernelCI i.e. a test job performed to validate a given git-commit
* Those metrics are posted to PowerCI using an evolution of the KernelCI API "Sending a Boot Report" see <https://api.kernelci.org/examples.html>
* Not all labs will provide power metrics for a given "boot"
* Not all labs are LAVA
* PowerCI does not keep the complete ganularity of a "boot" session, meaning that unit-tests are not kept. COnsequently, it is LAVA that will allow for this sort of granularity.

**The README section related to Lava-baylibre creation are now located [here](docs/lava-baylibre-setup.md)**

## "Power Metrics" tab in the frontend

PowerCI adds a "[Power Metrics]" tab  <http://www.powerci.org/power/>

* each line is a job, like in the [boots] tab <http://www.kernelci.org/boot/>

The job status must be "passed", and the job must have some power metrics.

* col1 : a summary "Description and ID" links back to the matching line in [Boots]
* col2 : date
* col3 : Energy (Joule)
* col4 : Power Average (Watt)
* col5 : Power Max (W)
* col6 : Power Min (W)
* col7 : Voltage Max (Volt)
* col8 : Current Max (Ampere)

## KernelCI API Payload changes ##

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

## LAVA Power recording hooks ##

I am adding host_hook when entering/exitting lava_command_run.
The hooks are defined in either device.conf file, and in our case,
will call iio-capture tool.

The iio-capture tool will issue a PN_INFO line in the job log:

```
02:46:40 PM DEBUG: Executing on host : '['sh', '-c', u'iio-probe-stop 0']'
02:46:42 PM INFO: vmax=5187.50 pmax=1225.00 pavg=1113.38 pmin=1075.00 energy=75.17 cmax=234.00 cmin=207.00

```
This line yields the power metrics, and can be parsed by lava-report.py into the JSON payload for the POST command towards PowerCI API.

### Power Metrics Processsing App ###

The power metrics are created by calling the scripts in SRC/iio-capture:

* iio-probe-start [probe number]
* iio-probe-stop [probe number]

See <https://github.com/BayLibre/iio-capture>

the scripts and capture app uses the IIO connectivity with baylibre-acme.

see <https://github.com/BayLibre/ACME> and related wikis and READMEs for more info.


## LAVA_CI Test plan 'POWER' ##

I've added a template for a new test plan called power, based on the boot tests plan.
It will add a basic "lava_command_run" dispatcher action to create power measurements.

In future developments, it is advised to create specific lava_commands that will stimulate the power comsumption, for exempale:

* a video decod
* audio play/record
* suspend/resume cycle on pm_test mode.

See <https://github.com/BayLibre/lava-ci>
