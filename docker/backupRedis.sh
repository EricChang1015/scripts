#!/bin/bash

## simple redis rdb backup script
## usage backup redis dump from docker container
errorCode_ok=0
errorCode_warning=1
errorCode_error=2
version=$(date +%Y%m%d_%H)
version_day=$(date +%Y%m%d_08)
expire_version_hours=$(date +%Y%m%d_%H --date="2 hours ago")
expire_version_week=$(date +%Y%m%d_%H --date="7 days ago")

backupRoot=/backup/redis

declare -a mapContainersBackPath=(
    fb_redis_p_srv         $backupRoot/$version/facebook/player \
    fb_redis_g_srv         $backupRoot/$version/facebook/global \
    fb_redis_s_srv         $backupRoot/$version/facebook/session \
    fb_redis_t_srv         $backupRoot/$version/facebook/tournament \
    fb_redis_q_srv         $backupRoot/$version/facebook/queue \
    guest_redis_p_srv      $backupRoot/$version/guest/player \
    guest_redis_g_srv      $backupRoot/$version/guest/global \
    guest_redis_s_srv      $backupRoot/$version/guest/session \
    guest_redis_q_srv      $backupRoot/$version/guest/queue \
)


###################################################
# arg1 redis docker container name
# arg2 backup to path
###################################################
function saveRedis()
{
    wait=${3:-10} ## default wait for 10 seconds
    if [ ! $# -eq 2 ]; then
        echo "api parameter error"
        return $errorCode_error
    fi
    containerName=$1
    backup_to=$2
    dockerCmd="docker exec $containerName bash -c"
    dockerCopyRdb="docker cp $containerName:/data/dump.rdb"
    # check if docker container exist
    if [ ! "$(docker ps -q -f name=$containerName)" ]; then
        echo  "containerName=\"$containerName\" no exist" 
        return $errorCode_error
    fi
    # check if destination path availiable
    if [ ! -d $backup_to ]; then
        mkdir -p $backup_to
        if [ ! $? -eq 0 ];then
            echo "create backup path directory permission denied"
            return $errorCode_error
        fi
    fi
    
    # save redis data in background (asynchronized)
    $dockerCmd "redis-cli bgsave"
    echo "waiting for $wait seconds..."
    sleep $wait
    try=5
    while [ $try -gt 0 ] ; do
        saved=$($dockerCmd "echo 'info Persistence' | redis-cli" | awk '/rdb_bgsave_in_progress:0/{print "saved"}')
        ok=$($dockerCmd "echo 'info Persistence' | redis-cli" | awk '/rdb_last_bgsave_status:ok/{print "ok"}')
        if [[ "$saved" = "saved" ]] && [[ "$ok" = "ok" ]] ; then
            $dockerCopyRdb $backup_to
            if [ $? -eq 0 ] ; then
                echo "$dockerCopyRdb $backup_to ."
                return $errorCode_ok
            else 
                echo ">> Failed to $dockerCopyRdb $backup_to !"
                return $errorCode_error
            fi
        fi
        try=$((try - 1))
        echo "redis maybe busy, waiting and retry in 5s..."
        sleep 5
    done
    echo "redis maybe busy, waiting and retry in 5s..."
    return $errorCode_warning
}

function removeExpiredData()
{
    cd $backupRoot
    backList=$(ls -d 20*/ 2>/dev/null)

    for folder in $backList
    do
        # remove backup data longer than one hours, but reserve at UTC 08:00 (American midnight)
        if [ $expire_version_hours \> $folder ] && [ $expire_version_week \< $folder ]; then
            echo $folder | grep -v "_08" | xargs rm -rf 
            backUpfolder=$(echo $folder | grep "_08")
            if [ ! -z $backUpfolder ] ; then
                echo "start to compress daily ${version_day}.tar.gz"
                time tar -zcf ${version_day}.tar.gz $backUpfolder
                rm -rf $backUpfolder
                echo "compress daily ${version_day}.tar.gz done"
            fi
        fi

        # remove backup data longer than a week
        if [ $expire_version_week \> $folder ]; then
            echo "remove expired backup $folder"
            rm -rf "$folder"
        fi
    done
    cd -
}

function main()
{
    removeExpiredData
    for ((i=0;i<${#mapContainersBackPath[@]};i+=2)); do
        saveRedis ${mapContainersBackPath[i]} ${mapContainersBackPath[i+1]}
        ret=$?
        if [ $? != 0 ];then
            errorCode=$?
        fi
    done
    return $errorCode
}

main
