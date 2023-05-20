#!/bin/bash
#run on Linux only
DIR_NAME=`dirname "${BASH_SOURCE[0]}"`
DIR_HOME=`cd ${DIR_NAME}>/dev/null;pwd`
echo $DIR_HOME

docker run --name my-mysql -p 3307:3306 -v $DIR_HOME/config:/etc/mysql/conf.d -v $DIR_HOME/data:/var/lib/mysql -e MYSQL_ROOT_PASSWORD=root -d mysql:5.7

