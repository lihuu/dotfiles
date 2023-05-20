#!/bin/bash
source ~/.bashrc
shopt -s expand_aliases

host="DEV/AAA"

#if [ "$host" = "DEV" ];then
#    echo "Dev host"
#fi

#打印第一个参数
#echo $1
#相当于移除第一个参数
#shift
#打印移位之后的第一个参数，也就是之前的第二个参数
#echo $1
#echo $#
#echo "$@"
#echo "${hots%*A}"
#echo "${host%${host#?}}"

echo "${host#?}"|tr '[[:upper:]]' '[[:lower:]]'

aa="AAA"

echo "${aa#?}"

if [ "$(uname)" == "Darwin" ];then
    echo "Darwin"
else
    echo "Other platform"
fi



PID=`ps -ef|grep java|awk '{print $2}'|head -1`

echo "The pid is: $PID"


NEW_PID=$(ps -ef|grep java|awk '{print $2}'|head -1)

echo "The new pid is: $NEW_PID"


if [ -z "$NEW_PID" ];then
    echo "The pid not exit"
fi


