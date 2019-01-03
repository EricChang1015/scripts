#!/bin/bash

# This bash script is used to help men's mental health, download healthy video from 18av.mm-cg.com.
# hope you will like it.
# 2018/05/26:

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
bashScriptName=$(echo $0 | sed "s/.*\///g")
downloadtemp=${downloadTo}/temp.${bashScriptName}
prefix_goingList=goingList
goingList=${prefix_goingList}.${bashScriptName}.txt
ongoingList=ongoingList.${bashScriptName}.txt
prefix_downloadGoingList=${downloadTo}/${prefix_goingList}
downloadGoingList=${downloadTo}/${goingList}
downloadOngoingList=${downloadTo}/${ongoingList}
downloadOngoingListPattern="${downloadTo}/*goingList.*"
downloadListPattern="${downloadTo}/list*.csv"
downloadList=${downloadTo}/list.$(date +%Y%m%d-%H%M).csv
metadataFolder=${downloadTo}/metadata/video
newsFolder=${downloadTo}/news
searchFolder=${downloadTo}/search
lock=${downloadTo}/lock
fftemp=.fftemp


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
    if [ $# -eq 0 ] && [ ! -f ${downloadOngoingList} ]; then
        show_help
        return
    fi
    mkdir -p ${downloadTo}
    parseParameters $@
    echo $@ | sed "s/ /\n/g" | sort -u | sed '/^\s*$/d' | grep -v "-" >> ${downloadOngoingList}
    if [ ! -f ${downloadGoingList} ]; then
        while [ $(wc -l ${downloadOngoingList} | awk '{print $1}') -gt 0 ]; do
            source=$(head -n1 ${downloadOngoingList})
            sed -i '1d' ${downloadOngoingList}
            execute preSetting ${source}       || continue
            echo ${source} > ${downloadGoingList}
            execute getWebInfo               || return $?
            execute getVideoTitle            || return $?
            execute downloadPreviewImages    || return $?
            execute downloadVideo            || return $?
            echo left $(wc -l ${downloadOngoingList} | awk '{print $1}') tasks
        done
        rm -rf ${downloadGoingList}
        rm -rf ${downloadOngoingList}
    fi
}

function execute()
{
    echo -e ${C_GREEN}"[Process] $@"${C_RESET} | tee -a $LOG
    echo $@
    $@
    result=$?
    if [ ! 0 -eq $result ]; then
        echo -e ${C_RED}"[Fail] $@"${C_RESET} | tee -a $LOG
        return $result
    else
        echo -e ${C_YELLOW}"[Success] $@"${C_RESET} | tee -a $LOG
    fi
}

#Note: use ":"and "$OPTARG" to argument
function parseParameters()
{
    while getopts "h?valcpd:s:fd:s:pvalc?h:" opt; do
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
            if [ ! -z ${proxy_server} ]; then
                echo -e ${C_YELLOW}"use proxy ${proxy_server}"${C_RESET}
            else
                echo "Please enter proxy info like this format: \${ip}:\${port}"
                echo "You can reference to https://free-proxy-list.net/"
                echo "Or use Ctrl+C to exit"
                echo ":"
                read -t 120 input
                proxy_server=${input}
                sed "s/^proxy_server=.*/proxy_server=\"${proxy_server}\"/g" $0 -i
            fi
            ;;
        a)
            showActress
	        exit 0
            ;;
        l)
            showOngoing
	        exit 0
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
        s)
            if [ ! -z $OPTARG ]; then
                keyword=$OPTARG
            fi
                searchVideo $keyword
                exit 0
            ;;
        esac
    done
}

