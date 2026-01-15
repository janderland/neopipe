" piper.vim - Plugin loader for piper.nvim
" Maintainer: piper.nvim
" License: MIT

if exists('g:loaded_piper')
  finish
endif
let g:loaded_piper = 1

" Auto-setup with default configuration
" This allows the plugin to work out of the box and with -c commands
lua require('piper').setup()
