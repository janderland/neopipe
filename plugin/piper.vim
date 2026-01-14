" piper.vim - Plugin loader for piper.nvim
" Maintainer: piper.nvim
" License: MIT

if exists('g:loaded_piper')
  finish
endif
let g:loaded_piper = 1

" Auto-setup with default configuration if user hasn't called setup()
" This allows the plugin to work out of the box
lua << EOF
-- Defer setup to allow user to call require('piper').setup() first
vim.api.nvim_create_autocmd('VimEnter', {
  callback = function()
    -- Only auto-setup if commands don't exist yet
    if vim.fn.exists(':Pipe') == 0 then
      require('piper').setup()
    end
  end,
  once = true,
})
EOF
