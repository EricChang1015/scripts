#!/bin/bash

# feature:
# 09/17: add download list and check if force download or not.
# 09/18: curl continue download when terminate => curl -C
# 09/19: use proxy for AWS can access this web

# bug fix:
# 09/27: truncate title when length longer than 255. (prevent download fail)

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

proxy_server="110.77.200.3:65205" #https://free-proxy-list.net/
downloadTo=18avVideo
downloadtemp=$downloadTo/temp
downloadOngoingList=$downloadTo/OngoingList.txt
downloadListPattern="$downloadTo/list*.csv"
downloadList=$downloadTo/list.$(date +%Y%m%d-%H%M).csv
metadataFolder=$downloadTo/metadata/video
newsFolder=$downloadTo/news

main()
{
    if [ $# -eq 0 ]; then
        show_help
        return
    fi
    mkdir -p $downloadTo
    parseParameters $@
    if [ -f $downloadOngoingList ] && [ $(wc -l $downloadOngoingList | awk '{print $1}') -gt 0 ] ; then
        echo $@ | sed "s/ /\n/g" | sort -u | sed '/^\s*$/d' | grep -v "-" >> $downloadOngoingList
    else
        echo $@ | sed "s/ /\n/g" | sort -u | sed '/^\s*$/d' | grep -v "-" >> $downloadOngoingList
        while [ $(wc -l $downloadOngoingList | awk '{print $1}') -gt 0 ]; do
            source=$(head -n1 $downloadOngoingList)
            sed -i '1d' $downloadOngoingList
            execute preSetting $source       || continue
            execute getWebInfo               || return $?
            execute getVideoTitle            || return $?
            execute downloadPreviewImages    || return $?
            execute downloadVideo            || return $?
            echo left $(wc -l $downloadOngoingList | awk '{print $1}') tasks
        done
        rm $downloadOngoingList
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
    echo $@
    while getopts "h?vpd:dfd:pv?h:" opt; do
    echo $opt
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
            echo -e ${C_YELLOW}"use proxy $proxy_server"${C_RESET}
            ;;
        d)
            nDaysAgo=0
            if [ ! -z $OPTARG ]; then
                nDaysAgo=$OPTARG
            fi
            downloadDailyNews $nDaysAgo
            exit
            ;;
        esac
    done
}

function downloadDailyNews()
{
    targetDate=$(date +%Y-%m-%d -d "$1 days ago")
    dailyNewsURL=http://18av.mm-cg.com/news/$targetDate.html
    mkdir -p $newsFolder
    if [ ! -f $newsFolder/$targetDate.html ]; then
        myCurl $dailyNewsURL | grep "影片區" | sed "s/<li/\n<li/g" | sed "s/<a class/\n<a class/g" | sed "s/<\/a>/<\/a>\n/g" > $newsFolder/$targetDate.html
    fi
    cat $newsFolder/$targetDate.html | grep "18av.mm-cg.com\/18av" | sed "s/.*\/18av\///g" | sed "s/.html.*src=\"/ , /g" | sed "s/jpg\".*alt=/jpg ,/g" | sed "s/jizcg.*//g"
    echo "open in browser? (Y/N)"
    read -t 30 input
    if [ $input == Y ] || [ $input == y ]; then
        start chrome $newsFolder/$targetDate.html
    fi
}

function show_help()
{
    echo -e "${C_YELLOW}=============<<<HELP>>>=================${C_RESET}"
    echo -e "${C_YELLOW}This bash script help you to download   ${C_RESET}"
    echo -e "${C_YELLOW}video from http://18av.mm-cg.com        ${C_RESET}"
    echo -e "${C_YELLOW}========================================${C_RESET}"
    echo -e "=            How to use                ="
    echo -e "-f force download, even in $downloadList"
    echo -e "----------------------------------------"
    echo -e "Exp 1. Download with whole URL"
    echo -e "${C_YELLOW}$0 http://18av.mm-cg.com/18av/23623.html ...${C_RESET}"
    echo -e "----------------------------------------"
    echo -e "Exp 2. Download with reference video number"
    echo -e "${C_YELLOW}$0 23623 26437 ...${C_RESET}"
    echo -e "Exp 3. Keep downloading after logout"
    echo -e "${C_YELLOW}nohup $0 23623 26437 ...${C_RESET}"
    echo -e "========================================"
}

function preSetting()
{
    source=$1
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
    videoTitle=$(cat $htmlFile | grep "影片名稱" | sed "s/<br>/\n/g" | grep "影片名稱" | sed "s/.*>//g" | sed "s/,/ /g")
    echo "$subFolder , $videoTitle" > $downloadtemp
    cat $downloadListPattern >> $downloadtemp
    rm -f $downloadListPattern
    cat $downloadtemp | sort -u > $downloadList
    title=$videoTitle
    if [ -z "$title" ]; then
        rm -f $htmlFile
        return $ERROR_INVALID_TITLE
    fi
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
        videoHD=$(grep mp4 $embedMetafile | sed "s/\,/\n/g" | grep filename | grep -v m3u8 | sed "s/\"/\n/g" | grep mp4 | sed "s/\\\//g" | grep -E "\-1080\-|\-720\-" | head -1)
        videoSD=$(grep mp4 $embedMetafile | sed "s/\,/\n/g" | grep filename | grep -v m3u8 | sed "s/\"/\n/g" | grep mp4 | sed "s/\\\//g" | grep -E "\-480\-|\-426\-|\-320\-|\-360\-" | head -1)
        if [ ! -z $videoHD ]; then
            videoUrl=https:$videoHD
        elif [ ! -z $videoSD ]; then
            videoUrl=https:$videoSD
        else
            echo "cann't resolve videoUrl of $filename"
            continue
        fi
        echo $videoUrl

        echo "$videoFile_downloading"
        if [ -f "$videoFile_downloading" ] || [ ! -f "$videoFile" ] ; then
            cd $downloadFolder
            curl -L -C - $videoUrl -o "$filename_downloading"
            mv "$filename_downloading" "$filename"
            cd - > /dev/null
        else
            echo "already download $filename"
        fi
    done
}

main $@
