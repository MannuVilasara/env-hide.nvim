-- plugin/env-hide.lua
-- Entry point for the env-hide plugin

if vim.g.loaded_env_hide then
  return
end
vim.g.loaded_env_hide = true

-- Create commands
vim.api.nvim_create_user_command('EnvHide', function()
  require('env-hide').hide()
end, {})

vim.api.nvim_create_user_command('EnvShow', function()
  require('env-hide').show()
end, {})

vim.api.nvim_create_user_command('EnvToggle', function()
  require('env-hide').toggle()
end, {})
