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

username=""

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
function mountData()
{
 execute "file -s /dev/xvdf"
 execute "mkfs -t ext4 /dev/xvdf"
 execute "mount /dev/xvdf /data"
 echo "/dev/xvdf               /data    ext4   defaults,nofail         0 2" >> /etc/fstab
 execute "mkdir -p /data/deploy"
 execute "chown -R $username:$username /data"
}

function main()
{
 execute "checkRoot"
 execute "apt-get update"
 execute "apt-get upgrade -y"
 execute "apt-get dist-upgrade -y"
 execute "apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 58118E89F3A912897C070ADBF76221572C52609D"
 echo $C_GREEN"[Process]apt-add-repository 'deb https://apt.dockerproject.org/repo ubuntu-xenial main'"$C_RESET | tee -a $LOG
 apt-add-repository 'deb https://apt.dockerproject.org/repo ubuntu-xenial main' || return 1
 echo $C_YELLOW"[Success]apt-add-repository 'deb https://apt.dockerproject.org/repo ubuntu-xenial main'"$C_RESET | tee -a $LOG
 execute "apt-get update"
 execute "apt-cache policy docker-engine"
 execute "apt-get install -y docker-engine"
# execute "systemctl status docker"
 
 # check docker-compose version https://github.com/docker/compose/releases
 execute "curl -L "https://github.com/docker/compose/releases/download/1.16.1/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose"
 execute "chmod +x /usr/local/bin/docker-compose"
 execute "apt-get install -y zip unzip"
 echo -n ${C_BG_RED}"Please input primary user name: "${C_RESET}
 read username
 execute "adduser $username"
 execute "mkdir -p /data/deploy"
 execute "chown $username:$username /data -R"
 execute "usermod -aG docker root"
 execute "usermod -aG docker ubuntu"
 execute "usermod -aG docker $username"
 sed "s/^PasswordAuthentication.*no/PasswordAuthentication yes/g" -i /etc/ssh/sshd_config 
 grep "PasswordAuthentication yes" /etc/ssh/sshd_config || echo $C_RED"set PasswordAuthentication fail"$C_RESET
 execute "systemctl restart ssh"
 #for redis
 execute "apt install sysfsutils -y"
 echo "kernel/mm/transparent_hugepage/enabled = never" >> /etc/sysfs.conf
 echo "vm.overcommit_memory=1" >> /etc/sysctl.conf 
 #for setting enviroments
 echo "alias dockerst='docker stats \$(docker ps --format={{.Names}})' " >> /home/$username/.bashrc
 echo "set nu" >> /home/$username/.vimrc
 su - $username
}

main $@
