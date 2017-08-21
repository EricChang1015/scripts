#!/bin/bash
# for wget http://18av.mm-cg.com/cg/ pic.
# list of web page exp:DGC
# curl -i http://18av.mm-cg.com/DGC.html | grep "\"aRF\"" | sed "s/>/>\\n/g" | grep href | grep cg_ | sed "s/.*http:/http/g" | sed "s/html.*/html/g" | sort -u

set -e


get18avWebPhoto()
{
	echo "get $@"
	tempFile=temp$(echo $@ | sed "s/.*\///g" | sed "s/.html//g")
	curl -i $@ | grep -E "<title>|Large_cgurl\[[0-9]+\]" >  $tempFile
	title=$(cat $tempFile | grep "<title>" | sed "s/.*<title>//g" | sed "s/<\/title>.*//g" | sed "s/18av,/18av\//g")
	urlList=$(cat $tempFile | grep -E  Large_cgurl\[[0-9]+\] | grep "\.jpg" | sed "s/.*= \"//g" | sed "s/\".*//g")
	if [ -d "$title" ]; then
		rm $tempFile
		echo "$title already download"
		return 
	fi
	mkdir -p "$title"
	rm $tempFile
	cd "$title"
	for url in $urlList; do
		#echo $url
		curl -O $url  > /dev/null 2>&1 &
		#echo $url done
	done
	echo "$title download"
	cd -

}

getCategoryPhoto()
{
	category=$(curl -i $@ | grep "\"aRF\"" | sed "s/>/>\\n/g" | grep href | grep cg_ | sed "s/.*http:/http:/g" | sed "s/html.*/html/g" | sort -u | xargs)
	for web in $category; do
		get18avWebPhoto $web
		sleep 30
	done
}

help()
{
	echo "1. Get certain web photos"
	echo -e "$0 http://18av.mm-cg.com/cg_3381.html"
	echo "2. Get all Category photos"
	echo -e "$0 http://18av.mm-cg.com/DGC.html"
}

main()
{
	if [ $# != 1 ]; then
		help
		return 
	fi
	if [ ! -z $(echo $@ | grep cg_ ) ]; then
		echo "get $@ photo"
		get18avWebPhoto $@
	else
		echo "get all category photos of $@ photo"
		getCategoryPhoto $@
	fi 
}

main $@