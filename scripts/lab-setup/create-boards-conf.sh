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
## check if environment variable upper(<device_name>)_ADDR exist or not
#  Purpose a default upper(<device_name>)_ADDR to user that shall validate or enter a new one
#  Put the validated upper(<device_name>)_ADDR in /etc/profile.d/lava_lab.sh that will contains some setup dedicated env variable
###################################################################################
board_addr()
{
    echo_debug "START board_addr $1"

    board=$1
    board_addr_name="`echo ${board//-/_} | sed 's/./\U&/g'`_ADDR"
    board_ip_name="`echo ${board//-/_} | sed 's/./\U&/g'`_IP"
    echo_debug "board_addr_name = ${board_addr_name}"

    if [ -z "`printenv | grep ${board_addr_name}`" ];then
        echo_log "Get address of ${board}"

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

            eval ${board_addr_name}="${user}@${addr}"
            echo_debug "${board_addr_name} = ${!board_addr_name}"
            eval ${board_ip_name}="${ip}"
            echo_debug "${board_ip_name} = ${!board_ip_name}"

            echo_log "Address read in ${board} is set to:"
            echo_info "${!board_addr_name} (${!board_ip_name})"
            echo_question -o "-n" "Correct? (Y|n): "
            read resp

            if [ "$resp" == "n" ];then
                while true; do
                    echo_question -o "-n" "Please enter your new address for ${board}: "
                    read addr
                    eval ${board_addr_name}="${addr}"
                    echo_debug "${board_addr_name} = ${!board_addr_name}"
                    if [ ! -z `echo ${!board_addr_name}` ];then break; fi
                done

                newaddr=`echo ${!board_addr_name} | cut -d@ -f2`

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
                    eval ${board_addr_name}="${user}@${newaddrchg}"
                    echo_log "${board} address is changed to:"
                    echo_info "${!board_addr_name}"
                else
                    echo_warning "### WARNING ### ${board} address is not changed !"
                fi

            fi

        else
            while true; do
                echo_question -o "-n" "Please enter manually an address for ${board}: "
                read addr
                eval ${board_addr_name}="${addr}"
                echo_debug "${board_addr_name} = ${!board_addr_name}"
                if [ ! -z `echo ${!board_addr_name}` ];then break; fi
            done
        fi
    fi

    if [ ! -f /etc/profile.d/lava_lab.sh ]; then
        touch /etc/profile.d/lava_lab.sh
    fi

    test_line="${board_addr_name}=${!board_addr_name}"
    if [ -z "`cat /etc/profile.d/lava_lab.sh | grep ${test_line}`" ]; then
        tmp_file=`mktemp`
        echo_debug "File /etc/profile.d/lava_lab.sh: Add line \"${test_line}\""
        echo "${board_addr_name}=${!board_addr_name}" >> ${tmp_file}
        sudo mv -f ${tmp_file} /etc/profile.d/lava_lab.sh 
        echo_debug "END board_addr"
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

    echo "NAME TYPE TTY ACME_PORT BAUD_RATE ADDR IP" > /tmp/lava_board
    echo_debug "DEVICE_LIST:\n ${DEVICE_LIST}"
    for d in ${DEVICE_LIST}; do
        device_name=`echo $d | awk -F: '{ print $1 }'`
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

        while true; do
            echo_question "Enter ACME port connected to this device (From 1 to 8): "
            read acme_port
            if [ $acme_port -ge 1 ] && [ $acme_port -le 8 ]; then break; 
            else echo " => Incorrect value"
            fi
        done
 
        echo_log "ReStart $d"
cat << EOF > commands.cmd
dut-hard-reset ${acme_port}
EOF
        expect_exec_cmd "conmux-console" "acme" "commands.cmd"
        rc=$?

        if [ $rc -eq 0 ]; then
            i=0
            while [ $i -lt 30 ]; do
                sleep 1
                echo_log -o "-ne" "."
                i=$(($i + 1))
            done
            board_addr ${device_name}

            board_addr_name="`echo ${board//-/_} | sed 's/./\U&/g'`_ADDR"
            board_ip_name="`echo ${board//-/_} | sed 's/./\U&/g'`_IP"
            newd="$d:${GET_ANSWER_RESULT}:${acme_port}:${!board_addr_name}:${!board_ip_name}"
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
## check an ssh cnx to dest_addr
#  if cnx succeed, get its user@address with command 'whoami' and 'uname -n'
###################################################################################
check_ssh_cnx()
{
cat << EOF > commands.cmd
pwd
EOF

    expect_exec_cmd "ssh" "$1" commands.cmd
    rc=$?
    
    return $rc
}

###################################################################################
## create ssh system between lab, acme and dut
###################################################################################
copy_sshkey()
{
    echo_debug "copy_sshkey START"
    local keyfile=`echo ~/.ssh/id_rsa`

    local opt=`getopt -o k: --long key: -- "$@"`
    if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi

    eval set -- "$opt"

    while true ; do
        case "$1" in
            -k|--key) 
                keyfile="$2"; shift 2;;
            --) shift ; break ;;
            *) echo "Internal error!" ; exit 1 ;;
        esac
    done

    local destination=$1

    if [ -n "`echo $destination | grep ':'`" ]; then
        dest_conmux=`echo $destination | cut -d: -f1`
        dest_user=`echo $destination | cut -d: -f2 | cut -d@ -f1`
        dest_addr=`echo $destination | cut -d: -f2 | cut -d@ -f2`
        dest_ip=`echo $destination | cut -d: -f2 | cut -d@ -f3`
    else
        dest_conmux=""
        dest_user=`echo $destination | cut -d@ -f1`
        dest_addr=`echo $destination | cut -d@ -f2`
        dest_ip=`echo $destination | cut -d@ -f3`
    fi

    #check if key exist for lab, create it if not
    if [ ! -f "$keyfile.pub" ]; then
        echo_log "    => Create `uname -n` rsa key"
        ssh-keygen -N "" -f $keyfile
    fi

    public_key=`cat $keyfile.pub`

    #check ssh connection
    echo_log "    => Check if ${dest_addr} is pingable"
    dest_addr_ext=""
    ping ${dest_addr} -c 1 > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        ping ${dest_addr}.local -c 1 > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            ping ${dest_ip} -c 1 > /dev/null 2>&1
            if [ $? -ne 0 ]; then
                #nothing is pingable, use conmux
                cnx_type="conmux-console"
                if [ -z "$dest_conmux" ]; then
                    echo_error "ssh connection does not work for ${dest_addr}"
                    echo_error "conmux device name is mandatory"
                    usage
                    exit 1
                else
                    cnx_dest="${dest_conmux}"
                fi
            else
                #only ip is pingable (addr issue) use ssh with ip
                cnx_type="ssh"
                cnx_dest="${dest_user}@${dest_ip}"
            fi
        else
            #addr.local is pingable, use ssh with addr.local
            dest_addr_ext=".local"
            cnx_type="ssh"
            cnx_dest="${dest_user}@${dest_addr}${dest_addr_ext}"
        fi
    else
        cnx_type="ssh"
        cnx_dest="${dest_user}@${dest_addr}"     
    fi

    if [ "${cnx_type}" == "ssh" ]; then
        echo_log "    => Check ssh connection from `uname -n` to ${dest_ip} already exist"
        check_ssh_cnx "${cnx_dest}"
        
        if [ $? -ne 0 ]; then
            cnx_type="conmux-console"
            if [ -z "$dest_conmux" ]; then
                echo_error "ssh connection does not work for ${dest_addr}"
                echo_error "conmux device name is mandatory"
                usage
                exit 1
            else
                cnx_dest="${dest_conmux}"
            fi
        fi
    fi

    #give authorized key via conmux
    ret_code=0
    echo_log "    => Copy $keyfile.pub key via '${cnx_type}' to '${cnx_dest}'"

    key_user_addr=`awk '{ print $NF }' $keyfile.pub`

