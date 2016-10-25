#!/bin/bash

###################################################################################
## 
###################################################################################
read_baud_rate()
{
    local device_name=$1
    if [ -f "/etc/conmux/${device_name}.cf" ]; then
        cat /etc/conmux/${device_name}.cf | grep "application console" | awk -F"/dev/${device_name} " '{ print $2 }' | cut -d\" -f1
    fi
}

###################################################################################
## 
###################################################################################
remove_serial_conf()
{
    local device_name=$1

    if [ -f "/etc/conmux/${device_name}.cf" ]; then
        sudo rm -f /etc/conmux/${device_name}.cf
    fi
}

###################################################################################
## 
###################################################################################
create_serial_conf()
{
    local device_name=$1

    echo_question -o "-n" "What is the baud rate used to connect to ${device_name}? (Default=115200)"
    read baud
    if [ -z "${baud}" ]; then baud=115200; fi

    tmpfile=`mktemp`
    echo """listener ${device_name}
application console '${device_name} console' 'exec sg dialout \"/usr/local/bin/cu-loop /dev/${device_name} ${baud}\"'""" > $tmpfile
    sudo mv -f $tmpfile /etc/conmux/${device_name}.cf

    DEVICE_BAUD_NAME="`echo ${device_name//-/_} | sed 's/./\U&/g'`_BAUD"
    DEVICE_PORT_NAME="`echo ${device_name//-/_} | sed 's/./\U&/g'`_PORT"
    eval ${DEVICE_BAUD_NAME}="${baud}"
    eval ${DEVICE_PORT_NAME}=""


    #conmux specific post install
    #check if cu-loop is in /usr/local/bin, copy it instead
    if [ -z "`which cu`" ];then
        echo_warning "CU is not yet installed. installation will start now."
        sudo apt-get install cu
    fi
    if [ ! -f /usr/local/bin/cu-loop ];then
        echo_debug "copy cu-loop to /usr/local/bin"
        sudo cp -f cu-loop /usr/local/bin/.
    fi

    test -e /usr/spool || sudo mkdir /usr/spool
    sudo chmod -R 775 /usr/spool
    test -e /usr/spool/uucp || sudo mkdir /usr/spool/uucp
    sudo chmod -R 775 /usr/spool/uucp
    sudo chown uucp /usr/spool/uucp
    sudo chgrp dialout /usr/spool/uucp


}

###################################################################################
## 
###################################################################################
is_serial_started()
{
    if [ "`sudo status conmux`" == "conmux stop/waiting" ]; then
        echo "NO"
    elif [ ! -z "`ps -ef | grep conmux | grep -v grep`" ] || [ ! -z "`ps aux | grep "/bin/cu " | grep -v grep`" ]; then
        echo "YES"
    else
        echo "NO"
    fi
}
###################################################################################
## 
###################################################################################
check_serial_started()
{
    echo_log ""
    if [ "`is_serial_started`" == "NO" ]; then
        echo_error "Conmux did not starts successfully"
        exit 1
    fi

    echo_log ""
    echo_log "Check if conmux config is started for each devices"
    echo "" > tmp.tmp
    CONNECTED=""
    ret_code=0
    for d in ${DEVICE_LIST}; do
        device=`echo $d | awk -F":" '{ print $1 }'`
        status=`wait_conmux_status "$device" "connected" | tr -d '[[:space:]]'`
        pid=`ps -aux | grep /usr/sbin/conmux | grep /etc/conmux/${device}.cf | awk '{ print $2 }'`
        if [ -z "$pid" ]; then
            echo_error "  $device: status=$status started=NO config_file=/etc/conmux/${device}" >> tmp.tmp
            ret_code=1
        else
            tcp_port=`sudo lsof -i | grep conmux | grep $pid | awk -F"TCP" '{ print $2 }'`
            if [ "$status" != "connected" ]; then
                echo_warning "  $device: status=$status started=YES config_file=/etc/conmux/${device}.cf pid=${pid} TCP=${tcp_port// /}"  >> tmp.tmp
            else
                echo_info "  $device: status=$status started=YES config_file=/etc/conmux/${device}.cf pid=${pid} TCP=${tcp_port// /}"  >> tmp.tmp

                CONNECTED="${CONNECTED} $d"
            fi
            
        fi
    done
    cat tmp.tmp | column -t
    sudo rm -f tmp.tmp


    return $ret_code
}

###################################################################################
## 
###################################################################################
wait_conmux_status()
{
    echo_log ""
    device=$1
    status_expected=$2
    timeout=60
    start=`date +%s`
    reach="false"
    while [ `date +%s` -lt $((start+timeout)) ]; do
        status_current=`conmux-console --status $device`
        if [ "${status_current}" == "${status_expected}" ]; then
            duration=$((`date +%s`-start))
            echo "$status_current"
            reach="true"
            break
        fi
        sleep 1
    done
    if [ "reach" == "false" ]; then
        echo "$status_current"
        return 1
    fi
}
###################################################################################
## 
###################################################################################
stop_serial()
{
    sudo stop conmux
    sleep 2
}
###################################################################################
## 
###################################################################################
start_serial()
{
    sudo start conmux
    sleep 4
}
###################################################################################
## 
###################################################################################
restart_serial()
{
    sudo stop conmux
    sleep 2
    sudo start conmux
    sleep 4
}

###################################################################################
## 
###################################################################################
exec_expect_serial()
{
    local device_name=$1
    local commands="$2"

    cnx_cmd="conmux-console ${device_name}"
    exec_expect "${cnx_cmd}" "$commands"
}

source utils.sh
