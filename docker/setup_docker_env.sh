#!/bin/bash
# Purpose: Create a clean OS for docker.
# Author: Ligang.Yao
# Script: Eric.Chang
# Date: 2017.04.07 

LOG=log_$(date +%Y%m%d%H%M).txt
C_BG_RED="-e \e[41m"
C_RED="-e \e[91m"
C_GREEN="-e \e[92m"
C_YELLOW="-e \e[93m"
C_RESET="\e[0m"

function checkRoot()
{
    if [ "$(id -u)" != "0" ]; then
       echo $C_RED"This script must be run as root"$C_RESET 1>&2
       return 1
    fi
}

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
}

function main()
{
 execute "checkRoot"
 execute "apt-get update"
 execute "apt-get upgrade -y"
 execute "apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D"
 echo $C_GREEN"[Process]apt-add-repository 'deb https://apt.dockerproject.org/repo ubuntu-xenial main'"$C_RESET | tee -a $LOG
 apt-add-repository 'deb https://apt.dockerproject.org/repo ubuntu-xenial main' || return 1
 echo $C_YELLOW"[Success]apt-add-repository 'deb https://apt.dockerproject.org/repo ubuntu-xenial main'"$C_RESET | tee -a $LOG
 execute "apt-get update"
 execute "apt-cache policy docker-engine"
 execute "apt-get install -y docker-engine"
# execute "systemctl status docker"
 execute "curl -L "https://github.com/docker/compose/releases/download/1.11.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose"
 execute "chmod +x /usr/local/bin/docker-compose"
 execute "apt-get install -y zip unzip"
 execute "adduser qa"
 execute "adduser qa sudo"
 execute "mkdir -p /data/deploy"
 execute "chown qa:qa /data/deploy"
 execute "usermod -aG docker root"
 execute "usermod -aG docker qa"
 sed "s/^PasswordAuthentication.*no/PasswordAuthentication yes/g" -i /etc/ssh/sshd_config 
 grep "PasswordAuthentication yes" /etc/ssh/sshd_config || echo $C_RED"set PasswordAuthentication fail"$C_RESET
 execute "systemctl restart ssh"
}

main $@