function showOngoing()
{
    if [ -f ${downloadGoingList} ]; then
        echo these ID are downloading: $(cat ${downloadGoingList} | xargs)
        ls -lht ${downloadTo}/$(cat ${downloadGoingList} | head -n1 | awk '{print $1}')/*.mp4*
    fi
    if [ -f ${downloadOngoingList} ] && [ $(cat ${downloadOngoingList} | wc -w ) -ge 1 ]; then
        echo these ID are pending to download: $(cat ${downloadOngoingList} | xargs)
    fi
    otherList=$(ls $(echo ${downloadGoingList} ${downloadOngoingList} | sed "s/${bashScriptName}/\*/g") 2>/dev/null \
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
        if [ $TbfFolder == "q" ]; then
            break
        fi
        if [ ! -z ${TbfFolder} ] && [ -d ${downloadTo}/${TbfFolder} ]; then
           echo "enter file index number:"
           read -t 30 TbfIndex
           if [ $TbfIndex == "q" ]; then
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

function downloadFromHtmlFile()
{
    HtmlFile=$1
    
    cat ${HtmlFile} | grep "18av.mm-cg.com\/18av" | sed "s/.*\/18av\///g" | sed "s/.html.*src=\"/ , ifdownloadorNot , /g" | sed "s/jpg\".*alt=/jpg ,/g" | sed "s/jizcg.*//g" > ${downloadtemp}
    fileListInHtml=$(cat ${downloadtemp} | sed "s/ .*//g")
    echo -e "Index,\tSerial,     Status,                                              URL , Title"
    index=1
    for fileNumber in ${fileListInHtml}; do
        grep -E "^${fileNumber} " ${downloadListPattern} >> /dev/null
        if [ $? -eq 0 ]; then
            state=O
        else
            grep -E "^${fileNumber}" ${downloadOngoingListPattern} >> /dev/null
            if [ $? -eq 0 ]; then
                state=P
            else
                state=-
            fi
            
        fi
        grep $fileNumber ${downloadtemp} | sed -E "s/ifdownloadorNot/\t${state}/g" | sed -E "s/^/${index},\t/g"
        index=$(($index+1))
    done
    echo "open in browser? (Y/N) or enter index to download index (1-$(cat ${downloadtemp} | wc -l))"
    read -t 30 input
    downloadIndexSet=$(echo ${input} | grep -E "[0-9\ ]+" -o | sed "s/ /\n/g" | sort -u | xargs)
    isPending=$(echo ${input} | grep -i -o "p")
    downloadNumbers=$(echo ${downloadIndexSet} | wc -w)
    echo ${downloadNumbers}
    if [ ${downloadNumbers} -ge 1 ]; then
        for index in ${downloadIndexSet} ; do
            downloadId=$(cat ${downloadtemp} | grep -E "^[0-9]+" -o | sed -n ${index}p)
            echo "put $downloadId in ${downloadOngoingList}"
            echo ${downloadId} >> ${downloadOngoingList}
        done
        if [ "${isPending}" == 'P' ] || [ "${isPending}" == 'p' ]; then
            exit
        fi
    elif [ "${input}" == 'Y' ] || [ "${input}" == 'y' ]; then
        start chrome --incognito ${HtmlFile}
        exit
    else
        exit
    fi
}

function downloadDailyNews()
{
    targetDate=$(date +%Y-%m-%d -d "$1 days ago")
    dailyNewsURL=http://18av.mm-cg.com/news/${targetDate}.html
    echo "==== ${targetDate} ===="
    mkdir -p ${newsFolder}
    if [ ! -f ${newsFolder}/${targetDate}.html ]; then
        myCurl ${dailyNewsURL} | grep "影片區" | sed "s/<li/\n<li/g" | sed "s/<a class/\n<a class/g" | sed "s/<\/a>/<\/a>\n/g" > ${newsFolder}/${targetDate}.html
    fi
    downloadFromHtmlFile ${newsFolder}/${targetDate}.html
}

urlencode() {
  local length="${#1}"
  for (( i = 0; i < length; i++ )); do
    local c="${1:i:1}"
    case $c in
      [a-zA-Z0-9.~_-]) printf "$c" ;;
    *) printf "$c" | xxd -p -c1 | while read x;do printf "%%%s" "$x";done
  esac
