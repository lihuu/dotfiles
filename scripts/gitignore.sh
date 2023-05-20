#!/bin/bash
# 将文件添加到git的忽略文件中

currentDir="$(pwd)"

if [ ! -d "$currentDir/.git" ];then
    echo "Not git repository!" >&2
    exit 1
fi

while getopts 'la:r:' opt;do
    case "$opt" in
        l) action="list" ;;
        a) action="add" 
           pattern="$OPTARG" ;;
        r) action="remove"
            pattern="$OPTARG";;
    esac
done

if [ "$action" = "list" ];then
    cat "$currentDir/.gitignore"
elif [ "$action" = "add" ];then
    echo "$pattern" >> "$currentDir/.gitignore"
elif [ "$action" = "remove" ];then
    sed -i "s/$pattern//g" "$currentDir/.gitignore"
    sed -i "/^$/d" "$currentDir/.gitignore"
else
    echo "Usage: $0 -l | $0 -a pattern | $0 -r pattern "
fi

exit 0





