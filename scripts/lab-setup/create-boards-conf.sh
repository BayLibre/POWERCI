#!/bin/bash
set -o pipefail
set -o errtrace
#set -o nounset #Error if variable not set before use  
#set -o errexit #Exit for any error found... 

VERSION="0.3"

BLUE=`tput setaf 4`
NC=`tput sgr0`

###################################################################################
## 
###################################################################################
usage()
{
    echo "usage: create-boards-conf.sh [OPTION]"
    echo ""
    echo "[OPTION]"
    echo "    -h | --help:        Print this usage"
    echo "    --version:          Print version"
    echo "    -l | --logfile:     Logfile to use"
    echo "    -v | --verbose:     Debug traces"
    echo "    -d | --device:      Device to create"
    echo "    -s | --status:      Get status"
    echo ""
}

###################################################################################
## 
###################################################################################
parse_args()
{
    STATUS="no"

    ## Analyse input parameter
    TEMP=`getopt -o chl:d:sv --long clear,help,logfile:,device:,status,version -- "$@"`

    if [ $? != 0 ] ; then echo_error "Terminating..." >&2 ; exit 1 ; fi

    eval set -- "$TEMP"

    while true ; do
        case "$1" in
            -h|--help)
                usage; exit 0; shift;;
            --version)
                echo "create-boards-conf.sh version: $VERSION" 
                python expect_exec_cmd.py --version
                exit 0; shift;;
            -v)
                DEBUG=$1
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
            -s|--status)
                STATUS="yes"
                shift;;
            --) shift ; break ;;
            *) echo_error "Internal error!" ; exit 1 ;;
        esac
    done
    echo_debug "START create-boards-conf"
    echo_debug "Analyse input argument"
    echo_debug "Logfile:       ${LOGFILE}"
    echo_debug "Debug Enabled: ${DEBUG_EN}"
    echo_debug "Device list:   ${DEVICE_LIST}"

    if [ "${STATUS}" == "yes" ]; then
        get_status
        exit 0
    fi
}

###################################################################################
## 
###################################################################################
get_status()
{
    echo_debug "START get_status"

    if [ ! -z "`echo ${DEVICE_LIST} | grep acme`" ]; then
        #Acme probe connected to something
        get_acme_probe
        echo_log ""
        echo_log "ACME Probe connected:"
        for p in ${ACME_PROBE}; do echo_info "  $p"; done
    fi

    echo_log ""
    echo_log "Devices address found:"
    echo "" > tmp.tmp
    for d in ${DEVICE_LIST}; do
        device=`echo $d | awk -F: '{ print $1 }'`

        get_board_addr $device
    done

    echo_log ""
    echo_log "SSH status:"
    for d in ${DEVICE_LIST}; do
        device=`echo $d | awk -F: '{ print $1 }'`
        BOARD_ADDR_NAME="`echo ${device//-/_} | sed 's/./\U&/g'`_ADDR"
        BOARD_IP_NAME="`echo ${device//-/_} | sed 's/./\U&/g'`_IP"

        user=`echo ${!BOARD_ADDR_NAME} | awk -F\@ '{ print $1 }'`
        addr=`echo ${!BOARD_ADDR_NAME} | awk -F\@ '{ print $2 }'`
        ip=${!BOARD_IP_NAME}

        if [ "$device" == "acme" ]; then object="ACME"
        else object="DUT"
        fi 
      
        warn="no"
        if [ "${!BOARD_ADDR_NAME}" == "None" ] && [ "${!BOARD_IP_NAME}" == "None" ]; then
            echo_error "* LAB `uname -n` to ${object} ($device): FAIL"
            continue
        elif [ "${!BOARD_ADDR_NAME}" == "None" ]; then
            echo_log "* LAB `uname -n` to ${object} ($device):"
            bash check-ssh.sh "${user}" "${ip}" | grep -v "Check ssh connection" > check-ssh.res
            warn="yes"
        elif [ "${!BOARD_IP_NAME}" == "None" ]; then
            echo_log "* LAB `uname -n` to ${object} ($device):"
            bash check-ssh.sh "${user}" "${addr} ${addr}.local" | grep -v "Check ssh connection" > check-ssh.res
            warn="yes"
        else
            echo_log "* LAB `uname -n` to ${object} ($device):"
            bash check-ssh.sh "${user}" "${addr} ${addr}.local ${ip}" | grep -v "Check ssh connection" > check-ssh.res
        fi

        echo "" > tmp.tmp
        save_IFS=$IFS
        IFS=$'\n'
        for line in `cat check-ssh.res`; do
            if [ "`echo $line | grep NOK`" != "" ] || [ "`echo $line | grep \"not pingable\"`" != "" ]; then
                echo_error "`echo ${line// - /    } | awk -F' => ' '{ print $1 \" \" $2}'`" >> tmp.tmp
            elif [ "$warn" == "yes" ]; then
                echo_warning "`echo ${line// - /    } | awk -F' => ' '{ print $1 \" \" $2}'`">> tmp.tmp
            else
                echo_info "`echo ${line// - /    } | awk -F' => ' '{ print $1 \" \" $2}'`">> tmp.tmp
            fi     
        done
        IFS=$save_IFS
        cat tmp.tmp | column -t
    done

    echo_debug "END get_status"
}

