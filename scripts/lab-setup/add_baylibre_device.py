#! /usr/bin/python
# -*- coding: utf-8 -*-
#
#  add_device.py
#
#  Copyright 2014 Linaro Limited
#  Author: Neil Williams <neil.williams@linaro.org>
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 3 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>.

# The aim of this script is to be a stand-alone helper to add new
# devices to a LAVA instance - wrapping local calls to lava-server manage
# on that instance. It is intended for use by local admins or
# community packagers instead of LAVA users and hence is not part
# of lava-tool and is explicitly not intended to gain XMLRPC support.
# The script renders files suitable for use with ConfigFile, it is not
# intended to gain Django settings.


import argparse
import simplejson
import subprocess
import os
import tempfile
import logging

def template_bundle_stream():
    """
    Returns the current definition of the dashboard_app.BundleStream
    model to a template JSON. The fields need to be updated
    when new migrations are added which affect the BundleStream model.
    """
    stream_json = subprocess.check_output([
        "lava-server",
        "manage",
        "dumpdata",
        "--format=json",
        "dashboard_app.BundleStream"
    ])
    devices = simplejson.loads(stream_json)
    if len(devices) > 0:
        return None
    return {
        'fields': {
            "is_public": True,
            "group": None,
            "is_anonymous": True,
            "slug": "lab-health",
            "name": "lab-health",
            "pathname": "/anonymous/lab-health/",
            "user": 1,
        },
        "model": "dashboard_app.bundlestream",
    }


def template_device():
    """
    Returns the current definition of the lava_scheduler_app.Device
    model to a template JSON. The fields need to be updated
    when new migrations are added which affect the Device model.
    """
    device_json = subprocess.check_output([
        "lava-server",
        "manage",
        "dumpdata",
        "--format=json",
        "lava_scheduler_app.Device"
    ])
    devices = simplejson.loads(device_json)
    if len(devices) == 0:
        template = {
            'fields': {},
            "model": "lava_scheduler_app.device",
        }
    else:
        template = devices[0]  # borrow the layout of the first device
    template['pk'] = "HOSTNAME"
    template['fields']['current_job'] = None
    template['fields']['status'] = 1  # Device.IDLE
    template['fields']['group'] = None
    template['fields']['description'] = ''
    template['fields']['tags'] = []
    template['fields']['last_health_report_job'] = None
    template['fields']['device_version'] = ''
    template['fields']['health_status'] = 0  # unknown
    template['fields']['worker_host'] = None
    template['fields']['user'] = None
    template['fields']['device_type'] = "DEVICE_TYPE"
    template['fields']['physical_group'] = None
    template['fields']['is_public'] = True
    template['fields']['physical_owner'] = None
    return template


def template_device_type():
    """
    Returns the current definition of the lava_scheduler_app.DeviceType
    model to a template JSON. The script needs to be updated
    when new migrations are added which affect the DeviceType model.
    """
    logging.debug("template_device_type START")
    type_json = subprocess.check_output([
        "lava-server",
        "manage",
        "dumpdata",
        "--format=json",
        "lava_scheduler_app.DeviceType"
    ])
    types = simplejson.loads(type_json)
    if len(types) == 0:
        template = {
            'fields': {},
            "model": "lava_scheduler_app.devicetype",
        }
    else:
        template = types[0]
    template['pk'] = "DEVICE_TYPE"
    template['fields']['health_check_job'] = ''
    template['fields']['display'] = True

    logging.debug(str(template))
    logging.debug("template_device_type END")
    return template


