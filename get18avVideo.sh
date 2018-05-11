#!/bin/bash

# This bash script is used to help men's mental health, download healthy video from 18av.mm-cg.com.
# hope you will like it.
# 2018/05/11:

#set -e

forceDownload='n'
verbose='n'
proxy='n'

LOG="/dev/null"
C_BG_RED="\e[41m"
C_RED="\e[91m"
C_GREEN="\e[92m"
C_YELLOW="\e[93m"
C_RESET="\e[0m"

ERROR_NONE=0
ERROR_INVALID_SOURCE=1
ERROR_INVALID_HTML=2
ERROR_ALREADY_DOWNLOAD=3
ERROR_INVALID_TITLE=4
ERROR_INVALID_INPUT=5
ERROR_DOWNLOADING=6

#proxy can reference to https://free-proxy-list.net/
proxy_server=""
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
downloadTo=$DIR/18avVideo
downloadtemp=${downloadTo}/temp
bashScriptName=$(echo $0 | sed "s/.*\///g")
prefix_goingList=goingList
goingList=${prefix_goingList}.${bashScriptName}.txt
ongoingList=ongoingList.${bashScriptName}.txt
prefix_downloadGoingList=${downloadTo}/${prefix_goingList}
downloadGoingList=${downloadTo}/${goingList}
downloadOngoingList=${downloadTo}/${ongoingList}
downloadListPattern="${downloadTo}/list*.csv"
downloadList=${downloadTo}/list.$(date +%Y%m%d-%H%M).csv
metadataFolder=${downloadTo}/metadata/video
newsFolder=${downloadTo}/news
lock=${downloadTo}/lock


# arg1: index to download
function checkIfDownloading()
{
    # no going list
    ls ${prefix_downloadGoingList}.* >/dev/null 2>&1 || return 0 
    # incorrect argument number
    if [ ! $# -eq 1 ]; then
        echo -e ${C_RED}"incorrect argument number which should be 1 argument"${C_RESET}
        return 1
    fi
    grep $1 ${prefix_downloadGoingList}.* >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e ${C_RED}"$1 is downloading"${C_RESET}
        grep $1 ${prefix_downloadGoingList}.* -H
        return 1
    else
        return 0
    fi
}

main()
{
    if [ $# -eq 0 ] && [ ! -f $downloadOngoingList ]; then
        show_help
        return
    fi
    mkdir -p $downloadTo
    parseParameters $@
    echo $@ | sed "s/ /\n/g" | sort -u | sed '/^\s*$/d' | grep -v "-" >> $downloadOngoingList
    if [ ! -f $downloadGoingList ]; then
        while [ $(wc -l $downloadOngoingList | awk '{print $1}') -gt 0 ]; do
            source=$(head -n1 $downloadOngoingList)
            sed -i '1d' $downloadOngoingList
            execute preSetting $source       || continue
            echo $source > $downloadGoingList
            execute getWebInfo               || return $?
            execute getVideoTitle            || return $?
            execute downloadPreviewImages    || return $?
            execute downloadVideo            || return $?
            echo left $(wc -l $downloadOngoingList | awk '{print $1}') tasks
        done
        rm -rf $downloadGoingList
        rm -rf $downloadOngoingList
    fi
}

function execute()
{
    echo -e $C_GREEN"[Process] $@"$C_RESET | tee -a $LOG
    echo $@
    $@
    result=$?
    if [ ! 0 -eq $result ]; then
        echo -e $C_RED"[Fail] $@"$C_RESET | tee -a $LOG
        return $result
    else
        echo -e $C_YELLOW"[Success] $@"$C_RESET | tee -a $LOG
    fi
}

#Note: use ":"and "$OPTARG" to argument
function parseParameters()
{
    while getopts "h?vlcpd:dfd:pvlc?h:" opt; do
        case "$opt" in
        h|\?)
            show_help
            exit 0
            ;;
        v)
            set -x
            verbose='y'
            echo -e ${C_YELLOW}"verbose"${C_RESET}
            ;;
        f)
            forceDownload='y'
            echo -e ${C_YELLOW}"force"${C_RESET}
            ;;
        p)
            proxy='y'
            if [ ! -z $proxy_server ]; then
                echo -e ${C_YELLOW}"use proxy $proxy_server"${C_RESET}
            else
                echo "Please enter proxy info like this format: \${ip}:\${port}"
                echo "You can reference to https://free-proxy-list.net/"
                echo "Or use Ctrl+C to exit"
                echo ":"
                read -t 120 input
                proxy_server=$input
                sed "s/^proxy_server=.*/proxy_server=\"$proxy_server\"/g" $0 -i
            fi
            ;;
        l)
            showOngoing
            ;;
        c)
            fixBrokenFile
            ;;
        d)
            nDaysAgo=0
            if [ ! -z $OPTARG ]; then
                nDaysAgo=$OPTARG
            fi
            downloadDailyNews $nDaysAgo
            ;;
        esac
    done
}

