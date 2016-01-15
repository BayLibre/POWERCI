# POWERCI Power metrics reporting #

This section is Work In Progress, some of the stuff herein
is subject to change, or even be wrong...

## Introduction and principle ##

* PowerCI metrics are posted for a "boot" as understood for KernelCI i.e. a test job performed to validate a given git-commit
* Those metrics are posted to PowerCI using an evolution of the KernelCI API "Sending a Boot Report" see <https://api.kernelci.org/examples.html>
* Not all labs will provide power metrics for a given "boot"
* Not all labs are LAVA
* PowerCI does not keep the complete ganularity of a "boot" session, meaning that unit-tests are not kept. COnsequently, it is LAVA that will allow for this sort of granularity.

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

## API Payload changes ##

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

### Optional fields additions ###

These fields must be optionnal, since not all labs will support them.

```
        "energy": "1234",
        "power_avg": "4567",
        "power_max": "8910",
        "power_min": "1011",
        "voltage_max": "1213",
        "current_max": "1415",
```


## Reminder on Lava job results ##

### Job results on disk ###

Some hints about how job results are stored on disk by the dispatcher

example in /var/lib/lava-server/default/media/job-output/job-165:

* output.txt
* result-bundle

output.txt is the raw console output of the job execution. The last line will
yield the url of the dashboard entry for the bundle:

> Dashboard : http://lava.baylibre.com:10080/dashboard/permalink/bundle/15cd1a9864f256bc4096a97703d6be5cae36dc51/

result-bundle is an extraction of the url above.

### Bundle JSON as a result of LAVA API get ###

example:
```
{
    "test_runs": [
        {
            "test_id": "lava",
            "attachments": [],
            "tags": [],
            "analyzer_assigned_date": "2016-01-14T17:21:40Z",
            "test_results": [
                {
                    "units": "",
                    "message": "",
                    "test_case_id": "deploy_linaro_kernel",
                    "result": "pass",
                    "measurement": ""
                },
                {
                    "units": "",
                    "message": "",
                    "test_case_id": "connect_to_console",
                    "result": "pass",
                    "measurement": ""
                },
                {
                    "units": "seconds",
                    "message": "",
                    "test_case_id": "enter_bootloader",
                    "result": "pass",
                    "measurement": "2.04"
                },
                {
                    "units": "",
                    "message": "",
                    "test_case_id": "execute_boot_cmds",
                    "result": "pass",
                    "measurement": ""
                },
                {
                    "units": "seconds",
                    "message": "",
                    "test_case_id": "boot_cmds_execution_time",
                    "result": "pass",
                    "measurement": "1.33"
                },
                {
                    "units": "",
                    "message": "Kernel Error: did not start booting.",
                    "test_case_id": "wait_for_image_boot_msg",
                    "result": "fail",
                    "measurement": ""
                },
                {
                    "units": "",
                    "message": "",
                    "test_case_id": "connect_to_console",
                    "result": "pass",
                    "measurement": ""
                },
                {
                    "units": "seconds",
                    "message": "",
                    "test_case_id": "enter_bootloader",
                    "result": "pass",
                    "measurement": "1.96"
                },
                {
                    "units": "",
                    "message": "",
                    "test_case_id": "execute_boot_cmds",
                    "result": "pass",
                    "measurement": ""
                },
                {
                    "units": "seconds",
                    "message": "",
                    "test_case_id": "boot_cmds_execution_time",
                    "result": "pass",
                    "measurement": "1.34"
                },
                {
                    "units": "",
                    "message": "Kernel Error: did not start booting.",
                    "test_case_id": "wait_for_image_boot_msg",
                    "result": "fail",
                    "measurement": ""
                },
                {
                    "units": "",
                    "message": "",
                    "test_case_id": "connect_to_console",
                    "result": "pass",
                    "measurement": ""
                },
                {
                    "units": "seconds",
                    "message": "",
                    "test_case_id": "enter_bootloader",
                    "result": "pass",
                    "measurement": "1.89"
                },
                {
                    "units": "",
                    "message": "",
                    "test_case_id": "execute_boot_cmds",
                    "result": "pass",
                    "measurement": ""
                },
                {
                    "units": "seconds",
                    "message": "",
                    "test_case_id": "boot_cmds_execution_time",
                    "result": "pass",
                    "measurement": "1.34"
                },
                {
                    "units": "",
                    "message": "Kernel Error: did not start booting.",
                    "test_case_id": "wait_for_image_boot_msg",
                    "result": "fail",
                    "measurement": ""
                },
                {
                    "units": "",
                    "message": "Lava failed at action boot_linaro_image with error:Failed to boot test image.\nTraceback (most recent call last):\n  File \"/usr/lib/python2.7/dist-packages/lava_dispatcher/job.py\", line 381, in run\n    action.run(**params)\n  File \"/usr/lib/python2.7/dist-packages/lava_dispatcher/actions/boot_control.py\", line 156, in run\n    raise CriticalError(\"Failed to boot test image.\")\nCriticalError: Failed to boot test image.\n",
                    "test_case_id": "boot_linaro_image",
                    "result": "fail",
                    "measurement": ""
                },
                {
                    "units": "",
                    "message": "",
                    "test_case_id": "gather_results",
                    "result": "pass",
                    "measurement": ""
                },
                {
                    "units": "",
                    "message": "",
                    "test_case_id": "job_complete",
                    "result": "fail",
                    "measurement": ""
                }
            ],
            "analyzer_assigned_uuid": "466e5444-bae3-11e5-ae7a-3ca82a9f2df0",
            "attributes": {
                "target.hostname": "dut1-panda-es",
                "target": "dut1-panda-es",
                "boot_retries": "2",
                "target.device_version": "error",
                "initrd-addr": "0x81600000",
                "kernel-addr": "0x80200000",
                "dtb-addr": "0x815f0000",
                "kernel-image": "uImage",
                "logging_level": "DEBUG"
            },
            "time_check_performed": false
        }
    ],
    "format": "Dashboard Bundle Format 1.7.1"
}

```


