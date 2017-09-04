#!/bin/bash

#todo download album
#todo save url serial as path
#todo downloading filename should be xxx.downloading
#todo curl continue download when terminate => curl -C
#todo only two files are downloading at the same time
#todo daily download latest video


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
	filename="$videoTitle $index.mp4"
	videoFile=$downloadFolder/$filename
	echo filename=$filename
	echo embedVideoWeb=$embedVideoWeb
	embedMetafileName=$(echo $embedVideoWeb | sed "s/.*\///g" )
	embedMetafile=$metadataFolder/$embedMetafileName
	if [ ! -f "$videoFile" ]; then
		cd $metadataFolder
		curl $embedVideoWeb -o $embedMetafileName
		cd -
	else
		echo "already download"
		continue
	fi
	videoUrl=https:$(grep mp4 $embedMetafile | sed "s/\,/\n/g" | grep filename | grep -v m3u8 | sed "s/\"/\n/g" | grep mp4 | sed "s/\\\//g")
	echo $videoUrl

	if [ ! -f "$videoFile" ]; then
		cd $downloadFolder
		curl $videoUrl -o "$filename" &
		cd -
	else
		echo "already download $filename"
	fi 
done