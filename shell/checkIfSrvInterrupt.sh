#!/bin/bash
# to test if server restart or not

help()
{
    echo "===================="
    echo -e "\$$0 &"
    echo -e "\$disown"
    echo "===================="
}


main()
{
    while [ 1 ]; 
    do
        log="log_$(date +%y%m%d)"
        date >> $log
        sleep 60
    done
    
}

help $@

main
