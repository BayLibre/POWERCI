#! /bin/bash
set -o pipefail
set -o errtrace
#set -o nounset #Error if variable not set before use  
#set -o errexit #Exit for any error found... 

lab_install()
{
    echo "Adding Repositery" 
    sudo apt-get -y update
    sudo apt-get -y upgrade

    if [ ! -f trusty-repo.key.asc ]; then
        wget http://images.validation.linaro.org/trusty-repo/trusty-repo.key.asc

        sudo apt-key add trusty-repo.key.asc
        sudo apt-get -y update
    fi

    echo "Install LAVA" 
    sudo apt-get -y install lava

    sudo cp /usr/share/lava-dispatcher/tftpd-hpa /etc/default/tftpd-hpa

    if [ -d lava_dispatcher ]; then sudo rm -rf lava_dispatcher; fi
    sudo ln -fs /home/$USER/POWERCI/SRC/lava-dispatcher/lava_dispatcher lava_dispatcher

    echo "link fs-overlay/etc stuff to /etc" 
    if [ -d /etc/lava-dispatcher/devices ]; then sudo rm -rf /etc/lava-dispatcher/devices; fi
    sudo ln -fs /home/$USER/POWERCI/fs-overlay/etc/lava-dispatcher/devices /etc/lava-dispatcher/devices
    if [ -d /etc/lava-dispatcher/device-types ]; then sudo rm -rf /etc/lava-dispatcher/device-types; fi
    sudo ln -fs /home/$USER/POWERCI/fs-overlay/etc/lava-dispatcher/device-types /etc/lava-dispatcher/device-types
    sudo ln -fs /home/$USER/POWERCI/fs-overlay/etc/lava-dispatcher/lava-dispatcher.conf /etc/lava-dispatcher/lava-dispatcher.conf

    if [ ! -f /etc/lava-server/settings.conf ]; then
        echo "### ERROR ### File /etc/lava-server/settings.conf not found" 
    fi

    if [ ! -f /etc/apache2/sites-available/lava-server.conf ]; then
        echo "### Need to check or create /et/apache2/sites-available/lava-server.conf"
    fi

    echo "apache2 service" 
    if [ "`sudo a2query -s 000-default | grep enabled 2>/dev/null`" != ""  ]; then
        sudo a2dissite 000-default
    fi
    if [ -f /etc/apache2/sites-available/lava-server.conf ]; then
        if [ -z "`sudo a2query -s lava-server | grep enabled`" ]; then
            sudo a2ensite lava-server.conf
        fi
    fi
    if [ -z "`cat /etc/apache2/sites-enabled/lava-server.conf | grep VirtualHost | grep ':10080'`" ]; then
        cat /etc/apache2/sites-available/lava-server.conf | sed -e "s/:80>/:10080>/g" > /etc/apache2/sites-available/lava-server.conf.new
        sudo mv -f /etc/apache2/sites-available/lava-server.conf.new /etc/apache2/sites-available/lava-server.conf
    fi
    if [ "`cat /etc/apache2/sites-enabled/lava-server.conf | grep ServerName | awk '{ print $2 }'`" != "`uname -n`" ]; then
        cat /etc/apache2/sites-available/lava-server.conf | sed -e "s/ServerName [a-zA-Z0-9 \t-_]*/ServerName `uname -n`/g" > /etc/apache2/sites-available/lava-server.conf.new
        sudo mv -f /etc/apache2/sites-available/lava-server.conf.new /etc/apache2/sites-available/lava-server.conf
    fi
    if [ "`cat /etc/apache2/sites-enabled/lava-server.conf | grep ServerAdmin | awk '{ print $2 }'`" != "webmaster@localhost" ]; then
        cat /etc/apache2/sites-available/lava-server.conf | sed -e "s/ServerAdmin [a-zA-Z0-9 \t-_.@]*/ServerAdmin webmaster@localhost/g" > /etc/apache2/sites-available/lava-server.conf.new
        sudo mv -f /etc/apache2/sites-available/lava-server.conf.new /etc/apache2/sites-available/lava-server.conf
    fi
    if [ -z "`cat /etc/apache2/ports.conf | grep 'Listen 10080'`" ]; then
        cat /etc/apache2/ports.conf | sed -e "s/Listen 80/Listen 10080/g" > /etc/apache2/ports.conf.new
        mv -f /etc/apache2/ports.conf.new /etc/apache2/ports.conf
    fi
    if [ -z "`cat /etc/apache2/ports.conf | grep 'Listen 10443'`" ]; then
        cat /etc/apache2/ports.conf | sed -e "s/Listen 443/Listen 10443/g" > /etc/apache2/ports.conf.new
        mv -f /etc/apache2/ports.conf.new /etc/apache2/ports.conf
    fi
    if [ -z "`cat /etc/apache2/apache2.conf | grep ServerName`" ]; then
        cat /etc/apache2/apache2.conf | sed -e "s/# Global configuration/# Global configuration\nServerName localhost/g" > /etc/apache2/apache2.conf.new
        mv -f /etc/apache2/apache2.conf.new /etc/apache2/apache2.conf
    fi
    sudo service apache2 restart

    echo "Create Lava superuser account " 
    sudo lava-server manage createsuperuser --username $USER --email="" 2>tmp.tmp
    if [ -f tmp.tmp ]; then
        cat tmp.tmp | grep DETAIL
        rm -f tmp.tmp
    fi
    
    echo "Create conmux config"
    bash ./scripts/lab-setup/create-conmux.sh -c
}

###################################################################################
ProcessAbort()
###################################################################################
# specific treatment for process abort
{
    echo "Process Aborted"
    echo "=> rc before Abort: $1"
    echo "=> abort called after: $2 $3"
    exit 1
}

###################################################################################
PostProcess()
###################################################################################
# cleaning before exit
{
    echo "PostProcess"
    echo "=> rc: $1"
    echo "=> exit after: $2 $3"
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
            echo "ErrorProcess"
            echo "=> $2 $3"
            echo "=> rc: $1"
            echo "=> Error: $stderr"
            rm -f $stderr

            #exit $1
        else
            rm -f $stderr
        fi
    fi
    continue
}


###################################################################################
### Script starts here
###################################################################################
#trap "" EXIT ERR SIGINT SIGTERM SIGKILL

abspath=`dirname $(readlink -f $0)`
cd $abspath

#source utils.sh

stderr_log="lab-install.err"
if [ -f ${stderr_log} ]; then rm -f ${stderr_log}; fi
exec 2>${stderr_log}


trap 'ProcessAbort $? ${BASH_SOURCE}:${LINENO} ${FUNCNAME[0]:+${FUNCNAME[0]}}' SIGINT SIGTERM SIGKILL
trap 'PostProcess $? ${BASH_SOURCE}:${LINENO} ${FUNCNAME[0]:+${FUNCNAME[0]}}' EXIT
#trap 'trapErr $? ${BASH_SOURCE}:${LINENO} ${FUNCNAME[0]:+${FUNCNAME[0]}}' ERR 


lab_install ${@}

#reset all trap
#trap - EXIT ERR SIGINT SIGTERM SIGKILL


