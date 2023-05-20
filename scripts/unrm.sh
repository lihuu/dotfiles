#!/bin/bash
#恢复已经删除的文件

trashDirectory=~/.trash
realrm="$(which rm)"
move="$(which mv)"
dest=$(pwd)

if [ ! -d "$trashDirectory" ];then
    echo "$0: No deleted files directory found, nothing to restore" >&2
    exit 1
fi

cd $trashDirectory

if [ $# -eq 0 ];then
    #什么参数都没有的，直接列出所有的待恢复的文件
    echo "Contents of your delted files in trash"
    ls -FC | sed -e 's/\([[:digit:]][[:digit:]]\)\{5\}//g' -e 's/^/ /'
    exit 0
fi

matches="$(ls -d *"$1" 2> /dev/null|wc -l)"
if [ $matches -eq 0 ];then
    echo "No match for $1 in the deleted files" >&2
    exit 1
fi

echo "$matches"

if [ $matches -gt 1 ];then
    #多个匹配，显示列表，让用户选择恢复哪个文件
    echo "More than one file or directory matched"
    index=1
    for name in $(ls -td *"$1");do
        datetime="$(echo $name|cut -c1-14|awk -F. '{print $5"/"$4" at "$3":"$2":"$1}')"
        filename="$(echo $nama|cut -c16-)"
        if [ -d $name ];then
            filecount="$(ls $name|wc -l|sed 's/[^[:digit:]]//g')"
            echo "$index) $filename (contents = $filecount times, deleted=$datetime)"
        else
            size="$(ls -sdk1 $name|awk '{print $1}')"
            echo "$index) $filename (size =${size}Kb, deleted=$datetime)"
        fi
        index=$(($index + 1))
    done

    echo ""

    echo "Which version of $1 to restore ('0' to quit) :"
    read input

    if [ ! -z "$(echo $input|sed 's/[[:digit:]]//g')" ];then
        echo "$0: Restore canceled by user: invalid input." >&2
        exit 1
    fi

    if [ ${input:=1} -ge $index ];then
        echo "$0: Restore canceled by user: index value to big." >&2
        exit 1
    fi

    if [ $input -lt 1 ];then
        echo "$0: restore cancelled by user." >&2
        exit 1
    fi

    restore="$(ls -td1 *"$1"|sed -n "${input}p")"

    if [ -e "$dest/$1" ];then
        echo "\"$1\" already exists in this directory. Cannont overwrite." >&2
        exit 1
    fi

    echo -n "Restoring file \"$1\" ... "
    $move "$restore" "$dest/$1"
    echo "Done"

    echo -n "Delete the additional copies of this file? [y]"
    read answer
    if [ ${answer:=y} = "y" ];then
        $realrm -rf *"$1"
        echo "Deleted."
    else
        echo "additional copies retained/"
    fi
else
    if [ -e "$dest/$1" ];then
        echo ""
        echo "\"$1\" already exists in this directory. Cannont overwrite." >&2
        exit 1
    fi
    restore="$(ls -d *"$1")"
    echo -n "Restoring file \"$1\" ..."
    $move "$restore" "$dest/$1"
    echo "done"
fi

exit 0