function showOngoing()
{
    if [ -f $downloadGoingList ]; then
        echo these ID are downloading: $(cat $downloadGoingList | xargs)
        ls -lht ${downloadTo}/$(cat $downloadGoingList | head -n1 | awk '{print $1}')/*.mp4*
    fi
    if [ -f $downloadOngoingList ] && [ $(cat $downloadOngoingList | wc -w ) -ge 1 ]; then
        echo these ID are pending to download: $(cat $downloadOngoingList | xargs)
    fi
    otherList=$(ls $(echo $downloadGoingList $downloadOngoingList | sed "s/${bashScriptName}/\*/g") 2>/dev/null \
              | sed "s/ /\n/g" | grep -v -E "${goingList}|${ongoingList}")

    if [ ! -z "$otherList" ]; then
        echo -e "\n= Other List ="
        for file in $otherList ; do
            if [ $(cat $file | wc -w) -ge 1 ]; then
                echo $file | sed "s/.*\///g"
                cat $file | xargs
            fi
        done
    fi
    exit
}

function fixBrokenFile()
{
    echo "==== enter q to exit ===="
    while true; do
        echo "enter folder number:"
        read -t 30 TbfFolder
        if [ $TbfFolder == q ]; then
            break
        fi
        if [ ! -z ${TbfFolder} ] && [ -d ${downloadTo}/${TbfFolder} ]; then
           echo "enter file index number:"
           read -t 30 TbfIndex
           if [ $TbfIndex == q ]; then
               break
           fi
           if [ ! -z ${TbfIndex} ] && [ -f "$(ls ${downloadTo}/${TbfFolder}/*${TbfIndex}.mp4)" ]; then
               cd ${downloadTo}/${TbfFolder}/
               echo fix $(ls *${TbfIndex}.mp4)
               mv *${TbfIndex}.mp4 ${TbfIndex}.mp4.download
               echo ${TbfFolder} >> ${downloadOngoingList}
           fi
        fi
    done
    exit

}

