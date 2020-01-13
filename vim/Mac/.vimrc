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
set guifont=Fira\ Code:h20

"Search config
set hlsearch
set incsearch

"Disble some temp files
set nobackup
set nowritebackup
set noswapfile
set noeb
"set vb

"Set viminfo storage
"set viminfo='100,<9999,s100
"
">^.^<"
if filereadable(expand("~/.vimrc.plug"))
     source ~/.vimrc.plug
endif


"Custom Keys
let mapleader = "\<space>"

"Next tab and previous tab
noremap <Leader>h <esc>:tabprevious<CR>
noremap <Leader>l <esc>:tabnext<CR>
"Sort lines
vnoremap <Leader>s :sort<CR>

nmap <Leader>f :NERDTreeToggle<cr>






