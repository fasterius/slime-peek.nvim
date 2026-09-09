local M = {}

---Handle R-specific commands
---Handle differing operation names between supported languages as well as
---whether the operation is a non-trivial function call with extra code.
---@param operation string the operation to perform
---@param object string the object to perform the operation on
---@return string command the complete command
function M.get_r_command(operation, object)
    local extra = ""
    if operation == "dtypes" then
        operation = "sapply"
        extra = ", class"
    end
    return operation .. "(" .. object .. extra .. ")\\n"
end

---Handle Python-specific commands
---Handle differing operation names between supported languages as well as
---whether the command pertains to an attribute (without parentheses) or a
---method (with parentheses)
---@param operation string the operation to perform
---@param object string the object to perform the operation on
---@return string command the complete command
function M.get_python_command(operation, object)
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

---Handle Julia-specific commands
---Translate the common operation names to Julia and DataFrames.jl expressions.
---@param operation string the operation to perform
---@param object string the object to perform the operation on
---@return string command the complete command
function M.get_julia_command(operation, object)
    if operation == "head" then
        return "first(" .. object .. ", 5)\\n"
    elseif operation == "tail" then
        return "last(" .. object .. ", 5)\\n"
    elseif operation == "dim" then
        return "size(" .. object .. ")\\n"
    elseif operation == "dtypes" then
        return "eltype.(eachcol(" .. object .. "))\\n"
    elseif operation == "help" then
        return "@doc " .. object .. "\\n"
    end
    return operation .. "(" .. object .. ")\\n"
end

return M
