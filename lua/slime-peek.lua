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

--- Send commands to the REPL
-- Get the word under the cursor, the file language and the command and send it
-- to the REPL. Does not return anything; errors are handled upstream.
-- @param operation the operation to send
local function send_command_to_repl(operation)
    local word_under_cursor = vim.fn.expand("<cword>")
    local language = get_file_language()
    local command
    if language == "r" then
        command = get_r_command(operation, word_under_cursor)
    elseif language == "python" then
        command = get_python_command(operation, word_under_cursor)
    end
    if command then
        vim.cmd('SlimeSend0 "' .. command .. '"')
    end
end

-- User-facing functions, one for each supported operation
function M.peek_head()
    send_command_to_repl("head")
end
function M.peek_tail()
    send_command_to_repl("tail")
end
function M.peek_names()
    send_command_to_repl("names")
end
function M.peek_dimensions()
    send_command_to_repl("dim")
end
function M.peek_types()
    send_command_to_repl("dtypes")
end
function M.peek_help()
    send_command_to_repl("help")
end

-- Add user commands for main plugin functions
vim.api.nvim_create_user_command("PeekHead", M.peek_head, { desc = "Print the head of an object" })
vim.api.nvim_create_user_command("PeekTail", M.peek_tail, { desc = "Print the tail of an object" })
vim.api.nvim_create_user_command("PeekNames", M.peek_names, { desc = "Print the column names of an object" })
vim.api.nvim_create_user_command("PeekDimensions", M.peek_dimensions, { desc = "Print the dimensions of an object" })
vim.api.nvim_create_user_command("PeekTypes", M.peek_types, { desc = "Print the column types of an object" })
vim.api.nvim_create_user_command("PeekHelp", M.peek_help, { desc = "Print the help pages of an object" })

return M
