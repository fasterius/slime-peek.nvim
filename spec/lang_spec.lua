local lang = require("slime_peek.lang")

describe("get_file_language", function()
    -- Open a scratch buffer before each test and close it afterwards
    before_each(function()
        vim.cmd("enew")
    end)
    after_each(function()
        vim.cmd("bwipeout!")
    end)

    it("returns `python` for a python filetype buffer", function()
        vim.bo.filetype = "python"
        assert.equal("python", lang.get_file_language(false))
    end)
end)