cat << EOF > commands.cmd
echo '${public_key}' > tmp.tmp
if [ -f ".ssh/authorized_keys" ];then sed '/${key_user_addr}/d' .ssh/authorized_keys > .ssh/authorized_keys.1; mv .ssh/authorized_keys.1 .ssh/authorized_keys; fi
cat tmp.tmp >> .ssh/authorized_keys; fi
EOF

    expect_exec_cmd "${cnx_type}" "${cnx_dest}" commands.cmd
    rc=$?

    if [ $rc -ne 0 ]; then
        echo_error "### ERROR ### Fail to copy public key to ${device_name}"
        ret_code=1
    else
        echo_log "    => Check ssh connection from `uname -n` to ${dest_addr} after key copy"
        check_ssh_cnx "${dest_user}@${dest_ip}"
        rc1=$?
        check_ssh_cnx "${dest_user}@${dest_addr}${dest_addr_ext}"
        rc2=$?

        if [ $rc1 -ne 0 ] && [ $rc2 -ne 0 ]; then 
            echo_error "### ERROR ### ssh connection does not work for ${dest_addr}"
            ret_code=1
        fi
    fi

    echo_debug "copy_sshkey END"
    echo_debug "copy_sshkey ret_code=${ret_code}"
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
        device_name=`echo $d | awk -F: '{ print $1 }'`
        device_user=`echo $d | awk -F: '{ print $7 }' | awk -F'@' '{ print $1}'`
        device_addr=`echo $d | awk -F: '{ print $7 }' | awk -F'@' '{ print $2}'`
        device_ip=`echo $d | awk -F: '{ print $8 }'`

        if [ ${device_name}"" == "acme" ]; then
            acme_device_user=${device_user}
            acme_device_addr=${device_addr}
            acme_device_ip=${device_ip}
        fi

        #copy lab key to remote
        #Note: ssh-copy-id does not work, so need to recreate a script to do it
        echo_log "    Copy `uname -n` public key to ${device_addr}"
        copy_sshkey ${device_name}:${device_user}@${device_addr}@${device_ip}
        if [ $? -eq 0 ]; then echo_log "    Done copy `uname -n` public key to ${device_addr}"; fi

        #copy dut key to acme
        if [ "${device_name}" != "acme" ]; then
            echo_log "    Copy ${device_name} public key to acme"

            echo_log "    => Check and Create pub key of ${device_name}"

