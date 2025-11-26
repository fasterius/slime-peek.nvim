local M = {}

local util = require("slime_peek.util")

-- Default configuration (can be overridden by main setup call)
M.opts = {
    use_yaml_language = false,
}

-- Setup with options
function M.setup(opts)
    M.opts = vim.tbl_extend("force", M.opts, opts or {})
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
        return util.raise_error("Cannot find chunk header")
    end

    -- Find a chunk end forwards from the cursor position; if it can't be found
    -- the cursor is outside a chunk at the end of the file
    local end_forward = vim.fn.search("^```$", "nW")
    if end_forward == 0 then
        return util.raise_error("Cannot find chunk ending")
    end

    -- Find a chunk start forwards from the cursor position; if it's found and
    -- is at a line number smaller than the previously found forward chunk end
    -- the cursor is outside of a chunk
    local start_forward = vim.fn.search("^```{", "nW")
    if start_forward > 0 and start_forward < end_forward then
        return util.raise_error("Cursor is not inside a valid code chunk")
    end

    -- Parse the chunk header and find the specified language
    local chunk_header = vim.fn.getline(start_backward)
    local language = chunk_header:match("^```{([%a]+)")
    if language == "python" or language == "r" then
        return language
    else
        return util.raise_error("Quarto language '" .. language .. "' is not supported")
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
        return util.raise_error("YAML header not found; Quarto document is malformed")
    end

    -- Search through the YAML header and get the line with language information
    local pattern = "^knitr:\\|^jupyter:\\|^engine:"
    local line_number = vim.fn.search(pattern, "nW", yaml_end_line)

    -- Reset cursor position as all searches are now done, but before checking
    -- if a match is found
    vim.api.nvim_win_set_cursor(0, original_cursor_position)

    -- Raise error if no match is found
    if line_number == 0 then
        return util.raise_error("Quarto language specification not found in YAML header")
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
            return util.raise_error("Engine " .. engine .. " is not supported")
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
            return util.raise_error("Kernel '" .. kernel .. "' is not supported")
        end
    end
end

--- Get language for current file
-- Check the current filetype and gets the corresponding language as appropriate
-- @return language
function M.get_file_language()
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
        return util.raise_error("Filetype '" .. filetype .. "' is not supported")
    end
end

return M
