#!/bin/bash

if [ -d '~/.emacs.d' ];then
    echo "Directory exist, will move it to .emacs.d.bak"
    #mv ~/.emacs.d ~/.emacs.d.bak
    exit 1
fi

git clone https://github.com/hlissner/doom-emacs.git ~/.emacs.d

if [ ! -d '~/.doom.d' ];then
   git clone https://github.com/lihuu/doom.d.git ~/.doom.d
fi

exit 0
