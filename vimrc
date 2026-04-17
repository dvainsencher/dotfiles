set runtimepath+=/usr/share/vim-scripts

set tabstop=4 shiftwidth=4 expandtab smarttab softtabstop=4 autoindent omnifunc=pythoncomplete#Complete

autocmd BufRead *.py set smartindent cinwords=if,elif,else,for,while,try,except,finally,def,class

syntax match Special "\t"
inoremap # X#

set incsearch
set showmatch

set statusline=%F%m%r%h%w\ [FORMATO=%{&ff}]\ [TIPO=%Y]\ %{\"[\".(&fenc==\"\"?&enc:&fenc).((exists(\"+bomb\")\ &&\ &bomb)?\",B\":\"\").\"]\ \"}\ [ASCII=\%03.3b]\ [linha=%04l,%04v][%p%%]\ [LINHAS=%L]
set laststatus=2

set wildmode=list:full wildmode=longest,list pastetoggle=<c-u>

filetype plugin on

set background=dark
colorscheme desert
