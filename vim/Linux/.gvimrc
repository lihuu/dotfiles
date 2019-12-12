" An example for a gvimrc file.
" The commands in this are executed when the GUI is started, after the vimrc
" has been executed.
"
" Maintainer:	Bram Moolenaar <Bram@vim.org>
" Last change:	2016 Apr 05
"
" To use it, copy it to
"     for Unix and OS/2:  ~/.gvimrc
"	      for Amiga:  s:.gvimrc
"  for MS-DOS and Win32:  $VIM\_gvimrc
"	    for OpenVMS:  sys$login:.gvimrc


set nocompatible
syntax on
set nu
syntax enable
colorscheme molokai
set ts=4
set shiftwidth=4
set expandtab
set ch=2		" Make command line two lines high
set mousehide		" Hide the mouse when typing text
set fdm=marker
"set guifont=Menlo:h16
set macligatures
set guifont=Fira\ Code:h16
"set guifont=Menlo\ Regular:h20
set t_Co=256
set background=dark

set autoread
"colorscheme macvim
map <S-Insert> <MiddleMouse>
map! <S-Insert> <MiddleMouse>

