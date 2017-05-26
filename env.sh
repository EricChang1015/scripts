# !/bin/bash

git config --global alias.co checkout
git config --global alias.st status
git config --global alias.br branch
git config --global user.email eric.chang.1015@gmail.com
git config --global user.name eric.chang


surveillance_detail_hint="more detail plz install htop, it's very good tool."
DISK_ALERT_THRESHOLD=85
export HISTTIMEFORMAT='%F %T ' 

function install_gadget()
{
	sudo apt-get install tree
	sudo apt-get install htop
}

function docker_cleanup()
{
	docker rm -v $(docker ps -a -q -f status=exited)
	docker rmi $(docker images -f "dangling=true" -q)
	docker run -v /var/run/docker.sock:/var/run/docker.sock -v /var/lib/docker:/var/lib/docker --rm martin/docker-cleanup-volumes
}

function directory_tree()
{
	echo "sudo apt-get install tree; tree -d"
	tree -d
	pwd;find . -type d -print 2>/dev/null|awk '!/\.$/ {for (i=1;i<NF-1;i++){printf("│   ")}print "├── "$NF}'  FS='/'
}

function surveillance_summary()
{
	echo -en "\ec"
	cpu_usage
	memory_usage
	disk_usage
	echo $surveillance_detail_hint
}

function cpu_usage()
{
	top -bn1 | grep load | awk '{printf "CPU Load: %.2f\n", $(NF-2)}'
}

function memory_usage()
{
	free | grep "available" > /dev/null
	if [ $? = 0 ] && [ 7 = $(free -m | awk 'NR==2'  | wc -w ) ]; then
			free -m | awk 'NR==2{printf "Memory Usage: %s/%sMB (%.2f%%)\n", ($2 - $7),$2,($2 - $7)*100/$2 }'
	elif [ 0 != $(free -m | awk 'NR==2{printf ($3+$4)}'  )  ]; then
			free -m | awk 'NR==3{printf "Memory Usage: %s/%sMB (%.2f%%)\n", $3,($3+$4),$3*100/($3+$4) }'
	else
			free -m | awk 'NR==2{printf "Memory Usage: %s/%sMB (%.2f%%)\n", $3,$2,$3*100/$2 }'
	fi
}

function disk_usage()
{
	df / | grep / | awk '{ print"Disk Usage:" $5}'
}

function GrepColor()
{
    ParaNum=$#                                    
    if [ $ParaNum -gt 0 ]; then
        if [ $1 -eq 1 ]; then
            export GREP_COLOR='01;31' #red
        elif [ $1 -eq 2 ]; then
            export GREP_COLOR='01;32' #green
        elif [ $1 -eq 3 ]; then
            export GREP_COLOR='01;33' #yellpw
        elif [ $1 -eq 4 ]; then 
            export GREP_COLOR='01;35' #pink
        elif [ $1 -eq 5 ]; then
            export GREP_COLOR='01;36' #light blue
        fi
    fi  
}   

function changeColor()
{
    colorNum=$(($(($colorNum + 1)) % 5))
    GrepColor $(($colorNum + 1))
}   

function ffind()
{
    find . -name .repo -prune -o -name .git -prune -o  -name .svn -prune -o -type f -name "*\.*" -print0 | xargs -0 grep --color -n "$@"
}

function jgrep()
{
    find . -name .repo -prune -o -name .git -prune -o  -name .svn -prune -o -type f -name "*\.java" -print0 | xargs -0 grep --color -n "$@"
}
function cgrep()
{
    find . -name .repo -prune -o -name .git -prune -o -name .svn -prune -o  -type f \( -name '*.c' -o -name '*.cc' -o -name '*.cpp' -o -name '*.h' \) -print0 | xargs -0 grep --color -n "$@"
}
function resgrep()
{
    for dir in `find . -name .repo -prune -o -name .git -prune -o -name res -type d`; do find $dir -type f -name '*\.xml' -print0 | xargs -0 grep --color -n "$@"; done;
}
function mangrep()
{
    find . -name .repo -prune -o -name .git -prune -o -path ./out -prune -o -type f -name 'AndroidManifest.xml' -print0 | xargs -0 grep --color -n "$@"
}
function sepgrep()
{
    find . -name .repo -prune -o -name .git -prune -o -path ./out -prune -o -name sepolicy -type d -print0 | xargs -0 grep --color -n -r --exclude-dir=\.git "$@"
}

#function check_disk_usage()
#{
#	CURRENT=$(df / | grep / | awk '{ print $5}' | sed 's/%//g')
#	if [ "$CURRENT" -gt "$DISK_ALERT_THRESHOLD" ] ; then
#		mail -s 'Disk Space Alert' eric.chang@aspectgaming.com << EOF
#	Your root partition remaining free space is critically low. Used: $CURRENT%
#	EOF
#	fi
#}

