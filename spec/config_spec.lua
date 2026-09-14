local config = require("slime_peek.config")

describe("config", function()
    -- Reset to defaults before each tests
    before_each(function()
        config.opts = vim.deepcopy(config.defaults)
    end)

    it("has `use_yaml_language` set to `false` by default", function()
        assert.is_false(config.defaults.use_yaml_language)
    end)

    it("merges a valid option into config.opts", function()
        config.setup({ use_yaml_language = true })
        assert.is_true(config.opts.use_yaml_language)
    end)

    it("keeps defaults for options not specified in setup()", function()
        config.setup({})
        assert.same(config.defaults, config.opts)
    end)

    it("keeps defaults when setup() is called with no arguments", function()
        config.setup()
        assert.same(config.defaults, config.opts)
    end)

    it("raises an error for a non-table opts argument", function()
        assert.has_error(function()
            config.setup("not a table")
        end)
    end)

    it("raises an error for a non-boolean use_yaml_language", function()
        assert.has_error(function()
            config.setup({ use_yaml_language = "not a boolean" })
        end)
    end)
end)
