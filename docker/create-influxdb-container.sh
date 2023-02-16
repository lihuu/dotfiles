#!/bin/sh
docker run -d --name influxdb --restart always -p 8086:8086 -p 8083:8083 influxdb:1.8
