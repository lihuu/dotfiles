#!/bin/sh
CURRENT_DIR=`dirname "${BASH_SOURCE-$0}"`
CURRENT_DIR_HOME=`cd "$CURRENT_DIR">/dev/null;cd .; pwd`
cp ~/.config/nvim/init.vim $CURRENT_DIR_HOME
cp -r ~/.config/nvim/autoload $CURRENT_DIR_HOME
cp -r ~/.config/nvim/colors $CURRENT_DIR_HOME
