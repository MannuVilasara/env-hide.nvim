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
local hidden_buffers = {}  -- Store original content for hidden buffers

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
    return nil, nil, line
  end
  
  -- Match various .env formats:
  -- KEY=value
  -- KEY="value"
  -- KEY='value'
  -- export KEY=value
  local key, value
  local prefix = ''
  
  -- Check for export prefix
  if line:match('^%s*export%s+') then
    prefix = line:match('^(%s*export%s+)')
    local rest = line:sub(#prefix + 1)
    key, value = rest:match('^([%w_]+)%s*=%s*(.*)$')
  else
    key, value = line:match('^%s*([%w_]+)%s*=%s*(.*)$')
    prefix = line:match('^(%s*)') or ''
  end
  
  if key and value then
    -- Check if value is quoted
    local quote_char = ''
    local unquoted_value = value
    
    if value:match('^".-"$') then
      quote_char = '"'
      unquoted_value = value:match('^"(.-)"$')
    elseif value:match("^'.-'$") then
      quote_char = "'"
      unquoted_value = value:match("^'(.-)'$")
    end
    
    return key, unquoted_value, line, quote_char, prefix
  end
  
  return nil, nil, line
end

-- Create hidden text for a value
local function create_hidden_text(value)
  if #value == 0 then
    return ''
  end
  local length = math.max(#value, config.min_hide_length)
  return string.rep(config.hide_char, length)
end

-- Create a hidden version of a line
local function hide_line(line)
  local key, value, original, quote_char, prefix = parse_env_line(line)
  
  if not key or not value or #value == 0 then
    return line
  end
  
  local hidden_value = create_hidden_text(value)
  
  -- Reconstruct the line with hidden value
  if quote_char ~= '' then
    return prefix .. key .. '=' .. quote_char .. hidden_value .. quote_char
  else
    return prefix .. key .. '=' .. hidden_value
  end
end

-- Hide sensitive values in the buffer
function M.hide(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  
  if not is_env_file(bufnr) then
    vim.notify('Current buffer is not an .env file', vim.log.levels.WARN)
    return
  end
  
  -- Don't hide if already hidden
  if hidden_buffers[bufnr] then
    vim.notify('Buffer already hidden', vim.log.levels.INFO)
    return
  end
  
  -- Get original lines
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  
  -- Store original content
  hidden_buffers[bufnr] = {
    lines = vim.deepcopy(lines),
    modified = vim.bo[bufnr].modified
  }
  
  -- Create hidden lines
  local hidden_lines = {}
  for _, line in ipairs(lines) do
    table.insert(hidden_lines, hide_line(line))
  end
  
  -- Set buffer to modifiable temporarily
  local was_modifiable = vim.bo[bufnr].modifiable
  vim.bo[bufnr].modifiable = true
  
  -- Replace buffer content with hidden version
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, hidden_lines)
  
  -- Mark buffer as hidden (add indicator in virtual text)
  vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
  vim.api.nvim_buf_set_extmark(bufnr, namespace, 0, 0, {
    virt_text = { { '  [Values Hidden]', 'WarningMsg' } },
    virt_text_pos = 'eol',
  })
  
  -- Restore modifiable state
  vim.bo[bufnr].modifiable = was_modifiable
  
  -- Restore modified flag
  vim.bo[bufnr].modified = hidden_buffers[bufnr].modified
  
  vim.notify('Environment values hidden', vim.log.levels.INFO)
end

-- Show actual values in the buffer
function M.show(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  
  if not is_env_file(bufnr) then
    vim.notify('Current buffer is not an .env file', vim.log.levels.WARN)
    return
  end
  
  -- Check if buffer is hidden
  if not hidden_buffers[bufnr] then
    vim.notify('Buffer is not hidden', vim.log.levels.INFO)
    return
  end
  
  -- Set buffer to modifiable temporarily
  local was_modifiable = vim.bo[bufnr].modifiable
  vim.bo[bufnr].modifiable = true
  
  -- Restore original content
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, hidden_buffers[bufnr].lines)
  
  -- Clear virtual text
  vim.api.nvim_buf_clear_namespace(bufnr, namespace, 0, -1)
  
  -- Restore modifiable state
  vim.bo[bufnr].modifiable = was_modifiable
  
  -- Restore modified flag
  vim.bo[bufnr].modified = hidden_buffers[bufnr].modified
  
  -- Clear stored content
  hidden_buffers[bufnr] = nil
  
  vim.notify('Environment values shown', vim.log.levels.INFO)
end

-- Toggle between hidden and shown states
function M.toggle(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  
  if hidden_buffers[bufnr] then
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
        vim.bo[bufnr].filetype = 'dotenv'
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
  
  -- Before writing, restore original content if hidden
  vim.api.nvim_create_autocmd('BufWritePre', {
    group = group,
    pattern = config.pattern,
    callback = function(args)
      local bufnr = args.buf
      if hidden_buffers[bufnr] then
        -- Temporarily show to save original content
        local was_hidden = true
        M.show(bufnr)
        -- Mark that we need to re-hide after save
        hidden_buffers[bufnr] = { should_rehide = true }
      end
    end,
  })
  
  -- After writing, re-hide if it was hidden before
  vim.api.nvim_create_autocmd('BufWritePost', {
    group = group,
    pattern = config.pattern,
    callback = function(args)
      local bufnr = args.buf
      if hidden_buffers[bufnr] and hidden_buffers[bufnr].should_rehide then
        hidden_buffers[bufnr] = nil
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
      hidden_buffers[args.buf] = nil
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
