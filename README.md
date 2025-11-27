# 👀 Slime-peek

A Neovim plugin that adds several convenience functions for data exploration,
allowing you to swiftly peek at your R and Python objects together with
[vim-slime](https://github.com/jpalardy/vim-slime).

https://github.com/user-attachments/assets/8c4edeaa-859d-47d1-9f55-7dc70bc53a65

## ✨ Features

- Peek at the head / tail of the word under the cursor
- Peek at the column names of the word under the cursor
- Peek at the dimensions of the word under the cursor
- Peek at the data types / classes of the columns of the word under the cursor
- Operator/motion-based variants of the above that work on arbitrary expressions
  (_e.g._ `df$col`, slices, _etc._)
- Automatic language- and file type-detection for R and Python across scripts, R
  Markdown and Quarto

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

The `slime-peek` plugin supplies several operations, each with two variants: one
that uses the word under the cursor, and one that uses Vim's operator-pending
mode (a motion or text object) to select the text. Each word-based operation is
named e.g. `peek_head`, while its motion equivalent is named `peek_head_motion`.
The motion variants will enter operator-pending mode and wait for the user to
supply a motion or a text object before sending the final text to the REPL.

For R, operations like `peek_head` translate to commands such as `head(<text>)`.
For Python, they are translated to attribute or method accesses such as
`<text>.head()`; please see [the documentation](doc/slime-peek.nvim.txt) for
details. The plugin will automatically detect which language you are working
with, whether that be R / Python scripts or R Markdown / Quarto documents and
send the appropriate code using `vim-slime`.

`slime-peek` does not set any key mappings by default, but instead provides
several Lua functions and user-commands that you can set key binds for:

- `peek_head[_motion]`: Print the head of some text.
- `peek_tail[_motion]`: Print the tail of some text.
- `peek_names[_motion]`: Print the column names of some text.
- `peek_dims[_motion]`: Print the dimensions of some text.
- `peek_types[_motion]`: Print the data types of the columns of some text.
- `peek_help[_motion]`: Print the help pages of some text.

If you want to create a key map for the commands, you can do something like
this:

```lua
local peek = require("slime_peek")
vim.keymap.set('n', '<localleader>h', peek.peek_head)
vim.keymap.set('n', '<localleader>mh', peek.peek_head_motion)
```

Or the equivalent using the user-commands:

```lua
vim.keymap.set('n', '<localleader>h', ':PeekHead<CR>')
vim.keymap.set('n', '<localleader>mh', ':PeekHeadMotion<CR>')
```

The Lua functions are generally recommended for keymaps, but the user-commands
can be useful for experimentation and are used in the demo above.

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
    config = function()
        local peek = require("slime_peek")
        peek.setup({
            use_yaml_language = false,
        })
        -- Word under cursor mappings
        vim.keymap.set("n", "<localleader>h", peek.peek_head)
        vim.keymap.set("n", "<localleader>T", peek.peek_tail)
        vim.keymap.set("n", "<localleader>n", peek.peek_names)
        vim.keymap.set("n", "<localleader>d", peek.peek_dims)
        vim.keymap.set("n", "<localleader>t", peek.peek_types)
        vim.keymap.set("n", "<localleader>H", peek.peek_help)
        -- Motion mappings
        vim.keymap.set("n", "<localleader>mh", peek.peek_head_motion)
        vim.keymap.set("n", "<localleader>mT", peek.peek_tail_motion)
        vim.keymap.set("n", "<localleader>mn", peek.peek_names_motion)
        vim.keymap.set("n", "<localleader>md", peek.peek_dims_motion)
        vim.keymap.set("n", "<localleader>mt", peek.peek_types_motion)
        vim.keymap.set("n", "<localleader>mH", peek.peek_help_motion)
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

The plugin assumes you have `vim-slime` configured and a running REPL in e.g. a
Tmux pane or a Neovim terminal; `slime-peek` only constructs and sends commands,
it does not manage the REPL itself.

This plugin was originally just a few functions living in my Neovim config, but
I decided to formalise them into a plugin and share it with others. I hope you
find it useful!