###################################################################################
## check an ssh cnx to dest_addr
#  if cnx succeed, get its user@address with command 'whoami' and 'uname -n'
###################################################################################
expect_exec_cmd()
{
    echo_debug "expect_exec_cmd START"
    local debug=`if [ "$DEBUG_EN" == "yes" ]; then echo "-v"; else echo ""; fi`
    local log="-l $LOGFILE --keeplog"
    local cnx_type="$1"
    local dest_addr="$2"
    local command_file="$3"

    tmp_res=${command_file%.*}.res
    echo_debug "python expect_exec_cmd.py $debug $log ${cnx_type} ${dest_addr} $command_file > ${tmp_res} 2>&1"
    echo_debug "with $command_file containing:"
    echo_debug "`cat $command_file`"
    python expect_exec_cmd.py $debug $log ${cnx_type} ${dest_addr} $command_file > ${tmp_res} 2>&1
    rc=$?

    echo_debug " => rc = $rc"
    echo_debug " => result:"
    echo_debug "`cat ${tmp_res}`"
    if [ $rc -ne 0 ]; then
        echo "### WARNING ### command execution fails" >> ${tmp_res}
        #echo_warning "`cat ${tmp_res}`"
        ret_code=1
    else
        ret_code=0
    fi
    if [ "`cat ${tmp_res} | grep '### ERROR ###'`" != "" ]; then
        #echo_error "`cat ${tmp_res}`"
        ret_code=1
    fi

    echo_debug "expect_exec_cmd END"
    return $ret_code

}

###################################################################################
expect_exec_reboot()
{
    echo_debug "expect_exec_reboot START"
    local debug=`if [ "$DEBUG_EN" == "yes" ]; then echo "-v"; else echo ""; fi`
    local log="-l $LOGFILE --keeplog"
    local cnx_type="$1"
    local dest_addr="$2"

    tmp_res="reboot.res"
    echo_debug "python expect_exec_cmd.py --reboot $debug $log ${cnx_type} ${dest_addr} \"\" > ${tmp_res} 2>&1"
    python expect_exec_cmd.py --reboot $debug $log ${cnx_type} ${dest_addr} "" > ${tmp_res} 2>&1
    rc=$?

    echo_debug " => rc = $rc"
    echo_debug " => result:"
    echo_debug "`cat ${tmp_res}`"
    if [ $rc -ne 0 ]; then
        echo "### WARNING ### reboot fails" >> ${tmp_res}
        #echo_warning "`cat ${tmp_res}`"
        ret_code=1
    else
        ret_code=0
    fi
    if [ "`cat ${tmp_res} | grep '### ERROR ###'`" != "" ]; then
        #echo_error "`cat ${tmp_res}`"
        ret_code=1
    fi

    echo_debug "expect_exec_reboot END"
    return $ret_code

}

###################################################################################
wait_board_restart()
{
    local board_ip=$1

    ret_code=0
    i=0
    restarted="no"
    sleep 5
    while [ $i -lt 60 ]; do
        sleep 1
        echo_log -o "-ne" "."
        #ping -c1 ${!board_ip_name} | grep "64 bytes from $board_ip_name"
        if [ ! -z "`ping -c 1 ${board_ip} | grep '1 received'`" ]; then
            echo_debug "    => restarted after $((i+5)) sec"
            restarted="yes"
            break
        fi 
        i=$(($i + 1))
    done
    if [ "${restarted}" == "no" ]; then
        echo_error "$device_name not restarted after 65sec"
        ret_code=1
    fi

    return $ret_code
}
###################################################################################
get_board_addr()
{
    board=$1
    BOARD_ADDR_NAME="`echo ${board//-/_} | sed 's/./\U&/g'`_ADDR"
    BOARD_IP_NAME="`echo ${board//-/_} | sed 's/./\U&/g'`_IP"
    echo_debug "board_addr_name = ${BOARD_ADDR_NAME}"

    if [ -z "`printenv | grep ${BOARD_ADDR_NAME}`" ];then

cat << EOF > commands.cmd
ls
whoami
uname -n
ifconfig eth0 | grep 'inet addr' | sed 's/\s\+/ /g' | cut -d: -f2 | cut -d' ' -f1
EOF

        expect_exec_cmd "conmux-console" "${board}" "commands.cmd"
        rc=$?
 
        if [ $rc -eq 0 ]; then
            echo_debug "`cat commands.res`"
            addr=$(cat commands.res | sed -e '1,/command: uname/d' -e '/rc/,$d' -e 's/response: //')
            user=$(cat commands.res | sed -e '1,/command: whoami/d' -e '/rc/,$d' -e 's/response: //')
            ip=$(cat commands.res | sed -e '1,/command: ifconfig/d' -e '/rc/,$d' -e 's/response: //')

            eval ${BOARD_ADDR_NAME}="${user}@${addr}"
            export ${BOARD_ADDR_NAME}="${user}@${addr}"
            echo_debug "${BOARD_ADDR_NAME} = ${!BOARD_ADDR_NAME}"
            eval ${BOARD_IP_NAME}="${ip}"
            export ${BOARD_IP_NAME}="${ip}"
            echo_debug "${BOARD_IP_NAME} = ${!BOARD_IP_NAME}"

            #echo_log "Address read in ${board} is set to:"
            echo_info "$board: ${!BOARD_ADDR_NAME} IP=${!BOARD_IP_NAME}" >> tmp.tmp
        else
            eval ${BOARD_ADDR_NAME}="None"
            export ${BOARD_ADDR_NAME}="None"
            eval ${BOARD_IP_NAME}="None"
            export ${BOARD_IP_NAME}="None"
            echo_warning "$board: ${!BOARD_ADDR_NAME} IP=${!BOARD_IP_NAME}" >> tmp.tmp
        fi

    else
        eval ${BOARD_ADDR_NAME}=`echo ${BOARD_ADDR_NAME}`
        eval ${BOARD_IP_NAME}=`echo ${BOARD_IP_NAME}`
        if [ "${!BOARD_ADDR_NAME}" == "None" -o "${!BOARD_ADDR_NAME}" == "" ] || [ "${!BOARD_IP_NAME}" == "None" -o "${!BOARD_IP_NAME}" == "" ]; then
            echo_warning "$board: ${!BOARD_ADDR_NAME} IP=${!BOARD_IP_NAME}" >> tmp.tmp
        else
            echo_info "$board: ${!BOARD_ADDR_NAME} IP=${!BOARD_IP_NAME}" >> tmp.tmp
        fi
    fi

    cat tmp.tmp | column -t
}

