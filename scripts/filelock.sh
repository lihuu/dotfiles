#!/bin/bash

# filelock -- 一种灵活的文件锁定机制。
retries="10"            # 默认的重试次数。   
action="lock"           # 默认操作。   
nullcmd="'which true'"  # 用于锁文件的空命令。

# lur:  r:表示可以赋值的参数

while getopts "lur:" opt;do
    case $opt in
        l) action="lock" ;;
        u) action="unlock" ;;
        r) retries="$OPTARG" ;;
    esac
done

#OPTIND 由getopts设置，它可以让脚本在处理完所有选项之后向左移动参数值（例如使$2变成$1）。
shift $(($OPTIND - 1))
if [ $# -eq 0 ] ; then      # 向stdout输出一条包含多行信息的错误信息。     
    cat <<EOF >&2   
Usage: $0 [-l|-u] [-r retries] LOCKFILE   
Where -l request a locak , -u request an unlock , -r X specifies a max number of retries before it failes 
EOF

exit 1

fi

if [ -z "$(which lockfile|grep -v '^no')" ];then
    echo "$0 failed: 'lockfile' utility not found in path." >&2
    exit 1
fi

if [ "$action" = "lock" ];then
    if ! lockfile -1 -r $retries "$1" 2> /dev/null; then
        echo "$0: Failed: Couldn't create lockfile in time." >&2       exit 1     
    fi
else
    if [ ! -f "$1" ];then
        echo "$0: Warning: lockfile $1 does not exist to unlock." >&2
        exit 1
    fi
    rm -f "$1"
fi
exit 0

