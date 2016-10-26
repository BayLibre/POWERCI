#! /bin/bash
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
    echo "usage: lab-install.sh [OPTION]"
    echo ""
    echo "[OPTION]"
    echo "    -h | --help:        Print this usage"
    echo "    --version:          Print version"
    echo "    -v | --verbose:     Debug traces"
    #echo "    -s | --status:      Get status"
    echo "    -l | --logfile:     Logfile to use"
    echo ""
}

###################################################################################
## 
###################################################################################
parse_args()
{

    ## Analyse input parameter
    TEMP=`getopt -o chl:v --long clear,help,logfile:,version -- "$@"`

    if [ $? != 0 ] ; then echo_error "Terminating..." >&2 ; exit 1 ; fi

    eval set -- "$TEMP"

    while true ; do
        case "$1" in
            -h|--help)
                usage; exit 0; shift;;
            --version)
                echo "lab-install.sh version: $VERSION"; 
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
            #-s|--status)
            #    STATUS="yes"; shift;;
            --) shift ; break ;;
            *) echo_error "Internal error!" ; exit 1 ;;
        esac
    done
    echo_debug "START lab-install"
    echo_debug "Analyse input argument"
    echo_debug "Logfile:       ${LOGFILE}"
    echo_debug "Debug Enabled: ${DEBUG_EN}"
    echo_debug "Debug Level:   ${DEBUG_LVL}"

}


