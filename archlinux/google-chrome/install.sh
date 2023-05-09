#!/bin/bash
#
#

if [ ! -e '/usr/bin/yay' ];then
    echo 'yay not install, will install yay...'
    ../yay/install.sh
fi


yay -S google-chrome
