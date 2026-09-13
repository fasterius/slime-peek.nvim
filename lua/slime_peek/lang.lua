local M = {}

local util = require("slime_peek.util")

---Get chunk language
---Check if cursor is inside a code chunk as well as parses and returns the
---language when this is the case.
---@return string language
local function get_chunk_language()
    -- Find a chunk start (header) backwards from the cursor position; if it
    -- can't be found the cursor is outside a chunk at the beginning of the file
    local start_backward = vim.fn.search("^```{", "nbcW")
    if start_backward == 0 then
        error("Cannot find chunk header", 0)
    end

    -- Find a chunk end forwards from the cursor position; if it can't be found
    -- the cursor is outside a chunk at the end of the file
    local end_forward = vim.fn.search("^```$", "ncW")
    if end_forward == 0 then
        error("Cannot find chunk ending", 0)
    end

    -- Find a chunk start forwards from the cursor position; if it's found and
    -- is at a line number smaller than the previously found forward chunk end
    -- the cursor is outside of a chunk
    local start_forward = vim.fn.search("^```{", "nW")
    if start_forward > 0 and start_forward < end_forward then
        error("Cursor is not inside a valid code chunk", 0)
    end

    -- Parse the chunk header and find the specified language
    local chunk_header = vim.fn.getline(start_backward)
    local language = chunk_header:match("^```{([%a]+)")
    if language == "python" or language == "r" or language == "julia" then
        return language
    else
        error("Quarto language '" .. language .. "' is not supported", 0)
    end
end

---Get YAML header lines and store in a table
---@return table lines
local function get_yaml_lines()
    -- Verify that the first line in the document is `---`
    local first_line = vim.api.nvim_buf_get_lines(0, 0, 1, false)[1]
    if first_line ~= "---" then
        error("YAML header not found; Quarto document is malformed", 0)
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
        error("YAML header not found; Quarto document is malformed", 0)
    end

    -- Get the YAML content and store in a table
    return vim.api.nvim_buf_get_lines(0, 1, yaml_end_line - 1, false)
end

---Scan an indented block for presence of fields and their values, returning
---both the YAML table with the fields/values added, as well as the index at
---which the field matched. The first non-blank line must be more indented
---than `indent_anchor`, or scanning stops immediately with no match. Stop
---scanning when reaching a lower indentation level, but ignore blank lines.
---@param start integer
---@param lines table
---@param indent_anchor integer
---@param yaml table
---@param fields table
---@return table, integer|nil
local function scan_yaml_block(start, lines, indent_anchor, yaml, fields)
    -- Check that the starting line exists
    if start > #lines then
        return yaml, nil
    end

    -- Check that the starting line (or lines) is not empty or whitespace only
    while lines[start]:match("^%s*$") do
        start = start + 1
        if start > #lines then
            return yaml, nil
        end
    end

    -- Check that the indentation level of the starting line is larger than the
    -- anchor indentation level
    local indent_level = #lines[start]:match("^(%s*)")
    if indent_level <= indent_anchor then
        return yaml, nil
    end

    -- Initialise index of matched pattern
    local matched_at = nil

    -- Loop across lines
    for i = start, #lines do
        -- Skip empty lines
        if not lines[i]:match("^%s*$") then
            local current_indent_level = #lines[i]:match("^(%s*)")
            if current_indent_level >= indent_level then
                indent_level = current_indent_level
                -- Add fields to the output YAML as appropriate
                for _, field in ipairs(fields) do
                    local value = lines[i]:match("^%s*" .. field .. ":%s*(.*)$")
                    if value then
                        yaml[field] = value:lower()
                        matched_at = i
                    end
                end
            else
                -- Stop parsing with decreased indentation
                break
            end
        end
    end
    return yaml, matched_at
end