done
}

function searchVideo() {
    #mytitle="%E7%89%87%E6%A1%90%E6%83%A0%E7%90%86%E9%A6%99"
    keyword=$1
    mkdir -p ${searchFolder}
    mytitle=$(urlencode $keyword)
    curl -s 'http://18av.mm-cg.com/serch/18av_serch.html' \
    -H 'Connection: keep-alive' \
    -H 'Pragma: no-cache' \
    -H 'Cache-Control: no-cache' \
    -H 'Origin: http://18av.mm-cg.com' \
    -H 'Upgrade-Insecure-Requests: 1' \
    -H 'Content-Type: application/x-www-form-urlencoded' \
    -H 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/66.0.3359.181 Safari/537.36' \
    -H 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8' \
    -H 'DNT: 1' -H 'Referer: http://18av.mm-cg.com/serch/18av_serch.html' -H 'Accept-Encoding: gzip, deflate' \
    -H 'Accept-Language: zh-TW,zh;q=0.9,en-US;q=0.8,en;q=0.7' \
    -H 'Cookie: __cfduid=d878535628107d75dc203340e717b8b131527255261; UM_distinctid=1639781fb8414b-0e73473b12dc07-737356c-1fa400-1639781fb8613a; CNZZDATA1273380027=1847662170-1527254675-%7C1527254675; HstCfa3035959=1527255270263; HstCmu3035959=1527255270263; HstCnv3035959=1; _ga=GA1.2.1451192212.1527255270; _gid=GA1.2.920867951.1527255270; CNZZDATA1273435591=817788004-1527250483-%7C1527255884; HstCns3035959=2; _gat_gtag_UA_108436699_2=1; _gat_gtag_UA_108436699_1=1; HstCla3035959=1527256990254; HstPn3035959=11; HstPt3035959=11' \
    --data "form_serch_category=form_serch_18av&key_myform=$mytitle&my_button=%E6%90%9C%E5%B0%8B&form_page=1&se_id%5B%5D=%E6%9C%AC%E7%AB%99%E7%B2%BE%E9%81%B8%E5%BD%B1%E7%89%87%E5%88%86%E9%A1%9E" \
    --compressed \
    grep "$keyword" | sed "s/<a class/\n<a class/g" | sed "s/<\/a>/<\/a><br>\n/g" | sed "s/<br>/<br>\n/g" | grep "$keyword"  | grep href   | grep -E "jpg" | grep -v "<\/div>" > ${searchFolder}/"${keyword}.html"
    downloadFromHtmlFile ${searchFolder}/"${keyword}.html"
}


function showName()
{
    declare -i count=0
    for name in $(cat $avnameZh | awk '{print $2}' | grep -v -E "[A-z]+" | grep $@ | xargs); do
        num=$(grep "$name" ${downloadListPattern} | wc -l)
        printf "%3d %s[%2d]\t" $count $name $num
        if [ $(($count%10+1)) -eq 10 ]; then
        echo
        fi
        count=$count+1
done < $avnameZh
 #   done
    echo -e "\n" 
}

