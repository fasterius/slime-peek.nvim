if vim.fn.has("nvim-0.7.0") ~= 1 then
    vim.api.nvim_err_writeln("slime-peek.nvim requires at least Neovim v0.7.0.")
end
