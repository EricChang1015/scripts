#!/bin/bash
# for wget aitaotu pic.
set -e

main()
{
    echo $@
	declare -i error_number=0
	urlFolderPath=$(echo $@ | sed -E "s/[0-9]+.jpg//g")
	subfolder=$(echo $urlFolderPath | sed -E "s/.*:[0-9]+\///g" )
	folderStatus=$(./checkIfEmptyFolder.sh $subfolder)

	if [ "$folderStatus" == "1" ];then
	    mkdir -p $subfolder
	elif [ "$folderStatus" == "0" ];then
	    return 2
	elif [ "$folderStatus" == "2" ]; then
		return 1
	fi
	cd $subfolder
	for ((i=1; i<1000; i++)); do
	   pic=$i.jpg
	   if [ $i -lt 10 ]; then
		  pic=0$i.jpg
	   fi

	   curl -O $urlFolderPath$pic  > /dev/null 2>&1
	   size=$(du $pic | sed -E "s/\t.*//g" )
	   #echo size=$size
	   if [ $size -lt 10 ]; then
		   rm $pic
		   error_number=$error_number+1
		   echo -n "$pic(x) "
	   else
	       error_number=0
		   echo -n "$pic(o) "
	   fi
	   #echo -e "error_num=$error_number"

	   if [ $i -eq 2 ] && [ $error_number -eq 2 ]  ; then
	       cd -
		   echo "$urlFolderPath not exist resource"
		   exit 1
	   fi
	   if [ $error_number -gt 5 ]; then
           echo "done $urlFolderPath"
		   exit 2
	   fi
	done
}

main $@
