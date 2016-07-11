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
    echo_debug "START acme_addr"

    if [ -z "`printenv | grep ACME_ADDR`" ];then
        ACME_ADDR=${DEFAULT_ACME_ADDR}
    fi
    
    echo_log "ACME address is set to:"
    echo_info "${ACME_ADDR}"
    echo_question -o "-n" "Correct? (Y|n): "
    read r
    if [ "$r" == "n" ];then
        echo_question -o "-n" "Please enter your ACME adress (user@adress format): "
        read ACME_ADDR
    fi
    if [ -z "`cat /etc/profile.d/lava_lab.sh | grep ACME_ADDR=${ACME_ADDR}`" ]; then
        tmp_file=`mktemp`
        echo_debug "File /etc/profile.d/lava_lab.sh: Add line "ACME_ADDR=${ACME_ADDR}""
        echo "ACME_ADDR=${ACME_ADDR}" >> ${tmp_file}
        sudo mv -f ${tmp_file} /etc/profile.d/lava_lab.sh 
        echo_debug "END acme_addr"
    fi

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
    echo_debug "START board_list"

    echo_log "BOARDS list set to:"
    
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
    echo_question -o "-n" "Is it correct (Y|n): "
    read r
    if [ "$r" == "n" ];then
        echo_question -o "-n" "Please enter your BOARD list formatted like <name>:<type>:<acme_port>[:<baud_rate>] "
        read BOARDS
    fi
    echo_debug "END board_list"
}

###################################################################################
create_conmux_config()
###################################################################################
{
    echo_debug "START create_conmux_config"

    #create the acme conmux config file
    echo_log "Create ACME conmux config"
    if [ ! -h "/dev/acme" ]; then
        echo_error "### ERROR ### /dev/ttyUSB0 and /dev/acme does not exist"
        echo_error "              => Launch create-conmux.sh before create-boars-conf.sh"
        exit 1
    fi

    tmpfile=`mktemp`
    echo """
listener acme
application console 'acme console' 'exec sg dialout "/usr/local/bin/cu-loop /dev/acme 115200"'
    """ > $tmpfile
    sudo mv -f $tmpfile /etc/conmux/acme.cf
    
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

        echo_log "Create conmux conf of ${board}"
        if [ ! -h "/dev/${board}" ]; then
            echo_warning "### WARNING ### /dev/${board} does not exist"
            echo_warning "check that ${board} is connnected to a /dev/ttyUSB and link it to /dev/${board}"    
        fi
        tmpfile=`mktemp`
        echo """
listener ${board}
application console '${board} console' 'exec sg dialout "/usr/local/bin/cu-loop /dev/${board} ${baud}"'
command 'hardreset' 'Reboot ${board}' 'ssh ${ACME_ADDR} dut-hard-reset ${port}'
command 'b' 'Reboot ${board}' 'ssh ${ACME_ADDR} dut-hard-reset ${port}'
command 'off' 'Power off ${board}' 'ssh ${ACME_ADDR} dut-switch-off ${port}'
command 'on' 'Power on ${board}' 'ssh ${ACME_ADDR} dut-switch-on ${port}'
        """ > $tmpfile
        sudo mv -f $tmpfile /etc/conmux/acme.cf

        echo_log "Create lava conf of ${board}"
        echo_debug "CALL sudo ./add_baylibre_device.py ${type} ${board}  -p ${port}  -a "ssh -t $ACME_ADDR" -b"
        sudo ./add_baylibre_device.py ${type} ${board}  -p ${port}  -a "ssh -t $ACME_ADDR" -b
breakpoint
        if [ -z `cat /etc/lava-dispatcher/devices/${board}.conf | grep hard_reset_command` ]; then
            echo_debug "file /etc/lava-dispatcher/devices/${board}.conf: Add hard_reset_command = ssh -t $ACME_ADDR dut-hard-reset ${port}"
            tmpfile=`mktemp`
            cat /etc/lava-dispatcher/devices/${board}.conf > $tmpfile
            echo "hard_reset_command = ssh -t $ACME_ADDR dut-hard-reset ${port}" >> $tmpfile
            sudo mv -f $tmpfile /etc/lava-dispatcher/devices/${board}.conf
        fi
breakpoint
        if [ -z `cat /etc/lava-dispatcher/devices/${board}.conf | grep power_off_cmd` ]; then
            echo_debug "file /etc/lava-dispatcher/devices/${board}.conf: Add power_off_cmd = ssh -t $ACME_ADDR dut-switch-off ${port}"
            tmpfile=`mktemp`
            cat /etc/lava-dispatcher/devices/${board}.conf > $tmpfile
            echo "power_off_cmd = ssh -t $ACME_ADDR dut-switch-off ${port}" >> $tmpfile
            sudo mv -f $tmpfile /etc/lava-dispatcher/devices/${board}.conf
        fi
breakpoint
        if [ -z `cat /etc/lava-dispatcher/devices/${board}.conf | grep conmux-console` ]; then
            tmp_file=`mktemp`
            cat /etc/lava-dispatcher/devices/${board}.conf > $tmpfile
            old_value=`cat /etc/lava-dispatcher/devices/${board}.conf | grep connection_command | awk -F= '{ print $2 }'`
            new_value="conmux-console ${board}"
            cat /etc/lava-dispatcher/devices/${board}.conf | sed -e "s/${old_value}/${new_value}" >> ${tmp_file}
            sudo mv -f ${tmp_file} /etc/lava-dispatcher/devices/${board}.conf
            echo_debug "file /etc/lava-dispatcher/devices/${board}.conf: Modif connection_command with: ${new_value}"
        fi
breakpoint

    done
    IFS=$SAVE_IFS

    echo_debug "END create_conmux_config"
}

