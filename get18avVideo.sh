#!/bin/bash

#todo download album
#todo save url serial as path
#todo downloading filename should be xxx.downloading
#todo only two files are downloading at the same time
#todo daily download latest video

# feature:
# curl continue download when terminate => curl -C

set -e

URL=$1
htmlFileName=$(echo $URL | sed "s/.*\///g" )
subFolder=$(echo $htmlFileName | sed "s/.html//g" )
metadataFolder=metadata/video
downloadFolder=18avVideo/$subFolder
htmlFile=$metadataFolder/$htmlFileName

mkdir -p $metadataFolder
mkdir -p $downloadFolder

if [ ! -f $htmlFile ]; then
	cd $metadataFolder
	curl $URL -o $htmlFileName
	cd -
fi


videoTitle=$(cat $htmlFile | grep "影片名稱" | sed "s/<br>/\n/g" | grep "影片名稱" | sed "s/.*>//g")
videoPreviewImages=$(cat $htmlFile | grep "影片名稱" | sed "s/<br>/\n/g"  | sed "s/http:/\nhttp:/g" | sed "s/jpg.*/jpg/g" | grep http | grep jpg | xargs)
echo title=$videoTitle
EmbedVideoWenList=$(cat $htmlFile | grep embed | sed "s/http/\nhttp/g" | sed "s/\".*//g" | grep embed | grep youjizz | xargs)
echo $EmbedVideoWenList
declare -i index=0

for ImageUrl in $videoPreviewImages; do
	filename=$(echo $ImageUrl | sed "s/.*\///g" )
	ImageFile=$downloadFolder/$filename
	if [ ! -f "$ImageFile" ]; then
		cd $downloadFolder
		curl -O $ImageUrl > /dev/null 2>&1 &
		sleep 0.5
		cd -
	fi 
done

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
		curl $videoUrl -o "$filename_downloading"
		mv "$filename_downloading" "$filename"
		cd -
	else
		echo "already download $filename"
	fi 
done