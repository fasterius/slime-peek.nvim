local M = {}

-- Default configuration
M.opts = {
    use_yaml_language = false,
}

-- Setup with options
function M.setup(opts)
    M.opts = vim.tbl_extend("force", M.opts, opts or {})
end

--- Error handling
-- Handle plugin errors by printing an error message and returning `nil` so that
-- execution can gracefully complete.
-- @param message the error message
-- @return nil
local function raise_error(message)
    vim.notify("Error: " .. message, vim.log.levels.ERROR)
    return nil
end

--- Get chunk language
-- Check if cursor is inside a code chunk as well as parses and returns the
-- language when this is the case.
-- @return language
local function get_chunk_language()
    -- Find a chunk start (header) backwards from the cursor position; if it
    -- can't be found the cursor is outside a chunk at the beginning of the file
    local start_backward = vim.fn.search("^```{", "nbW")
    if start_backward == 0 then
        return raise_error("Cannot find chunk header")
    end

    -- Find a chunk end forwards from the cursor position; if it can't be found
    -- the cursor is outside a chunk at the end of the file
    local end_forward = vim.fn.search("^```$", "nW")
    if end_forward == 0 then
        return raise_error("Cannot find chunk ending")
    end

    -- Find a chunk start forwards from the cursor position; if it's found and
    -- is at a line number smaller than the previously found forward chunk end
    -- the cursor is outside of a chunk
    local start_forward = vim.fn.search("^```{", "nW")
    if start_forward > 0 and start_forward < end_forward then
        return raise_error("Cursor is not inside a valid code chunk")
    end

    -- Parse the chunk header and find the specified language
    local chunk_header = vim.fn.getline(start_backward)
    local language = chunk_header:match("^```{([%a]+)")
    if language == "python" or language == "r" then
        return language
    else
        return raise_error("Quarto language '" .. language .. "' is not supported")
    end
end

--- Get YAML header language
-- Check that the YAML header exists, is properly formatted and contains a
-- language specification; return the language if this is the case.
-- @return language
local function get_yaml_language()
    -- Store the current cursor position and set the cursor position to the
    -- beginning of the file, so that we can search for the YAML header
    local original_cursor_position = vim.api.nvim_win_get_cursor(0)
    vim.api.nvim_win_set_cursor(0, { 1, 0 })

    -- Get the line number for the end of the YAML header
    local yaml_end_line = vim.fn.search("^---$", "nW")

    -- Abort if no YAML header found
    if yaml_end_line == 0 then
        vim.api.nvim_win_set_cursor(0, original_cursor_position)
        return raise_error("YAML header not found; Quarto document is malformed")
    end

    -- Search through the YAML header and get the line with language information
    local pattern = "^knitr:\\|^jupyter:\\|^engine:"
    local line_number = vim.fn.search(pattern, "nW", yaml_end_line)

    -- Reset cursor position as all searches are now done, but before checking
    -- if a match is found
    vim.api.nvim_win_set_cursor(0, original_cursor_position)

    -- Raise error if no match is found
    if line_number == 0 then
        return raise_error("Quarto language specification not found in YAML header")
    end

    -- Parse the engine specification line and return the language
    local line = vim.split(vim.fn.getline(line_number), "%s+")
    local engine_spec = line[1]
    if engine_spec == "engine:" then
        local engine = line[2]
        if engine == "knitr" then
            return "r"
        elseif engine == "jupyter" then
            return "python"
        else
            return raise_error("Engine " .. engine .. " is not supported")
        end
    elseif engine_spec == "knitr:" then
        return "r"
    elseif engine_spec == "jupyter:" then
        local kernel = line[2]
        if kernel == "python" or kernel == "python3" then
            return "python"
        elseif kernel == "r" then
            return "r"
        else
            return raise_error("Kernel '" .. kernel .. "' is not supported")
        end
    end
end

--- Get language for current file
-- Check the current filetype and gets the corresponding language as appropriate
-- @return language
local function get_file_language()
    -- Access the filetype of the current buffer
    local filetype = vim.bo.filetype

    -- Check the filetype and return corresponding language
    if filetype == "r" or filetype == "rmd" then
        return "r"
    elseif filetype == "python" then
        return "python"
    elseif filetype == "quarto" then
        if M.opts.use_yaml_language then
            return get_yaml_language()
        else
            return get_chunk_language()
        end
    else
        return raise_error("Filetype '" .. filetype .. "' is not supported")
    end
end

--- Handle R-specific commands
-- Handle differing operation names between R and Python as well as whether the
-- operation is a non-trivial function call with extra code.
-- @param operation the operation to perform
-- @param object the object to perform the operation on
-- @return a string with the complete command
local function get_r_command(operation, object)
    local extra = ""
    if operation == "dtypes" then
        operation = "sapply"
        extra = ", class"
    end
    return operation .. "(" .. object .. extra .. ")\\n"
end

--- Handle Python-specific commands
-- Handle differing operation names between R and Python as well as whether the
-- command pertains to an attribute (without parentheses) or a method (with
-- parentheses)
-- @param operation the operation to perform
-- @object object the object to perform the operation on
-- @return a string with the complete command
local function get_python_command(operation, object)
    if operation == "help" then
        return operation .. "(" .. object .. ")\\n"
    end
    local parentheses = "()"
    if operation == "names" then
        operation = "columns.tolist"
    elseif operation == "dim" then
        operation = "shape"
        parentheses = ""
    elseif operation == "dtypes" then
        parentheses = ""
    end
    return object .. "." .. operation .. parentheses .. "\\n"
