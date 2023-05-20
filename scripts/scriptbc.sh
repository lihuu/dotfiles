#!/bin/bash

if [ "$1" = "-p" ];then
    precision=$2
    shift 2
else
    precision=2
fi

bc -q << EOF
    scale=$precision
    $*
    quit
EOF
exit 0