###################################################################################
## check if environment variable upper(<device_name>)_ADDR exist or not
#  Purpose a default upper(<device_name>)_ADDR to user that shall validate or enter a new one
#  Put the validated upper(<device_name>)_ADDR in /etc/profile.d/lava_lab.sh that will contains some setup dedicated env variable
###################################################################################
board_addr()
{
    echo_debug "START board_addr $1"

    board=$1
    get_board_addr $board
    if [ "${!BOARD_ADDR_NAME}" == "None" ]; then
        while true; do
            echo_question -o "-n" "Please enter manually an address for ${board} (user@addr): "
            read addr
            eval ${BOARD_ADDR_NAME}="${addr}"
            echo_debug "${BOARD_ADDR_NAME} = ${!BOARD_ADDR_NAME}"
            if [ ! -z `echo ${!BOARD_ADDR_NAME}` ];then break; fi
        done

    else
        echo_question -o "-n" "Is it Correct? (Y|n): "
        read resp

    #board_addr_name="`echo ${board//-/_} | sed 's/./\U&/g'`_ADDR"
    #board_ip_name="`echo ${board//-/_} | sed 's/./\U&/g'`_IP"


    #echo_debug "board_addr_name = ${board_addr_name}"

    #if [ -z "`printenv | grep ${board_addr_name}`" ];then
    #    echo_log "Get address of ${board}"

#cat << EOF > commands.cmd
#ls
#whoami
#uname -n
#ifconfig eth0 | grep 'inet addr' | sed 's/\s\+/ /g' | cut -d: -f2 | cut -d' ' -f1
#EOF

    #    expect_exec_cmd "conmux-console" "${board}" "commands.cmd"
    #    rc=$?
 
    #    if [ $rc -eq 0 ]; then
    #        echo_debug "`cat commands.res`"
    #        addr=$(cat commands.res | sed -e '1,/command: uname/d' -e '/rc/,$d' -e 's/response: //')
    #        user=$(cat commands.res | sed -e '1,/command: whoami/d' -e '/rc/,$d' -e 's/response: //')
    #        ip=$(cat commands.res | sed -e '1,/command: ifconfig/d' -e '/rc/,$d' -e 's/response: //')

    #        eval ${board_addr_name}="${user}@${addr}"
    #        echo_debug "${board_addr_name} = ${!board_addr_name}"
    #        eval ${board_ip_name}="${ip}"
    #        echo_debug "${board_ip_name} = ${!board_ip_name}"

    #        echo_log "Address read in ${board} is set to:"
    #        echo_info "${!board_addr_name} (${!board_ip_name})"
    #        echo_question -o "-n" "Correct? (Y|n): "
    #        read resp

            if [ "$resp" == "n" ];then
                while true; do
                    echo_question -o "-n" "Please enter your new address for ${board}: "
                    read addr
                    eval ${BOARD_ADDR_NAME}="${addr}"
                    echo_debug "${BOARD_ADDR_NAME} = ${!BOARD_ADDR_NAME}"
                    if [ ! -z `echo ${!BOARD_ADDR_NAME}` ];then break; fi
                done

                newaddr=`echo ${!BOARD_ADDR_NAME} | cut -d@ -f2`

                echo_log "Change address of ${board}"
cat << EOF > commands.cmd
echo $newaddr > /etc/hostname
cat /etc/hosts | sed -e "s/127.0.1.1\t.*/127.0.1.1\t$newaddr/g" > /etc/hosts.new 
mv -f /etc/hosts.new /etc/hosts
hostname -F /etc/hostname
uname -n
EOF

                expect_exec_cmd "conmux-console" "${board}" "commands.cmd"
                rc=$?

                if [ $rc -eq 0 ]; then
                    echo_debug "`cat commands.res`"
                    newaddrchg=$(cat commands.res | sed -e '1,/command: uname/d' -e '/rc/,$d' -e 's/response: //')
                    eval ${BOARD_ADDR_NAME}="${user}@${newaddrchg}"
                    echo_log "${board} address is changed to:"
                    echo_info "${!BOARD_ADDR_NAME}"
                else
                    echo_warning "### WARNING ### ${board} address is not changed !"
                fi

                echo_debug "expect_exec_reboot \"conmux-console\" \"${board}\""
                expect_exec_reboot "conmux-console" "${board}"

            fi

    #    else
    #        while true; do
    #            echo_question -o "-n" "Please enter manually an address for ${board}: "
    #            read addr
    #            eval ${board_addr_name}="${addr}"
    #            echo_debug "${board_addr_name} = ${!board_addr_name}"
    #            if [ ! -z `echo ${!board_addr_name}` ];then break; fi
    #        done
    #    fi
    fi

    if [ ! -f /etc/profile.d/lava_lab.sh ]; then
        touch /etc/profile.d/lava_lab.sh
    fi

    test_line="${BOARD_ADDR_NAME}=${!BOARD_ADDR_NAME}"
    if [ -z "`cat /etc/profile.d/lava_lab.sh | grep ${test_line}`" ]; then
        tmp_file=`mktemp`
        echo_debug "File /etc/profile.d/lava_lab.sh: Add line \"${test_line}\""
        echo "${BOARD_ADDR_NAME}=${!BOARD_ADDR_NAME}" >> ${tmp_file}
        sudo mv -f ${tmp_file} /etc/profile.d/lava_lab.sh 
        echo_debug "END board_addr"
    fi

}

