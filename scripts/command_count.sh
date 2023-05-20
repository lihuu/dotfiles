#!/bin/bash
#统计当前PATH中有多少可以执行的命令
#IFS Input Field Separators
IFS=":"
count=0
nonex=0

for directory in $PATH;do
    if [ -d $directory ];then
        for com in "$directory"/*;do
            if [ -x "$com" ];then 
                count="$(($count + 1))"
            else
                nonex="$(($nonex + 1))"
            fi
        done
    fi
done

echo "$count commands, and $nonex entries that weren't executable"
exit 0








