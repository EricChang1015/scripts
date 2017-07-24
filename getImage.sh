#!/bin/bash
# for wget aitaotu pic.
set -e

main()
{

declare -i error_number=0
urlFolderPath=$(echo $@ | sed -E "s/[0-9]+.jpg//g")
subfolder=$(echo $urlFolderPath | sed -E "s/.*:[0-9]+\///g" )
mkdir -p $subfolder
cd $subfolder

for ((i=9; i<1000; i++)); do
   pic=$i.jpg
   if [ $i -lt 10 ]; then
      pic=0$i.jpg
   fi
   curl -O $urlFolderPath$pic  > /dev/null 2>&1
   size=$(du $pic | sed -E "s/\t.*//g" )
   echo size=$size
   if [ $size -lt 10 ]; then
       rm $pic
       error_number=$error_number+1
   fi
   echo error_number=$error_number
   if [ $error_number -gt 10 ]; then
       exit 1
   fi
done
}

main $@
