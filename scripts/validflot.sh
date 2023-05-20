#!/bin/bash
#验证数字是否为有效的浮点数

#点号引用另一个脚本到这个脚本中
. ./validint.sh

valid_float(){
    fvalue="$1"

    if [ ! -z $(echo $fvalue| sed 's/[^.]//g') ];then
        #提取小数点之前的数字
        decimalPart="$(echo $1|cut -d. -f1)"
        #提取小数点之后的数字
        #fractionPart="$(echo 2|cut -d. -f2)"
        fractionPart="${fvalue#*\.}"

        if [ ! -z $decimalPart ];then
            if ! valid_int "$decimalPart" "" "";then
                return 1
            fi
        fi

        if [ "${fractionPart%${fractionPart#?}}" = "-" ];then
            echo "Invalid float number" >&2
            return 1
        fi

        if [ "$fractionPart" != "" ];then
            if ! valid_int "$fractionPart" "0" "" ;then
                return 1
            fi
        else
            if [ "$fvalue" = "-" ];then
                echo "Invalid float number" >&2
            fi

            if ! valid_int "$fvalue" "" "" ;then
                return 1
            fi
        fi
    fi
    return 0
}

if valid_float $1;then
    echo "$1 is a valid floating-point value"
fi

exit 0




