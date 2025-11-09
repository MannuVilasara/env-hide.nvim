# env-hide.nvim

A Neovim plugin to hide sensitive content in `.env` files.

## Features

- Automatically detects `.env` files
- Hides values in environment variable files (replaces with asterisks)
- Toggle visibility with a simple command
- Preserves the actual file content (only changes display)

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'mannu/env-hide.nvim',
  ft = { 'env', 'dotenv' },
  config = function()
    require('env-hide').setup()
  end
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  'mannu/env-hide.nvim',
  config = function()
    require('env-hide').setup()
  end
}
```

### Using [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'mannu/env-hide.nvim'
```

Then add to your config:

```lua
require('env-hide').setup()
```

## Usage

### Commands

- `:EnvHide` - Hide sensitive values in the current buffer
- `:EnvShow` - Show actual values in the current buffer
- `:EnvToggle` - Toggle between hidden and shown states

### Configuration

```lua
require('env-hide').setup({
  -- Auto-hide when opening .env files
  auto_hide = true,

  -- Pattern to match env files
  pattern = { '*.env', '.env.*', '*.env.*' },

  -- Character to use for hiding
  hide_char = '*',

  -- Minimum number of hide characters to show
  min_hide_length = 8,

  -- Enable keymaps
  enable_keymaps = true,

  -- Custom keymaps (only used if enable_keymaps is true)
  keymaps = {
    toggle = '<leader>et',
    hide = '<leader>eh',
    show = '<leader>es',
  }
})
```

## How it works

The plugin uses Neovim's virtual text and extmarks to overlay asterisks on sensitive values without modifying the actual file content. When you save the file, the original values are preserved.

## License

MIT
