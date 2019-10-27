"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" => Plugin
"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""

" plugin
call plug#begin(expand('~/.vim/plugged'))
Plug 'mattn/vim-starwars'
"" leader + ne -> sidebar
Plug 'scrooloose/nerdtree'
Plug 'jistr/vim-nerdtree-tabs'
"" ga -> align
Plug 'junegunn/vim-easy-align'
"" leader + qr -> exec script
Plug 'thinca/vim-quickrun'
Plug 'Shougo/vimproc.vim', {'do' : 'make'}
"" gcc -> comment
Plug 'tpope/vim-commentary'
"" option bar
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
"" auto bracket
Plug 'Raimondi/delimitMate'
Plug 'tpope/vim-surround'
"" auto format
Plug 'Chiel92/vim-autoformat'
"" error detect
Plug 'scrooloose/syntastic'
"" delete white space
Plug 'bronson/vim-trailing-whitespace'
"" auto complete
Plug 'sheerun/vim-polyglot'
Plug 'Valloric/YouCompleteMe'
Plug 'ervandew/supertab'
"" html
Plug 'hail2u/vim-css3-syntax'
Plug 'gorodinskiy/vim-coloresque'
Plug 'tpope/vim-haml'
Plug 'mattn/emmet-vim'
"" javascript
Plug 'jelera/vim-javascript-syntax'
"" php
Plug 'arnaud-lb/vim-php-namespace'
"" python
Plug 'davidhalter/jedi-vim'
Plug 'raimon49/requirements.txt.vim', {'for': 'requirements'}
"" space + sh -> vimshell
Plug 'Shougo/vimshell.vim'
"" snippet
Plug 'SirVer/ultisnips'
Plug 'honza/vim-snippets'
call plug#end()
filetype plugin indent on
