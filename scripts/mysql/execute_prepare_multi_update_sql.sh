#!/bin/bash
#多个sql 语句执行的情况
user="root"
password="root"
while getopts "u:p:" opt;do
    case $opt in 
        u) user="$OPTARG" ;;
        p) password="$OPTARG" ;;
    esac
done
current_dir=$(cd `dirname $0`;pwd)
start_time=`date +%s%3N`
mysql -u$user -p$password -e "use test;source ${current_dir}/prepare.sql;"
end_time=`date +%s%3N`
echo "total time: $(($end_time-$start_time)) ms"
