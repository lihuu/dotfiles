#!/bin/bash
nohup java -jar -Xms4000m -Xmx10000m /var/projects/server/1.0.jar >/dev/null 2>&1 &
