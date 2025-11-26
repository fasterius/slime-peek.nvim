local M = {}

--- Error handling
-- Handle plugin errors by printing an error message and returning `nil` so that
-- execution can gracefully complete.
-- @param message the error message
-- @return nil
function M.raise_error(message)
    vim.notify("Error: " .. message, vim.log.levels.ERROR)
    return nil
end

return M
