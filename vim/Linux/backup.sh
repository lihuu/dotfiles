#!/bin/sh
CURRENT_DIR=`dirname "${BASH_SOURCE-$0}"`
CURRENT_DIR_HOME=`cd "$CURRENT_DIR">/dev/null;cd .; pwd`
cp ~/.vimrc $CURRENT_DIR_HOME
cp ~/.gvimrc $CURRENT_DIR_HOME
cp ~/.vimrc.plug $CURRENT_DIR_HOME
#cp -r autoload ~/.vim/autoload
#cp -r colors ~/.vim/colors
