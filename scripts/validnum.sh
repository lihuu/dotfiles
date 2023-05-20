#!/bin/bash
#判断输入的内容是否是数字和字母
valid_alpha_num(){
    valid_chars="$(echo $1|sed -e 's/[^[:alnum:]]'//g)" 
    if [ "$valid_chars" = "$1" ];then
        return 0
    else
        return 1
    fi
}

echo -n "Enter input:"
read input

if ! valid_alpha_num $input ;then
    echo "Input is not valid"
else
    echo "Input is valid: $input"
fi

exit 0


