" Basic settings
set nocompatible
set number
set relativenumber
set expandtab
set shiftwidth=4
set tabstop=4
set autoindent
set smartindent
set mouse=a
set clipboard=unnamed
set encoding=utf-8

" Plugin configurations
" Assuming vim-plug is installed
call plug#begin()
Plug 'tpope/vim-surround'
Plug 'tpope/vim-commentary'
Plug 'tpope/vim-fugitive'
Plug 'preservim/nerdtree'
Plug 'LnL7/vim-nix'
call plug#end()

" NERDTree settings
nnoremap <C-n> :NERDTreeToggle<CR>
autocmd VimEnter * if argc() == 0 && !exists("s:std_in") | NERDTree | endif

" Key mappings
let mapleader = "\<Space>"
nnoremap <leader>w :w<CR>
nnoremap <leader>q :q<CR>

" Color scheme
syntax enable
set background=dark 
