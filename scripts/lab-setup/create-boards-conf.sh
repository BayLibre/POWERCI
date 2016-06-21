#!/bin/bash
ORANGE=`tput setaf 3`
RED=`tput setaf 1`
BLUE=`tput setaf 4`
NC=`tput sgr0`

DEFAULT_ACME_ADDR="root@baylibre-acme-fab.local"
DEFAULT_BOARD_LIST="am335x-boneblack:beaglebone-black:1:115200"

###################################################################################
## check if environment variable ACME_ADDR exist or not
#  Purpose a default ACME_ADDR to user that shall validate or enter a new one
#  Put the validated ACME_ADDR in /etc/profile.d/lava_lab.sh that will contains some setup dedicated env variable
###################################################################################
acme_addr()
{
    if [ -z "`printenv | grep ACME_ADDR`" ];then
        ACME_ADDR=${DEFAULT_ACME_ADDR}
    fi
    
    echo "ACME address set to:"
    echo "${BLUE}${ACME_ADDR}${NC}"
    echo -n "Is it correct (Y|n): "
    read r
    if [ "$r" == "n" ];then
        echo -n "Please enter your ACME adress: "
        read ACME_ADDR
    fi
    echo "ACME_ADDR=${ACME_ADDR}" >> /etc/profile.d/lava_lab.sh 
}

###################################################################################
## list boards connected to ACME
#  Purpose a default BOARD_LIST to user that shall validate or enter a new one
#  Board are listed like:
#      <device name>:<device type>:<acme port>[:baud rate]...[<space><dev nameN>:<device type>:<acme portN>[:<baud rate>]]
#      <> variable
#      [] optionnal element
###################################################################################
board_list()
{
    echo "BOARDS list set to:"
    
    echo "NAME TYPE ACME_PORT BAUD_RATE" > /tmp/lava_board
    for b in ${DEFAULT_BOARD_LIST}; do
        IFS=':' read -a arr <<< "$b"

        baud=${arr[3]}
        IFS=$OIFS
        if [ -z $baud ]; then
            baud=115200
        fi

        echo "${arr[0]} ${arr[1]} ${arr[2]} ${baud}" >> /tmp/lava_board
    done
    echo $BLUE
    cat /tmp/lava_board | column -t
    echo $NC

    BOARDS=${DEFAULT_BOARD_LIST}
    echo -n "Is it correct (Y|n): "
    read r
    if [ "$r" == "n" ];then
        echo -n "Please enter your BOARD list formatted like <name>:<type>:<acme_port>[:<baud_rate>] "
        read BOARDS
    fi
}

###################################################################################
## List usb connected
###################################################################################
usb_connected()
{
    SAVE_IFS=$IFS
    IFS=$'\n'
    echo "List of ttyUSB connected"
    echo "/dev/ttyUSB connected:"
    for sysdevpath in `find /sys/bus/usb/devices/usb*/ -name dev | grep ttyUSB`; do
        syspath="${sysdevpath%/dev}"
        devname="$(udevadm info -q name -p $syspath)"
        [[ "$devname" == "bus/"* ]] && continue
        eval "$(udevadm info -q property --export -p $syspath)"
        [[ -z "$ID_SERIAL" ]] && continue
        echo "${BLUE}/dev/$devname - $ID_SERIAL${NC}"
    done
    echo ""
    IFS=$SAVE_IFS
}

###################################################################################
## Scripts starts here
###################################################################################

acme_addr

board_list

usb_connected

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
SAVE_IFS=$IFS
IFS=$'\n'
for b in `cat /tmp/lava_board | tail -n+2`; do
    IFS=' ' read -a arr <<< "$b"
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
    sudo ./add_baylibre_device.py ${type} ${board}  -p ${port}  -a "ssh -t $ACME_ADDR" -b

    if [ -z `cat /etc/lava-dispatcher/devices/${board}.conf | grep hard_reset_command` ]; then
        echo "hard_reset_command = ssh -t $ACME_ADDR dut-hard-reset ${port}" >> /etc/lava-dispatcher/devices/${board}.conf
    fi
    if [ -z `cat /etc/lava-dispatcher/devices/${board}.conf | grep power_off_cmd` ]; then
        echo "power_off_cmd = ssh -t $ACME_ADDR dut-switch-off ${port}" >> /etc/lava-dispatcher/devices/${board}.conf
    fi

done
IFS=$SAVE_IFS

echo "if acme is integrated into pdudaemon, then setup lavapdu.conf with 'pdu' as acme type"


