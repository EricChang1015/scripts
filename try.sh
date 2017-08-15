#!/bin/bash
#
baseUrl="https://img.aitaotu.cc:8089/Pics"

tryByDay()
{
	declare -i error_number=0
	day=$1
	for (( folderIdx=1; folderIdx < 50; folderIdx++)); do
		folderName=$folderIdx
		if [ $folderIdx -lt 10 ]; then
		folderName=0$folderIdx
		fi
		recordDate=$(date +%Y/%m%d -d "$day day ago")
		recordDate2=$(date +%Y%m%d -d "$day day ago")
		subfolder=$recordDate/$folderName
		mkdir -p report
		reportfile="report/report.$recordDate2.txt"
		echo ./getImage.sh $baseUrl/$subfolder/01.jpg
		./getImage.sh $baseUrl/$subfolder/01.jpg
		if [ $? -eq 1 ]; then
			error_number=$error_number+1
			echo $subfolder fail 
		else
			echo $subfolder ok | tee -a $reportfile
			error_number=0
		fi
		if [ $error_number -gt 15 ];then
		echo $recordDate done | tee -a $reportfile | tee -a report.txt
			break;
		fi
	done
}


main()
{

	for (( day=112; day<120 ;day++ )); do
		tryByDay $day &
	done

}

main
