# piper.nvim

Interactive pipeline building with buffer history for Neovim.

Build data processing pipelines interactively by piping buffer contents through shell commands. Each transformation creates a new buffer, and you can navigate back through your pipeline history at any time.

## Features

- **Pipeline Building**: Pipe any buffer through shell commands to create new buffers
- **Buffer History**: All buffers remain accessible via `:PipeList`
- **Parent Tracking**: Each buffer knows which buffer it came from
- **Two Modes**: Quick single-command (`:Pipe`) or exploratory shell (`:Pipet`)
- **Full Readline**: History, Ctrl+R search, tab completion, environment variables

## Installation

### lazy.nvim

```lua
{
  'your-username/piper.nvim',
  config = function()
    require('piper').setup()
  end,
}
```

### packer.nvim

```lua
use {
  'your-username/piper.nvim',
  config = function()
    require('piper').setup()
  end,
}
```

### vim-plug

```vim
Plug 'your-username/piper.nvim'

" In your init.vim or init.lua, after plug#end():
lua require('piper').setup()
```

## Commands

### `:Pipe`

Opens a small 3-line terminal at the bottom with a `pipe>` prompt. Type a shell command with full readline support. The current buffer contents are piped as stdin, and the output becomes a new buffer.

### `:Pipet`

Opens a larger 15-line terminal with your `$SHELL`. Two environment variables are available:

- `$IN` - path to temp file containing current buffer contents
- `$OUT` - path to temp file for capturing output

Explore freely, then capture output with `cmd > $OUT`. When you exit the shell, if `$OUT` has content, it becomes a new buffer.

### `:PipeLoad {source}`

Bootstrap a new piper buffer from:

- **File path**: `:PipeLoad /var/log/syslog`
- **Command** (prefixed with `!`): `:PipeLoad !kubectl get pods`

### `:PipeList`

Opens a scratch buffer showing all piper buffers with their lineage:

```
 # │ Parent │ Lines │ Command
───┼────────┼───────┼────────────────────────────────
 1 │      - │   142 │ !kubectl get pods
 2 │      1 │    23 │ jq '.items[].metadata.name'
 3 │      2 │    18 │ grep -v kube-system
 4 │      3 │    12 │ sort -u
 5 │      1 │   142 │ jq '.items[].status'
```

**Keymaps in PipeList:**
- `j`/`k` or arrows - navigate
- `<CR>` - open selected buffer, close list
- `d` - delete selected buffer
- `q` or `<Esc>` - close list

## Usage Examples

### Basic Pipeline

```vim
" Start with kubectl output
:PipeLoad !kubectl get pods -o json

" Filter to just names
:Pipe
pipe> jq '.items[].metadata.name'

" Remove system pods
:Pipe
pipe> grep -v kube-system

" Sort and deduplicate
:Pipe
pipe> sort -u
```

### Exploratory Analysis with :Pipet

```vim
" Load some JSON data
:PipeLoad !curl -s https://api.example.com/data

" Open interactive shell
:Pipet

# In the shell, explore the data
$ jq keys < $IN
$ jq '.users | length' < $IN
$ jq '.users[0]' < $IN | less

# When you find what you want, capture it
$ jq '.users[] | {name, email}' < $IN > $OUT

# Exit shell (Ctrl+D or 'exit')
# New buffer is created with the output
```

### Working with Files

```vim
" Load a log file
:PipeLoad /var/log/nginx/access.log

" Filter to errors
:Pipe
pipe> grep -E ' (4|5)[0-9]{2} '

" Extract IPs
:Pipe
pipe> awk '{print $1}'

" Count occurrences
:Pipe
pipe> sort | uniq -c | sort -rn
```

### Branching Pipelines

Navigate back to any previous buffer with `:PipeList` and create a new branch:

```vim
:PipeLoad !kubectl get pods -o json
:Pipe
pipe> jq '.items[].metadata.name'   " Buffer 2, parent 1

" Go back to the original data
:PipeList
" Select buffer 1

:Pipe
pipe> jq '.items[].status'          " Buffer 3, also parent 1
```

## Configuration

```lua
require('piper').setup({
  -- Shell to use for :Pipet (default: vim.o.shell)
  shell = '/bin/bash',

  -- Height of the :Pipe prompt terminal (default: 3)
  prompt_height = 3,

  -- Height of the :Pipet terminal (default: 15)
  terminal_height = 15,
})
```

## Suggested Mappings

```lua
vim.keymap.set('n', '<leader>pp', ':Pipe<CR>', { desc = 'Pipe buffer through command' })
vim.keymap.set('n', '<leader>pt', ':Pipet<CR>', { desc = 'Open pipe terminal' })
vim.keymap.set('n', '<leader>pl', ':PipeList<CR>', { desc = 'List pipe buffers' })
vim.keymap.set('n', '<leader>pf', ':PipeLoad ', { desc = 'Load file into piper' })
```

Or in VimL:

```vim
nnoremap <leader>pp :Pipe<CR>
nnoremap <leader>pt :Pipet<CR>
nnoremap <leader>pl :PipeList<CR>
nnoremap <leader>pf :PipeLoad<Space>
```

## Working with stdin

Start Neovim with piped input:

```bash
kubectl get pods -o json | nvim -c "setlocal buftype=nofile bufhidden=hide noswapfile" -
```

Then use `:Pipe` to continue processing. Note that buffers from stdin won't have piper metadata initially, but any `:Pipe` operations will create proper piper buffers.

For a cleaner workflow, use `:PipeLoad` with a command:

```bash
nvim -c "PipeLoad !kubectl get pods -o json"
```

## How It Works

Each piper buffer stores metadata:
- `piper_id` - unique incrementing counter
- `piper_cmd` - command that generated the buffer
- `piper_parent` - piper_id of the parent buffer (nil for initial loads)

Buffers are named like `piper://1/jq '.users'` and are read-only scratch buffers held in RAM.

## Tips

- Use `:Pipet` when you're not sure what command you need - explore interactively
- Use `:Pipe` when you know exactly what transformation you want
- Check `:PipeList` frequently to see your pipeline history
- The `d` key in `:PipeList` cleans up buffers you no longer need
- Parent relationships let you see how data flowed through your pipeline

## License

MIT
