set nocompatible
set laststatus=2
syntax on
set nu
syntax enable
set ts=4
set shiftwidth=4
set expandtab
"set background=dark
set cursorline
"set termguicolors
"colorscheme torte
colorscheme molokai
"set fdm=indent
"set sourcecode folding
set fdm=marker
set guifont=Monaco:h15:i
"set guifont=DejaVu\ Sans\ Mono:h13:i
"set guifont=Fira\ Code:h13:i
let $LANG='en'
set langmenu='en'
"source $VIMRUNTIME/vimrc_example.vim
"source $VIMRUNTIME/mswin.vim
"source $VIMRUNTIME/delmenu.vim
"source $VIMRUNTIME/menu.vim
behave mswin
set fileencodings=utf-8,chinese,latin-1,latin1
set encoding=utf-8
set nobackup
set noundofile
"set pythonthreedll=python36.dll
filetype off
"git clone https://github.com/VundleVim/Vundle.vim.git
"set rtp+=$VIM/vimfiles//Vundle.vim
call plug#begin('~/.config/nvim/plugged')
Plug 'easymotion/vim-easymotion'
"Plug 'Yggdroot/LeaderF', { 'do': '.\install.bat' }
Plug 'vim-scripts/Gundo'
Plug 'elzr/vim-json'
Plug 'vim-scripts/FuzzyFinder'
Plug 'vim-scripts/JavaScript-Indent'
Plug 'vim-scripts/L9'
Plug 'vim-scripts/Mark'
Plug 'vim-scripts/gtags.vim'
Plug 'vim-scripts/jQuery'
"Plug 'PasteBin.vim'
""'Plug 'VisIncr'

"左边的文件树
Plug 'scrooloose/nerdtree'
"ack命令
Plug 'mileszs/ack.vim'
"Plug 'gtk-vim-syntax'
"Plug 'matchit.zip'
Plug 'tpope/vim-surround'
Plug 'Lokaltog/vim-powerline'
Plug 'othree/html5.vim'

"Javascript 相关的插件
Plug 'pangloss/vim-javascript'
Plug 'mxw/vim-jsx'
Plug 'isruslan/vim-es6'

"语法检查
Plug 'scrooloose/syntastic'

"emmet
Plug 'mattn/emmet-vim'

"xml
Plug 'othree/xml.vim'
Plug 'sukima/xmledit'


"Nginx 配置文件高亮
Plug 'chr4/nginx.vim'
Plug 'calleerlandsson/pick.vim'
Plug 'hail2u/vim-css3-syntax' 
Plug 'groenewege/vim-less'
Plug 'Raimondi/delimitMate'
"彩虹括号
Plug 'luochen1990/rainbow'
"Plug Markdown config
Plug 'plasticboy/vim-markdown'
Plug 'tyru/open-browser.vim'
Plug 'iamcco/markdown-preview.vim'
Plug 'vimwiki/vimwiki'

"Git config 
"
Plug 'tpope/vim-fugitive'
Plug 'airblade/vim-gitgutter'
Plug 'flazz/vim-colorschemes'
Plug 'mhinz/vim-startify'

if has('gui_running')
"    Plug 'vim-multiple-cursors'
endif
if v:version < 704
    Plug 'Pydiction'
    Plug 'Python-mode-klen'
endif

call plug#end()
filetype plugin indent on

"vim-script的仓库
"+---------------------------------------------------------
"|自定义按键
"|
"+---------------------------------------------------------
"nerdtree 按键映射
noremap <F5> :NERDTreeToggle<cr>
"insert 模式中删除一行
inoremap <c-d> <ESC>ddi
inoremap <c-u>  <ESC>~i

"打开vim配置文件的映射
nnoremap <leader>ev :vsplit $MYVIMRC
"配置文件生效的映射
nnoremap <leader>sv :source $MYVIMRC<cr>



"
"Extral Configuration
let g:jsx_ext_required=0

let mapleader="\<space>"

"wiki configuration
"

let delimitMate_matchpairs="(:),[:],{:}"
au FileType vim,html let b:delimitMate_matchpairs = "(:),[:],{:}"
