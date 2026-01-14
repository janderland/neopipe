-- piper.nvim - Interactive pipeline building with buffer history
-- Each buffer is a read-only scratch buffer. Users can pipe any buffer
-- through shell commands to create new buffers.

local M = {}

-- Configuration with defaults
M.config = {
  shell = vim.o.shell,
  prompt_height = 3,
  terminal_height = 15,
  max_visible = 3,
}

-- State: mapping piper_id -> buffer number
M.buffers = {}

-- Counter for unique piper IDs
M.next_id = 1

-- Get the plugin's bin directory
local function get_bin_dir()
  local source = debug.getinfo(1, "S").source:sub(2)
  local plugin_dir = vim.fn.fnamemodify(source, ":h:h:h")
  return plugin_dir .. "/bin"
end

-- Create a new piper scratch buffer with given content
local function create_piper_buffer(content, cmd, parent_id)
  local buf = vim.api.nvim_create_buf(false, true)
  local id = M.next_id
  M.next_id = M.next_id + 1

  -- Set buffer options
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].swapfile = false

  -- Set buffer name
  local safe_cmd = cmd:gsub("[\n\r]", " "):sub(1, 50)
  vim.api.nvim_buf_set_name(buf, string.format("piper://%d/%s", id, safe_cmd))

  -- Set content
  local lines = vim.split(content, "\n", { plain = true })
  -- Remove trailing empty line if content ends with newline
  if #lines > 0 and lines[#lines] == "" then
    table.remove(lines)
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

  -- Make buffer read-only after setting content
  vim.bo[buf].modifiable = false

  -- Set buffer variables
  vim.api.nvim_buf_set_var(buf, "piper_id", id)
  vim.api.nvim_buf_set_var(buf, "piper_cmd", cmd)
  if parent_id then
    vim.api.nvim_buf_set_var(buf, "piper_parent", parent_id)
  end

  -- Register in our mapping
  M.buffers[id] = buf

  -- Try to detect filetype from content
  vim.api.nvim_buf_call(buf, function()
    vim.cmd("filetype detect")
  end)

  return buf, id
end

-- Get current buffer's piper_id if it's a piper buffer
local function get_current_piper_id()
  local ok, id = pcall(vim.api.nvim_buf_get_var, 0, "piper_id")
  if ok then
    return id
  end
  return nil
end

-- Get buffer content as string
local function get_buffer_content(buf)
  buf = buf or 0
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  return table.concat(lines, "\n")
end

-- Write content to temp file and return path
local function write_temp_file(content, suffix)
  local tmp = vim.fn.tempname() .. (suffix or "")
  local f = io.open(tmp, "w")
  if f then
    f:write(content)
    f:close()
  end
  return tmp
end

-- Read content from file
local function read_file(path)
  local f = io.open(path, "r")
  if not f then
    return nil
  end
  local content = f:read("*a")
  f:close()
  return content
end

-- Delete file if it exists
local function delete_file(path)
  if path and vim.fn.filereadable(path) == 1 then
    vim.fn.delete(path)
  end
end

-- Check if a buffer is a piper buffer
local function is_piper_buffer(buf)
  local ok = pcall(vim.api.nvim_buf_get_var, buf, "piper_id")
  return ok
end

-- Get all windows showing piper buffers, sorted by row position (top to bottom)
local function get_piper_windows()
  local piper_wins = {}
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if is_piper_buffer(buf) then
      local pos = vim.api.nvim_win_get_position(win)
      table.insert(piper_wins, { win = win, row = pos[1] })
    end
  end
  -- Sort by row position (topmost first)
  table.sort(piper_wins, function(a, b)
    return a.row < b.row
  end)
  return piper_wins
end

