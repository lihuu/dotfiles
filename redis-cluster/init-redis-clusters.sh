#!/bin/sh

address=$(docker network inspect redis-cluster-net | jq '.[0].Containers.[]|((.IPv4Address|split("/")[0])+":"+(.Name|split("-")[1]))' | sed "s/\"//g")

result=""
for VER in $address; do
  result="$result$VER "
done

command="redis-cli --cluster-yes --cluster create $result --cluster-replicas 1"

echo $command

docker exec redis-7001 $command
