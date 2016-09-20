#!/bin/bash
set -o pipefail
set -o errtrace
#set -o nounset #Error if variable not set before use  
#set -o errexit #Exit for any error found... 

BLUE=`tput setaf 4`
NC=`tput sgr0`

###################################################################################
## 
###################################################################################
usage()
{
    echo "usage: create-conmux.sh [OPTION]"
    echo ""
    echo "[OPTION]"
    echo "    -h | --help:        Print this usage"
    echo "    --version:          Print version"
    echo "    -l | --logfile:     Logfile to use"
    echo "    -v | --verbose:     Debug traces"
    echo "    -d | --device:      Device to create"
    echo ""
}

###################################################################################
## 
###################################################################################
parse_args()
{
    ## Analyse input parameter
    TEMP=`getopt -o chl:d:v --long clear,help,logfile:,device:,version -- "$@"`

    if [ $? != 0 ] ; then echo_error "Terminating..." >&2 ; exit 1 ; fi

    eval set -- "$TEMP"

    while true ; do
        case "$1" in
            -h|--help)
                usage; exit 0; shift;;
            --version)
                echo "Version: $VERSION"; exit 0; shift;;
            -v)
                DEBUG_LVL=$((${DEBUG_LVL}+1))
                if [ $DEBUG_LVL -ge 2 ]; then set -x; fi
                DEBUG_EN="yes"; shift;;
            -l|--logfile)
                LOGFILE="$2"
                exec 10>> ${LOGFILE}
                export BASH_XTRACEFD=10
                shift 2;;
            -d|--device)
                DEVICE_LIST="${2//,/ }"
                shift 2;;
            --) shift ; break ;;
            *) echo_error "Internal error!" ; exit 1 ;;
        esac
    done
    echo_debug "START create_conmux"
    echo_debug "Analyse input argument"
    echo_debug "Logfile:       ${LOGFILE}"
    echo_debug "Debug Enabled: ${DEBUG_EN}"
    echo_debug "Device list:   ${DEVICE_LIST}"

}