function downloadDailyNews()
{
    targetDate=$(date +%Y-%m-%d -d "$1 days ago")
    dailyNewsURL=http://18av.mm-cg.com/news/$targetDate.html
    echo "==== ${targetDate} ===="
    mkdir -p $newsFolder
    if [ ! -f $newsFolder/$targetDate.html ]; then
        myCurl $dailyNewsURL | grep "影片區" | sed "s/<li/\n<li/g" | sed "s/<a class/\n<a class/g" | sed "s/<\/a>/<\/a>\n/g" > $newsFolder/$targetDate.html
    fi
    cat $newsFolder/$targetDate.html | grep "18av.mm-cg.com\/18av" | sed "s/.*\/18av\///g" | sed "s/.html.*src=\"/ , /g" | sed "s/jpg\".*alt=/jpg ,/g" | sed "s/jizcg.*//g"
    echo "open in browser? (Y/N) or enter index to download index (1-8)"
    read -t 30 input
    downloadIndexSet=$(echo $input | grep -E "[0-9\ ]+" -o | sed "s/ /\n/g" | sort -u | xargs)
    isPending=$(echo $input | grep -i -o "p")
    downloadNumbers=$(echo $downloadIndexSet | wc -w)
    echo $downloadNumbers
    if [ $downloadNumbers -ge 1 ]; then
        for index in $downloadIndexSet ; do
            downloadId=$(cat $newsFolder/$targetDate.html | grep "18av.mm-cg.com\/18av" | sed "s/.*\/18av\///g" | sed "s/.html.*src=\"/ , /g" | sed "s/jpg\".*alt=/jpg ,/g" | sed "s/jizcg.*//g" | grep -E "^[0-9]+" -o | sed -n ${index}p)
            echo "put $downloadId in $downloadOngoingList"
            echo $downloadId >> $downloadOngoingList
        done
        if [ $isPending == P ] || [ $isPending == p ]; then
            exit
        fi
    elif [ $input == Y ] || [ $input == y ]; then
        start chrome --incognito $newsFolder/$targetDate.html
        exit
    else
        exit
    fi

}

function show_help()
{
    echo -e "${C_YELLOW}=============<<<HELP>>>=================${C_RESET}"
    echo -e "${C_YELLOW}This bash script help you to download   ${C_RESET}"
    echo -e "${C_YELLOW}video from http://18av.mm-cg.com        ${C_RESET}"
    echo -e "${C_YELLOW}========================================${C_RESET}"
    echo -e "=            options                ="
    echo -e "-f force download, even in $downloadList"
    echo -e "-x verbose"
    echo -e "-p use proxy"
    echo -e "-c continue download broken file"
    echo -e "-l show ongoing list"
    echo -e "-d N: get N days ago AV news"
    echo -e "----------------------------------------"
    echo -e "Exp 1. Download with whole URL"
    echo -e "${C_YELLOW}$0 http://18av.mm-cg.com/18av/23623.html ...${C_RESET}"
    echo -e "----------------------------------------"
    echo -e "Exp 2. Download with reference video number"
    echo -e "${C_YELLOW}$0 23623 26437 ... &${C_RESET}"
    echo -e "Exp 3. Keep downloading after logout"
    echo -e "${C_YELLOW}nohup $0 23623 26437 ... &${C_RESET}"
    echo -e "========================================"
}

function preSetting()
{
    source=$1
    checkIfDownloading $source || return $ERROR_DOWNLOADING
    testInput="$(echo $source | grep html)"
    if [ ! -z $testInput ]; then
        URL=$1
    elif [[ $source =~ ^-?[0-9]+$ ]] ;then
        URL="http://18av.mm-cg.com/18av/${source}.html"
    else
        echo "invalid source $source"
        return $ERROR_INVALID_SOURCE
    fi

    htmlFileName=$(echo $URL | sed "s/.*\///g" )
    subFolder=$(echo $htmlFileName | sed "s/.html//g" )
    downloadFolder=$downloadTo/$subFolder

    cat $downloadListPattern | awk '{print $1}' | grep $subFolder
    # already download
    if [ $? -eq 0 ]; then
        if [ "$forceDownload" == 'n' ] && [ ! -d $downloadFolder ]; then
            echo "already download $(cat $downloadListPattern | grep $subFolder)"
            return $ERROR_ALREADY_DOWNLOAD
        fi
    fi
    htmlFile=$metadataFolder/$htmlFileName
    mkdir -p $metadataFolder
    mkdir -p $downloadFolder
}

function testHtml(){
    grep youjizz $htmlFileName > /dev/null
}

function myCurl(){
    if [ "$proxy" == "n" ]; then
        curl $@
    else
        curl -x $proxy_server $@
    fi
}

