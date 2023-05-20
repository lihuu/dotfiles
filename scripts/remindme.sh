#!/bin/bash

rememberfile="$HOME/.remember"

if [ ! -f "$rememberfile" ];then
    echo "$0: You don't seem to have a .remember file." >&2
    echo "To remedy this, please use 'remember' to add reminders" >&2
    exit 1
fi

if [ $# -eq 0 ];then
    more $rememberfile
else
    grep -i -- "$@" $rememberfile | ${PAGER: -more}
fi
