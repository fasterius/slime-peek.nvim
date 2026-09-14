local util = require("slime_peek.util")

describe("raise_error", function()
    local notify_stub

    before_each(function()
        notify_stub = stub(vim, "notify")
    end)
    after_each(function()
        notify_stub:revert()
    end)

    it("notifies with the given message, prefixed with 'Error: '", function()
        util.raise_error("something went wrong")
        local message = "Error: something went wrong"
        ---@diagnostic disable-next-line: undefined-field
        assert.stub(notify_stub).was_called_with(message, vim.log.levels.ERROR)
    end)

    it("returns nil", function()
        assert.is_nil(util.raise_error("something went wrong"))
    end)
end)
