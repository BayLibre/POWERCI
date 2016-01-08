#!/bin/bash

export LAVA_SERVER_IP=lava.baylibre.com
export LAVA_SERVER=http://lava.baylibre.com:10080/RPC2/
export LAVA_JOBS=/home/powerci/POWERCI/jobs

## User specific, but this is the user we use...
#
export LAVA_USER=powerci
export BUNDLE_STREAM=/anonymous/powerci
export LAVA_TOKEN=bm6p0a2q9w0sytib04bjacx0dlcdhnfo10qni24np8j5sk2tfxxqf65hygcpq13mzhaprf03dciec55ykpn0yr55k900i81ix0i5005y9fgk34x7j1eaq5k3pb6t2gdt

## KernelCI API
#
export KERNELCI_TOKEN = bb4d438a-f412-4c65-9f7c-9daefd253ee7
export KERNELCI_API = http://api.kernelci.org

export PATH=$PATH:/home/powerci/POWERCI/scripts/lava-ci