###################################################################################
## 
###################################################################################
lab_install()
{
    LOGFILE="lab-install.log"
    DEBUG_EN="no"
    DEBUG_LVL=0
    if [ -f ${LOGFILE} ]; then rm -f ${LOGFILE}; fi

    #define xtrace fd to 10 and redirect as append LOGFILE
    exec 10>> ${LOGFILE}
    export BASH_XTRACEFD=10
    #redirect error to stderr_log
    #exec 2>${stderr_log} 

    ## Analyse input parameter
    parse_args "$@"

    echo_info "Adding Repositery" 
    sudo apt-get -y update
    sudo apt-get -y upgrade

    if [ ! -f trusty-repo.key.asc ]; then
        wget http://images.validation.linaro.org/trusty-repo/trusty-repo.key.asc

        sudo apt-key add trusty-repo.key.asc
        sudo apt-get -y update
    fi

    echo_info "Install LAVA" 
    sudo apt-get -y install lava

    echo_debug "    copy /etc/default/tftpd-hpa" 
    sudo cp /usr/share/lava-dispatcher/tftpd-hpa /etc/default/tftpd-hpa

    echo_debug "    link lava_dispatcher" 
    if [ -d lava_dispatcher ]; then sudo rm -rf lava_dispatcher; fi
    sudo ln -fs /home/$USER/POWERCI/SRC/lava-dispatcher/lava_dispatcher lava_dispatcher

    echo_info "link fs-overlay/etc stuff to /etc" 
    if [ -d /etc/lava-dispatcher/devices ]; then sudo rm -rf /etc/lava-dispatcher/devices; fi
    sudo ln -fs /home/$USER/POWERCI/fs-overlay/etc/lava-dispatcher/devices /etc/lava-dispatcher/devices
    if [ -d /etc/lava-dispatcher/device-types ]; then sudo rm -rf /etc/lava-dispatcher/device-types; fi
    sudo ln -fs /home/$USER/POWERCI/fs-overlay/etc/lava-dispatcher/device-types /etc/lava-dispatcher/device-types
    sudo ln -fs /home/$USER/POWERCI/fs-overlay/etc/lava-dispatcher/lava-dispatcher.conf /etc/lava-dispatcher/lava-dispatcher.conf

    if [ ! -f /etc/lava-server/settings.conf ]; then
        echo_error "### ERROR ### File /etc/lava-server/settings.conf not found" 
    fi

    echo_info "apache2 service" 
    echo_debug "    ports.conf" 
    if [ -f /etc/apache2/ports.conf ]; then
        if [ -z "`cat /etc/apache2/ports.conf | grep 'Listen 10080'`" ]; then
            sudo cat /home/$USER/POWERCI/fs-overlay/etc/apache2/ports.conf >> /etc/apache2/ports.conf
        fi
    else
        sudo ln -fs /home/$USER/POWERCI/fs-overlay/etc/apache2/ports.conf /etc/apache2/ports.conf
    fi

    echo_debug "    lava-server.conf" 
    if [ -f /etc/apache2/sites-available/lava-server.conf ]; then sudo rm -f /etc/apache2/sites-available/lava-server.conf; fi
    sudo ln -fs /home/$USER/POWERCI/fs-overlay/etc/apache2/sites-available/default-ssl.conf /etc/apache2/sites-available/lava-server.conf

    if [ "`sudo a2query -s 000-default | grep enabled 2>/dev/null`" != ""  ]; then
        sudo a2dissite 000-default
    fi
    if [ -f /etc/apache2/sites-available/lava-server.conf ]; then
        if [ -z "`sudo a2query -s lava-server | grep enabled`" ]; then
            sudo a2ensite lava-server.conf
        fi
    fi
    if [ -z "`cat /etc/apache2/sites-enabled/lava-server.conf | grep VirtualHost | grep ':10080'`" ]; then
        cat /etc/apache2/sites-available/lava-server.conf | sed -e "s/:80>/:10080>/g" > lava-server.conf.new
        sudo mv -f lava-server.conf.new /etc/apache2/sites-available/lava-server.conf
    fi
    if [ "`cat /etc/apache2/sites-enabled/lava-server.conf | grep ServerName | awk '{ print $2 }'`" != "`uname -n`" ]; then
        cat /etc/apache2/sites-available/lava-server.conf | sed -e "s/ServerName .*/ServerName `uname -n`/g" > lava-server.conf.new
        sudo mv -f lava-server.conf.new /etc/apache2/sites-available/lava-server.conf
    fi
    if [ "`cat /etc/apache2/sites-enabled/lava-server.conf | grep ServerAdmin | awk '{ print $2 }'`" != "webmaster@localhost" ]; then
        cat /etc/apache2/sites-available/lava-server.conf | sed -e "s/ServerAdmin .*/ServerAdmin webmaster@localhost/g" > lava-server.conf.new
        sudo mv -f lava-server.conf.new /etc/apache2/sites-available/lava-server.conf
    fi
    #if [ -z "`cat /etc/apache2/ports.conf | grep 'Listen 10443'`" ]; then
    #    cat /etc/apache2/ports.conf | sed -e "s/Listen 443/Listen 10443/g" > /etc/apache2/ports.conf.new
    #    mv -f /etc/apache2/ports.conf.new /etc/apache2/ports.conf
    #fi
    echo_debug "    apache2.conf" 
    if [ -z "`cat /etc/apache2/apache2.conf | grep ServerName`" ]; then
        cat /etc/apache2/apache2.conf | sed -e "s/# Global configuration/# Global configuration\nServerName localhost/g" > apache2.conf.new
        sudo mv -f apache2.conf.new /etc/apache2/apache2.conf
    fi
    sudo service apache2 restart

    echo_info "Create Lava superuser account " 
    sudo lava-server manage createsuperuser --username $USER --email="" 2>tmp.tmp
    if [ -f tmp.tmp ]; then
        cat tmp.tmp | grep DETAIL
        rm -f tmp.tmp
    fi
    
    echo_info "Create serial"
    if [ ${DEBUG_LVL} -eq 1 ]; then   DEBUG_OPTION="-v"
    elif [ ${DEBUG_LVL} -eq 2 ]; then DEBUG_OPTION="-vv"
    else                              DEBUG_OPTION=""
    fi

    bash ./scripts/lab-setup/create-serial ${DEBUG_OPTION} -c
}
###################################################################################
### echo_type [-o <echo option>] <type> <text>
##  echo <text> on stdout, log file and in statistic file (if defined)
###################################################################################
echo_type()
{
    #trace pre-treatment, we do not want to print echo_type traces
    local xtraceStatus=`set -o | grep xtrace | awk '{ print $2 }'`
    if [ "${xtraceStatus}" == "on" ]; then set +x; fi

    local logdate=`date +"[%Y/%m/%d - %H:%m:%S]"`    
    local option=""

    local opt=`getopt -o o: --long option: -- "$@"`
    if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi

    eval set -- "$opt"

    while true ; do
        case "$1" in
            -o|--option) 
                option=$2; shift 2;;
            --) shift ; break ;;
            *) echo "Internal error!" ; exit 1 ;;
        esac
    done

    local echo_type=$1
    local text=$2

    #debug treatment
    if [ "$DEBUG_EN" == "no" ] && [ "${echo_type}" == "DEBUG" ]; then
        return
    fi
   
    #color definition
    local bold=$(tput bold)     #bold

    local col_info=$(tput setaf 6)     #Cyan
    local col_warning=$(tput setaf 3)  #Yellow
    local col_error=$(tput setaf 1)    #Red
    local col_question=$(tput setaf 2) #Green
    local col_debug=${bold}$(tput setaf 5)    #Bold

    local col_rst=$(tput sgr0)       #no color, no bold

    #type definition
    case ${echo_type} in
        "INFO")     color=${col_info};;
        "QUESTION") color=${col_question};;
        "WARNING")  color=${col_warning};;
        "ERROR")    color=${col_error};;
        "DEBUG")    color=${col_debug};;
        "LOG")      color=${col_rst};;
        "")         color=${col_rst};;
        "*")        color=${col_rst};;
    esac

    echo -e ${option} "${color}${text}${col_rst}" | tee -a ${LOGFILE}

    if [ "${xtraceStatus}" == "on" ]; then set -x; fi

}

###################################################################################
### echo_<TYPE> [-o <echo option>] <text>
##  call the correct echo_type <TYPE>
###################################################################################
echo_log(){ echo_type LOG "$@"; }
echo_info(){ echo_type INFO "$@"; }
echo_warning(){ echo_type WARNING "$@"; }
echo_error(){ echo_type ERROR "$@"; }
echo_question(){ echo_type QUESTION "$@"; }
echo_debug(){ echo_type DEBUG "$@"; }

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
    if [ -f ${stderr_log} ];then sudo rm -f ${stderr_log};fi
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


#used by trapErr
stderr_log="lab-install.err"
#if [ -f ${stderr_log} ]; then rm -f ${stderr_log}; fi
#exec 2>${stderr_log}


trap 'ProcessAbort $? ${BASH_SOURCE}:${LINENO} ${FUNCNAME[0]:+${FUNCNAME[0]}}' SIGINT SIGTERM SIGKILL
trap 'PostProcess $? ${BASH_SOURCE}:${LINENO} ${FUNCNAME[0]:+${FUNCNAME[0]}}' EXIT
#trap 'trapErr $? ${BASH_SOURCE}:${LINENO} ${FUNCNAME[0]:+${FUNCNAME[0]}}' ERR 


lab_install ${@}

#reset all trap
#trap - EXIT ERR SIGINT SIGTERM SIGKILL