cat << EOF > commands.cmd
if [ ! -f ".ssh/id_rsa.pub" ]; then ssh-keygen -N "" -f ".ssh/id_rsa"; fi
EOF

            expect_exec_cmd "ssh" "${device_user}@${device_ip}" commands.cmd
            rc=$?

            if [ $rc -ne 0 ]; then 
                echo_error "Public key for ${device_name} does not exist and creation fails"
            else
                echo_log "    => Get pub key from ${device_name}"
                echo_debug "scp ${device_user}@${device_ip}:~/.ssh/id_rsa.pub ${device_name}_id_rsa.pub"
                scp ${device_user}@${device_ip}:~/.ssh/id_rsa.pub ${device_name}_id_rsa.pub
                if [ $? != 0 ]; then 
                    echo_error "Fail to copy public key of ${device_name} to acme"
                else
                    echo_log "    => Copy pub key onto acme"
                    copy_sshkey -k ${device_name}_id_rsa acme:${acme_device_user}@${acme_device_addr}@${acme_device_ip}
                    if [ $? -ne 0 ]; then
                        echo_error "Fail to copy public key of ${device_name} to acme"
                    else
                        echo_debug "    => Copy script expect_exec_cmd.py to ${device_name} "
                        echo_debug "scp expect_exec_cmd.py ${device_user}@${device_ip}:expect_exec_cmd.py"
                        scp expect_exec_cmd.py ${device_user}@${device_ip}:expect_exec_cmd.py
                        if [ $? -ne 0 ]; then 
                            echo_error "Fail to check ssh cnx from ${device_name} to acme"

                        else 
                            echo_debug "    => Install python and pexpect on ${device_name}"
cat << EOF > commands.cmd
sudo apt-get install python
sudo apt-get install python-pexpect
EOF

                            expect_exec_cmd "ssh" "${device_user}@${device_ip}" commands.cmd
                            rc=$?
                            if [ $? != 0 ]; then 
                                echo_error "Fail to check ssh cnx from ${device_name} to acme"
                            else                 
                                echo_log "    => Check ssh connection from ${device_name} to acme"

cat << EOF > commands.cmd
python expect_exec_cmd.py ssh ${acme_device_user}@${acme_device_ip} "ls"
python expect_exec_cmd.py ssh ${acme_device_user}@${acme_device_addr} "ls"
python expect_exec_cmd.py ssh ${acme_device_user}@${acme_device_addr}.local "ls"
EOF

                                expect_exec_cmd "ssh" "${device_user}@${device_ip}" commands.cmd
                                rc=$?

                                if [ $? != 0 ]; then 
                                    echo_error "Fail to check ssh cnx from ${device_name} to acme"
                                else                 
                                    echo_log "    Done copy ${device_name} public key to ${acme_device_addr}"
                                    echo_log ""
                                fi
                            fi
                        fi
                    fi
                fi
            fi        
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
    VERSION="0.2"

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
    board_addr "acme" 
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


