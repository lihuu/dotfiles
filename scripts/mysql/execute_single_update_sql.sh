#!/bin/bash
#多个sql 语句执行的情况
current_dir=$(cd `dirname $0`;pwd)
start_time=`date +%s%3N`
mysql -uroot -proot -e "use test;update t1 set c2=10 where c1<1000;"
end_time=`date +%s%3N`
echo "total time: $(($end_time-$start_time)) ms"
