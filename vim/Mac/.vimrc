set nocompatible
set nu
set laststatus=2
syntax on
syntax enable
set ts=4
set shiftwidth=4
set expandtab
set cursorline
set background=dark
colorscheme molokai
set fdm=marker
set shell=bash\ -i

"Search config
set hlsearch
set incsearch

"Set viminfo storage
"set viminfo='100,<9999,s100
"
">^.^<"
if filereadable(expand("~/.vimrc.plug"))
     source ~/.vimrc.plug
endif