function tryProxy(){
    echo "try $1 proxy"
    proxy="$1"
    myCurl $URL -o $htmlFileName
    testHtml
    if [ $? -eq 0 ]; then
        echo edit setting
        cd -  > /dev/null
        sed "s/^proxy=.*/proxy=\'$1\'/g" -i $0
        cd -  > /dev/null
    fi
}

function getWebInfo(){
    error_code=$ERROR_NONE
    if [ ! -f $htmlFile ]; then
        cd $metadataFolder

        myCurl $URL -o $htmlFileName
        #test if content usefull info
        testHtml
        if [ ! $? -eq 0 ]; then
            if [ "$proxy" == "n" ]; then
                tryProxy y
            else
                tryProxy n
            fi
        fi
        testHtml
        if [ ! $? -eq 0 ]; then
            error_code=$ERROR_INVALID_HTML
        fi
        cd - > /dev/null
    fi
    return $error_code
}

function getVideoTitle()
{
    trylock
    videoTitle=$(cat $htmlFile | grep "影片名稱" | sed "s/<br>/\n/g" | grep "影片名稱" | sed "s/.*>//g" | sed "s/,/ /g")
    echo "$subFolder , $videoTitle" > $downloadtemp
    cat $downloadListPattern >> $downloadtemp
    rm -f $downloadListPattern
    cat $downloadtemp | sort -u -h > $downloadList
    title=$videoTitle
    if [ -z "$title" ]; then
        rm -f $htmlFile
        return $ERROR_INVALID_TITLE
    fi
    unlock
}



function downloadPreviewImages()
{
    videoPreviewImages=$(cat $htmlFile | grep "影片名稱" | sed "s/<br>/\n/g"  | sed "s/http:/\nhttp:/g" | sed "s/jpg.*/jpg/g" | grep http | grep jpg | xargs)
    for ImageUrl in $videoPreviewImages; do
        filename=$(echo $ImageUrl | sed "s/.*\///g" )
        ImageFile=$downloadFolder/$filename
        if [ ! -f "$ImageFile" ]; then
            cd $downloadFolder
            curl -O $ImageUrl > /dev/null 2>&1 &
            sleep 0.5
            cd - > /dev/null
        fi
    done
}