end

--- Extract text from the last operator/motion range
-- Extract the text given by the last user-specified operation/motion that is
-- meant to be sent to the REPL.
-- @return a string with the selected text
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
        raise_error("Multi-line selections are not supported")
    end

    -- The function is always called from the current buffer
    local bufnr = vim.api.nvim_get_current_buf()

    -- Get the line contents and return the text specified by the start and end
    -- positions. The `nvim_buf_get_lines()` function is 0-based for the start
    local line = vim.api.nvim_buf_get_lines(bufnr, start_line - 1, end_line, false)[1]
    if not line then
        return raise_error("Could not get line for operator range")
    end
    return string.sub(line, start_col, end_col)
end

--- Initialise states
-- All states are changed in the user-facing functions; `_operator` is a
-- boolean, while valid values for `_command` is specified by the user-facing
-- functions.
M._operator = false
M._command = nil

--- Send commands to the REPL
-- Get the text to be sent (either the word under the cursor or the text
-- specified by the last operator/motion), the file language and the command and
-- send it to the REPL. Does not return anything; errors are handled upstream.
-- Uses states specified in `_operator` and `_command`.
function M._send_command_to_repl()
    local language = get_file_language()
    -- Get the text to send either from the word under the cursor or a
    -- user-specified operator/motion
    local text
    if M._operator then
        text = get_text_from_operator_range()
    else
        text = vim.fn.expand("<cword>")
    end
    -- Build the per-language command
    local command
    if language == "r" then
        command = get_r_command(M._command, text)
    elseif language == "python" then
        command = get_python_command(M._command, text)
    end
    -- Send to the REPL
    if command then
        vim.cmd('SlimeSend0 "' .. command .. '"')
    end
end

--- Send commands to the REPL using operator mode
-- Get the text from the user-specified operator/motion rather than the word
-- under the cursor.
function M._send_command_to_repl_with_operator()
    vim.o.operatorfunc = "v:lua.require'slime-peek'._send_command_to_repl"
    vim.api.nvim_feedkeys("g@", "n", false)
end

-- User-facing functions (word under cursor mode)
function M.peek_head()
    M._operator = false
    M._command = "head"
    M._send_command_to_repl()
end
function M.peek_tail()
    M._operator = false
    M._command = "tail"
    M._send_command_to_repl()
end
function M.peek_names()
    M._operator = false
    M._command = "names"
    M._send_command_to_repl()
end
function M.peek_dims()
    M._operator = false
    M._command = "dim"
    M._send_command_to_repl()
end
function M.peek_types()
    M._operator = false
    M._command = "dtypes"
    M._send_command_to_repl()
end
function M.peek_help()
    M._operator = false
    M._command = "help"
    M._send_command_to_repl()
end

vim.api.nvim_create_user_command("PeekHead", M.peek_head, { desc = "Print the head of an object" })
vim.api.nvim_create_user_command("PeekTail", M.peek_tail, { desc = "Print the tail of an object" })
vim.api.nvim_create_user_command("PeekNames", M.peek_names, { desc = "Print the column names of an object" })
vim.api.nvim_create_user_command("PeekDims", M.peek_dims, { desc = "Print the dimensions of an object" })
vim.api.nvim_create_user_command("PeekTypes", M.peek_types, { desc = "Print the column types of an object" })
vim.api.nvim_create_user_command("PeekHelp", M.peek_help, { desc = "Print the help pages of an object" })

-- User-facing functions (operator mode)
function M.peek_head_op()
    M._operator = true
    M._command = "head"
    M._send_command_to_repl_with_operator()
end
function M.peek_tail_op()
    M._operator = true
    M._command = "tail"
    M._send_command_to_repl_with_operator()
end
function M.peek_names_op()
    M._operator = true
    M._command = "names"
    M._send_command_to_repl_with_operator()
end
function M.peek_dims_op()
    M._operator = true
    M._command = "dim"
    M._send_command_to_repl_with_operator()
end
function M.peek_types_op()
    M._operator = true
    M._command = "dtypes"
    M._send_command_to_repl_with_operator()
end
function M.peek_help_op()
    M._operator = true
    M._command = "help"
    M._send_command_to_repl_with_operator()
end

vim.api.nvim_create_user_command("PeekHeadOp", M.peek_head_op, { desc = "Print the head of an object" })
vim.api.nvim_create_user_command("PeekTailOp", M.peek_tail_op, { desc = "Print the tail of an object" })
vim.api.nvim_create_user_command("PeekNamesOp", M.peek_names_op, { desc = "Print the column names of an object" })
vim.api.nvim_create_user_command("PeekDimsOp", M.peek_dims_op, { desc = "Print the dimensions of an object" })
vim.api.nvim_create_user_command("PeekTypesOp", M.peek_types_op, { desc = "Print the column types of an object" })
vim.api.nvim_create_user_command("PeekHelpOp", M.peek_help_op, { desc = "Print the help pages of an object" })

return M
