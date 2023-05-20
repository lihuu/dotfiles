#!/bin/bash
#验证日期
#输入 month day year

PATH=.:$PATH

#验证月份是否正确
exceed_days_in_month(){
    case $(echo $1|tr '[:upper:]' '[:lower:]') in
        jan*) days=31 ;;
        feb*) days=28 ;;
        mar*) days=31 ;;
        apr*) days=30 ;;
        may*) days=31 ;;
        jun*) days=30 ;;
        jul*) days=31 ;;
        aug*) days=31 ;;
        sep*) days=30 ;;
        otc*) days=31 ;;
        nov*) days=30 ;;
        dec*) days=31 ;;
        *) echo "$0: Unknown month name $1" >&2
            exit 1
    esac

    if [ $2 -lt 1 -o $2 -gt $days ];then
        return 1
    else
        return 0
    fi

}

#可以使用date命令判断是不是闰年 例如 data -d 12/31/2021 +%j
#闰年 366天，平年 365天
is_leep_year(){
    year=$1
    if [ "$((year%4))" -ne 0 ];then
        return 1
    elif [ "$((year%400))" -eq 0 ];then
        return 0
    elif [ "$((year%100))" -eq 0 ];then
        return 1
    else
        return 0
    fi
}


if [ $# -ne 3 ];then
    echo "Usage:$0 month day year" >&2
    echo "Typical input formats are August 9 2021" >&2
    exit 1
fi

#$@表示传递给脚本的所有参数
#echo $@
#直接像下面的那样调用，貌似是不行的
#newdate="$(@normdate "$@")"
newdate="$(./normdate.sh "$@")"

#$?表示上一个执行命令的返回值
if [ $? -eq 1 ];then
    exit 1
fi

month="$(echo $newdate|cut -d\  -f1)"
day="$(echo $newdate|cut -d\  -f2)"
year="$(echo $newdate|cut -d\  -f3)"

if ! exceed_days_in_month $month "$2" ;then
    if [ "$month" = "Feb" -a "$2" -eq "29" ];then
        if ! is_leep_year "$year";then
            echo "$0:$3 is not a leap year, so Feb does not have 29 days" >&2
            exit 1
        fi
    else
        echo "$0:bad day valud,$month does not have $2 days." >&2
        exit 1
    fi
fi

echo "Valid date: $newdate"
exit 0
