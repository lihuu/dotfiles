#!/bin/bash
#月份数字转名称
month_number_to_name(){
    case $1 in 
        1) month='Jan' ;;
        2) month='Feb' ;;
        3) month='Mar' ;;
        4) month='Apr' ;;
        5) month='May' ;;
        6) month='Jun' ;;
        7) month='Jul' ;;
        8) month='Aug' ;;
        9) month='Sep' ;;
        10) month='Oct' ;;
        11) month='Nov' ;;
        12) month='Dec' ;;
        *) echo "Invalid month number"
            exit 1 
    esac
    return 0;
}

if [ $# -eq 1 ];then
    set -- $(echo $1|sed 's/[\/\-]/ /g')
fi

# $# 表示传递给脚本的参数的个数
# &2 表示标准错误输出

if [ $# -ne 3 ];then
    echo "Usage: $0 month day year" >&2
    exit 1
fi


if [ $3 -le 99 ];then
    echo "$0: expected 4-digit year value" >&2
    exit 1
fi


if [ -z $(echo $1|sed 's/[[:digit:]]//g') ];then
    #移除了第一个参数中的数字，如果为空，表示输入的是数字
    month_number_to_name $1
else
    #截取第一个字符，把它转化为大写
    month="$(echo $1|cut -c1|tr '[:lower:]' '[:upper:]')"
    #截取第二个和第三个字符，把它们转换为小写
    month="$month$(echo $1|cut -c2-3|tr '[:upper:]' '[:lower:]')"
fi

echo $month $2 $3
exit 0


