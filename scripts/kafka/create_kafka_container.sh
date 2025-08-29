#!/bin/bash
set -e

# 集群 ID（固定一份，三个节点共享）
CLUSTER_ID="kraft-cluster-id-$(uuidgen | tr -d '-')"

# 创建数据卷
docker volume create kafka1_data
docker volume create kafka2_data
docker volume create kafka3_data

# 通用镜像
KAFKA_IMAGE="bitnami/kafka:3.7.0"

# 启动 kafka-1
docker run -d --name kafka-1 \
  -p 9092:9092 \
  -e KAFKA_BROKER_ID=1 \
  -e KAFKA_CFG_PROCESS_ROLES=broker,controller \
  -e KAFKA_CFG_NODE_ID=1 \
  -e KAFKA_CFG_CONTROLLER_QUORUM_VOTERS=1@kafka-1:9093,2@kafka-2:9093,3@kafka-3:9093 \
  -e KAFKA_CFG_LISTENERS=PLAINTEXT://:9092,CONTROLLER://:9093 \
  -e KAFKA_CFG_ADVERTISED_LISTENERS=PLAINTEXT://localhost:9092 \
  -e KAFKA_CFG_CONTROLLER_LISTENER_NAMES=CONTROLLER \
  -e KAFKA_CFG_LOG_DIRS=/bitnami/kafka \
  -e KAFKA_KRAFT_CLUSTER_ID=$CLUSTER_ID \
  --network bridge \
  -v kafka1_data:/bitnami/kafka \
  $KAFKA_IMAGE

# 启动 kafka-2
docker run -d --name kafka-2 \
  -p 9093:9092 \
  -e KAFKA_BROKER_ID=2 \
  -e KAFKA_CFG_PROCESS_ROLES=broker,controller \
  -e KAFKA_CFG_NODE_ID=2 \
  -e KAFKA_CFG_CONTROLLER_QUORUM_VOTERS=1@kafka-1:9093,2@kafka-2:9093,3@kafka-3:9093 \
  -e KAFKA_CFG_LISTENERS=PLAINTEXT://:9092,CONTROLLER://:9093 \
  -e KAFKA_CFG_ADVERTISED_LISTENERS=PLAINTEXT://localhost:9093 \
  -e KAFKA_CFG_CONTROLLER_LISTENER_NAMES=CONTROLLER \
  -e KAFKA_CFG_LOG_DIRS=/bitnami/kafka \
  -e KAFKA_KRAFT_CLUSTER_ID=$CLUSTER_ID \
  --network bridge \
  -v kafka2_data:/bitnami/kafka \
  $KAFKA_IMAGE

# 启动 kafka-3
docker run -d --name kafka-3 \
  -p 9094:9092 \
  -e KAFKA_BROKER_ID=3 \
  -e KAFKA_CFG_PROCESS_ROLES=broker,controller \
  -e KAFKA_CFG_NODE_ID=3 \
  -e KAFKA_CFG_CONTROLLER_QUORUM_VOTERS=1@kafka-1:9093,2@kafka-2:9093,3@kafka-3:9093 \
  -e KAFKA_CFG_LISTENERS=PLAINTEXT://:9092,CONTROLLER://:9093 \
  -e KAFKA_CFG_ADVERTISED_LISTENERS=PLAINTEXT://localhost:9094 \
  -e KAFKA_CFG_CONTROLLER_LISTENER_NAMES=CONTROLLER \
  -e KAFKA_CFG_LOG_DIRS=/bitnami/kafka \
  -e KAFKA_KRAFT_CLUSTER_ID=$CLUSTER_ID \
  --network bridge \
  -v kafka3_data:/bitnami/kafka \
  $KAFKA_IMAGE
