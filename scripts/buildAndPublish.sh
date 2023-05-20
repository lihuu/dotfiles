#!/bin/bash
# 项目部署脚本
while getopts "h:" opt;do
    case $opt in
        h) host=$OPTARG ;;
        *) host="dev" ;;
    esac
done

if [ -z "$host" ];then
    host="dev"
fi

echo "Using host: $host"

yarn build

if [ -e "editor.tar" ];then
    echo "Remove old file"
	rm editor.tar
fi

if [ -e "build" ];then
    echo "Start to create tar file"
	tar -cf editor.tar build/
fi

if ! ssh $host test -e ~/deploy/editor ;then
    echo "Target directory does not exit, will create it firstly"
    ssh $host mkdir -p ~/deploy/editor
fi

scp ./editor.tar $host:~/deploy/editor
scp ./deploy.sh $host:~/deploy/editor
ssh $host "~/deploy/editor/deploy.sh"










