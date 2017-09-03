#!/bin/bash

set -e

URL=$1
metadataFolder=metadata/video
downloadFolder=18avVideo
htmlFileName=$(echo $URL | sed "s/.*\///g" )
htmlFile=$metadataFolder/$htmlFileName

mkdir -p $metadataFolder
mkdir -p $downloadFolder

if [ ! -f $htmlFile ]; then
	cd $metadataFolder
	curl $URL -o $htmlFileName
	cd -
fi


videoTitle=$(cat $htmlFile | grep "影片名稱" | sed "s/<br>/\n/g" | grep "影片名稱" | sed "s/.*>//g")
echo title=$videoTitle
EmbedVideoWenList=$(cat $htmlFile | grep embed | sed "s/http/\nhttp/g" | sed "s/\".*//g" | grep embed | grep youjizz | xargs)
echo $EmbedVideoWenList
declare -i index=0
for embedVideoWeb in $EmbedVideoWenList; do
	index+=1
	echo $embedVideoWeb
	embedMetafileName=$(echo $embedVideoWeb | sed "s/.*\///g" )
	embedMetafile=$metadataFolder/$embedMetafileName
	if [ ! -f $embedMetafile ]; then
		cd $metadataFolder
		curl $embedVideoWeb -o $embedMetafileName
		cd -
	else
		echo "already download"
		continue
		echo "fail"
	fi
	videoUrl=https:$(grep mp4 $embedMetafile | sed "s/\,/\n/g" | grep filename | grep -v m3u8 | sed "s/\"/\n/g" | grep mp4 | sed "s/\\\//g")
	echo $videoUrl
	cd $downloadFolder
	filename="$videoTitle $index.mp4"
	echo $filename
	if [ ! -f $filename ]; then
		curl $videoUrl -o "$filename" &
	else
		echo "already download $filename"
	fi 
	cd -
done