# env-hide.nvim

A Neovim plugin to hide sensitive content in `.env` files.

## Preview
![output](https://github.com/user-attachments/assets/6242bb2d-1ce3-43d7-8d4a-a85ad35d7c9f)


## Features

- Automatically detects `.env` files
- Hides values in environment variable files (replaces with asterisks)
- Toggle visibility with a simple command
- Preserves the actual file content (only changes display)

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  'MannuVilasara/env-hide.nvim',
  config = function()
    require('env-hide').setup()
  end
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  'MannuVilasara/env-hide.nvim',
  config = function()
    require('env-hide').setup()
  end
}
```

### Using [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'MannuVilasara/env-hide.nvim'
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

The plugin temporarily replaces the buffer content with hidden values (asterisks) when you enable hiding. The original values are stored in memory and automatically restored when:

- You toggle visibility with `:EnvShow` or `:EnvToggle`
- You save the file (`:w`) - the original values are saved, not the hidden ones
- You close the buffer

This means the actual file content is never modified - only what you see on screen changes.

## License

MIT
