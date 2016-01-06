#!/bin/bash

## create jobs for JUNO
#python lava-ci/lava-kernel-ci-job-creator.py http://storage.kernelci.org/next/next-20160104/ --plans boot --targets juno --arch arm64

## create jobs for BBB
python lava-ci/lava-kernel-ci-job-creator.py http://storage.kernelci.org/next/next-20160104/ --plans boot --targets beaglebone-black --arch arm

## create jobs for Panda-es
python lava-ci/lava-kernel-ci-job-creator.py http://storage.kernelci.org/next/next-20160104/ --plans boot --targets panda-es --arch arm
