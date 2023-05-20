#!/bin/bash
#记录文件的删除操作

removelog="/tmp/remove.log"

if [ $# -eq 0 ];then
    echo "Usage: $0 [-s] list files or directories" >&2
    exit 1
fi

if [ "$1" = "-s" ];then
    #不记录删除操作
    shift
else
    echo "$(date):${USER}: $@" >> $removelog
fi
rm "$@"
exit 0


