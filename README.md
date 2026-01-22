# pipe.nvim

Interactive pipeline building with buffer history for Neovim.

Build data processing pipelines interactively by piping buffer contents through shell commands. Each transformation creates a new buffer, and you can navigate back through your pipeline history at any time.

## Features

- **Pipeline Building**: Pipe any buffer through shell commands to create new buffers
- **Stacked View**: New buffers appear in horizontal splits below, with configurable max visible
- **Buffer History**: All buffers remain accessible via `:PipeList`
- **Parent Tracking**: Each buffer knows which buffer it came from
- **Multiple Modes**: Quick single-command (`:PipePrompt`), exploratory shell (`:PipeTerm`), or interactive load (`:PipeLoadPrompt`)
- **Full Readline**: History, Ctrl+R search, tab completion, environment variables

## Installation

### lazy.nvim

```lua
{
  'your-username/pipe.nvim',
  config = function()
    require('pipe').setup()
  end,
}
```

### packer.nvim

```lua
use {
  'your-username/pipe.nvim',
  config = function()
    require('pipe').setup()
  end,
}
```

### vim-plug

```vim
Plug 'your-username/pipe.nvim'

" In your init.vim or init.lua, after plug#end():
lua require('pipe').setup()
```

## Commands

### `:PipePrompt`

Opens a small 3-line terminal at the bottom with a `pipe>` prompt. Type a shell command with full readline support. The current buffer contents are piped as stdin, and the output becomes a new buffer.

### `:PipeTerm`

Opens a larger 15-line terminal with your `$SHELL`. Two environment variables are available:

- `$IN` - path to temp file containing current buffer contents
- `$OUT` - path to temp file for capturing output

Explore freely, then capture output with `cmd > $OUT`. When you exit the shell, if `$OUT` has content, it becomes a new buffer.

### `:PipeLoad {command}`

Bootstrap a new pipe buffer by running a shell command:

```vim
:PipeLoad kubectl get pods -o json
:PipeLoad curl -s https://api.example.com/data
:PipeLoad cat /var/log/syslog
```

### `:PipeLoadPrompt`

Opens a small 3-line terminal at the bottom with a `load>` prompt, similar to `:PipePrompt`. Type any shell command, and its output becomes a new parentless pipe buffer.

This is useful when you want the readline experience (history, tab completion) but are starting fresh rather than piping from an existing buffer.

### `:PipeList`

Opens a scratch buffer showing all pipe buffers with their lineage:

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
:PipeLoad kubectl get pods -o json

" Filter to just names
:PipePrompt
pipe> jq '.items[].metadata.name'

" Remove system pods
:PipePrompt
pipe> grep -v kube-system

" Sort and deduplicate
:PipePrompt
pipe> sort -u
```

### Exploratory Analysis with :PipeTerm

```vim
" Load some JSON data
:PipeLoad curl -s https://api.example.com/data

" Open interactive shell
:PipeTerm

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
:PipeLoad cat /var/log/nginx/access.log

" Filter to errors
:PipePrompt
pipe> grep -E ' (4|5)[0-9]{2} '

" Extract IPs
:PipePrompt
pipe> awk '{print $1}'

" Count occurrences
:PipePrompt
pipe> sort | uniq -c | sort -rn
```

### Branching Pipelines

Navigate back to any previous buffer with `:PipeList` and create a new branch:

```vim
:PipeLoad kubectl get pods -o json
:PipePrompt
pipe> jq '.items[].metadata.name'   " Buffer 2, parent 1

" Go back to the original data
:PipeList
" Select buffer 1

:PipePrompt
pipe> jq '.items[].status'          " Buffer 3, also parent 1
```

## Configuration

```lua
require('pipe').setup({
  -- Shell to use for :PipeTerm (default: vim.o.shell)
  shell = '/bin/bash',

  -- Height of the :PipePrompt terminal (default: 3)
  prompt_height = 3,

  -- Height of the :PipeTerm terminal (default: 15)
  terminal_height = 15,

  -- Maximum number of pipe buffers visible at once (default: 3)
  -- New buffers appear in a split below; topmost closes when exceeded
  max_visible = 3,
})
```

## Suggested Mappings

```lua
vim.keymap.set('n', '<leader>pp', ':PipePrompt<CR>', { desc = 'Pipe buffer through command' })
vim.keymap.set('n', '<leader>pt', ':PipeTerm<CR>', { desc = 'Open pipe terminal' })
vim.keymap.set('n', '<leader>pl', ':PipeList<CR>', { desc = 'List pipe buffers' })
vim.keymap.set('n', '<leader>pf', ':PipeLoad ', { desc = 'Load command output into pipe' })
vim.keymap.set('n', '<leader>pn', ':PipeLoadPrompt<CR>', { desc = 'Load command output (with prompt)' })
```

Or in VimL:

```vim
nnoremap <leader>pp :PipePrompt<CR>
nnoremap <leader>pt :PipeTerm<CR>
nnoremap <leader>pl :PipeList<CR>
nnoremap <leader>pf :PipeLoad<Space>
nnoremap <leader>pn :PipeLoadPrompt<CR>
```

## Working with stdin

Start Neovim with piped input:

```bash
kubectl get pods -o json | nvim -c "setlocal buftype=nofile bufhidden=hide noswapfile" -
```

Then use `:PipePrompt` to continue processing. Note that buffers from stdin won't have pipe metadata initially, but any `:PipePrompt` operations will create proper pipe buffers.

For a cleaner workflow, use `:PipeLoad` with a command:

```bash
nvim -c "PipeLoad kubectl get pods -o json"
```

Add this function to your `.bashrc` or `.zshrc` for quick access:

```bash
pf() {
  nvim -c "PipeLoad $*"
}
```

Then use it directly from your shell:

```bash
np kubectl get pods -o json
np curl -s https://api.example.com/data
np cat /var/log/syslog
```

## How It Works

Each pipe buffer stores metadata:
- `pipe_id` - unique incrementing counter
- `pipe_cmd` - command that generated the buffer
- `pipe_parent` - pipe_id of the parent buffer (nil for initial loads)

Buffers are named like `pipe://1/jq '.users'` and are read-only scratch buffers held in RAM.

## Tips

- Use `:PipeTerm` when you're not sure what command you need - explore interactively
- Use `:PipePrompt` when you know exactly what transformation you want
- Check `:PipeList` frequently to see your pipeline history
- The `d` key in `:PipeList` cleans up buffers you no longer need
- Parent relationships let you see how data flowed through your pipeline

## License

MIT
