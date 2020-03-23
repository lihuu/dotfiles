#!/bin/sh
cp .vimrc ~
cp .gvimrc ~
cp .vimrc.plug ~
if [ ! -d  ~/.vim ]; then
    mkdir -p ~/.vim/autoload
    mkdir  ~/.vim/colors
fi

cp -r autoload ~/.vim
cp -r colors ~/.vim