###################################################################################
get_acme_probe()
{
    ACME_PROBE="None"
cat << EOF > commands.cmd
dut-dump-probe 0
dut-dump-probe 1
dut-dump-probe 2
dut-dump-probe 3
dut-dump-probe 4
dut-dump-probe 5
dut-dump-probe 6
dut-dump-probe 7
EOF
    expect_exec_cmd "conmux-console" "acme" "commands.cmd"
    rc=$?

    if [ $rc -eq 0 ]; then
        ACME_PROBE=""
        for p in 0 1 2 3 4 5 6 7; do
            avail=`cat commands.res | grep -A1 "dut-dump-probe $p" | grep "response:" | cut -d\: -f2`
            if [ "`echo $avail | grep \"Could not open\"`" == "" ]; then
                ACME_PROBE="${ACME_PROBE} Probe_$((p+1))"
            fi
        done
        ACME_PROBE=`echo ${ACME_PROBE}| sed -e 's/^[ \t]*//' -e 's/*[ \t]$//'`
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

    #list of acme port available
    get_acme_probe
    #acme_possible_port="None"
#cat << EOF > commands.cmd
#dut-dump-probe 0
#dut-dump-probe 1
#dut-dump-probe 2
#dut-dump-probe 3
#dut-dump-probe 4
#dut-dump-probe 5
#dut-dump-probe 6
#dut-dump-probe 7
#EOF
    #expect_exec_cmd "conmux-console" "acme" "commands.cmd"
    #rc=$?

    #if [ $rc -eq 0 ]; then
    #    acme_possible_port=""
    #    for p in 0 1 2 3 4 5 6 7; do
    #        avail=`cat commands.res | grep -A1 "dut-dump-probe $p" | grep "response:" | cut -d\: -f2`
    #        if [ "`echo $avail | grep \"Could not open\"`" == "" ]; then
    #            acme_possible_port="${acme_possible_port} Probe_$((p+1))"
    #        fi
    #    done
    #    acme_possible_port=`echo ${acme_possible_port}| sed -e 's/^[ \t]*//' -e 's/*[ \t]$//'`
    #fi
    acme_possible_port=${ACME_PROBE}

    echo "NAME TYPE TTY ACME_PORT BAUD_RATE ADDR IP" > /tmp/lava_board
    echo_debug "DEVICE_LIST:\n ${DEVICE_LIST}"
    for d in ${DEVICE_LIST}; do
        device_name=`echo $d | awk -F: '{ print $1 }'`

        board_addr ${device_name}

        board_addr_name="`echo ${board//-/_} | sed 's/./\U&/g'`_ADDR"
        board_ip_name="`echo ${board//-/_} | sed 's/./\U&/g'`_IP"

        echo_debug "define device type for $device_name"
        if [ "$device_name" == "acme" ]; then
            echo_debug " => Ignore acme"
            DEVICE_LIST=${DEVICE_LIST//$d/$d:beaglebone-black::${ACME_ADDR}:${ACME_IP}}
            echo "$d:beaglebone-black:-:${ACME_ADDR}:${ACME_IP}" | awk -F: '{ print $1 " " $5 " " $2 " " $6 " " $4 " " $7 " " $8 }' >> /tmp/lava_board
            continue
        fi
        echo_question "Choose device type associated to ${device_name}"
        #call the get_answer utils
        GET_ANSWER_RESULT=""
        echo_debug "get_answer \"$buffer\""
        get_answer "${buffer}"
        echo_debug "choice is: ${GET_ANSWER_RESULT}"    
        device_type=${GET_ANSWER_RESULT}
        while true; do
            if [ "$acme_possible_port" != "None" ]; then
                echo_question "Enter ACME port connected to this device: "
                GET_ANSWER_RESULT=""
                echo_debug "get_answer \"${acme_possible_port// /,}\""
                get_answer "${acme_possible_port// /,}"
                echo_debug "choice is: ${GET_ANSWER_RESULT}"
                acme_port=${GET_ANSWER_RESULT//Probe\_/}
                break
            else
                echo_warning "Unable to poll acme_port available"

                echo_question "Enter ACME port connected to this device (From 1 to 8): "
                read acme_port
                if [ $acme_port -ge 1 ] && [ $acme_port -le 8 ]; then break; 
                else echo " => Incorrect value"
                fi
            fi
        done
        echo_debug "acme_port=${acme_port}"
        echo_log "ReStart $device_name"
cat << EOF > commands.cmd
dut-hard-reset ${acme_port}
EOF
        expect_exec_cmd "conmux-console" "acme" "commands.cmd"
        rc=$?

        if [ $rc -eq 0 ]; then
            sleep 5
            wait_board_restart ${!board_ip_name}

            newd="$d:${device_type}:${acme_port}:${!board_addr_name}:${!board_ip_name}"
            echo_debug "echo \"$newd\" | awk -F: '{ print $1 \" \" $5 \" \" $2 \" \" $6 \" \" $4 \" \" $7 \" \" $8 }' >> /tmp/lava_board"
            echo "$newd" | awk -F: '{ print $1 " " $5 " " $2 " " $6 " " $4 " " $7 " " $8 }' >> /tmp/lava_board

            DEVICE_LIST=${DEVICE_LIST//$d/$newd}
        fi



    done

    echo_log "BOARDS list set to:"
    
    echo $BLUE
    cat /tmp/lava_board | column -t
    echo $NC

    echo_debug "DEVICE_LIST:\n ${DEVICE_LIST}"

    echo_debug "END board_list"
}


###################################################################################
## create ssh system between lab, acme and dut
###################################################################################
copy_check_sshkey()
{
    echo_debug "copy_check_sshkey START"
    local src_file=".ssh/id_rsa.pub"

    local opt=`getopt -o s: --long src: -- "$@"`
    if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi

    eval set -- "$opt"

    while true ; do
        case "$1" in
            -s|--src) 
                source="$2"; shift 2;;
            --) shift ; break ;;
            *) echo "Internal error!" ; exit 1 ;;
        esac
    done

    local destination=$1

    if [ "`echo $source | cut -d\: -f1 | cut -d\@ -f1`" == "" ]; then src_device="local"
    else src_device=`echo $source | cut -d\: -f1 | cut -d\@ -f1`
    fi
    src_user=`echo $source | cut -d\: -f1 | cut -d\@ -f2`
    src_addr=`echo $source | cut -d\: -f1 | cut -d\@ -f3`
    src_ip=`echo $source | cut -d\: -f1 | cut -d\@ -f4`
    if [ -n "`echo $source | grep ':'`" ]; then src_file=`echo $source | cut -d\: -f2`
    fi

    dst_device=`echo "$destination" | cut -d\: -f1 | cut -d\@ -f1`
    dst_user=`echo "$destination" | cut -d\: -f1 | cut -d\@ -f2`
    dst_addr=`echo "$destination" | cut -d\: -f1 | cut -d\@ -f3`
    dst_ip=`echo "$destination" | cut -d\: -f1 | cut -d\@ -f4`
    if [ -n "`echo "$destination" | grep ':'`" ]; then dst_file=`echo $destination | cut -d\: -f2`
    else dst_destination=""
    fi
    
    echo_debug ""
    echo_debug "    source  = ${source}"
    echo_debug "    src_device  = ${src_device}"
    echo_debug "    src_user    = ${src_user}"
    echo_debug "    src_addr    = ${src_addr}"
    echo_debug "    src_ip      = ${src_ip}"
    echo_debug "    src_file    = ${src_file}"
    echo_debug ""
    echo_debug "    destination = ${destination}"
    echo_debug "    dest_device = ${dst_device}"
    echo_debug "    dest_user   = ${dst_user}"
    echo_debug "    dest_addr   = ${dst_addr}"
    echo_debug "    dest_ip     = ${dst_ip}"
    echo_debug "    dest_file   = ${dst_file}"
    echo_debug ""

    if [ "${src_device}" == "local" ]; then
        #check if source key exist
        #if source key is ~/.ssh/id_rsa.pub and do not exist, create it
        if [ "${src_file}" == ".ssh/id_rsa.pub" ]; then
            src_file=`echo ~/${src_file}`

            if [ ! -f ${src_file} ]; then
                echo_log "    => Create ${src_device} rsa key"
                ssh-keygen -N "" -f "`echo ${src_file} | awk -F'.pub' '{ print $1 }'`"
                if [ $? -ne 0 ]; then
                    echo_error "### ERROR ### Unable to create local pub key"
                    echo_debug "copy_check_sshkey END"
                    return 1
                fi
                ls -lsa ~/.ssh/
            fi
        fi

    else
        echo_log "    => Check ssh connection from `uname -n` to ${src_addr}"
        echo_debug "bash check-ssh.sh \"${src_user}\" \"${src_addr} ${src_addr}.local ${src_ip}\" > check-ssh.res"
        bash check-ssh.sh "${src_user}" "${src_addr} ${src_addr}.local ${src_ip}" > check-ssh.res
        rc=$?
        echo_debug "`cat check-ssh.res`"
        if [ $rc -eq 0 ]; then 
            src_cnx_type="ssh"
            src_cnx_dest="${src_user}@${src_ip}"
        else 
            src_cnx_type="conmux-console"
            src_cnx_dest="${src_device}"
        fi

        #check or create src public key
cat << EOF > commands.cmd
if [ ! -f "~/.ssh/id_rsa.pub" ]; then ssh-keygen -N "" -f ~/.ssh/id_rsa; fi
ls -lsa ~/.ssh/
EOF
        expect_exec_cmd "${src_cnx_type}" "${src_cnx_dest}" commands.cmd
        rc=$?

    fi

    #check dest ssh connection
    echo_log "    => Check ssh connection from `uname -n` to ${dst_addr}"
    echo_debug "bash check-ssh.sh ${dst_user} \"${dst_addr} ${dst_addr}.local ${dst_ip}\" > check-ssh.res"
    bash check-ssh.sh "${dst_user}" "${dst_addr} ${dst_addr}.local ${dst_ip}" > check-ssh.res
    rc=$?
    echo_debug "`cat check-ssh.res`"
    if [ $rc -eq 0 ]; then 
        dst_cnx_type="ssh"
        dst_cnx_dest="${dst_user}@${dst_ip}"
    else 
        dst_cnx_type="conmux-console"
        dst_cnx_dest="${dst_device}"
    fi

    #if src is not local, src_cnx_type AND dst_cnx_type is ssh, use scp src:file dst:file
    #else use conmux and copy via local host
    if [ "${src_device}" != "local" ]; then
        if [ "${src_cnx_type}" == "ssh" ] && [ "${dst_cnx_type}" == "ssh" ]; then
            echo_log "    => Copy $src_file key via '${src_cnx_type}' to '${dst_cnx_dest}'"
            echo_debug "scp ${src_cnx_dest}:${src_file} ${src_cnx_dest}_id_rsa.pub"
            scp ${src_cnx_dest}:${src_file} ${src_cnx_dest}_id_rsa.pub
            rc=$?
            if [ $rc -ne 0 ]; then
                echo_error "### ERROR ### Fail to copy public key from ${src_cnx_dest} to `uname -n`"
                echo_debug "copy_check_sshkey END"
                return 1
            fi
            echo_debug "scp ${src_cnx_dest}_id_rsa.pub ${dst_cnx_dest}:.ssh/${src_cnx_dest}_id_rsa.pub"
            scp ${src_cnx_dest}_id_rsa.pub ${dst_cnx_dest}:.ssh/${src_cnx_dest}_id_rsa.pub
            rc=$?
            if [ $rc -ne 0 ]; then
                echo_error "### ERROR ### Fail to copy public key from `uname -n` to ${dst_cnx_dest}"
                echo_debug "copy_check_sshkey END"
                return 1
            fi

            key_user_addr=${src_cnx_dest}

        elif [ "${src_cnx_type}" != "ssh" ]; then
            echo_log "    => Copy $src_file key via '${src_cnx_type}' to local"
            cat << EOF > commands.cmd
echo '${src_file}'
EOF
            expect_exec_cmd "${src_cnx_type}" "${src_cnx_dest}" commands.cmd
            rc=$?
            if [ $rc -ne 0 ]; then
                echo_error "### ERROR ### Fail to copy public key from ${src_device} to `uname -n`"
                echo_debug "copy_check_sshkey END"
                return 1
            fi

            public_key=`cat $commands.res | grep response | awk '{ print $2 }'`
            key_user_addr=`echo ${public_key} | awk '{ print $NF }'`
            echo ${public_key} > ${key_user_addr}_id_rsa.pub
            src_file=${key_user_addr}_id_rsa.pub

            if  [ "${dst_cnx_type}" == "ssh" ]; then
                echo_log "    => Copy local $src_file key via '${dst_cnx_type}' to ${dst_cnx_dest}"
                echo_debug "scp $src_file ${dst_cnx_dest}:.ssh/${key_user_addr}_id_rsa.pub"
                scp $src_file ${dst_cnx_dest}:.ssh/${key_user_addr}_id_rsa.pub
                rc=$?
            else
                echo_log "    => Copy local $src_file key via '${dst_cnx_type}' to ${dst_cnx_dest}"
                cat << EOF > commands.cmd
echo '${public_key}' > ~/.ssh/$src_file
EOF
                expect_exec_cmd "${dst_cnx_type}" "${dst_cnx_dest}" commands.cmd
                rc=$?

            fi            
        
        fi
    else
        public_key=`cat $src_file`
        key_user_addr=`awk '{ print $NF }' $src_file`

        if [ "${dst_cnx_type}" == "ssh" ]; then
            echo_log "    => Copy local ${src_file} key via '${dst_cnx_type}' to ${dst_cnx_dest}"
            echo_debug "scp $src_file ${dst_cnx_dest}:.ssh/${key_user_addr}_id_rsa.pub"
            scp $src_file ${dst_cnx_dest}:.ssh/${key_user_addr}_id_rsa.pub
            rc=$?
        else
            echo_log "    => Copy local ${src_file} key via '${dst_cnx_type}' to ${dst_cnx_dest}"
            cat << EOF > commands.cmd
echo '${public_key}' > ~/.ssh/${key_user_addr}_id_rsa.pub
EOF
            expect_exec_cmd "${dst_cnx_type}" "${dst_cnx_dest}" commands.cmd
            rc=$?
        fi        
    fi

    if [ $rc -ne 0 ]; then
        echo_error "### ERROR ### Fail to copy public key to ${device_name}"
        echo_debug "copy_check_sshkey END"
        return 1
    fi

    cat << EOF > commands.cmd
if [ -f "~/.ssh/authorized_keys" ];then sed "/${key_user_addr}/d" ~/.ssh/authorized_keys > ~/.ssh/authorized_keys.1; mv ~/.ssh/authorized_keys.1 ~/.ssh/authorized_keys; fi
cat ~/.ssh/${key_user_addr}_id_rsa.pub >> ~/.ssh/authorized_keys
rm -f ~/.ssh/${key_user_addr}_id_rsa.pub
EOF
    expect_exec_cmd "${dst_cnx_type}" "${dst_cnx_dest}" commands.cmd
    rc=$?

    if [ $rc -ne 0 ]; then
        echo_error "### ERROR ### Fail to authorize public key to ${device_name}"
        echo_debug "copy_check_sshkey END"
        return 1
    fi

    #Note: restart of acme will also restart dut's BUT sometime, eth iface of dut will not start
    #      So, after restart acme, you must restart dut with dut-hard-reset that cut off input alim
    echo_log "    => Check if ${dst_addr} (${dst_ip}) is restarted"
    echo_debug "copy_check_sshkey - expect_exec_reboot \"${dst_cnx_type}\" \"${dst_cnx_dest}\""
    expect_exec_reboot "${dst_cnx_type}" "${dst_cnx_dest}"
    echo_debug "copy_check_sshkey - wait_board_restart \"${dst_ip}\""
    wait_board_restart "${dst_ip}"
    if [ "${src_device}" != "local" ]; then
        echo_log "    => Check if ${src_addr} (${src_ip}) is restarted" 
        echo_debug "copy_check_sshkey - wait_board_restart \"${src_ip}\""
        wait_board_restart "${src_ip}"
    fi

    sleep 10

    #retest destination ssh
    echo_log "    => Check ssh connection from `uname -n` to ${dst_addr} after key copy"
    echo_debug "bash check-ssh.sh \"${dst_user}\" \"${dst_addr} ${dst_addr}.local ${dst_ip}\" > check-ssh.res"
    bash check-ssh.sh "${dst_user}" "${dst_addr} ${dst_addr}.local ${dst_ip}" > check-ssh.res
    rc=$?
    echo_debug "`cat check-ssh.res`"
    if [ $rc -ne 0 ]; then 
        echo_error "### ERROR ### ssh connection does not work from local `uname -n` to ${dst_addr}"
        echo_debug "copy_check_sshkey END"
        return 1
    fi


    #if source is not local, need to retest also ping and ssh cnx
    if [ "${src_device}" != "local" ]; then
        echo_log "    => Check ssh connection from `uname -n` to ${src_addr} after key copy"
        echo_debug "bash check-ssh.sh \"${src_user}\" \"${src_addr} ${src_addr}.local ${src_ip}\" > check-ssh.res"
        bash check-ssh.sh "${src_user}" "${src_addr} ${src_addr}.local ${src_ip}" > check-ssh.res
        rc=$?
        echo_debug "`cat check-ssh.res`"
        if [ $rc -ne 0 ]; then 
            echo_error "### ERROR ### ssh connection does not work from local `uname -n` to ${src_addr}"
            echo_debug "copy_check_sshkey END"
            return 1
        fi


        #we also need to check ping and ssh cnx from src to dst
        echo_log "    => Check ssh connection from ${src_addr} to ${dst_addr} after key copy"

        echo_debug "Copy file check-ssh.sh to ${src_cnx_dest}"
        echo_debug "scp check-ssh.sh ${src_cnx_dest}:check-ssh.sh"
        scp check-ssh.sh ${src_cnx_dest}:check-ssh.sh
        if [ $? -ne 0 ]; then
            echo_error "### ERROR ### Cannot test ssh connection from ${src_addr} to ${dst_addr}"
            echo_debug "copy_check_sshkey END"
            return 1
        fi

        cat << EOF > commands.cmd
bash check-ssh.sh "${dst_user}" "${dst_addr} ${dst_addr}.local ${dst_ip}"
EOF
        expect_exec_cmd "ssh" "${src_cnx_dest}" commands.cmd
        rc=$?
        if [ $rc -ne 0 ]; then 
            echo_error "### ERROR ### ssh connection does not work from ${src_addr} to ${dst_addr}"
            echo_debug "copy_check_sshkey END"
            return 1
        fi

    fi


    echo_debug "copy_check_sshkey END"
    echo_debug "copy_check_sshkey ret_code=${ret_code}"
    return ${ret_code}

}






