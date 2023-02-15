#!/bin/sh
#docker run --name my-mysql -p 3306:3306 --restart always -v c:/mysql/conf/conf.d:/etc/mysql/conf.d -v c:/mysql/data:/var/lib/mysql -e MYSQL_ROOT_PASSWORD=root -d mysql:5.7
docker run --name my-mysql -p 3306:3306 --restart always -e MYSQL_ROOT_PASSWORD=root -d mysql:5.7
