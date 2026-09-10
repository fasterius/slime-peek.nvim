local M = {}

local util = require("slime_peek.util")

---Get chunk language
---Check if cursor is inside a code chunk as well as parses and returns the
---language when this is the case.
---@return string|nil language
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
    if language == "python" or language == "r" or language == "julia" then
        return language
    else
        return util.raise_error("Quarto language '" .. language .. "' is not supported")
    end
end

---Get YAML header lines and store in a table
---@return table|nil
local function get_yaml_lines()
    -- Verify that the first line in the document is `---`
    local first_line = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
    if first_line ~= "---" then
        return util.raise_error("YAML header not found; Quarto document is malformed")
    end

    -- Find the closing `---` of the YAML header (starting from line 2)
    local yaml_end_line = nil
    local lines = vim.api.nvim_buf_get_lines(0, 1, -1, false)
    for i, line in ipairs(lines) do
        if line == "---" then
            yaml_end_line = i + 1 -- +1 since `nvim_buf_get_lines` is 0-indexed
            break
        end
    end
    if not yaml_end_line then
        return util.raise_error("YAML header not found; Quarto document is malformed")
    end

    -- Get the YAML content and store in a table
    return vim.api.nvim_buf_get_lines(0, 1, yaml_end_line - 1, false)
end

---Get YAML header language
---Check that the YAML header exists, is properly formatted and contains a
---language specification; return the language if this is the case.
---@return string|nil language
local function get_yaml_language()
    -- Read YAML header into table
    local yaml_lines = get_yaml_lines()
    if not yaml_lines then
        return
    end

    -- Loop over YAML header table and store relevant information
    local yaml = {}
    for _, line in ipairs(yaml_lines) do
        for _, key in ipairs({ "jupyter", "knitr", "engine" }) do
            -- Pattern works even for lines like `^knitr:$` with nothing after
            -- it, as it returns "" (empty string), which is truthy for later
            -- checks against e.g. `if yaml.knitr then ...`
            local value = line:match("^" .. key .. ":%s*(.*)$")
            if value then
                yaml[key] = value
            end
        end
    end

    -- Raise error if no match is found
    if not (yaml.engine or yaml.jupyter or yaml.knitr) then
        return util.raise_error("Quarto language specification not found in YAML header")
    end

    -- Parse the YAML specification line and return the language
    if yaml.knitr then
        return "r"
    elseif yaml.jupyter then
        if yaml.jupyter == "python" or yaml.jupyter == "python3" then
            return "python"
        elseif yaml.jupyter == "r" then
            return "r"
        elseif yaml.jupyter == "julia" or yaml.jupyter:match("^julia%-") then
            return "julia"
        else
            return util.raise_error("Kernel '" .. yaml.jupyter .. "' is not supported")
        end
    elseif yaml.engine == "jupyter" then
        return "python"
    elseif yaml.engine == "knitr" then
        return "r"
    else
        return util.raise_error("Engine '" .. yaml.engine .. "' is not supported")
    end
end

---Get language for current file
---Check the current filetype and gets the corresponding language as appropriate
---@param use_yaml_language boolean|nil whether to use the Quarto YAML header for
---language detection instead of the current code chunk's language
---@return string|nil language
function M.get_file_language(use_yaml_language)
    -- Access the filetype of the current buffer
    local filetype = vim.bo.filetype

    -- Check the filetype and return corresponding language
    if filetype == "r" or filetype == "rmd" then
        return "r"
    elseif filetype == "python" then
        return "python"
    elseif filetype == "julia" then
        return "julia"
    elseif filetype == "quarto" then
        if use_yaml_language then
            return get_yaml_language()
        else
            return get_chunk_language()
        end
    else
        return util.raise_error("Filetype '" .. filetype .. "' is not supported")
    end
end

return M