###################################################################################
## check if environment variable ACME_ADDR exist or not
#  Purpose a default ACME_ADDR to user that shall validate or enter a new one
#  Put the validated ACME_ADDR in /etc/profile.d/lava_lab.sh that will contains some setup dedicated env variable
###################################################################################
acme_addr()
{
    echo_debug "START acme_addr"

    if [ -z "`printenv | grep ACME_ADDR`" ];then
        tmp_res=`mktemp`
        echo_log "Get address of ACME"
        conmux_cmd="success"
        debug_option=""
        if [ "$DEBUG_EN" == "yes" ]; then debug_option="-v"; fi
        echo_debug "python expect_exec_cmd.py ${debug_option} -l $LOGFILE acme \"pwd\" \"uname -n\" \"whoami\" > ${tmp_res}"
        python expect_exec_cmd.py ${debug_option} -l $LOGFILE acme "uname -n" "whoami" > ${tmp_res}
        if [ $? != 0 ]; then
            echo_error "### ERROR ### Did not perform to connect or read adress from acme"
            conmux_cmd="fail"
        fi

        if [ "$conmux_cmd" != "fail" ]; then
            echo_debug "`cat ${tmp_res}`"        
            addr=`cat ${tmp_res} | grep -A1 "command: uname -n" | grep response | awk -F"response: " '{ print $2 }' | sed -e "s/[ \t\n]*//g"`
            user=`cat ${tmp_res} | grep -A1 "command: whoami" | grep response | awk -F"response: " '{ print $2 }' | sed -e "s/[ \t\n]*//g"`
        
            ACME_ADDR=`echo "${user}@${addr}"`
        fi
        rm -f ${tmp_action} ${tmp_res}
        
    fi
        
    if [ "$conmux_cmd" == "fail" ]; then
        while true; do
            echo_question -o "-n" "Please enter an ACME adress: "
            read ACME_ADDR
            if [ ! -z `echo ${ACME_ADDR}` ];then break; fi
        done
        r="y"
    else
        echo_log "ACME address read in ACME is set to:"
        echo_info "${ACME_ADDR}"
        echo_question -o "-n" "Correct? (Y|n): "
        read r
    fi
    if [ "$r" == "n" ];then
        while true; do
            echo_question -o "-n" "Please enter your new ACME adress: "
            read ACME_ADDR
            if [ ! -z `echo ${ACME_ADDR}` ];then break; fi
        done
        #newuser=`echo ${ACME_ADDR} | cut -d@ -f1`
        newaddr=`echo ${ACME_ADDR} | cut -d@ -f2`
        tmp_cmd=`mktemp`
        tmp_res=`mktemp`
        echo """
echo $newaddr > /etc/hostname
cat /etc/hosts | sed -e \"s/127.0.1.1\t.*/127.0.1.1\t$newaddr/g\" > /etc/hosts.new 
mv -f /etc/hosts.new /etc/hosts
hostname -F /etc/hostname
uname -n
""" >> ${tmp_cmd}
        #execute file via conmux

        echo_log "Change address of ACME"
        if [ "$DEBUG_EN" == "yes" ]; then debug_option="-v"; fi
        echo_debug "python expect_exec_cmd.py ${debug_option} -l $LOGFILE acme ${tmp_cmd} > ${tmp_res}"
        python expect_exec_cmd.py ${debug_option} -l $LOGFILE acme ${tmp_cmd} > ${tmp_res}
        #get result
        newaddrchg=`cat ${tmp_res} | grep -A1 "command: uname -n" | grep response | awk -F"response: " '{ print $2 }' | sed -e "s/[ \t\n]*//g"`
        ACME_ADDR=`echo "${user}@${newaddrchg}"`

        echo_log "ACME address is changed to:"
        echo_info "${ACME_ADDR}"

        #rm tmp file and set ACME_ADDR
        #rm -f ${tmp_action} ${tmp_res}

    fi
    if [ ! -f /etc/profile.d/lava_lab.sh ]; then
        touch /etc/profile.d/lava_lab.sh
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

    #define board list
    echo_log "Define device type associated to each devices"

    #create the list of device_type
    buffer=""
    for dt in `ls /etc/lava-dispatcher/device-types/*.conf | awk -F/ '{ print $NF }'`; do
        if [ -z "$buffer" ]; then buffer="${dt//.conf/}"
        else                      buffer="$buffer,${dt//.conf/}"
        fi
    done

    echo "NAME TYPE TTY ACME_PORT BAUD_RATE" > /tmp/lava_board
    echo_debug "DEVICE_LIST:\n ${DEVICE_LIST}"
    for d in ${DEVICE_LIST}; do
        echo_debug "define device type for $d"
        if [ "`echo $d | grep "acme:"`" != "" ]; then
            echo_debug " => Ignore acme"
            DEVICE_LIST=${DEVICE_LIST//$d/$d::}
            echo "$d:-:-" | awk -F: '{ print $1 " " $5 " " $2 " " $6 " " $4 }' >> /tmp/lava_board
            continue
        fi
        echo_question "Choose device type associated to `echo $d | awk -F: '{ print $1 }'`"
        #call the get_answer utils
        GET_ANSWER_RESULT=""
        echo_debug "get_answer \"$buffer\""
        get_answer "${buffer}"
        echo_debug "choice is: ${GET_ANSWER_RESULT}"    

        while true; do
            echo_question "Enter ACME port connected to this device (From 1 to 8): "
            read acme_port
            if [ $acme_port -ge 1 ] && [ $acme_port -le 8 ]; then break; 
            else echo " => Incorrect value"
            fi
        done

        newd="$d:${GET_ANSWER_RESULT}:${acme_port}"
        echo "$newd" | awk -F: '{ print $1 " " $5 " " $2 " " $6 " " $4 }' >> /tmp/lava_board

        DEVICE_LIST=${DEVICE_LIST//$d/$newd}
    done

    echo_log "BOARDS list set to:"
    
    echo $BLUE
    cat /tmp/lava_board | column -t
    echo $NC

    echo_debug "DEVICE_LIST:\n ${DEVICE_LIST}"

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

   
    #for each boards in the list,
    SAVE_IFS=$IFS
    IFS=$'\n'
    for b in `cat /tmp/lava_board | tail -n+2`; do
        if [ "`echo $b | grep acme`" != "" ]; then continue; fi
        IFS=' ' read -a arr <<< "$b"
        board=${arr[0]}
        type=${arr[1]}
        port=${arr[3]}
        baud=${arr[4]}
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
        cat /etc/conmux/${board}.cf > tmpfile
        echo """command 'hardreset' 'Reboot ${board}' 'ssh ${ACME_ADDR} dut-hard-reset ${port}'
command 'b' 'Reboot ${board}' 'ssh ${ACME_ADDR} dut-hard-reset ${port}'
command 'off' 'Power off ${board}' 'ssh ${ACME_ADDR} dut-switch-off ${port}'
command 'on' 'Power on ${board}' 'ssh ${ACME_ADDR} dut-switch-on ${port}'""" >> $tmpfile
        sudo cat $tmpfile >> /etc/conmux/${board}.cf

        echo_log "Create lava conf of ${board}"
        debug_option=""
        if [ "$DEBUG_EN" == "yes" ]; then debug_option="-v"; fi
        echo_debug "CALL sudo python ./add_baylibre_device.py ${debug_option} -l $LOGFILE  -p ${port} -a \"$ACME_ADDR\" -b ${type} ${board} "
        sudo python ./add_baylibre_device.py ${debug_option} -l $LOGFILE -p ${port} -a "ssh -t $ACME_ADDR" -b ${type} ${board} 

        if [ -z `cat /etc/lava-dispatcher/devices/${board}.conf | grep hard_reset_command` ]; then
            echo_debug "file /etc/lava-dispatcher/devices/${board}.conf: Add hard_reset_command = ssh -t $ACME_ADDR dut-hard-reset ${port}"
            tmpfile=`mktemp`
            cat /etc/lava-dispatcher/devices/${board}.conf > $tmpfile
            echo "hard_reset_command = ssh -t $ACME_ADDR dut-hard-reset ${port}" >> $tmpfile
            sudo mv -f $tmpfile /etc/lava-dispatcher/devices/${board}.conf
        fi

        if [ -z `cat /etc/lava-dispatcher/devices/${board}.conf | grep power_off_cmd` ]; then
            echo_debug "file /etc/lava-dispatcher/devices/${board}.conf: Add power_off_cmd = ssh -t $ACME_ADDR dut-switch-off ${port}"
            tmpfile=`mktemp`
            cat /etc/lava-dispatcher/devices/${board}.conf > $tmpfile
            echo "power_off_cmd = ssh -t $ACME_ADDR dut-switch-off ${port}" >> $tmpfile
            sudo mv -f $tmpfile /etc/lava-dispatcher/devices/${board}.conf
        fi

        if [ -z `cat /etc/lava-dispatcher/devices/${board}.conf | grep conmux-console` ]; then
            tmp_file=`mktemp`
            cat /etc/lava-dispatcher/devices/${board}.conf > $tmpfile
            old_value=`cat /etc/lava-dispatcher/devices/${board}.conf | grep connection_command | awk -F= '{ print $2 }'`
            new_value="conmux-console ${board}"
            cat /etc/lava-dispatcher/devices/${board}.conf | sed -e "s/${old_value}/${new_value}" >> ${tmp_file}
            sudo mv -f ${tmp_file} /etc/lava-dispatcher/devices/${board}.conf
            echo_debug "file /etc/lava-dispatcher/devices/${board}.conf: Modif connection_command with: ${new_value}"
        fi


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
create_board_conf()
###################################################################################
{
    VERSION="0.2"

    LOGFILE="create-boards-conf.log"
    DEBUG_EN="no"
    DEBUG_LVL=0

    if [ -f ${LOGFILE} ]; then rm -f ${LOGFILE}; fi

    #define xtrace fd to 10 and redirect as append LOGFILE
    exec 10>> ${LOGFILE}
    export BASH_XTRACEFD=10
    #redirect error to stderr_log
    #exec 2>${stderr_log} 

    ACME_ADDR=""
    DEVICE_LIST=""

    ## Analyse input parameter
    parse_args "$@" 

    #check or define define acme_addr
    echo_debug "CALL acme_addr"
    acme_addr 
    #check or define boardlist
    echo_debug "CALL board_list"
    board_list

    #clean previous config files if exist
    echo_log "Cleaning /etc/lava-dispatcher/devices"
    if [ ! -h /etc/lava-dispatcher/devices ];then
        sudo ln -fs ~/POWERCI/fs-overlay/etc/lava-dispatcher/devices /etc/lava-dispatcher/devices
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
abspath=`dirname $(readlink -f $0)`
cd $abspath

source utils.sh

stderr_log="create-conmux.err"
if [ -f ${stderr_log} ]; then rm -f ${stderr_log}; fi
exec 2>${stderr_log}


trap 'ProcessAbort $? ${BASH_SOURCE}:${LINENO} ${FUNCNAME[0]:+${FUNCNAME[0]}}' SIGINT SIGTERM SIGKILL
trap 'PostProcess $? ${BASH_SOURCE}:${LINENO} ${FUNCNAME[0]:+${FUNCNAME[0]}}' EXIT
#trap 'trapErr $? ${BASH_SOURCE}:${LINENO} ${FUNCNAME[0]:+${FUNCNAME[0]}}' ERR 


create_board_conf ${@}

#reset all trap
#trap - EXIT ERR SIGINT SIGTERM SIGKILL


#trap "ProcessAbort" SIGINT SIGTERM
#trap "PostProcess" EXIT

#source utils.sh
#create_board_conf ${@}