###################################################################################
ProcessAbort()
###################################################################################
# specific treatment for process abort
{
    echo_error "Process Aborted"
    exit 1
}

###################################################################################
PostProcess()
###################################################################################
# cleaning before exit
{
    echo_debug "PostProcess"
}


###################################################################################
###################################################################################
### 
###                                 MAIN
### 
###################################################################################
create_board_conf()
###################################################################################
{
    LOGFILE="create-board-conf.log"
    DEBUG_EN="no"
    if [ -f ${LOGFILE} ]; then rm -f ${LOGFILE}; fi

    ## Analyse input parameter
    TEMP=`getopt -o a:dl: --long acme:,debug,logfile: -- "$@"`

    if [ $? != 0 ] ; then echo_error "Terminating..." >&2 ; exit 1 ; fi

    eval set -- "$TEMP"

    while true ; do
        case "$1" in
            -a|--acme)
                ACME_ADDR=$2
                export ACME_ADDR=$ACME_ADDR
                shift;;
            -d|--debug) 
                DEBUG_EN="yes"; shift;;
            -l|--logfile) 
                LOGFILE=$2; shift 2;;
            --) shift ; break ;;
            *) echo_error "Internal error!" ; exit 1 ;;
        esac
    done

    echo_debug "START create_board_conf"
    echo_debug "Analyse input argument"
    echo_debug "Logfile:       ${LOGFILE}"
    echo_debug "Debug Enabled: ${DEBUG_EN}"
    echo_debug "Acme Address:  ${ACME_ADDR}"

    #check or define define acme_addr
    echo_debug "CALL acme_addr"
    acme_addr 
    #check or define boardlist
    echo_debug "CALL board_list"
    board_list

    #clean previous config files if exist
    echo_log "Cleaning /etc/conmux and /etc/lava-dispatcher/devices"
    echo_debug "sudo rm -f /etc/conmux/*.cf"
    sudo rm -f /etc/conmux/*.cf
    if [ ! -h /etc/lava-dispatcher/devices ];then
        ln -s ~/POWERCI/fs-overlay/etc/lava-dispatcher/devices /etc/lava-dispatcher/devices
    fi
    echo_debug "sudo rm -f /etc/lava-dispatcher/devices/*.conf"
    sudo rm -f /etc/lava-dispatcher/devices/*.conf

    #create the acme conmux config file
    echo_debug "CALL create_conmux_config"
    create_conmux_config    

    echo_warning "if acme is integrated into pdudaemon, then setup lavapdu.conf with 'pdu' as acme type"
    echo_debug "END create_board_conf"
}

###################################################################################
### Script starts here
###################################################################################
trap "ProcessAbort" SIGINT SIGTERM
trap "PostProcess" EXIT

source utils.sh
create_board_conf ${@}