function getStringBytes()
{
    myvar=$1
    chrlen=${#myvar}
    oLang=$LANG
    LANG=C
    bytlen=${#myvar}
    LANG=$oLang
    echo $bytlen
}

# To get avaliable string, because filename should less than 255 bytes
# Arg 1: input string
# Arg 2: bytes limitation
# return output string
function truncateString()
{
    if [ ! $# -eq 2 ]; then
        echo "truncateString should have two arguments"
        return ERROR_INVALID_INPUT
    fi
    input="$1"
    limitBytes=$2
    echo $input | head -c $limitBytes
}

function downloadVideoCommand()
{
    curl -L -C - $videoUrl -o "$filename_downloading"
}

function isStreamDownloadIncomplete()
{
    if [ ! -z "$(ffprobe -version 2>&1)" ] ; then
        streamBitRate=$(ffprobe $filename_downloading 2>&1 | grep -E "bitrate:.*kb\/s" -o | sed "s/ kb\/s//g" | sed "s/.* //g")
        videoTrackBitRate=$(ffprobe $filename_downloading 2>&1 | grep -E "Video.*kb\/s" -o -m1 | sed "s/ kb\/s//g" | sed "s/.* //g")
        if [ $streamBitRate -gt $videoTrackBitRate ]; then
            echo "$filename download completed"
            return 1 #complete
        fi
    fi
    return 0 #incomplete
}

function downloadVideoUntilComplete()
{
    downloadVideoCommand
    declare -i maxRetry=5;
    if [ -z "$(ffprobe -version 2>&1)" ] ; then
        return;
    fi
    for ((retry=1;retry<=$maxRetry; retry++)); do
        isStreamDownloadIncomplete || return;
        sleep 5
        echo "$filename retry $retry time"
        downloadVideoCommand
    done
}

function downloadVideo()
{
    EmbedVideoWenList=$(cat $htmlFile | grep embed | sed "s/http/\nhttp/g" | sed "s/\".*//g" | grep embed | grep youjizz | xargs)
    echo $EmbedVideoWenList
    declare -i index=0
    for embedVideoWeb in $EmbedVideoWenList; do
        index+=1
        adjustTitle=$(truncateString  "$videoTitle" 240)
        filename="$adjustTitle $index.mp4"
        filename_downloading="$index.mp4.download"
        videoFile=$downloadFolder/$filename
        videoFile_downloading=$downloadFolder/$filename_downloading
        echo filename=$filename
        echo embedVideoWeb=$embedVideoWeb
        embedMetafileName=$(echo $embedVideoWeb | sed "s/.*\///g" )
        embedMetafile=$metadataFolder/$embedMetafileName
        if [ ! -f "$videoFile" ]; then
            cd $metadataFolder
            curl $embedVideoWeb -o $embedMetafileName
            cd - > /dev/null
        else
            echo "already download $videoFile"
            continue
        fi

        videoFHD=$(grep mp4 "$embedMetafile" | sed "s/\,/\n/g" | grep filename | grep -v m3u8 | sed "s/\"/\n/g" | grep mp4 | sed "s/\\\//g" | grep -E "1920\-1080\-" | head -1)
        videoHD=$(grep mp4 "$embedMetafile" | sed "s/\,/\n/g" | grep filename | grep -v m3u8 | sed "s/\"/\n/g" | grep mp4 | sed "s/\\\//g" | grep -E "1280\-720\-" | head -1)
        videoSD="$(grep mp4 "$embedMetafile" | sed "s/\,/\n/g" | grep filename | grep -v m3u8 | sed "s/\"/\n/g" | grep mp4 | sed "s/\\\//g" | grep -E "532\-480|536\-480|546\-480|564\-480|678\-480|704\-480|710\-480|712\-480|718\-480|720\-480|736\-414" | head -1)"
        videoUnknown=$(grep mp4 "$embedMetafile" | sed "s/\,/\n/g" | grep filename | grep -v m3u8 | sed "s/\"/\n/g" | grep mp4 | sed "s/\\\//g" | head -1)

        if [ ! -z "$videoFHD" ]; then
            videoUrl=https:$videoFHD
        elif [ ! -z "$videoHD" ]; then
            videoUrl=https:$videoHD
        elif [ ! -z "$videoSD" ]; then
            videoUrl=https:$videoSD
        elif [ ! -z "$videoUnknown" ]; then
            videoUrl=https:$videoUnknown
        else
            echo "cann't resolve videoUrl of $filename"
            continue
        fi

        echo "$videoFile_downloading"
        if [ -f "$videoFile_downloading" ] || [ ! -f "$videoFile" ] ; then
            cd $downloadFolder
            downloadVideoUntilComplete
            mv "$filename_downloading" "$filename"
            cd - > /dev/null
        else
            echo "already download $filename"
        fi
    done
    ls -lht ${downloadFolder}/*.mp4
}

function waitlock()
{
    counter=20
    while [ -f ${lock}.* ] && [ $counter -gt 0 ] ; do
        sleep 2
        let counter-=1
        echo $(ls ${lock}.* | sed -e "s/.*lock.//g") ls locking
    done
}

function trylock()
{
    waitlock
    touch ${lock}.${bashScriptName}
}

function unlock()
{
    rm -rf ${lock}.${bashScriptName}
}

trap '{ interruptHandler ; }' INT
function interruptHandler()
{
    if [ -f $downloadGoingList ]; then
        echo "ID $(cat $downloadGoingList) are downloading"
        echo "Do you want to stop? (Y/N)"
        read -t 60 input
        if [ $input == 'Y' ] || [ $input == 'y' ]; then
            cat $downloadGoingList >> $downloadOngoingList
            rm $downloadGoingList
            unlock
            exit 0
        fi
    else
        unlock
        exit 0
    fi
}

main $@