-- Check if a buffer is empty and unnamed (like the default buffer on startup)
local function is_empty_unnamed_buffer(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  -- Check if buffer has no name
  local name = vim.api.nvim_buf_get_name(buf)
  if name ~= "" then
    return false
  end
  -- Check if buffer is empty (0 or 1 empty line)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  if #lines > 1 then
    return false
  end
  if #lines == 1 and lines[1] ~= "" then
    return false
  end
  -- Check if buffer is unmodified
  if vim.bo[buf].modified then
    return false
  end
  -- Check if it's a normal buffer (not special)
  if vim.bo[buf].buftype ~= "" then
    return false
  end
  return true
end

-- Open buffer in a new horizontal split below, managing visible window count
local function open_buffer(buf)
  -- If current buffer is empty and unnamed (default startup buffer),
  -- just replace it instead of creating a split
  if is_empty_unnamed_buffer() then
    vim.api.nvim_set_current_buf(buf)
    return
  end

  -- Create horizontal split below and show the new buffer
  vim.cmd("rightbelow split")
  vim.api.nvim_set_current_buf(buf)

  -- Get all piper windows after the split
  local piper_wins = get_piper_windows()

  -- If we have more than max_visible piper windows, close the topmost one
  while #piper_wins > M.config.max_visible do
    local topmost = piper_wins[1]
    -- Don't close the window we just created
    if topmost.win ~= vim.api.nvim_get_current_win() then
      vim.api.nvim_win_close(topmost.win, false)
    end
    piper_wins = get_piper_windows()
  end
end

-- Pipe command: opens small terminal with pipe-prompt
function M.pipe()
  local content = get_buffer_content()
  local parent_id = get_current_piper_id()
  local prev_win = vim.api.nvim_get_current_win()

  -- Create temp files
  local input_file = write_temp_file(content, ".piper_in")
  local output_file = vim.fn.tempname() .. ".piper_out"
  local cmd_file = vim.fn.tempname() .. ".piper_cmd"

  -- Ensure output and cmd files exist (empty)
  io.open(output_file, "w"):close()
  io.open(cmd_file, "w"):close()

  -- Create terminal buffer
  local term_buf = vim.api.nvim_create_buf(false, true)

  -- Open terminal in a split at bottom
  vim.cmd("botright " .. M.config.prompt_height .. "split")
  local term_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(term_win, term_buf)

  -- Start the pipe-prompt script
  local bin_dir = get_bin_dir()
  local pipe_prompt = bin_dir .. "/pipe-prompt"

  vim.fn.termopen({ pipe_prompt, input_file, output_file, cmd_file }, {
    on_exit = function(_, exit_code, _)
      -- Clean up terminal window
      if vim.api.nvim_win_is_valid(term_win) then
        vim.api.nvim_win_close(term_win, true)
      end

      -- Read the command that was executed
      local cmd = read_file(cmd_file)
      if cmd then
        cmd = cmd:gsub("[\n\r]+$", "")
      end

      -- Check if output file has content
      local output = read_file(output_file)

      -- Clean up temp files
      delete_file(input_file)
      delete_file(output_file)
      delete_file(cmd_file)

      -- Return focus to previous window if valid
      if vim.api.nvim_win_is_valid(prev_win) then
        vim.api.nvim_set_current_win(prev_win)
      end

      -- Handle results
      if exit_code ~= 0 then
        if cmd and cmd ~= "" then
          vim.notify("Pipe command failed with exit code " .. exit_code, vim.log.levels.ERROR)
        end
        return
      end

      if not output or output == "" then
        vim.notify("Pipe produced no output", vim.log.levels.WARN)
        return
      end

      if not cmd or cmd == "" then
        return
      end

      -- Create new piper buffer with output
      local new_buf, _ = create_piper_buffer(output, cmd, parent_id)
      open_buffer(new_buf)
    end,
  })

  -- Enter insert mode in terminal
  vim.cmd("startinsert")
end

-- Pipet command: opens larger terminal with user's shell
function M.pipet()
  local content = get_buffer_content()
  local parent_id = get_current_piper_id()
  local prev_win = vim.api.nvim_get_current_win()

  -- Create temp files for $IN and $OUT
  local in_file = write_temp_file(content, ".piper_in")
  local out_file = vim.fn.tempname() .. ".piper_out"

  -- Ensure output file exists (empty)
  io.open(out_file, "w"):close()

  -- Create terminal buffer
  local term_buf = vim.api.nvim_create_buf(false, true)

  -- Open terminal in a split at bottom
  vim.cmd("botright " .. M.config.terminal_height .. "split")
  local term_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(term_win, term_buf)

  -- Start user's shell with IN and OUT environment variables
  local shell = M.config.shell
  local env = {
    IN = in_file,
    OUT = out_file,
  }

  vim.fn.termopen({ shell }, {
    env = env,
    on_exit = function(_, _, _)
      -- Clean up terminal window
      if vim.api.nvim_win_is_valid(term_win) then
        vim.api.nvim_win_close(term_win, true)
      end

      -- Check if output file has content
      local output = read_file(out_file)

      -- Clean up temp files
      delete_file(in_file)
      delete_file(out_file)

      -- Return focus to previous window if valid
      if vim.api.nvim_win_is_valid(prev_win) then
        vim.api.nvim_set_current_win(prev_win)
      end

      if not output or output == "" then
        return
      end

      -- Create new piper buffer with output
      -- For shell sessions, we use a generic command indicator
      local new_buf, _ = create_piper_buffer(output, "$SHELL > $OUT", parent_id)
      open_buffer(new_buf)
    end,
  })

  -- Enter insert mode in terminal
  vim.cmd("startinsert")
end

-- PipeLoad command: bootstrap a new piper buffer from file or command
function M.pipe_load(source)
  if not source or source == "" then
    vim.notify("PipeLoad requires a source (file path or !command)", vim.log.levels.ERROR)
    return
  end

  local content
  local cmd

  if source:sub(1, 1) == "!" then
    -- Command mode
    cmd = source
    local shell_cmd = source:sub(2)
    local output = vim.fn.system(shell_cmd)
    if vim.v.shell_error ~= 0 then
      vim.notify("Command failed with exit code " .. vim.v.shell_error, vim.log.levels.ERROR)
      return
    end
    content = output
  else
    -- File mode
    cmd = source
    local expanded = vim.fn.expand(source)
    if vim.fn.filereadable(expanded) ~= 1 then
      vim.notify("Cannot read file: " .. source, vim.log.levels.ERROR)
      return
    end
    content = read_file(expanded)
    if not content then
      vim.notify("Failed to read file: " .. source, vim.log.levels.ERROR)
      return
    end
  end

  -- Create new piper buffer (no parent for initial loads)
  local buf, _ = create_piper_buffer(content, cmd, nil)
  open_buffer(buf)
end

-- PipeLoadPrompt command: interactive prompt to load command output
function M.pipe_load_prompt()
  local prev_win = vim.api.nvim_get_current_win()

  -- Create temp files
  local output_file = vim.fn.tempname() .. ".piper_out"
  local cmd_file = vim.fn.tempname() .. ".piper_cmd"

  -- Ensure output and cmd files exist (empty)
  io.open(output_file, "w"):close()
  io.open(cmd_file, "w"):close()

  -- Create terminal buffer
  local term_buf = vim.api.nvim_create_buf(false, true)

  -- Open terminal in a split at bottom
  vim.cmd("botright " .. M.config.prompt_height .. "split")
  local term_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(term_win, term_buf)

  -- Start the pipe-load-prompt script
  local bin_dir = get_bin_dir()
  local pipe_load_prompt_script = bin_dir .. "/pipe-load-prompt"

  vim.fn.termopen({ pipe_load_prompt_script, output_file, cmd_file }, {
    on_exit = function(_, exit_code, _)
      -- Clean up terminal window
      if vim.api.nvim_win_is_valid(term_win) then
        vim.api.nvim_win_close(term_win, true)
      end

      -- Read the command that was executed
      local cmd = read_file(cmd_file)
      if cmd then
        cmd = cmd:gsub("[\n\r]+$", "")
      end

      -- Check if output file has content
      local output = read_file(output_file)

      -- Clean up temp files
      delete_file(output_file)
      delete_file(cmd_file)

      -- Return focus to previous window if valid
      if vim.api.nvim_win_is_valid(prev_win) then
        vim.api.nvim_set_current_win(prev_win)
      end

      -- Handle results
      if exit_code ~= 0 then
        if cmd and cmd ~= "" then
          vim.notify("Load command failed with exit code " .. exit_code, vim.log.levels.ERROR)
        end
        return
      end

      if not output or output == "" then
        vim.notify("Load produced no output", vim.log.levels.WARN)
        return
      end

      if not cmd or cmd == "" then
        return
      end

      -- Create new piper buffer with output (no parent for loads)
      local new_buf, _ = create_piper_buffer(output, "!" .. cmd, nil)
      open_buffer(new_buf)
    end,
  })

  -- Enter insert mode in terminal
  vim.cmd("startinsert")
end

-- PipeList command: show all piper buffers with lineage
function M.pipe_list()
  local prev_win = vim.api.nvim_get_current_win()

  -- Collect valid piper buffers
  local entries = {}
  local valid_buffers = {}

  for id, buf in pairs(M.buffers) do
    if vim.api.nvim_buf_is_valid(buf) then
      valid_buffers[id] = buf
      local ok_cmd, cmd = pcall(vim.api.nvim_buf_get_var, buf, "piper_cmd")
      local ok_parent, parent = pcall(vim.api.nvim_buf_get_var, buf, "piper_parent")
      local line_count = vim.api.nvim_buf_line_count(buf)

      table.insert(entries, {
        id = id,
        buf = buf,
        parent = ok_parent and parent or nil,
        cmd = ok_cmd and cmd or "?",
        lines = line_count,
      })
    end
  end

  -- Update buffers table to only valid ones
  M.buffers = valid_buffers

  -- Sort by id
  table.sort(entries, function(a, b)
    return a.id < b.id
  end)

  if #entries == 0 then
    vim.notify("No piper buffers", vim.log.levels.INFO)
    return
  end

  -- Calculate column widths
  local max_id = 1
  local max_parent = 6
  local max_lines = 5

  for _, e in ipairs(entries) do
    max_id = math.max(max_id, #tostring(e.id))
    max_parent = math.max(max_parent, e.parent and #tostring(e.parent) or 1)
    max_lines = math.max(max_lines, #tostring(e.lines))
  end

  -- Ensure minimum widths for headers
  max_id = math.max(max_id, 1)
  max_parent = math.max(max_parent, 6)
  max_lines = math.max(max_lines, 5)

  -- Build display lines
  local display_lines = {}
  local header = string.format(
    " %" .. max_id .. "s │ %" .. max_parent .. "s │ %" .. max_lines .. "s │ %s",
    "#",
    "Parent",
    "Lines",
    "Command"
  )
  table.insert(display_lines, header)

  local sep = string.rep("─", max_id + 2)
    .. "┼"
    .. string.rep("─", max_parent + 2)
    .. "┼"
    .. string.rep("─", max_lines + 2)
    .. "┼"
    .. string.rep("─", 40)
  table.insert(display_lines, sep)

  for _, e in ipairs(entries) do
    local parent_str = e.parent and tostring(e.parent) or "-"
    local line = string.format(
      " %" .. max_id .. "d │ %" .. max_parent .. "s │ %" .. max_lines .. "d │ %s",
      e.id,
      parent_str,
      e.lines,
      e.cmd
    )
    table.insert(display_lines, line)
  end

  -- Create list buffer
  local list_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[list_buf].buftype = "nofile"
  vim.bo[list_buf].bufhidden = "wipe"
  vim.bo[list_buf].swapfile = false
  vim.api.nvim_buf_set_name(list_buf, "piper://list")

  vim.api.nvim_buf_set_lines(list_buf, 0, -1, false, display_lines)
  vim.bo[list_buf].modifiable = false

  -- Store entries for keymap handlers
  vim.api.nvim_buf_set_var(list_buf, "piper_list_entries", entries)

  -- Open in a split
  vim.cmd("botright split")
  local list_win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(list_win, list_buf)

  -- Resize to fit content (max 15 lines)
  local height = math.min(#display_lines + 1, 15)
  vim.api.nvim_win_set_height(list_win, height)

  -- Move cursor to first entry (line 3, after header and separator)
  if #entries > 0 then
    vim.api.nvim_win_set_cursor(list_win, { 3, 0 })
  end

  -- Helper to get selected entry
  local function get_selected_entry()
    local line = vim.api.nvim_win_get_cursor(0)[1]
    local idx = line - 2 -- Account for header and separator
    if idx >= 1 and idx <= #entries then
      return entries[idx], idx
    end
    return nil, nil
  end

  -- Keymap: Enter - open selected buffer
  vim.keymap.set("n", "<CR>", function()
    local entry = get_selected_entry()
    if entry and vim.api.nvim_buf_is_valid(entry.buf) then
      vim.api.nvim_win_close(list_win, true)
      -- Return to previous window before opening split
      if vim.api.nvim_win_is_valid(prev_win) then
        vim.api.nvim_set_current_win(prev_win)
      end
      open_buffer(entry.buf)
    end
  end, { buffer = list_buf, nowait = true })

  -- Keymap: d - delete selected buffer
  vim.keymap.set("n", "d", function()
    local entry, idx = get_selected_entry()
    if entry then
      -- Remove from our tracking
      M.buffers[entry.id] = nil

      -- Wipe the buffer
      if vim.api.nvim_buf_is_valid(entry.buf) then
        vim.api.nvim_buf_delete(entry.buf, { force = true })
      end

      -- Remove from entries and refresh display
      table.remove(entries, idx)
      vim.api.nvim_buf_set_var(list_buf, "piper_list_entries", entries)

      if #entries == 0 then
        vim.api.nvim_win_close(list_win, true)
        vim.notify("No piper buffers remaining", vim.log.levels.INFO)
        return
      end

      -- Rebuild display
      local new_lines = { display_lines[1], display_lines[2] }
      for _, e in ipairs(entries) do
        local parent_str = e.parent and tostring(e.parent) or "-"
        local line = string.format(
          " %" .. max_id .. "d │ %" .. max_parent .. "s │ %" .. max_lines .. "d │ %s",
          e.id,
          parent_str,
          e.lines,
          e.cmd
        )
        table.insert(new_lines, line)
      end

      vim.bo[list_buf].modifiable = true
      vim.api.nvim_buf_set_lines(list_buf, 0, -1, false, new_lines)
      vim.bo[list_buf].modifiable = false

      -- Adjust cursor if needed
      local cursor = vim.api.nvim_win_get_cursor(0)
      if cursor[1] > #new_lines then
        vim.api.nvim_win_set_cursor(0, { #new_lines, 0 })
      end
    end
  end, { buffer = list_buf, nowait = true })

  -- Keymap: q or Esc - close list
  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(list_win, true)
  end, { buffer = list_buf, nowait = true })

  vim.keymap.set("n", "<Esc>", function()
    vim.api.nvim_win_close(list_win, true)
  end, { buffer = list_buf, nowait = true })
end

-- Setup function for user configuration
function M.setup(opts)
  opts = opts or {}
  M.config = vim.tbl_deep_extend("force", M.config, opts)

  -- Create user commands
  vim.api.nvim_create_user_command("Pipe", function()
    M.pipe()
  end, { desc = "Pipe current buffer through a shell command" })

  vim.api.nvim_create_user_command("Pipet", function()
    M.pipet()
  end, { desc = "Open terminal with $IN and $OUT for interactive piping" })

  vim.api.nvim_create_user_command("PipeLoad", function(cmd_opts)
    M.pipe_load(cmd_opts.args)
  end, { nargs = 1, complete = "file", desc = "Load file or command output into piper buffer" })

  vim.api.nvim_create_user_command("PipeList", function()
    M.pipe_list()
  end, { desc = "List all piper buffers" })

  vim.api.nvim_create_user_command("PipeLoadPrompt", function()
    M.pipe_load_prompt()
  end, { desc = "Prompt for command and load output into piper buffer" })
end

return M
