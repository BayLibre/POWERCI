#!/bin/bash
set -o pipefail
set -o errtrace
#set -o nounset #Error if variable not set before use  
#set -o errexit #Exit for any error found... 

VERSION="1.0"


###################################################################################
## 
###################################################################################
usage()
{
    echo "usage: create-serial.sh [OPTION]"
    echo ""
    echo "[OPTION]"
    echo "    -h | --help:        Print this usage"
    echo "    --version:          Print version"
    echo "    -c | --clear:       Clear all existing configuration and proceed"
    echo "    -v | --verbose:     Debug traces"
    echo "    -s | --status:      Get status"
    echo "    -l | --logfile:     Logfile to use"
    echo "    -t | --type:        Serial type connection to use (telnet|ser2net)"
    echo ""
}

###################################################################################
## 
###################################################################################
parse_args()
{

    ## Analyse input parameter
    TEMP=`getopt -o chl:st:v --long clear,help,logfile:,status,type:,version -- "$@"`

    if [ $? != 0 ] ; then echo_error "Terminating..." >&2 ; exit 1 ; fi

    eval set -- "$TEMP"

    while true ; do
        case "$1" in
            -h|--help)
                usage; exit 0; shift;;
            --version)
                echo "create-serial.sh version: $VERSION"; 
                ./create-boards-conf.sh --version
                exit 0; shift;;
            -v)
                DEBUG_LVL=$((${DEBUG_LVL}+1))
                if [ $DEBUG_LVL -ge 2 ]; then set -x; fi
                DEBUG_EN="yes"; shift;;
            -l|--logfile)
                LOGFILE=$2
                exec 10>> ${LOGFILE}
                export BASH_XTRACEFD=10
                shift 2;;
            -c|--clear)
                CLEAR_ALL="yes"; shift;;
            -s|--status)
                STATUS="yes"; shift;;
            -t|--type)
                SERIAL_TYPE=$2
                shift 2;;
            --) shift ; break ;;
            *) echo_error "Internal error!" ; exit 1 ;;
        esac
    done
    echo_debug "START create_serial"
    echo_debug "Analyse input argument"
    echo_debug "Logfile:       ${LOGFILE}"
    echo_debug "Debug Enabled: ${DEBUG_EN}"
    echo_debug "Debug Level:   ${DEBUG_LVL}"
    echo_debug "Serial Type:   ${SERIAL_TYPE}"

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
get_status()
{
    echo_debug "START get_status"
    get_connected_devices
    
    #check if ${SERIAL_TYPE} is installed, and install it if not
    if [ $(dpkg-query -W -f='${Status}' ${SERIAL_TYPE} 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
        echo_debug "install ${SERIAL_TYPE}"
        sudo apt-get install ${SERIAL_TYPE};
    fi

    #create basic serial config in:
    # - /etc/conmux/<device_name>.cf for conmux
    # - /etc/ser2net.conf for ser2net
    echo_debug "CALL create_serial_conf"
    for d in ${ADD_DEVICE_LIST}; do
        device=`echo $d | awk -F":" '{ print $1 }'`
        create_serial_conf $device
        DEVICE_LIST=${DEVICE_LIST/$d/$d:${!DEVICE_BAUD_NAME}}
    done

    if [ "`is_serial_started`" == "NO" ]; then
        echo_log "Start serial"
        start_serial
    fi

    CONNECTED=""
    check_serial_started

    #Get Address and ssh status of each devices at least connected via conmux
    if [ ${DEBUG_LVL} -eq 1 ]; then   DEBUG_OPTION="-v"
    elif [ ${DEBUG_LVL} -eq 2 ]; then DEBUG_OPTION="-vv"
    else                              DEBUG_OPTION=""
    fi

    echo_debug "CALL ./create-boards-conf.sh ${DEBUG_OPTION} --logfile ${LOGFILE} --status --device ${DEVICE_LIST// /,} --type ${SERIAL_TYPE}"
    ./create-boards-conf.sh ${DEBUG_OPTION} --logfile ${LOGFILE} --status --device ${DEVICE_LIST// /,} --type ${SERIAL_TYPE}

    stop_serial

    echo_debug "END get_status"
}

###################################################################################
## 
###################################################################################
remove_device_symlink()
{
    echo_debug "START remove_device_symlink"
    
    if [ "$#" -ne 0 ]; then
        #if [ "$1" == "all" ]; then
        #    GET_ANSWER_RESULT=${DEVICE_LIST/ /,}
        #else 
            GET_ANSWER_RESULT=${@/ /,}
        #fi
    else
        #create a comma separated list string
        buffer=""
        for d in ${DEVICE_LIST}; do
            d=`echo $d | awk -F: '{ print $1 }'`
            if [ -z "$buffer" ]; then buffer="$d"
            else                      buffer="$buffer,$d"
            fi
        done
        #call the get_answer utils
        GET_ANSWER_RESULT=""
        echo_debug "get_answer -n -m \"$buffer\""
        get_answer -n -m "${buffer}"
        echo_debug "choice is: ${GET_ANSWER_RESULT}"
    fi

    if [ "${GET_ANSWER_RESULT}" == "" ]; then
        echo_log "Remove nothing"
        return 0
    fi
    if [ "${GET_ANSWER_RESULT}" == "all" ]; then
        echo_log "Remove all devices"
        while [ "`ls -1 /dev/ | grep ttyUSB 2>/dev/null`" != "" ]; do
            TTYUSB=""
            wait_ttyUSB_disconnection
            device_name=`ls -l /dev/ | grep $TTYUSB | awk '{ print $9 }' 2>/dev/null`
            if [ "${device_name}" != "" ]; then 
                echo_debug "sudo rm -rf /dev/${device_name}"
                sudo rm -f /dev/${device_name}
                remove_serial_conf ${device_name}
            fi
            echo_log "  => ${device_name} disconnected"
        done
        
        #remove remaining link to any ttyUSB
        if [ ! -z "`ls -l /dev/ | grep ttyUSB | grep ' -> '`" ]; then
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
        fi

        sudo rm -f /etc/udev/rules.d/50-lava-tty.rules
        DEVICE_LIST=""
        
        return 0
    fi

    for answer in `echo ${GET_ANSWER_RESULT/,/ }`; do
        device_name="$answer"
        for d in ${DEVICE_LIST}; do
            if [ "`echo $d | grep $answer`" != "" ]; then
                buffer=$d
                break
            fi
        done
        device_tty=`echo $buffer | awk -F: '{ print $2 }'`

        #wait and check ttyUSB disconnection
        while true; do
            echo_log "Please, unplug ${device_name} connected to ${device_tty}"
            wait_ttyUSB_disconnection
            if [ "$TTYUSB" != "${device_tty}" ]; then
                for d in ${DEVICE_LIST}; do
                    if [ "`echo $d | grep $TTYUSB`" != "" ]; then
                        wrong_device=$d
                        break
                    fi
                done
                echo_warning "You unplug the wrong ttyUSB, please reconnect it"
                old_ttyusb=$TTYUSB
                old_kernel=$KERNEL
                wait_ttyUSB_connection
                new_ttyusb=$TTYUSB
                new_kernel=$KERNEL
                wrong_device_fixed=`echo ${wrong_device} | sed -e 's/$old_ttyusb/$new_ttyusb/g' | sed -e 's/$old_kernel/$new_kernel/g'` 
                DEVICE_LIST=${DEVICE_LIST/${wrong_device}/${wrong_device_fixed}}
            else
                break
            fi
        done

        #remove device_name from ${DEVICE_LIST[@]}
        DEVICE_LIST=${DEVICE_LIST/${buffer}/}
        if [ -z "${DEL_DEVICE_LIST// /}" ]; then DEL_DEVICE_LIST="$buffer"
        else                                     DEL_DEVICE_LIST="${DEL_DEVICE_LIST} $buffer"
        fi

        #remove device link from /dev if exist
        if [ "`ls /dev/${device_name}`" != "" ]; then 
            echo_debug "sudo rm -rf /dev/${device_name}"
            sudo rm -rf /dev/${device_name}
            remove_serial_conf ${device_name}
        fi
        
        #remove device from rule if exist
        if [ -f /etc/udev/rules.d/50-lava-tty.rules ] && [ "`sudo cat /etc/udev/rules.d/50-lava-tty.rules | grep ${device_name}`" ]; then
            echo_debug "file /etc/udev/rules.d/50-lava-tty.rules: remove line `sudo cat /etc/udev/rules.d/50-lava-tty.rules | grep ${device_name}`"
            tmp_rules=`mktemp` 
            if [ -z "`sudo cat /etc/udev/rules.d/50-lava-tty.rules | grep -v ${device_name} 2>/dev/null`" ]; then
                sudo rm -f /etc/udev/rules.d/50-lava-tty.rules ${tmp_rules}
            else    
                sudo cat /etc/udev/rules.d/50-lava-tty.rules | grep -v ${device_name} > ${tmp_rules} 
                sudo rm -f /etc/udev/rules.d/50-lava-tty.rules 
                sudo mv -f ${tmp_rules} /etc/udev/rules.d/50-lava-tty.rules
            fi
        fi
        echo "  => Done"
    done
    echo_debug "END remove_device_symlink"
}

###################################################################################
## 
###################################################################################
wait_ttyUSB_connection()
{
    #create a list of connected ttyUSB 
    tty_connected=`ls /dev/ | grep ttyUSB 2>/dev/null`
    echo_debug "tty_connected: ${tty_connected}"

    #save_ifs=$IFS
    #IFS=' '
    device_connected="false"   
    while [ "${device_connected}" == "false" ];do
        for t in `ls /dev/ | grep ttyUSB 2>/dev/null`; do
            if [ -z "`echo ${tty_connected// /} | grep $t`" ]; then
                #new ttyUSB found
                echo_log -o "-ne" "+"
                #get info
                TTYUSB=`basename $t`
                KERNEL=`dmesg | grep "now attached to $TTYUSB" | tail -1 | cut -d: -f1 | awk '{ print $NF }'`
                device_connected="true"
                break
            fi
        done
        sleep 1
        echo_log -o "-ne" "."

    done
    #IFS=${save_ifs}
}

###################################################################################
## 
###################################################################################
wait_ttyUSB_disconnection()
{
    #create a list of connected ttyUSB 
    tty_connected=`ls -1 /dev/ttyUSB* 2>/dev/null`
    echo_debug "tty_connected: ${tty_connected}"

    #save_ifs=$IFS
    #IFS=' '
    device_connected="true"   
    while [ "${device_connected}" == "true" ];do
        for t in ${tty_connected}; do
            if [ -z "`ls /dev/ttyUSB* | grep ${t} 2>/dev/null`" ]; then
                #ttyUSB removed
                echo_log -o "-ne" "-"
                #get info
                TTYUSB=`basename $t`
                echo_debug $TTYUSB
                KERNEL=`dmesg | grep -A1 "now disconnected from $TTYUSB" | tail -1 | cut -d: -f1 | awk '{ print $NF }'`
                device_connected="false"
                break
            fi
        done
        sleep 1
        echo_log -o "-ne" "."
    done
    #IFS=${save_ifs}
}
###################################################################################
## 
###################################################################################
add_device_symlink()
{

    echo_debug "START add_device_symlink"

    device_name=$1
    echo_debug "  device_name: ${device_name}"
    echo_debug "  DEVICE_LIST (`echo ${DEVICE_LIST} | wc -w`): ${DEVICE_LIST}"


    if [ "${device_name}" == "" ];then
        echo_question -o "-ne" "Enter the name of the device to add: "
        read device_name
    fi
    for d in ${DEVICE_LIST}; do
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

    TTYUSB=""
    KERNEL=""
    wait_ttyUSB_connection

    echo_log "    => Connected to $TTYUSB"
    
    #add device to DEVICE_LIST
    d="${device_name}:${TTYUSB}:$KERNEL"
    if [ -z "${DEVICE_LIST// /}" ]; then DEVICE_LIST="$d"
    else                                 DEVICE_LIST="${DEVICE_LIST} $d"
    fi
    if [ -z "${ADD_DEVICE_LIST// /}" ]; then ADD_DEVICE_LIST="$d"
    else                                     ADD_DEVICE_LIST="${ADD_DEVICE_LIST} $d"
    fi

    if [ -f "/etc/udev/rules.d/50-lava-tty.rules" ]; then
        if [ "`sudo cat /etc/udev/rules.d/50-lava-tty.rules | grep ${device_name}`" == "" ]; then
            new_line=`echo "KERNEL==\"ttyUSB*\", KERNELS==\"${KERNEL}\", SYMLINK=\"${device_name}\""`
            echo "${new_line}" >> ${tmp_rules}
        fi
    else
        new_line=`echo "KERNEL==\"ttyUSB*\", KERNELS==\"${KERNEL}\", SYMLINK=\"${device_name}\""`
        echo "${new_line}" > ${tmp_rules}
    fi

    sudo ln -fs /dev/${TTYUSB} /dev/${device_name}
    echo_info "    => OK symlink done, rule added"
    
    echo_debug "file /etc/udev/rules.d/50-lava-tty.rules: Add line: ${new_line}"
    sudo rm -f /etc/udev/rules.d/50-lava-tty.rules 
    sudo mv -f ${tmp_rules} /etc/udev/rules.d/50-lava-tty.rules

    echo_debug "  DEVICE_LIST (`echo ${DEVICE_LIST} | wc -w`): ${DEVICE_LIST}"
    echo_debug "  ADD_DEVICE_LIST (`echo ${ADD_DEVICE_LIST} | wc -w`): ${ADD_DEVICE_LIST}"
    echo_debug "END add_device_symlink"

}

###################################################################################
## 
###################################################################################
get_connected_devices()
{
    echo_debug "START get_connected_devices"

    ## List what is connected
    ttyUSB_connected=`ls -1 /dev/tty* | grep ttyUSB`
    nb_ttyUSB=`echo "${ttyUSB_connected}" | wc -w`
    echo_log "USB and devices connected (${nb_ttyUSB}):"
    if [ -z "${ttyUSB_connected}" ]; then 
        echo_error "None"
    #else                        
    #    echo_info "${ttyUSB_connected}"
    fi

    device_ttys=`ls -l /dev/ | grep ttyUSB | grep " -> " | awk '{ print $9 ":" $11 }'`
    nb_devices=`echo $device_ttys | wc -w`
    #echo_log "Boards connected to ttyUSB (${nb_devices})"
    if [ -z "$device_ttys" ]; then 
        for t in ${ttyUSB_connected}; do
            echo_error "  $t    No device"
            echo_error "  $t    No device"
        done

    else
        for d in ${device_ttys}; do
            device=`echo $d | cut -d: -f1`
            tty=$(basename `echo $d | cut -d: -f2`)
            kernel=`dmesg | grep "now attached to $tty" | tail -1 | cut -d: -f1 | awk '{ print $NF }'`

            #echo_info "  $device attached to $tty"

            baud=""
            baud=`read_baud_rate ${device}`
            
            if [  -z "${DEVICE_LIST}" ]; then DEVICE_LIST="$device:$tty:$kernel:$baud"
            else                              DEVICE_LIST="${DEVICE_LIST} $device:$tty:$kernel:$baud"
            fi
        done
        
        for t in ${ttyUSB_connected}; do
            tty=$(basename $t)
            if [ -z "`echo ${DEVICE_LIST} | grep $tty`" ]; then
                echo_error "  $t    No device"
            else
                for d in ${DEVICE_LIST}; do
                    if [ ! -z "`echo ${d} | grep $tty`" ]; then
                        echo_info "  $t    `echo $d | cut -d\: -f1`"
                        break
                    fi
                done
            fi
        done
    fi


    echo_debug "END get_connected_devices"
}

###################################################################################
## 
###################################################################################
manage_symlink()
{
    echo_debug "START manage_symlink"
    echo ""

    if [[ -z "${DEVICE_LIST// /}" ]]; then
        echo_log "Nothing connected"
    else
        if [ "$CLEAR_ALL" == "yes" ]; then
            #clear_all
            remove_device_symlink all
        else
            echo_question "Do you want to remove device(s)? (Y/n) "
            read r
            if [ "$r" != "n" -a "$r" != "no" ];then
                echo_debug "CALL remove_device_symlink"
                remove_device_symlink
            fi
        fi
    fi

    if [ $nb_devices -ne 0 ]; then
        if [ "`echo ${DEVICE_LIST} | grep acme`" == "" ]; then
            echo_log "Missing ACME device, add it"
            echo_debug "CALL add_device_symlink"
            add_device_symlink acme
        fi
    else
        echo_debug "CALL add_device_symlink"
        add_device_symlink acme
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

    echo_debug "Remove device (`echo ${DEL_DEVICE_LIST} | wc -w`): \"${DEL_DEVICE_LIST}\""
    echo_debug "Add device    (`echo ${ADD_DEVICE_LIST} | wc -w`): \"${ADD_DEVICE_LIST}\""

    if [ -z "${DEL_DEVICE_LIST// /}" ] && [ -z "${ADD_DEVICE_LIST// /}" ]; then
        echo_info "No device changes, exit"
        exit 0
    fi

    echo_debug "END manage_symlink"

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
    if [ -z "${old_value}" ]; then
        wrong_value=`cat /etc/hosts | grep "127.0.1.1" | awk '{ print $2 }'`
        cat /etc/hosts | sed -e "s/${wrong_value}/${myhostname}/" > ${tmp_file}
        sudo mv -f ${tmp_file} /etc/hosts
        old_value=`cat /etc/hosts | grep $myhostname`
    fi
    if [ -z "`echo ${old_value} | grep ${myhostname}.local`" ]; then
        old_value=`echo ${old_value} | awk '{ print $2 }'`
        new_value=`echo "${old_value} ${old_value}.local"`
        cat /etc/hosts | sed -e "s/${old_value}/${new_value}/" > ${tmp_file}
        sudo mv -f ${tmp_file} /etc/hosts
        sudo chown root:root /etc/hosts
        sudo chmod 644 /etc/hosts
        echo_debug "file /etc/hosts: add ${myhostname}.local to line ${old_value}"

        #restart networking only if change done
        #WARNING: 'service networking restart' => does not work on ubuntu 14.04
        #                                         need to do 'ip link set eth0 down' instead 
        echo_debug "restart networking to take modif"
        sudo service networking restart 2>/dev/null
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
    stop_serial
    echo_error "=> rc before Abort: $1"
    echo_error "=> abort called after: $2 $3"
    exit 1
}

###################################################################################
PostProcess()
###################################################################################
# cleaning before exit
{
    echo_debug "PostProcess"
    sudo rm -f *.err *.res
    echo_debug "=> rc: $1"
    echo_debug "=> exit after: $2 $3"
}

###################################################################################
trapErr()
###################################################################################
# Each error found in script is trapped and come here
# if error generate an stderr message, exit script (script issue)
# if not continue script (normal status) 
{
    if test -f $stderr_log; then
        stderr=$( cat $stderr_log | grep -v "^+" | grep -v "^$" )
        if test -n "$stderr"; then
            echo_error "ErrorProcess"
            echo_error "=> $2 $3"
            echo_error "=> rc: $1"
            echo_error "=> Error: $stderr"
            rm -f $stderr
            
            #exit $1
        else
            rm -f $stderr
        fi
    fi
}

###################################################################################
###################################################################################
### 
###                                 MAIN
### 
###################################################################################
create_serial()
###################################################################################
{
    LOGFILE="create_serial.log"
    DEBUG_EN="no"
    DEBUG_LVL=0
    if [ -f ${LOGFILE} ]; then rm -f ${LOGFILE}; fi
    CLEAR_ALL="no"
    SERIAL_TYPE="conmux"
    STATUS="no"

    #define xtrace fd to 10 and redirect as append LOGFILE
    exec 10>> ${LOGFILE}
    export BASH_XTRACEFD=10
    #redirect error to stderr_log
    #exec 2>${stderr_log} 

    # list USB device connected and ask if it's correct
    # if not help user to define symlink in rule
    DEVICE_LIST=""
    ADD_DEVICE_LIST=""
    DEL_DEVICE_LIST=""

    ## Analyse input parameter
    parse_args "$@"
    #source the correct serial communication element according to option -t|--type
    source ${SERIAL_TYPE}.sh 
    if [ "${STATUS}" == "yes" ]; then
        get_status
        exit 0
    fi

    #get list of /dev/ttyUSB* used and /dev/<device> linked to a /dev/ttyUSB*
    echo_debug "CALL get_connected_devices"
    get_connected_devices    # -> return DEVICE_LIST array and nb_devices

    #create symlink and rules for our device configuration
    echo_debug "CALL manage_symlink"
    manage_symlink

    #check if ${SERIAL_TYPE} is installed, and install it if not
    if [ $(dpkg-query -W -f='${Status}' ${SERIAL_TYPE} 2>/dev/null | grep -c "ok installed") -eq 0 ]; then
        echo_debug "install ${SERIAL_TYPE}"
        sudo apt-get install ${SERIAL_TYPE};
    fi

    #create basic serial config in:
    # - /etc/conmux/<device_name>.cf for conmux
    # - /etc/ser2net.conf for ser2net
    echo_debug "CALL create_serial_conf"
    for d in ${ADD_DEVICE_LIST}; do
        device=`echo $d | awk -F":" '{ print $1 }'`
        create_serial_conf $device
        DEVICE_LIST=${DEVICE_LIST/$d/$d:${!DEVICE_BAUD_NAME}}
    done
    #create_conmux_conf

    #modif /etc/hosts to add <hostname>.local on same line as <hostname>
    echo_debug "CALL modif_hosts"
    modif_hosts


    #then restart serial
    echo_debug "restart serial service"
    start_serial

    #check if serial is started
    check_serial_started

    #create the boards configurations needed
    if [ ${DEBUG_LVL} -eq 1 ]; then   DEBUG_OPTION="-v"
    elif [ ${DEBUG_LVL} -eq 2 ]; then DEBUG_OPTION="-vv"
    else                              DEBUG_OPTION=""
    fi
    
    echo_debug "CALL ./create-boards-conf.sh ${DEBUG_OPTION} --logfile ${LOGFILE} --device ${DEVICE_LIST// /,} --type ${SERIAL_TYPE}"
    ./create-boards-conf.sh ${DEBUG_OPTION} --type ${SERIAL_TYPE} --logfile ${LOGFILE} --device ${DEVICE_LIST// /,} --type ${SERIAL_TYPE}
    if [ $? -ne 0 ]; then
        echo_error "### ERROR ### ./create-boards-conf.sh"
    fi

    stop_serial
    echo_debug "END create_serial"
    
}

###################################################################################
### Script starts here
###################################################################################
#trap "" EXIT ERR SIGINT SIGTERM SIGKILL

abspath=`dirname $(readlink -f $0)`
cd $abspath

source utils.sh

stderr_log="create_serial.err"
if [ -f ${stderr_log} ]; then rm -f ${stderr_log}; fi
exec 2>${stderr_log}


trap 'ProcessAbort $? ${BASH_SOURCE}:${LINENO} ${FUNCNAME[0]:+${FUNCNAME[0]}}' SIGINT SIGTERM SIGKILL
trap 'PostProcess $? ${BASH_SOURCE}:${LINENO} ${FUNCNAME[0]:+${FUNCNAME[0]}}' EXIT
#trap 'trapErr $? ${BASH_SOURCE}:${LINENO} ${FUNCNAME[0]:+${FUNCNAME[0]}}' ERR 


create_serial ${@}

#reset all trap
#trap - EXIT ERR SIGINT SIGTERM SIGKILL




