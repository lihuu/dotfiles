#!/bin/sh
docker run -d --name grafana --restart always -p 3000:3000 grafana/grafana
