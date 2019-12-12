set nocompatible
set laststatus=2
syntax on
set nu
syntax enable
set ts=4
set shiftwidth=4
set expandtab
set background=dark
set cursorline
set termguicolors
"colorscheme torte
colorscheme molokai
"set fdm=indent
"set sourcecode folding
set fdm=marker
set guifont=Consolas:h14:i
"set guifont=DejaVu\ Sans\ Mono:h13:i
"set guifont=Fira\ Code:h13:i
let $LANG='en'
set langmenu='en'
source $VIMRUNTIME/vimrc_example.vim
source $VIMRUNTIME/mswin.vim
source $VIMRUNTIME/delmenu.vim
source $VIMRUNTIME/menu.vim
behave mswin
set fileencodings=utf-8,chinese,latin-1,latin1
set encoding=utf-8
set nobackup
set noundofile
"set pythonthreedll=python36.dll


set diffexpr=MyDiff()
function MyDiff()
  let opt = '-a --binary '
  if &diffopt =~ 'icase' | let opt = opt . '-i ' | endif
  if &diffopt =~ 'iwhite' | let opt = opt . '-b ' | endif
  let arg1 = v:fname_in
  if arg1 =~ ' ' | let arg1 = '"' . arg1 . '"' | endif
  let arg2 = v:fname_new
  if arg2 =~ ' ' | let arg2 = '"' . arg2 . '"' | endif
  let arg3 = v:fname_out
  if arg3 =~ ' ' | let arg3 = '"' . arg3 . '"' | endif
  if $VIMRUNTIME =~ ' '
    if &sh =~ '\<cmd'
      if empty(&shellxquote)
        let l:shxq_sav = ''
        set shellxquote&
      endif
      let cmd = '"' . $VIMRUNTIME . '\diff"'
    else
      let cmd = substitute($VIMRUNTIME, ' ', '" ', '') . '\diff"'
    endif
  else
    let cmd = $VIMRUNTIME . '\diff'
  endif
  silent execute '!' . cmd . ' ' . opt . arg1 . ' ' . arg2 . ' > ' . arg3
  if exists('l:shxq_sav')
    let &shellxquote=l:shxq_sav
  endif
endfunction

filetype off
"git clone https://github.com/VundleVim/Vundle.vim.git
"set rtp+=$VIM/vimfiles//Vundle.vim
call plug#begin('$VIM/vimfiles/plugged/')
Plug 'easymotion/vim-easymotion'
"Plug 'Yggdroot/LeaderF', { 'do': '.\install.bat' }
"Plug 'FuzzyFinder'
"Plug 'Gundo'
Plug 'elzr/vim-json'
"Plug 'JavaScript-Indent'
"Plug 'L9'
"Plug 'Mark'
"Plug 'PasteBin.vim'
""'Plug 'VisIncr'

"左边的文件树
Plug 'scrooloose/nerdtree'
"ack命令
Plug 'mileszs/ack.vim'
"Plug 'gtags.vim'
"Plug 'gtk-vim-syntax'
"Plug 'jQuery'
"Plug 'matchit.zip'
"Plug 'xml.vim'
Plug 'tpope/vim-surround'
Plug 'Lokaltog/vim-powerline'
Plug 'othree/html5.vim'

"Javascript 相关的插件
Plug 'pangloss/vim-javascript'
Plug 'mxw/vim-jsx'
Plug 'isruslan/vim-es6'
"Plug 'https://github.com/isRuslan/vim-es6.git'

"语法检查
Plug 'scrooloose/syntastic'

"emmet
Plug 'mattn/emmet-vim'

"language syntax 
Plug 'othree/xml.vim'
Plug 'sukima/xmledit'
Plug 'chr4/nginx.vim'
Plug 'calleerlandsson/pick.vim'
Plug 'hail2u/vim-css3-syntax' 
Plug 'groenewege/vim-less'
Plug 'Raimondi/delimitMate'
Plug 'cespare/vim-toml'
Plug 'toml-lang/toml'
"
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

Plug 'honza/vim-snippets'
"Plug 'airblade/vim-rooter'
Plug 'vim-scripts/DrawIt'
Plug 'prettier/vim-prettier', { 'do': 'yarn install', 'for': ['javascript', 'typescript', 'css', 'less', 'scss', 'json', 'graphql', 'markdown', 'vue', 'yaml', 'html'] }



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





"
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

"wiki configuration
"
let g:vimwiki_list = [{'path': 'D:/OneDrive/mywiki/'}]

let delimitMate_matchpairs="(:),[:],{:}"
au FileType vim,html let b:delimitMate_matchpairs = "(:),[:],{:}"

"vim-markdown configuration
let g:vim_markdown_folding_disabled=1
let g:vim_markdown_toc_autofit = 1

let mapleader="\<space>"

