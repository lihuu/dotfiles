#!/bin/bash
set -e

# 固定 CLUSTER_ID，三个节点必须一致
CLUSTER_ID="my-cluster-id-123456"

# 镜像版本
KAFKA_IMAGE="apache/kafka:3.7.0"

# 创建数据卷
docker volume create kafka1_data
docker volume create kafka2_data
docker volume create kafka3_data

# 创建网络（保证容器间能通过名字通信）
docker network create kafka-net || true
# 通用镜像
KAFKA_IMAGE="apache/kafka:3.7.0"

# 启动 kafka-1
docker run -d --name kafka-1 \
  --network kafka-net \
  -p 9092:9092 \
  -e KAFKA_NODE_ID=1 \
  -e KAFKA_PROCESS_ROLES=broker,controller \
  -e KAFKA_LISTENERS=PLAINTEXT://:9092,CONTROLLER://:9093 \
  -e KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://kafka-1:9092 \
  -e KAFKA_CONTROLLER_LISTENER_NAMES=CONTROLLER \
  -e KAFKA_CONTROLLER_QUORUM_VOTERS=1@kafka-1:9093,2@kafka-2:9093,3@kafka-3:9093 \
  -e CLUSTER_ID=$CLUSTER_ID \
  -v kafka1_data:/var/lib/kafka/data \
  $KAFKA_IMAGE

# 启动 kafka-2
docker run -d --name kafka-2 \
  --network kafka-net \
  -p 9093:9092 \
  -e KAFKA_NODE_ID=2 \
  -e KAFKA_PROCESS_ROLES=broker,controller \
  -e KAFKA_LISTENERS=PLAINTEXT://:9092,CONTROLLER://:9093 \
  -e KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://kafka-2:9092 \
  -e KAFKA_CONTROLLER_LISTENER_NAMES=CONTROLLER \
  -e KAFKA_CONTROLLER_QUORUM_VOTERS=1@kafka-1:9093,2@kafka-2:9093,3@kafka-3:9093 \
  -e CLUSTER_ID=$CLUSTER_ID \
  -v kafka2_data:/var/lib/kafka/data \
  $KAFKA_IMAGE

# 启动 kafka-3
docker run -d --name kafka-3 \
  --network kafka-net \
  -p 9094:9092 \
  -e KAFKA_NODE_ID=3 \
  -e KAFKA_PROCESS_ROLES=broker,controller \
  -e KAFKA_LISTENERS=PLAINTEXT://:9092,CONTROLLER://:9093 \
  -e KAFKA_ADVERTISED_LISTENERS=PLAINTEXT://kafka-3:9092 \
  -e KAFKA_CONTROLLER_LISTENER_NAMES=CONTROLLER \
  -e KAFKA_CONTROLLER_QUORUM_VOTERS=1@kafka-1:9093,2@kafka-2:9093,3@kafka-3:9093 \
  -e CLUSTER_ID=$CLUSTER_ID \
  -v kafka3_data:/var/lib/kafka/data \
  $KAFKA_IMAGE