function showActress()
{
    avname=${downloadTo}/.avname
	avnameZh=${downloadTo}/.avnameZh
    avnameEng=${downloadTo}/.avnameEng
    sed -E "s/[ ，、。！＆,.-:&0-9]+/\n/g" ${downloadListPattern} | \
    grep -v "^.......*" |\
    grep -v "^$" |\
    grep -v "^.$" |\
    grep -v -E "[0-9]|「|…|】|」|？|,|、|。|～|！|\!|\.|\-|BEST|Sex|SEX|THE|高潮|電|肛|亂|癡|の|我|你|他|她|汗|屁|精|夜|編|熱|戰|姊|妹|兄|弟|服|孕|懷|婦|淫|運|動|噴|吹|護|師|主|侵|秘|的|射|態|婆|中文|碼|字|幕|Hot|老|體|禁|妻|母|人|女|姦|乳|中出|性|姐|貌|篇|褲|娘|使|第|祭|不|^......" | \
    sort | uniq -c | sort -hr  > $avname
	grep -E "[0-9]+ [A-z]+$" $avname | grep -v -E "AV|NO|ANIMATION" > $avnameEng
	grep -v -E "[A-z]+" $avname > $avnameZh

    echo "[5 chars]"
    showName '^.....$'
    echo "[4 chars]"
    showName '^....$'
    echo "[3 chars]"
    showName '^...$'
    echo "[2 chars]"
    showName '^..$'
    echo "[English chars]"
    cat $avnameEng | awk '{print $2}' | xargs
    rm $avname $avnameZh $avnameEng
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
    echo -e "-s \"keyword\": get video list with search keyword"
    echo -e "-a show all actresses in list"
    echo -e "----------------------------------------"
    echo -e "Exp 1. Download with whole URL"
    echo -e "${C_YELLOW}$0 http://18av.mm-cg.com/18av/23623.html ...${C_RESET}"
    echo -e "----------------------------------------"
    echo -e "Exp 2. Download with reference video number"
    echo -e "${C_YELLOW}$0 23623 26437 ... &${C_RESET}"
    echo -e "Exp 3. Keep downloading after logout"
    echo -e "${C_YELLOW}nohup $0 23623 26437 ... &${C_RESET}"
    echo -e "Exp 4. Search AV Girls"
    echo -e "${C_YELLOW}$0 -s 香山美櫻${C_RESET}"
    echo -e "========================================"
}

function preSetting()
{
    source=$1
    checkIfDownloading ${source} || return $ERROR_DOWNLOADING
    testInput="$(echo ${source} | grep html)"
    if [ ! -z $testInput ]; then
        URL=$1
    elif [[ ${source} =~ ^-?[0-9]+$ ]] ;then
        URL="http://18av.mm-cg.com/18av/${source}.html"
    else
        echo "invalid source ${source}"
        return $ERROR_INVALID_SOURCE
    fi

    htmlFileName=$(echo $URL | sed "s/.*\///g" )
    subFolder=$(echo $htmlFileName | sed "s/.html//g" )
    downloadFolder=$downloadTo/$subFolder

    cat $downloadListPattern | awk '{print $1}' | grep $subFolder
    # already download
    if [ $? -eq 0 ]; then
        if [ "$forceDownload" == 'n' ] && [ ! -d ${downloadFolder} ]; then
            echo "already download $(cat $downloadListPattern | grep $subFolder)"
            return $ERROR_ALREADY_DOWNLOAD
        fi
    fi
    htmlFile=${metadataFolder}/$htmlFileName
    mkdir -p ${metadataFolder}
    mkdir -p ${downloadFolder}
}

function testHtml(){
    grep youjizz $htmlFileName > /dev/null
}

function myCurl(){
    if [ "$proxy" == "n" ]; then
        curl -s $@
    else
        curl -s -x ${proxy_server} $@
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
        cd ${metadataFolder}

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
    #videoPreviewImages=$(cat $htmlFile | grep "影片名稱" | sed "s/<br>/\n/g"  | sed "s/http:/\nhttp:/g" | sed "s/jpg.*/jpg/g" | grep http | grep jpg | xargs)
    coverPhoto=$(cat $htmlFile | grep "影片名稱" | sed "s/<br>/\n/g"  | sed "s/http:/\nhttp:/g" | sed "s/jpg.*/jpg/g" | grep http | grep jpg  | grep -v "\-..jpg" | xargs)
    for ImageUrl in $coverPhoto; do
        filename=$(echo $ImageUrl | sed "s/.*\///g" )
        ImageFile=${downloadFolder}/$filename
        if [ ! -f "$ImageFile" ]; then
            cd ${downloadFolder}
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
    echo ${input} | head -c $limitBytes
}