###################################################################################
## create ssh system between lab, acme and dut
###################################################################################
create_ssh()
{
    echo_debug "START create_ssh"
    echo_log "Create SSH connection between lab(`uname -n`), acme and dut"

    lab_key=`cat ~/.ssh/id_rsa.pub`
    #check if lab key is in authorized key of each device, add it if not

    for d in ${DEVICE_LIST}; do
        if [ "`echo $d | awk -F\: '{ print $1 }'`" == "acme" ]; then
            acme_device_user=`echo $d | awk -F: '{ print $7 }' | awk -F'@' '{ print $1}'`
            acme_device_addr=`echo $d | awk -F: '{ print $7 }' | awk -F'@' '{ print $2}'`
            acme_device_ip=`echo $d | awk -F: '{ print $8 }'`
        fi
    done

    for d in ${DEVICE_LIST}; do
        device_name=`echo $d | awk -F: '{ print $1 }'`
        device_user=`echo $d | awk -F: '{ print $7 }' | awk -F'@' '{ print $1}'`
        device_addr=`echo $d | awk -F: '{ print $7 }' | awk -F'@' '{ print $2}'`
        device_ip=`echo $d | awk -F: '{ print $8 }'`

        echo_debug "    d = $d"
        echo_debug "    device_name = $device_name"
        echo_debug "    device_user = $device_user"
        echo_debug "    device_addr = $device_addr"
        echo_debug "    device_ip   = $device_ip"

        #copy lab key to each remote (acme and dut)
        #Note: ssh-copy-id does not work, so need to recreate a script to do it
        echo_log "    Copy `uname -n` public key to ${device_addr}"
        echo_debug "copy_check_sshkey \"${device_name}@${device_user}@${device_addr}@${device_ip}\""
        copy_check_sshkey "${device_name}@${device_user}@${device_addr}@${device_ip}"
        if [ $? -eq 0 ]; then echo_log "    Done copy `uname -n` public key to ${device_addr}"; fi

        #copy each dut key to acme
        if [ "${device_name}" != "acme" ]; then
            echo_log "    Copy ${device_name} public key to acme"

            echo_debug "copy_check_sshkey -s \"${device_name}@${device_user}@${device_addr}@${device_ip}\" \"acme@${acme_device_user}@${acme_device_addr}@${acme_device_ip}:.ssh/${device_name}_id_rsa.pub\""
            copy_check_sshkey -s "${device_name}@${device_user}@${device_addr}@${device_ip}" "acme@${acme_device_user}@${acme_device_addr}@${acme_device_ip}:.ssh/${device_name}_id_rsa.pub"
            if [ $? -eq 0 ]; then echo_log "    Done copy `uname -n` public key to ${device_addr}"; fi
                
      
        fi
            
    done

    echo_debug "END create_ssh"
}

###################################################################################
create_board_config()
###################################################################################
{
    echo_debug "START create_board_config"

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

        echo_debug "restart conmux service"
        sudo stop conmux
        sleep 1
        sudo start conmux
        sleep 2

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

    echo_debug "END create_board_config"
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

    LOGFILE="create-boards-conf.log"
    DEBUG=""
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
    #acme_addr
    #board_addr "acme" 
    #check or define boardlist
    echo_debug "CALL board_list"
    board_list

    create_ssh

    #clean previous config files if exist
    echo_log "Cleaning /etc/lava-dispatcher/devices"
    if [ ! -h /etc/lava-dispatcher/devices ];then
        sudo ln -fs ~/POWERCI/fs-overlay/etc/lava-dispatcher/devices /etc/lava-dispatcher/devices
    fi
    echo_debug "sudo rm -f /etc/lava-dispatcher/devices/*.conf"
    sudo rm -f /etc/lava-dispatcher/devices/*.conf

    #create the acme conmux config file
    echo_debug "CALL create_board_config"
    create_board_config    

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


