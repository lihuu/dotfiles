#!/bin/bash
# 验证整数输入 允许出现负数
valid_int(){
    number="$1";
    min="$2";
    max="$3";

    if [ -z "$number" ];then
        echo "Please enter a number" >&2
        return 1
    fi
    # #表示去掉左边
    # %表示去掉右边
    # ${number#?} 表示去掉左边第一个字符
    # ${number%${number#?}} 
    if [ "${number%${number#?}}" = "-" ];then
        testvalue="${number#?}"
    else
        testvalue="${number}"
    fi

    #清除
    nodigits="$(echo $testvalue|sed 's/[[:digit:]]//g')"
    
    if [ ! -z $nodigits ];then
        echo "Invalid digits" >&2
        return 1
    fi

    if [ ! -z $min ];then
        if [ "$number" -lt "$min" ];then
            echo "Your value is too small: smallest acceptable value is $min" >&2
            return 1
        fi
    fi

    if [ ! -z $max ];then
        if [ "$number" -gt "$max" ];then
            echo "Your value is too big: largest acceptable valud is $max" >&2
            return 1
        fi
    fi

    return 0
}


if valid_int "$1" "$2" "$3" ;then
    echo "Input is a valid int"
fi





