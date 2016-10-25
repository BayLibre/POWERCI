#!/bin/bash

###################################################################################
## 
###################################################################################
read_baud_rate()
{
    local device_name=$1
    if [ -f "/etc/ser2net.conf" ]; then
        cat /etc/ser2net.conf | grep "/dev/${device}" | awk -F\: '{ print $5 }' | awk '{ print $1 }'
    fi
}

###################################################################################
## 
###################################################################################
read_port()
{
    local device_name=$1
    if [ -f "/etc/ser2net.conf" ]; then
        cat /etc/ser2net.conf | grep ^4 | grep "/dev/${device}" | awk -F\: '{ print $1 }'
    fi
}

###################################################################################
## 
###################################################################################
remove_serial_conf()
{
    local device_name=$1

    if [ -f "/etc/ser2net.conf" ]; then
        cat /etc/ser2net.conf | grep -v /dev/${device_name} > /etc/ser2net.conf.sav
        sudo mv -f /etc/ser2net.conf.sav /etc/ser2net.conf
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

    if [ "${device_name}" == "acme" ]; then
        port=4000
    else
        #get next free port from 4001
        for ((i=4001;i<5000;i++)); do
            if [ -z "`cat /etc/ser2net.conf | grep ^$i`" ]; then 
                port=$i
                break
            fi
        done
    fi

    tmpfile=`mktemp`
    echo """${port}:telnet:0:/dev/${device_name}:${baud} 8DATABITS NONE 1STOPBIT banner""" > $tmpfile
    sudo cat $tmpfile >> /etc/ser2net.conf

    DEVICE_BAUD_NAME="`echo ${device_name//-/_} | sed 's/./\U&/g'`_BAUD"
    DEVICE_PORT_NAME="`echo ${device_name//-/_} | sed 's/./\U&/g'`_PORT"
    eval ${DEVICE_BAUD_NAME}="${baud}"
    eval ${DEVICE_PORT_NAME}="${port}"
}

###################################################################################
## 
###################################################################################
is_serial_started()
{
    if [ "`sudo service --status-all 2>/dev/null | grep "ser2net" | cut -d[ -f2 | cut -d] -f1 | sed 's/\s*//g'`" == "-" ]; then
        echo "NO"
    elif [ ! -z "`ps -aux | grep /usr/sbin/ser2net | grep /etc/ser2net.conf | grep -v grep`" ]; then
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
    echo_log ""
    if [ "`is_serial_started`" == "NO" ]; then
        echo_error "Ser2net did not starts successfully"
        exit 1
    fi

    echo_log "Check if ser2net is started"
    echo "" > tmp.tmp
    CONNECTED=""
    ret_code=0
    for d in ${DEVICE_LIST}; do
        device=`echo $d | awk -F":" '{ print $1 }'`

        pid=`ps -aux | grep /usr/sbin/ser2net | grep /etc/ser2net.conf | awk '{ print $2 }'`
        port=`read_port $device`
        if [ -z "$pid" ]; then
            echo_error "  $device: started=NO" >> tmp.tmp
            ret_code=1
        else 
            tcp_port=`sudo lsof -i | grep ser2net | grep $pid | awk -F"TCP" '{ print $2 }' | grep $port`
            if [ ! -z "$tcp_port"]; then
                echo_info "  $device: started=YES pid=${pid} TCP=${tcp_port// /}"  >> tmp.tmp

                CONNECTED="${CONMUX_CONNECTED} $d"
            fi
            
        fi
    done
    cat tmp.tmp | column -t
    sudo rm -f tmp.tmp
}

###################################################################################
## 
###################################################################################
stop_serial()
{
    sudo service ser2net stop
    sleep 2
}
###################################################################################
## 
###################################################################################
start_serial()
{
    sudo service ser2net start
    sleep 4
}
###################################################################################
## 
###################################################################################
restart_serial()
{
    sudo service ser2net restart
    sleep 2
}

###################################################################################
## 
###################################################################################
reboot_device()
{
    local device_name=$1

    port=`read_port ${device_name}`
    cnx_cmd="telnet ${port}"
    echo_debug "exec_expect \"${cnx_cmd}\" \"-\" \"--reboot\""
    exec_expect "${cnx_cmd}" "-" "--reboot"
}

###################################################################################
## 
###################################################################################
exec_expect_serial()
{
    local device_name=$1
    local commands="$2"

    port=`read_port ${device_name}`
    cnx_cmd="telnet ${port}"
    echo_debug "exec_expect \"${cnx_cmd}\" \"$commands\""
    exec_expect "${cnx_cmd}" "$commands"
}


source utils.sh
