#!/bin/bash


###################################################################################
## 
###################################################################################
usage()
{
    echo "usage: create-conmux.sh [OPTION]"
    echo ""
    echo "[OPTION]"
    echo "    -h | --help:          Print this usage"
    echo "    -c | --clear-all:     Clear all existing configuration"
    echo "    -d | --debug:         Debug traces"
    echo "    -l | --logfile:       Logfile to use"
    echo ""
}


###################################################################################
## 
###################################################################################
clear_all()
{
    echo_debug "START clear_all"
    echo_log "Please disconnect all USB devices"
    while [ "`ls /dev/ttyUSB* 2>/dev/null`" != "" ];do
        sleep 1
    done
    echo_info "    => OK"


    sudo rm -f /etc/udev/rules.d/50-lava-tty.rules
    SAVE_IFS=$IFS
    IFS=$'\n'

    for d in `ls -l /dev/ | grep ttyUSB | grep ' -> '`; do
        dev=`echo $d | awk '{ print $9}'`        
        if [ ! -z $dev -o "$dev" != "*" -o "$dev" != "*.*" ]; then
            echo_debug "sudo rm -rf /dev/`echo $d | awk '{ print $9}'`"
            sudo rm -rf /dev/`echo $d | awk '{ print $9}'`
        fi
    done
    IFS=$SAVE_IFS
    echo_debug "END clear_all"
}

###################################################################################
## 
###################################################################################
remove_device_symlink()
{
    echo_debug "START remove_device_symlink"

    echo_question -o "-ne" "Enter the name of the device to remove: "
    read device_name
    if [ "`ls /dev/${device_name}`" != "" ]; then 
        echo_debug "sudo rm -rf /dev/${device_name}"
        sudo rm -rf /dev/${device_name}
        
        if [ -f /etc/udev/rules.d/50-lava-tty.rules -a "`cat /etc/udev/rules.d/50-lava-tty.rules | grep ${device_name}`" ]; then
            echo_debug "file /etc/udev/rules.d/50-lava-tty.rules: remove line `cat /etc/udev/rules.d/50-lava-tty.rules | grep ${device_name}`"
            tmp_rules=`mktemp` 
            cat /etc/udev/rules.d/50-lava-tty.rules | grep -v ${device_name} > ${tmp_rules}
            sudo rm -f /etc/udev/rules.d/50-lava-tty.rules 
            sudo mv -f ${tmp_rules} /etc/udev/rules.d/50-lava-tty.rules
        fi 
        echo_info "    => OK"
    elif [ -f /etc/udev/rules.d/50-lava-tty.rules -a "`cat /etc/udev/rules.d/50-lava-tty.rules | grep ${device_name}`" ]; then
        echo_debug "file /etc/udev/rules.d/50-lava-tty.rules: remove line `cat /etc/udev/rules.d/50-lava-tty.rules | grep ${device_name}`"
        tmp_rules=`mktemp` 
        cat /etc/udev/rules.d/50-lava-tty.rules | grep -v ${device_name} > ${tmp_rules}
        sudo rm -f /etc/udev/rules.d/50-lava-tty.rules 
        sudo mv -f ${tmp_rules} /etc/udev/rules.d/50-lava-tty.rules

    else
        echo_error "    => Device ${device_name} do not exist"
        return
    fi

    echo_debug "END remove_device_symlink"
}

###################################################################################
## 
###################################################################################
add_acme_symlink()
{
    echo_debug "START add_acme_symlink"
    echo_debug "CALL add_device_symlink acme"
    add_device_symlink acme
    echo_debug "END add_acme_symlink"
}

