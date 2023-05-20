#!/bin/bash
#shell中的数组
# shell 中只支持一维数组，不支持多维数组
my_array=("A" "B" "C" "D")
echo "${my_array[@]}"
echo "${my_array[*]}"


# shell 支持关联数组 ，看起来就像一个Map
# 这个在MacOs中好像是不支持的呢
declare -A site
site["google"]="www.google.com"
site["baidu"]="www.baidu.com"
site["bing"]="www.bing.cn"

echo "${site[@]}"
echo "${site[*]}"
echo "${site['google']}"

