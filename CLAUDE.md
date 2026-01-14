# CLAUDE.md

This file provides guidance for AI assistants working on this codebase.

## Project Overview

**pipe.nvim** is a Neovim plugin for building interactive data processing pipelines. Users pipe buffer contents through shell commands, with each transformation creating a new buffer. The plugin tracks parent-child relationships between buffers, enabling exploration of different processing branches.

## Architecture

### Directory Structure

```
pipe.nvim/
├── lua/piper/init.lua    # Main plugin code (all Lua logic)
├── plugin/piper.vim      # Plugin loader (auto-setup on VimEnter)
├── bin/
│   ├── pipe-prompt       # Zsh script for :PipePrompt command
│   └── pipe-load-prompt  # Zsh script for :PipeLoadPrompt command
├── Makefile              # Docker-based linting
└── Dockerfile            # Development environment
```

### Key Components

- **`lua/piper/init.lua`**: Contains all plugin logic including:
  - Buffer creation and management (`create_piper_buffer`)
  - Window management with stacking (`open_buffer`, `get_piper_windows`)
  - Command implementations (`pipe`, `pipet`, `pipe_load`, `pipe_load_prompt`, `pipe_list`)
  - User command registration in `setup()`

- **`bin/pipe-prompt`**: Zsh script providing readline support for `:PipePrompt`. Uses `vared` for ZLE-based editing with vi keybindings.

- **`bin/pipe-load-prompt`**: Similar to pipe-prompt but without input piping, used for `:PipeLoadPrompt`.

## Commands

| Command | Function | Description |
|---------|----------|-------------|
| `:PipePrompt` | `M.pipe()` | Pipe buffer through command |
| `:PipeTerm` | `M.pipet()` | Open shell with `$IN`/`$OUT` |
| `:PipeLoad {cmd}` | `M.pipe_load()` | Load command output |
| `:PipeLoadPrompt` | `M.pipe_load_prompt()` | Interactive load prompt |
| `:PipeList` | `M.pipe_list()` | Show buffer list |

## Buffer Metadata

Each piper buffer has these variables (via `nvim_buf_set_var`):
- `piper_id`: Unique integer ID
- `piper_cmd`: Command that created the buffer
- `piper_parent`: Parent buffer's piper_id (nil for root buffers)

## Development

### Linting

Run luacheck via Docker:
```bash
make lint
```

### Code Style

- Lua code follows standard Neovim plugin conventions
- Shell scripts use Zsh for ZLE (readline) support
- No external Lua dependencies

### Testing

There are no automated tests currently. Manual testing requires Neovim with the plugin loaded.

## Common Tasks

### Adding a New Command

1. Add the implementation function to `lua/piper/init.lua`
2. Register the user command in `M.setup()` using `nvim_create_user_command`
3. Update README.md with documentation

### Modifying Prompt Behavior

The prompts (`pipe>` and `load>`) are implemented in `bin/pipe-prompt` and `bin/pipe-load-prompt`. These use Zsh's `vared` for line editing with full readline support.

### Changing Buffer Display

Buffer stacking is managed by:
- `open_buffer()`: Creates splits and manages visible count
- `get_piper_windows()`: Finds all piper windows sorted by position
- `M.config.max_visible`: Controls how many piper windows stay visible