###################################################################################
## 
###################################################################################
add_device_symlink()
{

    echo_debug "START add_device_symlink"

    device_name=$1
    echo_debug "  device_name: ${device_name}"
    echo_debug "  DEVICE_LIST: ${DEVICE_LIST[@]}"


    if [ "${device_name}" == "" ];then
        echo_question -o "-ne" "Enter the name of the device to add: "
        read device_name
    fi
    for d in ${DEVICE_LIST[@]}; do
        if [ "`echo $d | grep ${device_name}`" != "" ]; then
            echo_warning "    => ${device_name} already exist and linked to `echo $d | cut -d, -f2`"
            return
        fi 
    done


    tmp_rules=`mktemp`
    if [ -f /etc/udev/rules.d/50-lava-tty.rules ]; then
        cat /etc/udev/rules.d/50-lava-tty.rules > ${tmp_rules}
    fi
    echo_log "Connect device ${device_name} to USB port"

    save_ifs=$IFS
    IFS=' '
    device_connected="false"   
    while [ "${device_connected}" == "false" ];do
        nb_devices=${#DEVICE_LIST[@]}
        nb_tty=`ls -1 /dev/ttyUSB* 2>/dev/null | wc -l`

        if [ $nb_tty -gt $nb_devices ]; then
            device_connected="true"
            # what is the new connection
            for t in `ls -1 /dev/ttyUSB* 2>/dev/null`; do
                if [ -z "`echo ${DEVICE_LIST[@]} | grep $t`" ]; then
                    echo_log -o "-ne" "+"
                    t_usb=`basename $t`
                    break
                fi
            done

        fi
        sleep 1
        echo_log -o "-ne" "."

    done
    IFS=${save_ifs}

    device=`dmesg | grep "now attached to $t_usb" | tail -1`
    device_val=`echo $device | cut -d: -f1 | awk '{ print $NF }'`
    device_usb=`echo $device | awk '{ print $NF }'`
    echo_log "    => Connected to $device_usb"
    
    d="${device_name},${device_usb}"
    DEVICE_LIST=(${DEVICE_LIST[@]} $d)

    if [ ! "`cat /etc/udev/rules.d/50-lava-tty.rules | grep ${device_name}`" ]; then
        device_val=`echo $device | cut -d: -f1 | awk -F"usb " '{ print $2 }'`
        new_line=`echo "KERNEL==\"ttyUSB*\", KERNELS==\"${device_val}\", SYMLINK=\"${device_name}\""`
        echo "${new_line}" >> ${tmp_rules}
    fi

    sudo ln -s /dev/${device_usb} /dev/${device_name}
    echo_info "    => OK symlink done, rule added"
    
    echo_debug "file /etc/udev/rules.d/50-lava-tty.rules: Add line: ${new_line}"
    sudo rm -f /etc/udev/rules.d/50-lava-tty.rules 
    sudo mv -f ${tmp_rules} /etc/udev/rules.d/50-lava-tty.rules

    echo_debug "  DEVICE_LIST: ${DEVICE_LIST[@]}"
    echo_debug "END add_device_symlink"

}

###################################################################################
## 
###################################################################################
get_connected_devices()
{
    echo_debug "START get_connected_devices"
    #SAVE_IFS=$IFS
    #IFS=$'\n'

    ## List what is connected
    ttyUSB=`ls -1 /dev/ttyUSB* 2>/dev/null`
    nb_ttyUSB=`echo ${ttyUSB} | wc -w`
    echo_log "USB devices connected (${nb_ttyUSB}):"
    if [ -z "${ttyUSB}" ]; then echo_error "None"
    else                        echo_info "${ttyUSB}"
    fi


    echo ""
    devices=`ls -l /dev/ | grep ttyUSB | grep " -> " | awk '{ print $9 "," $11 }'`
    nb_devices=`echo $devices | wc -w`
    echo_log "Devices connected to ttyUSB (${nb_devices})"
    if [ -z "$devices" ]; then echo_error "None"
    else
        for d in ${devices}; do
            echo_info "${d/,/ -> }"
            DEVICE_LIST=(${DEVICE_LIST[@]} $d)        
        done
    fi
    echo_debug "END get_connected_devices"
}

###################################################################################
## 
###################################################################################
create_symlink()
{
    echo_debug "START create_symlink"
    echo ""
    if [ $nb_devices -ne 0 ]; then
        if [ "`echo ${DEVICE_LIST[@]} | grep acme`" == "" ]; then
            echo_log "Missing ACME device, add it"
            echo_debug "CALL add_device_symlink"
            add_acme_symlink
        fi
    else
        echo_debug "CALL add_device_symlink"
        add_acme_symlink
    fi

    echo_question "Do you want to add device(s)? (Y/n) "
    add_dev="false"
    while [ "${add_dev}" == "false" ]; do
        read r
        if [ "$r" == "n" -o "$r" == "no" ];then 
            add_dev="true"
        else 
            echo_debug "CALL add_device_symlink"
            add_device_symlink
            echo_question "Another one? (Y/n) "
        fi
    done

    echo_question "Do you want to remove device(s)? (Y/n) "
    add_dev="false"
    while [ "${add_dev}" == "false" ]; do
        read r
        if [ "$r" == "n" -o "$r" == "no" ];then 
            add_dev="true"
        else 
            echo_debug "CALL remove_device_symlink"
            remove_device_symlink
            echo_question "Another one? (Y/n) "
        fi
    done

    echo_debug "END create_symlink"

}

###################################################################################
## 
###################################################################################
modif_hosts()
{
    echo_debug "START modif_hosts"

    tmp_file=`mktemp` 
    myhostname=`hostname`
    old_value=`cat /etc/hosts | grep $myhostname`
    if [ -z "`echo ${old_value} | grep ${myhostname}.local`" ]; then
        new_value=`echo "${old_value} ${old_value}.local"`
        cat /etc/hosts | sed -e "s/${old_value}/${new_value}/" > ${tmp_file}
        sudo mv -f ${tmp_file} /etc/hosts
        echo_debug "file /etc/hosts: add ${myhostname}.local to line ${old_value}"

        #restart networking only if change done
        #WARNING: 'service networking restart' => does not work on ubuntu 14.04
        #                                         need to do 'ip link set eth0 down' instead 
        echo_debug "restart networking to take modif"
        res=`sudo service networking restart`
        if [ $? -ne 0 ]; then
            sudo ip link set eth0 down
            sudo ip link set eth0 up
        fi
    fi 
    echo_debug "END modif_hosts"

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
create_conmux()
###################################################################################
{
    LOGFILE="create-conmux.log"
    DEBUG_EN="no"
    if [ -f ${LOGFILE} ]; then rm -f ${LOGFILE}; fi

    
    # list USB device connected and ask if it's correct
    # if not help user to define symlink in rule
    declare -a DEVICE_LIST

    ## Analyse input parameter
    TEMP=`getopt -o cdhl: --long clear-all,debug,help,logfile: -- "$@"`

    if [ $? != 0 ] ; then echo_error "Terminating..." >&2 ; exit 1 ; fi

    eval set -- "$TEMP"

    while true ; do
        case "$1" in
            -c|--clear-all) 
                clear_all; shift;;
            -d|--debug) 
                DEBUG_EN="yes"; shift;;
            -h|--help) 
                usage 
                exit 0
                shift;;
            -l|--logfile) 
                LOGFILE=$1; shift 2;;
            --) shift ; break ;;
            *) echo_error "Internal error!" ; exit 1 ;;
        esac
    done
    echo_debug "START create_conmux"
    echo_debug "Analyse input argument"
    echo_debug "Logfile:       ${LOGFILE}"
    echo_debug "Debug Enabled: ${DEBUG_EN}"

    #get list of /dev/ttyUSB* used and /dev/<device> linked to a /dev/ttyUSB*
    echo_debug "CALL get_connected_devices"
    get_connected_devices    # -> return DEVICE_LIST array and nb_devices

    #create symlink and rules for our device configuration
    echo_debug "CALL create_symlink"
    create_symlink

    #check if conmux is installed, and install it if not
    if [ $(dpkg-query -W -f='${Status}' conmux 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
        echo_debug "install conmux"
        sudo apt-get install conmux;
    fi

    #create the conmux boards configuration in /etc/conmux/<device_name>.cf
    if [ "${DEBUG_EN}" == "yes" ]; then DEBUG_OPTION="--debug"
    else                                DEBUG_OPTION=""
    fi
    
    echo_debug "CALL ./create-boards-conf.sh --logfile=${LOGFILE} ${DEBUG_OPTION}"
    ./create-boards-conf.sh --logfile=${LOGFILE} ${DEBUG_OPTION}
    if [ $? -ne 0 ]; then
        echo_error "### ERROR ### ./create-boards-conf.sh --logfile=${LOGFILE} ${DEBUG_OPTION}"
    fi

    #modif /etc/hosts to add <hostname>.local on same line as <hostname>
    echo_debug "CALL modif_hosts"
    modif_hosts

    #check if cu-loop is in /usr/local/bin, copy it instead
    if [ -f /usr/local/bin/cu-loop ];then
        echo_debug "copy cu-loop to /usr/local/bin"
        sudo cp -f cu-loop /usr/local/bin/.
    fi

    #in fine restart conmux
    echo_debug "restart conmux service"
    sudo stop conmux
    sudo start conmux
    

    #test connection to acme


    echo_debug "END create_conmux"
    
}

###################################################################################
### Script starts here
###################################################################################
trap "ProcessAbort" SIGINT SIGTERM
trap "PostProcess" EXIT

source utils.sh
create_conmux ${@}






