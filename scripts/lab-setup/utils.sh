#!/bin/bash
###################################################################################
### This file contains a collection of functions and variablesused as library for other shell scripts
### Need to be sourced to be used
###
### Global variable
### - DEBUG_EN		debug enable, default=no, yes to accept debug
### - LOGFILE           usual logfile name
### - STATSFILE         statistic file (execution time, size, ...)
###
### function available
### - echo_log		echo in stdout and log file
### - echo_stat		echo in stdout and log file and stat file
### - echo_type		echo in stdout and log file, dependanding of DEBUG_EN and traces
###                     echo in color depending of TYPE
### - echo_<TYPE>       shortcut to echo_type <TYPE> <message>
### - breakpoint        break point in script
### - locker            pseudo locker to manage concurrent access
###
###################################################################################

###################################################################################
### Global variable used in the following
###################################################################################
DEBUG_EN="no"
LOGFILE=""
STATSFILE=""
LOCKER=""

###################################################################################
### echo_log <text>
##  echo <text> in log file only (if defined) 
###################################################################################
echo_logonly()
{
    if [ ! -z ${LOGFILE} ]; then
        echo -e "$@" > ${LOGFILE} 2>&1
    fi
}

###################################################################################
### echo_stats <text>
##  echo <text> on stdout, log file and in statistic file (if defined)
###################################################################################
echo_stat()
{
    local logdate=`date +"[%Y/%m/%d - %H:%m:%S]"`

    if [ ! -z ${STATSFILE} ]; then
        echo_log "$@"
        echo -e "${logdate} $@" | tee -a ${STATSFILE}
    fi
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

    local opt=`getopt -o o: --long option: -- "$@"`
    if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi

    eval set -- "$opt"

    while true ; do
        case "$1" in
            -o|--option) 
                local option=$2; shift 2;;
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
### breakpoint
##  stop script at this step and wait for enter to continue
###################################################################################
breakpoint()
{
    echo_debug "(${BASH_SOURCE}:${LINENO}) BREAK (Type Enter to continue)"
    read a
}

###################################################################################
### locker
##  stop script at this step and wait for enter to continue
###################################################################################
locker()
{
    local option=$1
    locker=`mktemp`

    if [ "$option" == "acquire" ]; then
        while [ -f $LOCKER ]; do
            echo_warning -o "-n" "Operation locked by another script, Please wait\r"
            sleep 10
        done
    elif [ "$option" == "release" ]; then
        if [ -f $LOCKER ]; then rm -f $LOCKER; fi
    fi

    echo_debug "(${BASH_SOURCE}:${LINENO}) BREAK (Type Enter to continue)"
    read a
}





