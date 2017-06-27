#!/bin/bash

## simple script save status 
## for save memory status to dump file before stop service.

errorCode_ok=0
errorCode_warning=1
errorCode_error=2
backupRoot=/data/redis

containerList="
    fb_redis_p_srv    \
    fb_redis_g_srv    \
    fb_redis_s_srv    \
    fb_redis_t_srv    \
    fb_redis_q_srv    \
    guest_redis_p_srv \
    guest_redis_g_srv \
    guest_redis_s_srv \
    guest_redis_q_srv \
"

C_BG_RED="-e \e[41m"
C_RED="-e \e[91m"
RED="\e[91m"
C_GREEN="-e \e[92m"
C_YELLOW="-e \e[93m"
C_RESET="\e[0m"

###################################################
# arg1 redis docker container name
# arg2 backup to path
###################################################
function saveRedis()
{
    echo $C_YELLOW${FUNCNAME[0]} $container$C_RESET
    if [ ! $# -eq 1 ]; then
        echo $C_RED"api parameter error"$C_RESET
        return $errorCode_error
    fi

    containerName=$1

    # check if docker container exist
    if [ ! "$(docker ps -q -f name=$containerName)" ]; then
        echo  $C_RED"containerName=\"$containerName\" no exist" $C_RESET
        return $errorCode_warning
    fi

    # save redis data (synchronized)
    docker exec $containerName bash -c "redis-cli save"
    return $?
}

function show_help()
{
	clear
	echo -e "========== ${RED}Method 1 w/o arguments $C_RESET==========="
	echo $C_GREEN$0$C_RESET
	echo "---------------------------------------------"
    echo "save following redis containers in scripts"
	for container in $containerList
	do 
		echo $C_YELLOW$container$C_RESET
	done
	echo -e "\n========== ${RED}Method 2 with arguments $C_RESET=========="
	echo $C_GREEN"$0 \e[93mname1 name2 ..."$C_RESET
	echo "---------------------------------------------"
	echo "save your specified redis containers" 
	echo $C_YELLOW"name1"$C_RESET
	echo $C_YELLOW"name2"$C_RESET
	echo $C_YELLOW"..."$C_RESET
	echo "============================================="
}

function parseParameters()
{
	while getopts "h?vf:" opt; do
		case "$opt" in
		h|\?)
			show_help
			exit 0
			;;
		esac
	done
}

function main()
{
	errorCode=$errorCode_ok
    if [ $# -gt 0 ]; then
		parseParameters $@
		containerList=$@
    fi

	for container in $containerList; do
		saveRedis $container
		ret=$?
		if [ $? != 0 ];then
			errorCode=$?
		fi
	done	
	
    return $errorCode
}

main $@
