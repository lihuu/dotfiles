#!/bin/bash
#获取任意时区对应的当前时间

zonedir="/usr/share/zoneinfo"
if [ ! -d "${zonedir}" ];then
    echo "No time zone database at $zonedir" >&2
    exit 1
fi

if [ -d "$zonedir/posix" ];then
    zonedir="$zonedir/posix" #Linux 系统
fi

if [ $# -eq 0 ];then
    timezone="UTC"
    mixedzone="UTC"
elif [ "$1" = "list" ];then
    #列出系统中所有的时区
    (echo "All known time zones and regions defined on this system:"
    cd $zonedir
    find -L * -type f -print | xargs -n 2 | awk '{printf " %-38s %-38s\n", $1, $2}'
    )|more
else
    region="$(dirname $1)"
    zone="$(basename $1)"
    matchit="$(find -L $zonedir -name $zone -type f -print|wc -l | sed 's/[^[:digit:]]//g')"
    
    if [ "$matchit" -gt 0 ];then
        if [ "$matchit" -gt 1 ];then
            echo "\"$zone\" matched more then one possible time zone record." >&2
            echo "Please use 'list' to see all known regions and time zones." >&2
            exit 1
        fi
        match="$(find -L $zonedir -name $zone -type f -print)"
        mixedzone="$zone"
    else
        mixedregion="$(echo ${region%${region#?}}|tr '[[:lower:]]' '[[:upper:]]')\
            $(echo ${region#?}|tr '[[:upper:]]' '[[:lower:]]')"

        mixedzone="$(echo ${zone%${zone#?}}|tr '[[:lower:]]' '[[:upper:]]')\
            $(echo ${zone#?}|tr '[[:upper:]]' '[[:lower:]]')"

        if [ "$mixedregion" != '.' ];then
            match="$(find -L $zonedir/$mixedregion -type f -name $mixedzone -print)"
        else
            match="$(find -L $zonedir -name $mixedzone -type f -print)"
        fi

        if [ -z "$match" ];then
            if [ -z $(find -L $zonedir -name $mixedzone -type f -d -print) ];then
                echo "The region \"$1\" has more then one time zone" >&2
            else
                echo "Cant't find an exact match for \"$1\"" >&2
            fi
            echo "Please use 'list' to see all known regions and time zones." >&2
            exit 1
        fi
    fi
    timezone="$match"
fi

nicetz=$(echo $timezone|sed "s|$zonedir/||g")

echo lt\'s $(TZ=$timezone date '+%A,%B %e, %Y, at %I:%M %p') in $nicetz

