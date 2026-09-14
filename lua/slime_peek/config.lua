local M = {}

---@class slime_peek.Opts
---@field use_yaml_language? boolean

---Default configuration
---@type slime_peek.Opts
M.defaults = {
    use_yaml_language = false,
}
M.opts = vim.deepcopy(M.defaults)

---Setup with options and validation
---@param opts slime_peek.Opts|nil
function M.setup(opts)
    opts = opts or {}
    vim.validate("opts", opts, "table")
    vim.validate(
        "opts.use_yaml_language",
        opts.use_yaml_language,
        "boolean",
        true
    )
    M.opts = vim.tbl_extend("force", M.opts, opts)
end

return M
