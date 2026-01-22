" pipe.vim - Plugin loader for pipe.nvim
" Maintainer: pipe.nvim
" License: MIT

if exists('g:loaded_pipe')
  finish
endif
let g:loaded_pipe = 1

" Auto-setup with default configuration if user hasn't called setup()
" This allows the plugin to work out of the box
lua << EOF
-- Defer setup to allow user to call require('pipe').setup() first
vim.api.nvim_create_autocmd('VimEnter', {
  callback = function()
    -- Only auto-setup if commands don't exist yet
    if vim.fn.exists(':PipePrompt') == 0 then
      require('pipe').setup()
    end
  end,
  once = true,
})
EOF
