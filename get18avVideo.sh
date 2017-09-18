#!/bin/bash

#todo daily download latest video

# feature:
# 09/17: add download list and check if force download or not.
# 09/18: curl continue download when terminate => curl -C (test fail)

#set -e

forceDownload='n'
verbose='n'

LOG="/dev/null"
C_BG_RED="\e[41m"
C_RED="\e[91m"
C_GREEN="\e[92m"
C_YELLOW="\e[93m"
C_RESET="\e[0m"

ERROR_NONE=0
ERROR_INVALID_SOURCE=1
ERROR_ALREADY_DOWNLOAD=2
ERROR_INVALID_TITLE=3


downloadTo=18avVideo
downloadList=$downloadTo/list.csv
downloadtemp=$downloadTo/temp
metadataFolder=$downloadTo/metadata/video

main()
{
	if [ $# -eq 0 ]; then
		show_help
		return
	fi
	parseParameters $@
	for source in $@; do
		execute preSetting $source       || continue
		execute getWebInfo               || return $?
		execute getVideoTitle            || return $?
		execute downloadPreviewImages    || return $?
		execute downloadVideo            || return $?
	done
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

function parseParameters()
{
	echo $@
	while getopts "h?vfv?h:" opt; do
	echo $opt
		case "$opt" in
		h|\?)
			show_help
			exit 0
			;;
		v)
			set -x
			verbose='y'
			echo verbose
			;;
		f)
			forceDownload='y'
			echo force 
			;;
		esac
	done
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
	#TODO: if subFolder in $downloadList
	if [ "$forceDownload" == 'n' ]; then
		cat $downloadList | awk '{print $1}' | grep $subFolder
		if [ $? -eq 0 ]; then
			echo "already download $(cat $downloadList | grep $subFolder)"
			return $ERROR_ALREADY_DOWNLOAD
		fi
	fi
	downloadFolder=$downloadTo/$subFolder
	htmlFile=$metadataFolder/$htmlFileName
	mkdir -p $metadataFolder
	mkdir -p $downloadFolder
}

function getWebInfo(){
	if [ ! -f $htmlFile ]; then
		cd $metadataFolder
		curl $URL -o $htmlFileName
		cd - > /dev/null
	fi
}

function getVideoTitle()
{
	videoTitle=$(cat $htmlFile | grep "影片名稱" | sed "s/<br>/\n/g" | grep "影片名稱" | sed "s/.*>//g" | sed "s/,/ /g")
	echo "$subFolder , $videoTitle" > $downloadtemp
	cat $downloadList >> $downloadtemp
	cat $downloadtemp | sort -u > $downloadList
	echo title=$videoTitle
	if [ ! -z $title ]; then
		rm $htmlFile
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

function downloadVideo()
{
	EmbedVideoWenList=$(cat $htmlFile | grep embed | sed "s/http/\nhttp/g" | sed "s/\".*//g" | grep embed | grep youjizz | xargs)
	echo $EmbedVideoWenList
	declare -i index=0
	for embedVideoWeb in $EmbedVideoWenList; do
		index+=1
		filename="$videoTitle $index.mp4"
		filename_downloading="$videoTitle $index.mp4.download"
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
		videoUrl=https:$(grep mp4 $embedMetafile | sed "s/\,/\n/g" | grep filename | grep -v m3u8 | sed "s/\"/\n/g" | grep mp4 | sed "s/\\\//g" | sort | head -1)
		echo $videoUrl
		if [ "$videoUrl" == "https:" ]; then
			echo "cann't resolve videoUrl of $filename"
			continue
		fi 
		echo "$videoFile_downloading"
		if [ -f "$videoFile_downloading" ] ; then
			echo "continue download $videoFile_downloading"
			offsetBytes=$(ls "$videoFile_downloading" -l | awk '{print $5}')
			cd $downloadFolder
			curl -L -C - $videoUrl -o "$filename_downloading"
			mv "$filename_downloading" "$filename"
			cd - > /dev/null
		elif [ ! -f "$videoFile" ]; then
			cd $downloadFolder
			curl -L $videoUrl -o "$filename_downloading"
			mv "$filename_downloading" "$filename"
			cd - > /dev/null
		else
			echo "already download $filename"
		fi 
	done
}

main $@
