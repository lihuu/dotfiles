#!/bin/sh
echo "Will stop these containers"
docker stop redis-7001
docker stop redis-7002
docker stop redis-7003
docker stop redis-7004
docker stop redis-7005
docker stop redis-7006
echo "Done"
echo "Will remove these containers"
docker rm redis-7001
docker rm redis-7002
docker rm redis-7003
docker rm redis-7004
docker rm redis-7005
docker rm redis-7006
echo "Done"
