local M = {}

local config = require("slime_peek.config")

---Run slime-peek's healthcheck
---Report on the presence of the plugin's requirements: a recent enough
---Neovim version, the `vim-slime` dependency, and flag any unrecognised
---configuration key set via `setup()`.
function M.check()
    vim.health.start("slime-peek.nvim")

    if vim.fn.has("nvim-0.11.0") == 1 then
        vim.health.ok("Neovim version is >= 0.11.0")
    else
        vim.health.error("Neovim version is too old", "slime-peek.nvim requires at least Neovim v0.11.0")
    end

    if vim.fn.exists(":SlimeSend0") == 2 then
        vim.health.ok("vim-slime is installed (`:SlimeSend0` is available)")
    else
        vim.health.error(
            "vim-slime does not appear to be installed",
            "Install https://github.com/jpalardy/vim-slime; slime-peek requires it to send text to a REPL"
        )
    end

    local unknown = {}
    for key in pairs(config.opts) do
        if config.defaults[key] == nil then
            table.insert(unknown, key)
        end
    end
    if #unknown == 0 then
        vim.health.ok("No unrecognised configuration options")
    else
        vim.health.warn(
            "Unrecognised configuration option(s): " .. table.concat(unknown, ", "),
            "Check for typos; see |slime-peek.configuration| for the supported options"
        )
    end
end

return M
