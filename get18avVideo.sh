#!/bin/bash

#todo download album
#todo save url serial as path
#todo downloading filename should be xxx.downloading
#todo only two files are downloading at the same time
#todo daily download latest video

# feature:
# curl continue download when terminate => curl -C

set -e

LOG="/dev/null"
C_BG_RED="\e[41m"
C_RED="\e[91m"
C_GREEN="\e[92m"
C_YELLOW="\e[93m"
C_RESET="\e[0m"

ERROR_INVALID_SOURCE=1
ERROR_INVALID_TITLE=2

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
		execute preSetting $source       || return $?
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
        exit
    else
        echo -e $C_YELLOW"[Success] $@"$C_RESET | tee -a $LOG
    fi
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

function show_help()
{
	echo -e "${C_YELLOW}=============<<<HELP>>>=================${C_RESET}"
	echo -e "${C_YELLOW}This bash script help you to download   ${C_RESET}"
	echo -e "${C_YELLOW}video from http://18av.mm-cg.com        ${C_RESET}"
	echo -e "${C_YELLOW}========================================${C_RESET}"
	echo -e "=            How to use                ="
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
			sleep 0.1
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
		if [ ! -f "$videoFile" ] && [ ! -f "$videoFile_downloading" ] ; then
			cd $metadataFolder
			curl $embedVideoWeb -o $embedMetafileName
			cd -
		else
			echo "already download $videoFile"
			continue
		fi
		videoUrl=https:$(grep mp4 $embedMetafile | sed "s/\,/\n/g" | grep filename | grep -v m3u8 | sed "s/\"/\n/g" | grep mp4 | sed "s/\\\//g" | head -1)
		echo $videoUrl
		if [ -z $videoUrl ]; then
			echo "cann't resolve videoUrl of $filename"
			continue
		fi 
		if [ ! -f "$videoFile" ]; then
			cd $downloadFolder
			curl $videoUrl -o "$filename"
			#mv "$filename_downloading" "$filename"
			cd -
		else
			echo "already download $filename"
		fi 
	done
}

main $@
