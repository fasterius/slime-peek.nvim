if vim.g.loaded_slime_peek then
    return
end
vim.g.loaded_slime_peek = 1

-- 0.11.0 is required because `health.lua` uses `vim.health.start/ok/warn/
-- error`, which aren't available on older versions
if vim.fn.has("nvim-0.11.0") ~= 1 then
    vim.api.nvim_err_writeln(
        "slime-peek.nvim requires at least Neovim v0.11.0."
    )
    return
end

-- User-commands (word under cursor mode)
vim.api.nvim_create_user_command("PeekHead", function()
    require("slime_peek").peek_head()
end, { desc = "Print the head of a word" })
vim.api.nvim_create_user_command("PeekTail", function()
    require("slime_peek").peek_tail()
end, { desc = "Print the tail of a word" })
vim.api.nvim_create_user_command("PeekNames", function()
    require("slime_peek").peek_names()
end, { desc = "Print the column names of a word" })
vim.api.nvim_create_user_command("PeekDims", function()
    require("slime_peek").peek_dims()
end, { desc = "Print the dimensions of a word" })
vim.api.nvim_create_user_command("PeekTypes", function()
    require("slime_peek").peek_types()
end, { desc = "Print the column types of a word" })
vim.api.nvim_create_user_command("PeekHelp", function()
    require("slime_peek").peek_help()
end, { desc = "Print the help pages of a word" })

-- User-commands (operator/motion mode)
vim.api.nvim_create_user_command("PeekHeadMotion", function()
    require("slime_peek").peek_head_motion()
end, { desc = "Print the head of a motion" })
vim.api.nvim_create_user_command("PeekTailMotion", function()
    require("slime_peek").peek_tail_motion()
end, { desc = "Print the tail of a motion" })
vim.api.nvim_create_user_command("PeekNamesMotion", function()
    require("slime_peek").peek_names_motion()
end, { desc = "Print the column names of a motion" })
vim.api.nvim_create_user_command("PeekDimsMotion", function()
    require("slime_peek").peek_dims_motion()
end, { desc = "Print the dimensions of a motion" })
vim.api.nvim_create_user_command("PeekTypesMotion", function()
    require("slime_peek").peek_types_motion()
end, { desc = "Print the column types of a motion" })
vim.api.nvim_create_user_command("PeekHelpMotion", function()
    require("slime_peek").peek_help_motion()
end, { desc = "Print the help pages of a motion" })
