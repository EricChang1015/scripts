#!/bin/bash
# for wget http://18av.mm-cg.com/cg/ pic.
# list of web page exp:Graphis_Special
# curl -i http://18av.mm-cg.com/Graphis_Special.html | grep "\"aRF\"" | sed "s/>/>\\n/g" | grep href | grep cg_ | sed "s/.*http:/http/g" | sed "s/html.*/html/g" | sort -u

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

# param categoryName categoryUrl
checkGetCategoryPhoto()
{
	if [ ! $# -eq 2 ]; then
		echo "param categoryName categoryUrl"
	    return 2
	fi

	if [ ! -f $1 ]; then
		curl -i $2 > $1
	fi 

	CategoryName="$(echo $1 | sed "s/_/ /g" )"
	echo $CategoryName
	declare -a raw=($(grep "\"aRF\"" $1 | sed "s/>/>\\n/g" | grep -E "href.*cg_.*html" -A1  | sed "s/.*http:/http:/g" | sed "s/html.*/html/g" | sed "s/<br>//g" | grep "$CategoryName" -B1 | sed "s/--.*//g" | sed "s/ /_/g"))
	rawLines=${#raw[@]}
	echo rawLines=$rawLines
	for ((i=0 ;i < $rawLines; i+=2)); do
		printf "%s\n" ${raw[i+1]}
	done

	echo -e "\nAre You Sure Download These Photos? (Y/N)"
	read YesOrNot
	if [ $YesOrNot == "Y" ] || [ $YesOrNot == "y" ]; then
		for ((i=0 ;i < $rawLines; i+=2)); do
			folderName=$(echo 18av/${raw[i+1]} | sed "s/_/ /g")
			if [ -d "$folderName" ]; then
				echo "$folderName already download"
			else
				get18avWebPhoto ${raw[i]}
				sleep 30
			fi 
		done
	fi
	
}

getCategoryPhoto()
{
	category=$(curl -i $@ | grep "\"aRF\"" | sed "s/>/>\\n/g" | grep href | grep cg_ | sed "s/.*http:/http:/g" | sed "s/html.*/html/g" | sort -u | xargs)
	for web in $category; do
		get18avWebPhoto $web
		sleep 30
	done
}

showAllCategories()
{
	if [ ! -f allCategories ]; then
		curl -i http://18av.mm-cg.com/cg/ | grep "biaotou" | grep "href" | sed "s/.*http:/http:/g" | sed "s/<.*//g" | sed "s/ /_/g" | sed "s/\">/	/g" > allCategories
	fi 
	declare -a categoryUrl=($(cat allCategories | awk '{print $1}' | xargs))
	declare -a categoryName=($(cat allCategories | awk '{print $2}' | xargs))
	declare -a categoryPicSetNumber=($(cat allCategories | awk '{print $3}' | xargs))
	totalCategoriesNum=${#categoryName[@]}
	printf "|____________________________________________________|\n"
	printf "| %3s | %10s  | %30s |\n" "idx" "TotalSets" "Category"
	printf "|_____|_____________|________________________________|\n"
	for ((i=0 ;i < $totalCategoriesNum; i++)); do
		printf "| %3d | %10s  | %30s |\n" $i ${categoryPicSetNumber[i]}  ${categoryName[i]}
	done
	printf "|____________________________________________________|\n"
	echo "choose index to continue?"
	read chooseIdx
	if [ $chooseIdx -gt 0 ] && [ $chooseIdx -lt $totalCategoriesNum ]; then
		checkGetCategoryPhoto ${categoryName[$chooseIdx]} ${categoryUrl[$chooseIdx]}
		
	else
		echo "input incorrect, plze enter index between \"0 to $(($totalCategoriesNum - 1))\""
	fi 
}


help()
{
	echo "1. Get certain web photos"
	echo -e "$0 http://18av.mm-cg.com/cg_3381.html"
	echo "2. Get all Category photos"
	echo -e "$0 http://18av.mm-cg.com/Graphis_Special.html"
}

main()
{
	if [ $# != 1 ]; then
		help
		showAllCategories
	elif [ ! -z $(echo $@ | grep cg_ ) ]; then
		echo "get $@ photo"
		get18avWebPhoto $@
	else
		echo "get all category photos of $@ photo"
		getCategoryPhoto $@
	fi 
	sleep 60
}

main $@