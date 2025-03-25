#!/bin/sh

NETWORK_NAME="redis-cluster-net"

# 检查网络是否存在
if docker network ls --filter "name=$NETWORK_NAME" --format "{{.ID}}" >/dev/null 2>&1; then
  echo "网络 '$NETWORK_NAME' 已存在。"
else
  echo "网络 '$NETWORK_NAME' 不存在，正在创建..."
  docker network create "$NETWORK_NAME"
  echo "网络 '$NETWORK_NAME' 创建成功。"
fi

for port in $(seq 7001 7006); do
  docker run -d --name redis-$port \
    -p $port:$port -p 1$port:1$port \
    -v $(pwd)/$port/redis.conf:/usr/local/etc/redis/redis.conf \
    --net $NETWORK_NAME \
    redis:7 \
    redis-server /usr/local/etc/redis/redis.conf
done
