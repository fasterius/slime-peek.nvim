# 👀 Slime-peek

A Neovim plugin that adds several convenience functions for data exploration,
allowing you to swiftly peek at your R and Python objects together with
[vim-slime](https://github.com/jpalardy/vim-slime).

https://github.com/user-attachments/assets/8c4edeaa-859d-47d1-9f55-7dc70bc53a65

## ✨ Features

- Peek at the head / tail of the object under the cursor
- Peek at the column names of the object under the cursor
- Peek at the dimensions of the object under the cursor
- Peek at the data types / classes of the columns of the object under the cursor
- Automatic language- and file type-detection for R and Python

## 📚 Requirements

- Neovim >= **0.7.0**
- The [vim-slime](https://github.com/jpalardy/vim-slime) Vim plugin

## 📦 Installation

You can install the plugin with your preferred package manager:

```lua
{
    "fasterius/slime-peek.nvim",
    dependencies = "jpalardy/vim-slime",
    config = true,
}
```

## 🚀 Usage

`slime-peek` does not set any key mappings by default, but instead provides
several commands that you can set key binds for: The plugin will automatically
detect which language you are working with, whether that be R / Python scripts
or R Markdown / Quarto documents and send the appropriate code to `vim-slime`.
The commands available are as follows:

- `PeekHead`: Print the head of the word under the cursor.
- `PeekTail`: Print the tail of the word under the cursor.
- `PeekNames`: Print the column header of the word under the cursor.
- `PeekDimensions`: Print the dimensions of the word under the cursor.
- `PeekTypes`: Print the data types of the columns of the word under the cursor.

If you want to create a key map for the commands, you can do something like
this:

```lua
vim.keymap.set('n', '<localleader>h', ':PeekHead<CR>')
```

You can also access the underlying plugin function directly:

```lua
vim.keymap.set('n', '<localleader>h', require('slime-peek').peek_head)
```

> [!NOTE]
> Please note that `slime-peek` doesn't actually have any knowledge regarding
> the objects that are sent to your REPL, so if you try to get _e.g._ the
> dimensions of a dimensionless object you'll receive an error.

## ⚙️ Configuration

`slime-peek` comes with the following options and their respective defaults:

```lua
{
    -- Uses the Quarto YAML header for language detection instead of using the
    -- current code chunk's language. This is useful if you want to specify
    -- Quarto languages in a document-wide manner, rather than per code chunk.
    use_yaml_header = false
}
```

A complete installation and configuration might look something like this:

```lua
{
    "fasterius/slime-peek.nvim",
    dependencies = "jpalardy/vim-slime",
    keys = {
        { "<localleader>h" },
        { "<localleader>T" },
        { "<localleader>n" },
        { "<localleader>d" },
        { "<localleader>t" },
    },
    config = function()
        local peek = require("slime-peek")
        peek.setup({
            use_yaml_language = false,
        })
        vim.keymap.set("n", "<localleader>h", peek.peek_head)
        vim.keymap.set("n", "<localleader>T", peek.peek_tail)
        vim.keymap.set("n", "<localleader>n", peek.peek_names)
        vim.keymap.set("n", "<localleader>d", peek.peek_dimensions)
        vim.keymap.set("n", "<localleader>t", peek.peek_types)
    end,
}
```

> [!NOTE]
> Please note that `slime-peek` assumes that `vim-slime` has been correctly
> installed and configured.

## 📕 About

If you already perform data exploration and/or analyses using R / Python, Neovim
and [vim-slime](https://github.com/jpalardy/vim-slime) (or if you'd like to
start doing so), `slime-peek.nvim` is for you! The aim of this plugin is to
provide convenient ways for simple data exploration tasks while working with a
REPL using the `vim-slime` plugin. The tasks include things such as looking at
the head of a data frame or the column names of a data frame. These are not
complex tasks, but it is convenient to have them a shortcut away when working on
_e.g._ a Quarto document with some data analysis project.

The plugin will automatically detect which of the supported languages are
currently in use in your document, whether that be Python or R scripts, R
Markdown or Quarto documents. For scripts and R Markdown documents, the language
is inferred by the file type, as those documents are only used with their
respective programming language. For Quarto documents, `slime-peek` will check
the current code chunk's language by default, with an option to instead use the
language specified in the YAML header of the document (using either `engine:`,
`knitr:` or `jupyter:`).

This plugin was originally just a few functions living in my Neovim config, but
I decided to formalise them into a plugin and share it with others. I hope you
find it useful!
