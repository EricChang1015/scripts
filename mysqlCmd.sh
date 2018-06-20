#!/bin/bash
# Author: Eric.Chang
# Purpose: This script help to access mysql db without install mysql client, depends on docker
#
# Dependenices:
# - docker

# please fill these arguments of db setting.
DB_HOST=
DB_USER=
DB_PASS=
DB_NAME=

function checkSetting()
{
    if [ -z ${!1} ]; then
        echo "enter $1:"
	read input
	sed "s/$1=/$1=$input/g" $0 -i
    fi
}


function help() {
    clear
    echo -e "============================= HELP ============================="
    echo "This script help to access mysql db without install mysql client, depends on docker"
    echo -e "$0 + \"mysql command\""
    echo "note: please add quote to wrap mysql command"
    echo
    echo "example:"
    echo -e "$0 \"select * from xxx where id = 123\""
    echo -e "================================================================"
}



if [ $# -eq 0 ]; then
    help
    exit
else
    checkSetting DB_HOST
    checkSetting DB_USER
    checkSetting DB_PASS
    checkSetting DB_NAME
    docker run --rm imega/mysql-client mysql --host=${DB_HOST} --user=${DB_USER} --password=${DB_PASS} --database=${DB_NAME} --execute="$@" 2>/dev/null
fi

