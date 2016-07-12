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

foo()
{
    echo $1
}
##############################################################
### get_answer [OPTION] "<answer1>,<answer2>,...,<answerN>"
##  echo a list of possible answers, like:
##  1. answer1 (can contains spaces, -, _, ...)
##  2. answer2
##  ...
##  N.  answerN
##  N+1. all (if option -m|--multi)
##  N+2. none (if option -n|--none)
##
##  get and return the result list
##  if option multi is set, it can be a single,partial or complete list
##  unless only a single element is accepted
##  choice can be done by number (multi is space separated choice) or value
##############################################################
get_answer()
{
#set -x
    get_answer_usage="""usage: get_answer [OPTION] <answer1>,<answer2>,...,<answerN>

[OPTION]
  -m: multi choice available
  -n: none of the answer accepted
"""

    local multi="no"
    local none="no"

    ## Analyse input parameter
    local OPTIND o m n
    while getopts ":mn" o; do
        case "${o}" in
            m) 
                multi="yes";;
            n) 
                none="yes";;
            *) echo ${get_answer_usage}; exit 1 ;;
        esac
    done
    shift $((OPTIND-1))

    declare -a answers
    save_IFS=$IFS
    IFS=","
    for e in $*; do
        answers=("${answers[@]}" "$e")
    done
    IFS=$save_IFS
    local nb_answers=${#answers[@]}

    #echo ${answers[@]}
    #echo $nb_answers
   
   
    if [ "$multi" == "yes" ]; then nb_answers=$((nb_answers+1)); fi
    if [ "$none" == "yes" ];  then nb_answers=$((nb_answers+1));fi

    local wrong_choice="yes"
    while [ "$wrong_choice" == "yes" ]; do
        i=0
        for answer in ${answers[@]}; do
            i=$((i+1))
            echo_log "$i. $answer"
        done
        if [ "${multi}" == "yes" ]; then 
            i=$((i+1))
            echo_log "$i. all"
            answer_all=$i
        fi
        if [ "${none}" == "yes" ]; then 
            i=$((i+1))
            echo_log "$i. none"
            answer_none=$i
        fi

        if [ "${multi}" == "yes" ]; then echo_question -o "-n" "Please, enter your choice [1-$i] (space separated if multi): "  
        else                             echo_question -o "-n" "Please, enter your choice [1-$i] : "
        fi
        read mychoice

        declare -a choices=($mychoice)
        if [ "${multi}" == "no" ]; then
            if [ ${#choices[@]} -gt 1 ]; then echo_warning "1 choice allowed"
            else valid_choices=$mychoice; wrong_choice="no"
            fi

        elif [ "${multi}" == "yes" ]; then
            invalid_choices=""
            valid_choices=""
            for choice in ${choices[@]}; do
                if [ $choice -gt $nb_answers ]; then invalid_choices="$invalid_choices $choice"
                elif [ $choice -lt 1 ]; then         invalid_choices="$invalid_choices $choice"
                else                                 valid_choices="$valid_choices $choice"
                fi
            done
            if [ "$invalid_choices" != "" ]; then echo_warning "invalid choices: ${invalid_choices}"
            elif [ "`echo $mychoice | grep $answer_all`" != "" ]; then
                valid_choices=""
                for((j=1;j<$answer_all;j++)); do
                    valid_choices="$valid_choices $j"
                done
                wrong_choice="no"
            else wrong_choice="no"
            fi
        elif [ "${multi}" == "yes" ] && [ "${none}" == "yes" ] && [ "`echo $mychoice | grep $answer_all | grep $answer_none`" != "" ]; then
            echo_type "WARNING" "choice cannot be 'all' and 'none' at same time"
        elif [ "${none}" == "yes" ]; then
            valid_choices=""
            wrong_choice="no"
        fi
        
    done

    GET_ANSWER_RESULT=""
    for valid_choice in $valid_choices; do
        if [ "$GET_ANSWER_RESULT" == "" ]; then GET_ANSWER_RESULT="${answers[$((valid_choice-1))]}"
        else                                    GET_ANSWER_RESULT="$GET_ANSWER_RESULT,${answers[$((valid_choice-1))]}"
        fi
    done
}