def add_baylibre_device(dt, name, options):
    if options.verbosity: verbosity_level=logging.DEBUG
    else:                 verbosity_level=logging.INFO
    logging.basicConfig(filename=options.logfile,filemode='a',level=verbosity_level,format='%(filename)s - %(levelname)s - %(message)s')

    config = {}
    sequence = [
        'device_type',
        'hostname',
        'connection_command',
	'host_hook_enter_command',
        'host_hook_exit_command',
        'hard_reset_command',
        'power_off_cmd'
    ]
    default_type = os.path.join("/etc/lava-dispatcher/device-types", "%s%s" % (dt, ".conf"))
    logging.info("device type exist?: %s" % default_type)
    if not os.path.exists(default_type):
        logging.info(" => No")
        # FIXME: integrate this into lava CLI to prevent the need
        # for this hardcoded path.
        default_type = os.path.join(
            "/usr/lib/python2.7/dist-packages/lava_dispatcher/",
            "default-config/lava-dispatcher/device-types/",
            "%s%s" % (dt, ".conf"))
        logging.info("so, device type exist?: %s" % default_type)
        if not os.path.exists(default_type):
            logging.info(" => No")
            logging.error("'%s' is not an existing device-type for this instance." % dt)
            logging.error("A default device_type configuration needs to be written as %s" % default_type)
            print ("'%s' is not an existing device-type for this instance." % dt)
            print ("A default device_type configuration needs to be written as %s" % default_type)
            exit(1)
        logging.info(" => Yes")
    
    config['device_type'] = dt
    deviceconf = os.path.join("/etc/lava-dispatcher/devices", "%s%s" % (name, ".conf"))
    logging.info("device name exist?: %s" % deviceconf)
    if os.path.exists(deviceconf):
        logging.info(" => No")
        logging.error("'%s' is an existing device on this instance." % name)
        logging.error("If you want to add another device of type %s, use a different devicename." % default_type)
        print ("'%s' is an existing device on this instance." % name)
        print ("If you want to add another device of type %s, use a different hostname." % default_type)
        exit(1)
    config['hostname'] = name
    # FIXME: need a config file for daemon, pdu hostname and telnet ser2net host
    if options.pduport:
        if options.acmecmd:
            config['host_hook_enter_command'] = "iio-probe-start " + options.acmecmd + " " + str(int(options.pduport)-1)
            config['host_hook_exit_command'] = "iio-probe-stop " + str(int(options.pduport)-1)
        else:
            config['hard_reset_command'] = "/usr/bin/pduclient " \
                                       "--daemon localhost " \
                                       "--hostname baylibre-acme.local --command reboot" \
                                       "--port %02d" % options.pduport
            config['power_off_cmd'] = "/usr/bin/pduclient " \
                                  "--daemon localhost " \
                                  "--hostname baylibre-acme.local --command off " \
                                  "--port %02d" % options.pduport
    else:
        logging.warning("Skipping hard_reset_command for %s" % name)
        print("Skipping hard_reset_command for %s" % name)
    if options.telnetport:
        config['connection_command'] = "telnet localhost %d" % options.telnetport
    else:
        config['connection_command'] = "conmux-console %s" % name
    
    template = [template_device_type()]
    template[0]['pk'] = dt
    template.append(template_device())
    template[1]['pk'] = name
    template[1]['fields']['device_type'] = dt
    if options.simulate:
        for key in sequence:
            if key in config:
                logging.info("%s = %s" % (key, config[key]))
                print "%s = %s" % (key, config[key])
        logging.info(simplejson.dumps(template, indent=4))
        print simplejson.dumps(template, indent=4)
        return 0
    with open(deviceconf, 'w') as f:
        for key in sequence:
            if key in config:
                f.write("%s = %s\n" % (key, config[key]))
    fd, json = tempfile.mkstemp(suffix=".json", text=True)
    if options.bundlestream:
        res=template_bundle_stream()
        if res != None:
            template.append(res)
    with open(json, 'w') as f:
        simplejson.dump(template, f, indent=4)
        f.write("\n")
    # sadly, lava-server manage loaddata exits 0 even if no data was loaded
    # so this only catches errors in lava-server itself.
    loaded = subprocess.check_call([
        "lava-server",
        "manage",
        "loaddata",
        "%s" % json
    ])
    if loaded:
        logging.error("lava-server manage loaddata failed for %s" % json)
        print "lava-server manage loaddata failed for %s" % json
        exit(1)
    else:
        os.close(fd)
        os.unlink(json)
    return 0

def main():
    description = "LAVA device helper. Allows local admins to add devices to a " \
                  "running instance by creating the database entry and creating an initial " \
                  "device configuration. Optionally add the pdu port and ser2net port to use " \
                  "for serial connections using telnet. Health check instructions, device" \
                  "tags and device ownership are NOT supported and need to be set using the " \
                  "Django admin interface. This script is intended for initial setup only." \
                  "pduport settings are intended to support lavapdu only." \
                  "telnetport settings are intended to support ser2net only."

    #parser = argparse.ArgumentParser(usage=usage, description=description)
    parser = argparse.ArgumentParser(description=description)
    parser.add_argument('devicetype',  metavar='devicetype', nargs=1, 
                       help="devicetype to use")
    parser.add_argument('devicename', metavar='devicename', nargs=1,
                       help="devicename to use")
    parser.add_argument("-a", "--acmecmd",      action="store",      dest="acmecmd",    
                       default="",
                       help="ACME ssh url for on/off ex: ssh -t root@lab-baylibre-acme.local")
    parser.add_argument("-p", "--pduport",      action="store",      dest="pduport",    
                       type=int,
                       help="PDU Portnumber (ex: 04)")
    parser.add_argument("-t", "--telnetport",   action="store",      dest="telnetport", 
                       type=int,
                       help="ser2net port (ex: 4003)")
    parser.add_argument("-b", "--bundlestream", action="store_true", dest="bundlestream",
                       help="add a lab health bundle stream if no streams exist.")
    parser.add_argument("-s", "--simulate",     action="store_true", dest="simulate",
                       help="output the data files without adding the device.")
    parser.add_argument("-l", "--logfile",      action="store",      dest='logfile',  
                       default="add_baylibre_device.log", 
                       help="logfile to use, default is conmux_cmd.log")
    parser.add_argument("-v", "--verbosity",    action="store_true", dest='verbosity', 
                       default=False, 
                       help="verbosity level, default=0")
    parser.add_argument("--version",            action="version", version='Version v1.1', 
                       help="print version")

    args=parser.parse_args()

    #pdb.set_trace()
    add_baylibre_device(args.devicetype[0], args.devicename[0], args)


if __name__ == '__main__':
    main()

