local M = {}

-- Setup
function M.setup() end

-- Internal function to get the language of the current Quarto document
local function get_quarto_language()
    -- Store the current cursor position for later repositioning
    local current_position = vim.api.nvim_win_get_cursor(0)

    -- Parse the YAML header and get the line with language information
    vim.api.nvim_command("normal! gg")
    local line_number = vim.fn.search("^knitr:\\|^jupyter:\\|^engine:", "W")

    -- Reposition cursor to original position
    vim.api.nvim_win_set_cursor(0, current_position)

    -- Handle non-existant matches
    if line_number == 0 then
        return nil
    end

    -- Parse language information line and get document language
    local line = vim.split(vim.fn.getline(line_number), "%s+")
    if line[1] == "engine:" then
        if line[2] == "knitr" then
            return "r"
        else
            return "python"
        end
    elseif line[1] == "knitr:" then
        return "r"
    elseif line[1] == "jupyter:" then
        local kernel = string.match(vim.fn.getline(line_number), "^jupyter: (.*)")
        if kernel == "python" or kernel == "r" then
            return kernel
        end
    else
        return nil
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
        return get_quarto_language()
    else
        return nil
    end
end

-- Function to print the head of the data frame under the cursor
function M.print_head()
    -- Get the current word under the cursor
    local current_word = vim.fn.expand("<cword>")
    -- Print the language-dependent head of the current word
    local language = get_file_language()
    if language == "r" then
        vim.cmd('SlimeSend0 "head(' .. current_word .. ')\\n"')
    elseif language == "python" then
        vim.cmd('SlimeSend0 "' .. current_word .. '.head()\\n"')
    else
        print("Error: requires Python or R")
    end
end

-- Function to print the column names of the data frame under the cursor
function M.print_names()
    -- Get the current word under the cursor
    local current_word = vim.fn.expand("<cword>")

    -- Print the language-dependent column names of the current word
    local language = get_file_language()
    if language == "r" then
        vim.cmd('SlimeSend0 "names(' .. current_word .. ')\\n"')
    elseif language == "python" then
        vim.cmd('SlimeSend0 "list(' .. current_word .. ')\\n"')
    else
        print("Error: requires Python or R")
    end
end

-- TODO: Possible additions include
--       - Tail of object
--       - Classes of data frame columns
--       - Summary of object
--       - Length / size of object
--       - Extensions of the existing to work with individual columns, e.g.
--         finding not just the word under the cursor but also df$column or
--         df['column']

-- Add user commands for main plugin functions
vim.api.nvim_create_user_command("PrintHead", M.print_head, { desc = "Print the head of a data frame" })
vim.api.nvim_create_user_command("PrintNames", M.print_names, { desc = "Print the column names of a data frame" })

return M
