# 👀 Slime-peek

A Neovim plugin that adds convenience functions for data exploration using
[vim-slime](https://github.com/jpalardy/vim-slime).

<!-- TODO: Make a screencast to display as an example of plugin functionality. -->
<!-- https://github.com/fasterius/simple-zoom.nvim/assets/12528765/354e67fa-5bc0-4aae-a41d-5f0440de21ff -->

## ✨ Features

- Print the head of the word under the cursor
- Print the column names of the word under the cursor
- Automatic language-detection for R and Python

## 📚 Requirements

The [vim-slime](https://github.com/jpalardy/vim-slime) plugin.

<!-- TODO: Check through plugin code and find minimum Neovim version required. -->

## 📦 Installation

You can install the plugin with your preferred package manager:

```lua
{
    "fasterius/slime-peek.nvim",
    config = true,
}
```

## ⚙️ Configuration

`slime-peek` comes with the following options and their respective defaults:

```lua
{
    -- Description
    my_config_value = true
}
```

A more complete installation and configuration could look like this:

```lua
{
    "fasterius/slime-peek.nvim",
    opts = {
        my_config_value = true
    }
}
```

## 🚀 Usage

This plugin does not set any key mappings by default, but instead provides
several commands that you can set key binds for: The plugin will automatically
detect which language you are working with, whether that be R / Python scripts
or R Markdown / Quarto documents and send the appropriate code to `vim-slime`.
The commands available are as follows:

- `PrintHead`: Print the head of the word under the cursor.
- `PrintNames`: Print the column header of the word under the cursor.

If you want to create a key map for the commands, you can do something like
this:

```lua
vim.keymap.set('n', '<localleader>h', ':PrintHead<CR>')
```

You can also access the underlying plugin function directly in a slightly more
verbose way, if you prefer:

```lua
vim.keymap.set('n', '<localleader>h', require('slime-peek').printHead)
```

## 📕 About

If you already perform data exploration and/or analyses using R / Python, Neovim
and [vim-slime](https://github.com/jpalardy/vim-slime) (or if you'd like to
start doing so), `slime-peek.nvim` is for you! The aim of this plugin is to
provide convenient ways for simple data exploration tasks while working with a
REPL using the `vim-slime` plugin.

The tasks include things such as looking at the head of a data frame or the
column names of a data frame. These are not complex tasks, but it is convenient
to have them a shortcut away when working on _e.g._ a Quarto document with some
data analysis project. This plugin was originally functions living in my Neovim
config, but I decided to formalise them into a plugin and share it with others.
I hope you find it useful!
