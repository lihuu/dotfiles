#!/bin/sh
cp .vimrc ~
cp .gvimrc ~
cp .vimrc.plug ~

if [ ! -d  ~/.vim] ;then
   mkdir ~/.vim 
fi

cp -r autoload ~/.vim
cp -r colors/* ~/.vim
