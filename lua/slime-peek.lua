local M = {}

-- Default configuration
M.opts = {
    use_yaml_language = false,
}

-- Setup with options
function M.setup(opts)
    M.opts = vim.tbl_extend("force", M.opts, opts or {})
end

-- Internal function for handling errors with a message
local function raise_error(message)
    vim.notify("Error: " .. message, vim.log.levels.ERROR)
    return nil
end

-- Internal readability-improving function for setting the cursor position
local function set_cursor_position(position)
    vim.api.nvim_win_set_cursor(0, position)
end

-- Internal function to get the language of a code chunk
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

-- Local function to get the language from the Quarto YAML header
local function get_yaml_language()
    -- Store the current cursor position
    local original_cursor_position = vim.api.nvim_win_get_cursor(0)

    -- Set cursor position to beginning of file
    set_cursor_position({ 1, 0 })

    -- Get the ending line number of the YAML header
    local yaml_end_line = vim.fn.search("^---$", "nW")

    -- Abort if no YAML header found
    if yaml_end_line == 0 then
        set_cursor_position(original_cursor_position)
        return raise_error("YAML header not found; Quarto document is malformed")
    end

    -- Search through the YAML header and get the line with language information
    local pattern = "^knitr:\\|^jupyter:\\|^engine:"
    local line_number = vim.fn.search(pattern, "nW", yaml_end_line)

    -- Reset cursor position
    set_cursor_position(original_cursor_position)

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

-- Internal function to get the language of the current file
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

-- Internal function to get language-specific commands
local function get_r_command(operation, object)
    -- Handle differing operation names between R and Python as well as whether
    -- the operation is a non-trivial function call with extra code
    local extra = ""
    if operation == "dtypes" then
        operation = "sapply"
        extra = ", class"
    end
    return operation .. "(" .. object .. extra .. ")\\n"
end

local function get_python_command(operation, object)
    -- Handle differing operation names between R and Python as well as whether
    -- the command pertains to an attribute (without parentheses) or a method
    -- (with parentheses)
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

-- Internal function to send a specific command to the REPL
local function send_command_to_repl(operation)
    -- Get the word under the cursor
    local word_under_cursor = vim.fn.expand("<cword>")

    -- Get the current language
    local language = get_file_language()

    -- Get the language-appropriate command
    local command
    if language == "r" then
        command = get_r_command(operation, word_under_cursor)
    elseif language == "python" then
        command = get_python_command(operation, word_under_cursor)
    end

    -- Send the command to the REPL
    if command then
        vim.cmd('SlimeSend0 "' .. command .. '"')
    end
end

-- Function to print the head of the data frame under the cursor
function M.peek_head()
    send_command_to_repl("head")
end

-- Function to print the tail of the data frame under the cursor
function M.peek_tail()
    send_command_to_repl("tail")
end

-- Function to print the column names of the data frame under the cursor
function M.peek_names()
    send_command_to_repl("names")
end

-- Function to print the dimensions of the data frame under the cursor
function M.peek_dimensions()
    send_command_to_repl("dim")
end

-- Function to print the column types of the data frame under the cursor
function M.peek_types()
    send_command_to_repl("dtypes")
end

-- Add user commands for main plugin functions
vim.api.nvim_create_user_command("PeekHead", M.peek_head, { desc = "Print the head of an object" })
vim.api.nvim_create_user_command("PeekTail", M.peek_tail, { desc = "Print the tail of an object" })
vim.api.nvim_create_user_command("PeekNames", M.peek_names, { desc = "Print the column names of an object" })
vim.api.nvim_create_user_command("PeekDimensions", M.peek_dimensions, { desc = "Print the dimensions of an object" })
vim.api.nvim_create_user_command("PeekTypes", M.peek_types, { desc = "Print the column types of an object" })

return M
