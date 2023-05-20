#!/bin/bash
#获取执行的脚本所在的目录
echo "${BASH_SOURCE[*]}"
echo "${BASH_SOURCE-$0}"
echo "${BASH_SOURCE}"
DIR_NAME=`dirname "${BASH_SOURCE[0]}"`
APP_HOME=`cd "${DIR_NAME}" >/dev/null;pwd`

echo $APP_HOME



