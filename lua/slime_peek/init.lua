local M = {}

local commands = require("slime_peek.commands")
local lang = require("slime_peek.lang")
local util = require("slime_peek.util")

---@class slime_peek.Opts
---@field use_yaml_language? boolean

---Default configuration
---@type slime_peek.Opts
M.opts = {
    use_yaml_language = false,
}

---Setup with options and validation
---@param opts slime_peek.Opts|nil
function M.setup(opts)
    opts = opts or {}
    vim.validate({
        opts = { opts, "table" },
        ["opts.use_yaml_language"] = { opts.use_yaml_language, "boolean", true },
    })
    M.opts = vim.tbl_extend("force", M.opts, opts)
end

---Extract text from the last operator/motion range
---Extract the text given by the last user-specified operation/motion that is
---meant to be sent to the REPL.
---@return string text the selected text
local function get_text_from_operator_range()
    -- Get the positions of the start and end of the last operator/motion
    -- The `getpos()` function returns {bufnum, lnum, col, off}
    local start_pos = vim.fn.getpos("'[")
    local end_pos = vim.fn.getpos("']")

    -- Lines are 1-based; columns are 1-based and inclusive
    local start_line = start_pos[2]
    local start_col = start_pos[3]
    local end_line = end_pos[2]
    local end_col = end_pos[3]

    -- Enforce single-line selection
    if start_line ~= end_line then
        util.raise_error("Multi-line selections are not supported")
    end

    -- The function is always called from the current buffer
    local bufnr = vim.api.nvim_get_current_buf()

    -- Get the line contents and return the text specified by the start and end
    -- positions. The `nvim_buf_get_lines()` function is 0-based for the start
    local line = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)[1]
    if not line then
        return util.raise_error("Could not get line for operator range")
    end
    return string.sub(line, start_col, end_col)
end

---Initialise states
---All states are changed in the user-facing functions; `_use_operator` is a
---boolean, while valid values for `_command` is specified by the user-facing
---functions.
---@type boolean
M._use_operator = false
---@type string|nil
M._command = nil

---Send commands to the REPL
---Get the text to be sent (either the word under the cursor or the text
---specified by the last operator/motion), the file language and the command and
---send it to the REPL. Does not return anything; errors are handled upstream.
---Uses states specified in `_use_operator` and `_command`.
function M._send_command_to_repl()
    local language = lang.get_file_language(M.opts.use_yaml_language)
    -- Get the text to send either from the word under the cursor or a
    -- user-specified operator/motion
    local text
    if M._use_operator then
        text = get_text_from_operator_range()
    else
        text = vim.fn.expand("<cword>")
    end
    -- Build the per-language command
    local command
    if language == "r" then
        command = commands.get_r_command(M._command, text)
    elseif language == "python" then
        command = commands.get_python_command(M._command, text)
    elseif language == "julia" then
        command = commands.get_julia_command(M._command, text)
    end
    -- Send to the REPL
    if command then
        vim.cmd('SlimeSend0 "' .. command .. '"')
    end
end

---Send commands to the REPL using operator mode
---Get the text from the user-specified operator/motion rather than the word
---under the cursor.
local function send_command_to_repl_with_operator()
    vim.o.operatorfunc = "v:lua.require'slime_peek'._send_command_to_repl"
    vim.api.nvim_feedkeys("g@", "n", false)
end

---Helper function for user-facing functions
---Reduce code duplication by having all individual per-command user-facing
---functions call this function with the correct command and whether to use
---operator mode.
---@param command string the operation to send to the REPL
---@param use_operator boolean whether to use operator/motion mode
local function peek_command(command, use_operator)
    M._use_operator = use_operator
    M._command = command
    if use_operator then
        send_command_to_repl_with_operator()
    else
        M._send_command_to_repl()
    end
end

-- User-facing functions (word under cursor mode)
function M.peek_head()
    peek_command("head", false)
end
function M.peek_tail()
    peek_command("tail", false)
end
function M.peek_names()
    peek_command("names", false)
end
function M.peek_dims()
    peek_command("dim", false)
end
function M.peek_types()
    peek_command("dtypes", false)
end
function M.peek_help()
    peek_command("help", false)
end

-- User-facing functions (operator/motion mode)
function M.peek_head_motion()
    peek_command("head", true)
end
function M.peek_tail_motion()
    peek_command("tail", true)
end
function M.peek_names_motion()
    peek_command("names", true)
end
function M.peek_dims_motion()
    peek_command("dim", true)
end
function M.peek_types_motion()
    peek_command("dtypes", true)
end
function M.peek_help_motion()
    peek_command("help", true)
end

return M
