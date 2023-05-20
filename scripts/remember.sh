#!/bin/bash

rememberfile="$HOME/.remember"

if [ $# -eq 0 ];then
    echo "Enter note, end witn ^D:"
    cat - >> $rememberfile
else
    echo "$@" >> $rememberfile
fi
exit 0
