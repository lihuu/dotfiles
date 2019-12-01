#!/bin/sh
CURRENT_DIR=`dirname "${BASH_SOURCE-$0}"`
CURRENT_DIR_HOME=`cd "$CURRENT_DIR">/dev/null;cd .; pwd`
if [ ! -d "~/.config/nvim/" ];then
    mkdir ~/.config/nvim
fi

cp $CURRENT_DIR_HOME/init.vim ~/.config/nvim/
cp -r $CURRENT_DIR_HOME/autoload ~/.config/nvim/autoload
cp -r $CURRENT_DIR_HOME/colors ~/.config/nvim/colors
