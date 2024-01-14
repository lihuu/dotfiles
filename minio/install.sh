#!/bin/bash
#
sudo addgroup --system minio
sudo adduser --system --ingroup minio --no-create-home --disabled-password minio

sudo mkdir /usr/local/minio
sudo mkdir /etc/minio
sudo mkdir /data
sudo mkdir /data/minio

curl https://dl.min.io/server/minio/release/linux-amd64/minio -o /tmp/minio
sudo chmod +x /tmp/minio
sudo cp /tmp/minio /usr/local/minio
sudo cp ./minio.conf /etc/minio
sudo cp ./minio.service /etc/systemd/system
sudo systemctl daemon-reload
sudo systemctl start minio.service
