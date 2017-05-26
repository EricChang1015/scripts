#!/bin/bash
# Author: Eric Chang
# Purpose: if the private IP changed of the spot instance, we can use this script to change config file setting.
# Date: 2017.05.16
set -e

OriginalIP="172.31.2.214"
CurrentIP=$(hostname -i)
ScriptName=$(echo $0 | sed "s/.*\///g")
Ignore="\.log\.|.war$|.gz$|.log$|.rdb|\/data\/mysql"
MatchFiles=$(find /data/deploy/. -type f -and ! -name ${ScriptName}| grep -v -E $Ignore | xargs grep ${OriginalIP} -H -m1 2>/dev/null | sed "s/:.*//g" | xargs)

function help()
{
    clear
    echo ===================== How to  =====================
    echo 'step 1: modified the OriginalIP in this script (/data/deploy)'
    echo step 2: unmark \#main \$@ in this script
    echo step 3: execute this script again
    echo step    \$$0
    echo ===================================================
}

function main()
{
    if [ -z $CurrentIP ]; then
        echo "plz modify CurrentIP as private IP of this machine"
        exit
    fi
    if [ -z "$MatchFiles" ]; then
       echo -e "no match of IP $OriginalIP"
       exit
    fi
    echo $MatchFiles
    export GREP_COLOR='01;32'
    grep ${OriginalIP} --color ${MatchFiles}
    export GREP_COLOR='01;33' #yellpw
    sed -e "s/${OriginalIP}/${CurrentIP}/g" ${MatchFiles} -i # | grep ${CurrentIP} --color
    export GREP_COLOR='01;36' #light blue
    grep ${CurrentIP} --color ${MatchFiles}
}

help
#main $@
