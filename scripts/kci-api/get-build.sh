#!/bin/bash

wget -d --header="Authorization: bb4d438a-f412-4c65-9f7c-9daefd253ee7" "https://api.kernelci.org/build?sort=created_on&sort_order=-1&limit=16&job=next" -O latest-builds

#cat latest-builds | json_pp 


