#!/bin/bash
#在指定的目录中创建备份

if [ -z "$1" ];then
    echo "Usage: $0 target store" >&2
    exit 1
fi

BACKUP_DIR=~/.backup
if [ ! -z "$2" ];then
    BACKUP_DIR=$2
fi

if [ ! -e "$BACKUP_DIR" ];then
    mkdir -p $BACKUP_DIR
fi

if [ -d "$1" ];then
    cp -r $1 $BACKUP_DIR
    exit 0
fi

if [ -f "$1" ];then
    cp $1 $BACKUP_DIR
    exit 0
fi

echo "Invalid file type, file and directory only"
exit 1