function downloadVideoCommand()
{
    curl -L -C - $videoUrl -o "${filename_downloading}"
}

function isStreamDownloadIncomplete()
{
    streamBitRate=0
    videoTrackBitRate=0
    audioTrackBitRate=0

    if [ ! -z "$(ffprobe -version 2>&1)" ] ; then
OIFS="$IFS"
IFS=$'\n'
        ls $videoFile_downloading
        ffprobe $videoFile_downloading > $fftemp 2>&1 || return 0
        streamBitRate=$(cat $fftemp | grep -E "bitrate:.*kb\/s" -o | sed "s/ kb\/s//g" | sed "s/.* //g")
        videoTrackBitRate=$(cat $fftemp | grep -E "Video.*kb\/s" -o -m1 | sed "s/ kb\/s//g" | sed "s/.* //g")
        audioTrackBitRate=$(cat $fftemp | grep -E "Audio.*kb\/s" -o -m1  | sed  "s/.*, //g" | sed "s/ kb.*//g")
IFS="$OIFS"
        rm $fftemp
        if [ $streamBitRate -lt $(( $videoTrackBitRate + $audioTrackBitRate )) ]; then
            echo -en $C_RED[fail] 
            printf "[s:%5s kb/s : v:%5s kb/s : a:%5s kb/s] " $streamBitRate $videoTrackBitRate $audioTrackBitRate
            echo -e $C_RESET $videoFile_downloading
            echo "retry"
            return 0 #imcompleted
        fi
    fi
    return 1 #completed
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
        sleep 60
        echo "$filename retry $retry time"
        downloadVideoCommand
    done
}

function downloadVideo()
{
    EmbedVideoWenList=$(cat $htmlFile | grep embed | sed "s/http/\nhttp/g" | sed "s/\".*//g" | grep embed | grep youjizz | xargs)
    echo ${EmbedVideoWenList}
    declare -i index=0
    for embedVideoWeb in ${EmbedVideoWenList}; do
        index+=1
        adjustTitle=$(truncateString  "$videoTitle" 240)
        filename="$adjustTitle $index.mp4"
        filename_downloading="$index.mp4.download"
        videoFile=${downloadFolder}/$filename
        videoFile_downloading=${downloadFolder}/${filename_downloading}
        echo filename=$filename
        echo embedVideoWeb=${embedVideoWeb}
        embedMetafileName=$(echo ${embedVideoWeb} | sed "s/.*\///g" )
        embedMetafile=${metadataFolder}/${embedMetafileName}
        if [ ! -f "$videoFile" ]; then
            cd ${metadataFolder}
            curl ${embedVideoWeb} -o ${embedMetafileName}
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
            videoUrl=https:${videoFHD}
        elif [ ! -z "$videoHD" ]; then
            videoUrl=https:${videoHD}
        elif [ ! -z "$videoSD" ]; then
            videoUrl=https:${videoSD}
        elif [ ! -z "$videoUnknown" ]; then
            videoUrl=https:${videoUnknown}
        else
            echo "cann't resolve videoUrl of $filename"
            continue
        fi

        echo "$videoFile_downloading"
        if [ -f "$videoFile_downloading" ] || [ ! -f "$videoFile" ] ; then
            cd ${downloadFolder}
            downloadVideoUntilComplete
            mv "${filename_downloading}" "$filename"
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
    if [ -f ${downloadGoingList} ]; then
        echo "ID $(cat ${downloadGoingList}) are downloading"
        echo "Do you want to stop? (Y/N)"
        read -t 60 input
        if [ ${input} == 'Y' ] || [ ${input} == 'y' ]; then
            cat ${downloadGoingList} >> ${downloadOngoingList}
            rm ${downloadGoingList}
            unlock
            exit 0
        fi
    else
        unlock
        exit 0
    fi
}

main $@
