#!/bin/bash
service --status-all | grep lavapdu
/usr/bin/pduclient --daemon localhost --hostname baylibre-acme.local --command $1 --port 1
tail -n 100 /var/log/lavapdu-runner.log 
echo 1 > /var/log/lavapdu-runner.log
