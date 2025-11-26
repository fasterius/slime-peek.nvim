local M = {}

--- Handle R-specific commands
-- Handle differing operation names between R and Python as well as whether the
-- operation is a non-trivial function call with extra code.
-- @param operation the operation to perform
-- @param object the object to perform the operation on
-- @return a string with the complete command
function M.get_r_command(operation, object)
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

return M
