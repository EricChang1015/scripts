# !/bin/bash
# Purpose: build and launch node.js app
# Author: Eric.Chang
# Ref: https://nodejs.org/en/docs/guides/nodejs-docker-webapp/
# Note: if VM DRAM size is less than 1G, it's will easily build fail without any warning.
# Date: 2017.04.18
#
# How to update
# 1. remove all file except "Dockerfile" "docker-compose.yml" "launch.sh"
# 2. copy your source to the same folder with Dockerfile
# 3. execute this script file

LOG=log_$(date +%Y%m%d%H%M).txt
IMAGE_VERSION=$(date +%Y.%m.%d)
HOST_IP=$(hostname -i)
C_BG_RED="-e \e[41m"
C_RED="-e \e[91m"
C_GREEN="-e \e[92m"
C_YELLOW="-e \e[93m"
C_RESET="\e[0m"

function execute()
{
    echo $C_GREEN"[Process] $@"$C_RESET | tee -a $LOG
    echo $@ 
    $@
    result=$?
    if [ ! 0 -eq $result ]; then
        echo $C_RED"[Fail] $@"$C_RESET | tee -a $LOG
        exit
    else
        echo $C_YELLOW"[Success] $@"$C_RESET | tee -a $LOG
    fi
    sleep 2
}


function main()
{

    #Step 1-1: turn off docker daemond
    cd ../node
    if [ $? == 0 ]; then
        execute "docker-compose down"
        cd -
    else
        echo $C_BG_RED"../node not exist"$C_RESET
    fi

    #Step 1-2: set symbolic link to node
    unlink ../node
    ln -s $PWD ../node

    #Step 1-3: update image version for build script
    sed -e "s/\"mongodbhost:.*\"/\"mongodbhost:${HOST_IP}\"/g" docker-compose.yml -i
    sed -e "s/aspect_node\/wrapper:.*/aspect_node\/wrapper:${IMAGE_VERSION}/g" docker-compose.yml -i


    #Step 2: build (when your haven't generate image, or source code changed)
    execute "docker build -t  aspect_node/wrapper:${IMAGE_VERSION} ."

    #Step 3: execute
    execute "docker-compose up -d"

    #Step 4: check up
    execute "docker-compose ps"
    execute "curl -i localhost:80"
}

main $@

