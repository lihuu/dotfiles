#!/bin/bash

# ANSI color -- 使用这些变量输出不同的颜色和格式。 
# 以f结尾的颜色名称表示前景色，以b结尾的表示背景色。

initialize_ansi(){
    esc="\033"    
    # 如果无效，直接敲ESC键。   
    # 前景色：   
    blackf="${esc}[30m";
    redf="${esc}[31m";
    greenf="${esc}[32m"   yellowf="${esc}[33m"   bluef="${esc}[34m";
    purplef="${esc}[35m"   cyanf="${esc}[36m";  
    whitef="${esc}[37m"   
    # 背景色：   
    blackb="${esc}[40m"; 
    redb="${esc}[41m";
    greenb="${esc}[42m"   yellowb="${esc}[43m"   blueb="${esc}[44m";
    purpleb="${esc}[45m"   cyanb="${esc}[46m"; 
    whiteb="${esc}[47m"

    # 粗体、斜体、下划线以及样式切换：   
    boldon="${esc}[1m"; 
    boldoff="${esc}[22m"   italicson="${esc}[3m";
    italicsoff="${esc}[23m"   ulon="${esc}[4m";
    uloff="${esc}[24m"   invon="${esc}[7m"; 
    invoff="${esc}[27m"   reset="${esc}[0m"
}

