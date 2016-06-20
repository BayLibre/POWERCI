#!/bin/bash
ORANGE=`tput setaf 3`
RED=`tput setaf 1`
BLUE=`tput setaf 4`
NC=`tput sgr0`

#check if env var ACME_ADDR exist or not
#Enter it if not
if [ -z "`printenv | grep ACME_ADDR`" ];then
    ACME_ADDR="root@baylibre-acme-fab.local"
fi

echo "ACME address set to:"
echo ${ACME_ADDR}
echo -l "Is it correct (Y|n): "
read r
if [ "$r" == "n" ];then
    echo -l "Please enter your ACME adress: "
    read ACME_ADDR
fi

#Board connected to the ACME listed as:
#<device name>:<device type>:<acme port>[:baud rate]...[ <dev nameN>:<device type>:<acme portN>[:<baud rate>]]
#<> variable
#[] optionnal element
#example:
BOARDS="am335x-boneblack:beaglebone-black:1"

#define the ttyUSB connected
echo "List of ttyUSB connected"
echo "${BLUE}/dev/ttyUSB connected:${NC}"
for sysdevpath in $(find /sys/bus/usb/devices/usb*/ -name dev | grep ttyUSB); do
    (
        syspath="${sysdevpath%/dev}"
        devname="$(udevadm info -q name -p $syspath)"
        [[ "$devname" == "bus/"* ]] && continue
        eval "$(udevadm info -q property --export -p $syspath)"
        [[ -z "$ID_SERIAL" ]] && continue
        echo "/dev/$devname - $ID_SERIAL"
    )
done
echo ""

#clean previous config files
echo "Cleaning /etc/conmux and /etc/lava-dispatcher/devices"
rm -f /etc/conmux/*.cf
if [ ! -h /etc/lava-dispatcher/devices ];then
    ln -s ~/POWERCI/fs-overlay/etc/lava-dispatcher/devices /etc/lava-dispatcher/devices
fi
rm -f /etc/lava-dispatcher/devices/*.conf

#create the acme conmux config file
echo "Create ACME conmux config"
if [ ! -h "/dev/acme" ]; then
    if [ ! -f "/dev/ttyUSB0" ];then
        echo -e "${ORANGE}### WARNING ### /dev/acme does not exist"
        echo "Create automatically a link to /dev/ttyUSB0${NC}"
        ln -s /dev/ttyUSB0 /dev/acme
    else
        echo -e "${RED}### ERROR ### /dev/ttyUSB0 and /dev/acme does not exist"
        echo "Before use, please connect your ACME to ttyUSB0 and link it to /dev/acme${NC}"
    fi
fi

cat > /etc/conmux/acme.cf <<EOF
listener acme
application console 'acme console' 'exec sg dialout "/usr/local/bin/cu-loop /dev/acme 115200"'
EOF


#for each boards in the list
first_time=1
for b in ${BOARDS}; do
    IFS=':' read -a arr <<< "$b"
    board=${arr[0]}
    type=${arr[1]}
    port=${arr[2]}
    baud=${arr[3]}
    IFS=$OIFS
    if [ -z $baud ]; then
        baud=115200
    fi

    echo "Create conmux conf of ${board}"
    if [ ! -h "/dev/${board}" ]; then
        echo -e "${ORANGE}### WARNING ### /dev/${board} does not exist"
        echo "check that ${board} is connnected to a /dev/ttyUSB and link it to /dev/${board}${NC}"    
    fi
    cat > /etc/conmux/${board}.cf <<EOF
listener ${board}
application console '${board} console' 'exec sg dialout "/usr/local/bin/cu-loop /dev/${board} ${baud}"'
command 'hardreset' 'Reboot ${board}' 'ssh ${ACME_ADDR} dut-hard-reset ${port}'
command 'b' 'Reboot ${board}' 'ssh ${ACME_ADDR} dut-hard-reset ${port}'
command 'off' 'Power off ${board}' 'ssh ${ACME_ADDR} dut-switch-off ${port}'
command 'on' 'Power on ${board}' 'ssh ${ACME_ADDR} dut-switch-on ${port}'
EOF


    echo "Create lava conf of ${board}"
    # option -b : DO THE FIRST TIME TO CREATE THE BUNDLE
    #if [ ${first_time} -eq 1 ]; then
    #    sudo ./add_baylibre_device.py ${type} ${board}  -p ${port}  -a "ssh -t $ACME_ADDR" -b
    #    first_time=0
    #else
        sudo ./add_baylibre_device.py ${type} ${board}  -p ${port}  -a "ssh -t $ACME_ADDR" 
    #fi

done

echo "if acme is not yet integrated as a pdudaemon device, you may have to manually set the"
echo "following commands:"
echo " hard_reset_command = ssh -t $ACME_ADDR dut-hard-reset 1"
echo " power_off_cmd = ssh -t $ACME_ADDR dut-switch-off 1"

echo "if acme is integrated into pdudaemon, then setup lavapdu.conf with 'pdu' as acme type"
