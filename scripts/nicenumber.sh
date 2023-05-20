#!/bin/bash
#给定的数字以 逗号分隔的格式显示出来

nice_number(){

    #使用 cut命令截取输入 
    #如果没有指定文件，或者文件为"-"，则从标准读取
    # -d 指定分解符代替制表符作为区域分界
    # -f 选中分隔的域
    integer=$(echo $1|cut -d. -f1)
    decimal=$(echo $1|cut -d. -f2)

    #检查数字是否包含小数
    if [ "$decimal" != "$1" ];then
        #小数部分，将其保存起来
        #${DD:='.'} 这个表达式表示如果 DD变量没有设置就使用 '.' 作为变量的值
        result="${DD:='.'}$decimal"
    fi

    thousands=$integer

    while [ $thousands -gt 999 ];do
        remainder=$(($thousands % 1000))
        while [ ${#remainder} -lt 3 ];do
            remainder="0$remainder"
        done
        result="${TD:=","}${remainder}${result}"
        thousands=$(($thousands / 1000))
    done

    niceNumber="${thousands}${result}"

    if [ ! -z $2 ];then
        echo $niceNumber
    fi
}

DD="."
DT=","

while getopts "d:t" opt;do
    case $opt in 
        d) DD="$OPTARG" ;;
        t) TD="$OPTARG" ;;
    esac
done

shift $(($OPTIND - 1))

if [ $# -eq 0 ];then
    echo "Usage: $(basename $0) [-d c] [-t c] number_value"
    echo " -d specifies the decimal point delimiter (default '.')"
    echo " -t specifies the thousands delimiter (default ',')"
    exit 0
fi

nice_number $1 1
exit 0







