#!/bin/bash
python lava-ci/lava-kernel-ci-job-creator.py http://storage.kernelci.org/next/next-20160104/ --plans boot --targets juno --arch arm64
