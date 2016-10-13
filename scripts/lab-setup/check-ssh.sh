#!/bin/bash

###################################################################################
ProcessAbort()
###################################################################################
# specific treatment for process abort
{
    echo "Process Aborted"
    exit 1
}

###################################################################################
PostProcess()
###################################################################################
# cleaning before exit
{
    if [ -f ssh.chk ]; then rm ssh.chk; fi
    if [ -f ssh.expect ]; then rm ssh.expect; fi
    #echo ""
}


stderr_log="create-conmux.err"
if [ -f ${stderr_log} ]; then rm -f ${stderr_log}; fi
exec 2>${stderr_log}

trap 'ProcessAbort $? ${BASH_SOURCE}:${LINENO} ${FUNCNAME[0]:+${FUNCNAME[0]}}' SIGINT SIGTERM SIGKILL
trap 'PostProcess $? ${BASH_SOURCE}:${LINENO} ${FUNCNAME[0]:+${FUNCNAME[0]}}' EXIT


set -x
if [ -z "\`which expect\`" ]; then 
    sudo apt-get install expect
fi


user="$1"
addr_to_check="$2"

addr_pingable=""
addr_checked=""

#current=`date +%Y%m%d-%H%M%S`

#echo "user = $user"
#echo "addr_to_check = $addr_to_check"
#echo "date = $current"

echo "Check ssh connection to:"
for addr in ${addr_to_check}; do
    echo -ne " - $addr => "

    #step 1: check if pingable
    ping ${addr} -c 1 > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        addr_pingable="${addr_pingable} $addr"
    else
        echo "not pingable"
        continue
    fi

    #cat << EOF > ssh.expect.$current
    cat << EOF > ssh.expect
spawn ssh ${user}@${addr} "echo -ne whoami=\`whoami\`"
expect {
      "\*yes/no\*"    { send "yes\r"; exp_continue }
}
EOF

    #step 2: check ssh cnx
    #expect ssh.expect.$current > ssh.chk.$current 2>&1
    #if [ "`cat ssh.chk.$current | grep -v spawn | grep 'whoami=' | cut -d= -f2`" == "$user" ]; then
    expect ssh.expect > ssh.chk 2>&1
    if [ "`cat ssh.chk | grep -v spawn | grep 'whoami=' | cut -d= -f2`" == "$user" ]; then
        echo "OK"
        addr_checked="${addr_checked} $addr"
    else
        echo "NOK"
    fi    

done
set +x

if [ "${addr_pingable// /}" == "" ];then
    exit 2
fi
if [ "${addr_checked// /}" == "" ];then
    exit 1
fi

