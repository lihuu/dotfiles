#!/bin/bash
PID=`ps -ef|grep java|grep app|awk '{print $2}'`
if [ -n "${PID}" ];then
    kill -s 15 $PID
    sleep 5
    echo "Process with PID: ${PID} been killed"
else
    echo "No process to stop"
fi
