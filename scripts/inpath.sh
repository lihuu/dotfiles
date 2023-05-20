#!/bin/bash

in_path(){
    cmd=$1 
    ourpath=$2
    result=1
    oldIFS=$IFS
    IFS=":"
    for directory in $ourpath
    do
        if [ -x $directory/$cmd ];then
            result=0 #表示已经找到了该命令
        fi
    done

    IFS=$oldIFS
    return $result
}

check_for_cmd_in_path(){
    var=$1
    if [ "$var" != "" ];then
        if [ "${var:0:1}" = "/" ];then
            # 字符串切割
            if [ ! -x $var ];then
                return 1
            fi
        elif  ! in_path "${var}" "$PATH" ;then
            return  2
        fi
    fi
}


if [ $# -ne 1 ];then
    echo "Usage: $0 command" >&2
    exit 1
fi

check_for_cmd_in_path "$1"

case $? in 
    0) echo "$1 found in PATH" ;;
    2) echo "$1 not found or not executable" ;;
    2) echo  "$1 not found in PATH" ;;
esac
exit 0











