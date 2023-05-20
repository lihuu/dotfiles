#!/bin/bash
#调用rm命令的时候，将内容移动
#到指定的目录里面，类似于回收站的功能。

trashdir=~/.trash
realrm="$(which rm)"
copy="$(which cp) -R"

if [ $# -eq 0 ];then
    #exec 执行完成之后直接退出
    #exec 使用指定的进程替换当前的进程，此时当前进程就退出了
    exec $realrm
fi

flags=""

#读取参数
while getopts "dfiPRrvW" opt;do
    case $opt in 
        f) exec $realrm "$@"    ;; #直接删除，不用移动到回收站
        *) flags="$flags -$opt" ;;
    esac
done

shift $(($OPTIND - 1))

if [ ! -d "$trashdir" ];then
    if [ ! -w "$HOME" ];then
        echo "$0 failed: could not create $trashdir in $HOME" >&2
        exit 1
    fi
    mkdir $trashdir
    chmod 700 $trashdir #只有当前用户可以访问
fi

# 这里的for 会遍历 ($1,$2,$3...)这样的参数
for arg ;do 
    echo "$arg"
    echo "$(basename "$arg")"
    newname="$trashdir/$(date "+%S.%M.%H.%d.%m").$(basename "$arg")"
    if [ -f "$arg" -o -d "$arg" ];then
        $copy "$arg" "$newname"
    fi
done

exec $realrm $flags "$@"

#以下for 循环是等价的
#for arg in "$@";do
    #echo "$arg"
#done
