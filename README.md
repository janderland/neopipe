# pipe.nvim

pipe.nvim augments your ZSH environment with the goal of making it easier to explore complex CLI tools and process their output.

## Core Concepts

Every command's output is stored in an addressable buffer and associated with metadata:
- ID for addressing
- Command that generated it
- STDIN source (parent ID)
- Timestamp

A particular output can be reused as the STDIN to another command multiple times, enabling branching pipelines and iterative exploration.

## Command Matrix

There are two kinds of commands and three ways to invoke them. Your command can accept an existing output via STDIN and generate a new
output, or it can generate a new output without STDIN. You can invoke the command via the vim ex command line, a single command prompt
or at the end of a full terminal session.

```
┌──────────────────┬─────────────────┬──────────────────┬───────────────────┐
│                  │ Ex Command Line │ Single Command   │ Full Terminal     │
│                  │                 │ Prompt           │ Environment       │
├──────────────────┼─────────────────┼──────────────────┼───────────────────┤
│ Not Using STDIN  │ :PipeLoad       │ :PipeLoadPrompt  │ :PipeLoadTerm     │
│                  │                 │                  │                   │
├──────────────────┼─────────────────┼──────────────────┼───────────────────┤
│ Using STDIN      │ :PipeFilter     │ :PipeFilterPrompt│ :PipeFilterTerm   │
│                  │                 │                  │                   │
└──────────────────┴─────────────────┴──────────────────┴───────────────────┘
```

## Installation

### vim-plug

```vim
Plug 'janderland/pipe.nvim'

" In your init.vim or init.lua, after plug#end():
lua require('pipe').setup()
```

### Setup

```lua
require('pipe').setup({
  shell = '/bin/zsh',           -- Shell for terminal commands
  prompt_height = 3,            -- Height of prompt terminals
  terminal_height = 15,         -- Height of full terminals
  max_visible = 3,              -- Max pipe buffers visible at once
})
```

### Keybindings

```lua
-- Filter commands (transform current buffer with STDIN)
vim.keymap.set('n', '<leader>pf', ':PipeFilter ', { desc = 'Filter buffer through command' })
vim.keymap.set('n', '<leader>pp', ':PipeFilterPrompt<CR>', { desc = 'Filter buffer (prompt)' })
vim.keymap.set('n', '<leader>pt', ':PipeFilterTerm<CR>', { desc = 'Filter buffer (terminal)' })

-- Load commands (create new buffer without STDIN)
vim.keymap.set('n', '<leader>pl', ':PipeLoad ', { desc = 'Load command output' })
vim.keymap.set('n', '<leader>pP', ':PipeLoadPrompt<CR>', { desc = 'Load command output (prompt)' })
vim.keymap.set('n', '<leader>pT', ':PipeLoadTerm<CR>', { desc = 'Load command output (terminal)' })

-- Utility
vim.keymap.set('n', '<leader>pb', ':PipeList<CR>', { desc = 'List pipe buffers' })
```

### Shell Integration

Add this function to your `.zshrc` for quick access to the pipe terminal environment:

```bash
pipe() {
  nvim -c "PipeLoadTerm"
}
```

## License

MIT
