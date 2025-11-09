-- lua/env-hide/init.lua
local M = {}

-- Default configuration
local default_config = {
  auto_hide = true,
  pattern = { '*.env', '.env.*', '*.env.*' },
  hide_char = '*',
  min_hide_length = 8,
  enable_keymaps = true,
  keymaps = {
    toggle = '<leader>et',
    hide = '<leader>eh',
    show = '<leader>es',
  }
}

-- Plugin state
local config = {}
local namespace = vim.api.nvim_create_namespace('env-hide')
local buffer_state = {}  -- Track which buffers are hidden

-- Check if a buffer is an env file
local function is_env_file(bufnr)
  local filename = vim.api.nvim_buf_get_name(bufnr)
  local basename = vim.fn.fnamemodify(filename, ':t')
  
  for _, pattern in ipairs(config.pattern) do
    if vim.fn.match(basename, vim.fn.glob2regpat(pattern)) ~= -1 then
      return true
    end
  end
  
  -- Also check filetype
  local ft = vim.bo[bufnr].filetype
  return ft == 'env' or ft == 'dotenv'
end

-- Parse a line and extract key-value pair
local function parse_env_line(line)
  -- Skip empty lines and comments
  if line:match('^%s*$') or line:match('^%s*#') then
    return nil
  end
  
  -- Match various .env formats:
  -- KEY=value
  -- KEY="value"
  -- KEY='value'
  -- export KEY=value
  local key, value = line:match('^%s*export%s+([%w_]+)%s*=%s*(.*)$')
  if not key then
    key, value = line:match('^%s*([%w_]+)%s*=%s*(.*)$')
  end
  
  if key and value then
    -- Remove quotes if present
    value = value:match('^"(.-)"$') or value:match("^'(.-)'$") or value
    return key, value
  end
  
  return nil
end

-- Create hidden text for a value
local function create_hidden_text(value)
  local length = math.max(#value, config.min_hide_length)
  return string.rep(config.hide_char, length)
end

-- Hide sensitive values in the buffer
function M.hide(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  
  if not is_env_file(bufnr) then
    vim.notify('Current buffer is not an .env file', vim.log.levels.WARN)
    return
  end
  
  -- Clear existing marks
  vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
  
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  
  for line_num, line in ipairs(lines) do
    local key, value = parse_env_line(line)
    
    if key and value and #value > 0 then
      -- Find the position of the value in the line
      local _, value_start = line:find(key .. '%s*=%s*["\']?')
      
      if value_start then
        -- Check if value is quoted
        local is_quoted = line:sub(value_start, value_start):match('["\']')
        local value_col = value_start
        if is_quoted then
          value_col = value_start + 1
        end
        
        -- Create virtual text to hide the value
        local hidden_text = create_hidden_text(value)
        
        vim.api.nvim_buf_set_extmark(bufnr, namespace, line_num - 1, value_col - 1, {
          end_col = value_col - 1 + #value,
          conceal = config.hide_char,
          virt_text = { { hidden_text, 'Comment' } },
          virt_text_pos = 'overlay',
        })
      end
    end
  end
  
  buffer_state[bufnr] = true
  vim.notify('Environment values hidden', vim.log.levels.INFO)
end

-- Show actual values in the buffer
function M.show(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  
  if not is_env_file(bufnr) then
    vim.notify('Current buffer is not an .env file', vim.log.levels.WARN)
    return
  end
  
  vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
  buffer_state[bufnr] = false
  vim.notify('Environment values shown', vim.log.levels.INFO)
end

-- Toggle between hidden and shown states
function M.toggle(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  
  if buffer_state[bufnr] then
    M.show(bufnr)
  else
    M.hide(bufnr)
  end
end

-- Setup keymaps for a buffer
local function setup_buffer_keymaps(bufnr)
  if not config.enable_keymaps then
    return
  end
  
  local opts = { buffer = bufnr, silent = true, noremap = true }
  
  vim.keymap.set('n', config.keymaps.toggle, function()
    M.toggle(bufnr)
  end, vim.tbl_extend('force', opts, { desc = 'Toggle env values visibility' }))
  
  vim.keymap.set('n', config.keymaps.hide, function()
    M.hide(bufnr)
  end, vim.tbl_extend('force', opts, { desc = 'Hide env values' }))
  
  vim.keymap.set('n', config.keymaps.show, function()
    M.show(bufnr)
  end, vim.tbl_extend('force', opts, { desc = 'Show env values' }))
end

-- Auto-hide when opening env files
local function setup_autocommands()
  local group = vim.api.nvim_create_augroup('EnvHide', { clear = true })
  
  vim.api.nvim_create_autocmd({ 'BufRead', 'BufNewFile' }, {
    group = group,
    pattern = config.pattern,
    callback = function(args)
      local bufnr = args.buf
      
      -- Set filetype if not already set
      if vim.bo[bufnr].filetype == '' then
        vim.bo[bufnr].filetype = 'env'
      end
      
      -- Setup keymaps
      setup_buffer_keymaps(bufnr)
      
      -- Auto-hide if enabled
      if config.auto_hide then
        vim.defer_fn(function()
          if vim.api.nvim_buf_is_valid(bufnr) then
            M.hide(bufnr)
          end
        end, 100)
      end
    end,
  })
  
  -- Re-hide after editing if buffer was hidden
  vim.api.nvim_create_autocmd('TextChanged', {
    group = group,
    pattern = config.pattern,
    callback = function(args)
      local bufnr = args.buf
      if buffer_state[bufnr] then
        vim.defer_fn(function()
          if vim.api.nvim_buf_is_valid(bufnr) then
            M.hide(bufnr)
          end
        end, 50)
      end
    end,
  })
  
  -- Clean up buffer state when buffer is deleted
  vim.api.nvim_create_autocmd('BufDelete', {
    group = group,
    callback = function(args)
      buffer_state[args.buf] = nil
    end,
  })
end

-- Setup function
function M.setup(user_config)
  config = vim.tbl_deep_extend('force', default_config, user_config or {})
  
  -- Setup autocommands
  setup_autocommands()
end

return M