---Parse YAML specification stored in a table
---@param lines table
---@return table
local function parse_yaml_table(lines)
    -- Loop over YAML header table and store relevant information
    local yaml = {}
    for i, line in ipairs(lines) do
        -- Check if line matches either of the possible language specifications
        -- Pattern works even for lines like `^knitr:$` with nothing after it,
        -- as it returns "" (empty string), which is truthy for later checks
        -- against e.g. `if yaml.knitr then ...`
        local jupyter = line:match("^jupyter:%s*(.*)$")
        local knitr = line:match("^knitr:%s*(.*)$")
        local engine = line:match("^engine:%s*(.*)$")

        -- Check which language specifications exist, with priority given to
        -- jupyter and knitr over engine
        if jupyter then
            -- Short-form (single line) jupyter kernel specification (is an
            -- empty string for full kernelspecs)
            yaml["jupyter"] = jupyter
            -- Check for complete kernelspec
            if jupyter == "" then
                -- Find the line where `kernelspec:` is specified, if present
                local current_indent = #lines[i]:match("^(%s*)")
                local _, kernelspec_at = scan_yaml_block(i + 1, lines, current_indent, yaml, { "kernelspec" })
                if kernelspec_at then
                    local kernelspec_indent = #lines[kernelspec_at]:match("^(%s*)")
                    -- Find the `language:` and `name:` lines
                    scan_yaml_block(kernelspec_at + 1, lines, kernelspec_indent, yaml, { "language", "name" })
                end
            end
        -- Knitr can be both short-form and nested, but makes no difference to
        -- language specification, so no conditional is needed here
        elseif knitr then
            yaml["knitr"] = knitr
        elseif engine then
            yaml["engine"] = engine
        end
    end
    return yaml
end

-- Allowed languages and their identifiers
local LANGUAGE_IDENTIFIERS = {
    python = "python",
    python3 = "python",
    r = "r",
    ir = "r",
    julia = "julia",
}

---Resolve an identifier name to a Jupyter language
---@param identifier string
---@return string language
local function get_language_from_identifier(identifier)
    local language = LANGUAGE_IDENTIFIERS[identifier]
    -- Direct match
    if language then
        return language
    end
    -- Julia can uniquely be specified with `julia-[version]`
    if identifier:match("^julia%-") then
        return "julia"
    end
    error("'" .. identifier .. "' is not supported", 0)
end

---Get YAML header language
---Check that the YAML header exists, is properly formatted and contains a
---language specification; return the language if this is the case.
---@return string language
local function get_yaml_language()
    -- Read YAML header into table
    local yaml_lines = get_yaml_lines()

    -- Parse YAML table
    local yaml = parse_yaml_table(yaml_lines)

    -- Raise error if no match is found
    if not (yaml.engine or yaml.jupyter or yaml.knitr) then
        error("Quarto language specification not found in YAML header", 0)
    end

    -- Parse the YAML specification line and return the language
    if yaml.knitr then
        return "r"
    elseif yaml.jupyter then
        -- Short-form jupyter
        if yaml.jupyter == "" then
            -- Full kernelspec, prioritising `language` over `name`
            if yaml.language or yaml.name then
                if yaml.language then
                    return get_language_from_identifier(yaml.language)
                elseif yaml.name then
                    return get_language_from_identifier(yaml.name)
                end
            else
                error("Kernel field is empty, without a full kernelspec", 0)
            end
        else
            -- Get language from allowed identifiers
            return get_language_from_identifier(yaml.jupyter)
        end
    elseif yaml.engine then
        if yaml.engine == "jupyter" then
            error("Engine specifies 'jupyter' without a full kernelspec or short-form specification", 0)
        elseif yaml.engine == "knitr" then
            return "r"
        elseif yaml.engine == "" then
            error("Engine specification is empty", 0)
        else
            error("Engine '" .. yaml.engine .. "' is not supported", 0)
        end
    end
end

---Get language for current file
---Check the current filetype and gets the corresponding language as
---appropriate.
---@param use_yaml_language boolean|nil
---@return string|nil language
function M.get_file_language(use_yaml_language)
    -- Catch errors in language specifications
    local ok, results = pcall(function()
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
            error("Filetype '" .. filetype .. "' is not supported", 0)
        end
    end)
    if not ok then
        return util.raise_error(results)
    end
    return results
end

return M
