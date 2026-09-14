local peek = require("slime_peek")
local lang = require("slime_peek.lang")

describe("_send_command_to_repl", function()
    -- Stubs for `vim.notify` (error messages), `vim.cmd` (for sending commands
    -- to the REPL) and `lang.get_file_language()` for specifying language
    -- (stubbed here since that function has its own tests)
    local notify_stub
    local cmd_stub
    local lang_stub

    -- Open a scratch buffer and stub before each test and close them afterwards
    before_each(function()
        vim.cmd("enew")
        notify_stub = stub(vim, "notify")
        cmd_stub = stub(vim, "cmd")
    end)
    after_each(function()
        vim.cmd("bwipeout!")
        notify_stub:revert()
        cmd_stub:revert()
        lang_stub:revert()
    end)

    ---Helper: populate file with content and test an operation
    ---@param operation string
    ---@param command string
    local function test_cmd(operation, command)
        vim.api.nvim_buf_set_lines(0, 0, -1, true, { "content" })
        vim.api.nvim_win_set_cursor(0, { 1, 0 })
        peek._command = operation
        peek._send_command_to_repl()
        assert
            .stub(cmd_stub)
            ---@diagnostic disable-next-line: undefined-field
            .was_called_with('SlimeSend0 "' .. command .. '\\n"')
    end

    -- Test dispatch for each individual language, but only a single command,
    -- since all operation -> command string builds are tested elsewhere
    describe("Python operations", function()
        before_each(function()
            ---@diagnostic disable-next-line: undefined-field
            lang_stub = stub(lang, "get_file_language").returns("python")
            peek._use_operator = false
        end)
        it("returns correct string for 'head' command", function()
            test_cmd("head", "content.head()")
        end)
    end)

    describe("R operations", function()
        before_each(function()
            ---@diagnostic disable-next-line: undefined-field
            lang_stub = stub(lang, "get_file_language").returns("r")
            peek._use_operator = false
        end)
        it("returns correct string for 'head' command", function()
            test_cmd("head", "head(content)")
        end)
    end)

    describe("Julia operations", function()
        before_each(function()
            ---@diagnostic disable-next-line: undefined-field
            lang_stub = stub(lang, "get_file_language").returns("julia")
            peek._use_operator = false
        end)
        it("returns correct string for 'head' command", function()
            test_cmd("head", "first(content, 5)")
        end)
    end)

    describe("operator mode", function()
        before_each(function()
            ---@diagnostic disable-next-line: undefined-field
            lang_stub = stub(lang, "get_file_language").returns("python")
            peek._use_operator = true
            peek._command = "head"
        end)

        it("returns error for multi-line selections", function()
            vim.api.nvim_buf_set_lines(
                0,
                0,
                -1,
                true,
                { "line one", "line two" }
            )
            -- Set marks for start and end of the operator motion
            vim.api.nvim_buf_set_mark(0, "[", 1, 0, {})
            vim.api.nvim_buf_set_mark(0, "]", 2, 0, {})
            peek._send_command_to_repl()
            ---@diagnostic disable-next-line: undefined-field
            assert.stub(cmd_stub).was_not_called()
            ---@diagnostic disable-next-line: undefined-field
            assert.stub(notify_stub).was_called_with(
                "Error: Multi-line selections are not supported",
                vim.log.levels.ERROR
            )
        end)

        it("sends the correct command for a valid single-line range", function()
            vim.api.nvim_buf_set_lines(0, 0, -1, true, { "content" })
            vim.api.nvim_buf_set_mark(0, "[", 1, 0, {})
            vim.api.nvim_buf_set_mark(0, "]", 1, 6, {})
            peek._send_command_to_repl()
            assert
                .stub(cmd_stub)
                ---@diagnostic disable-next-line: undefined-field
                .was_called_with('SlimeSend0 "content.head()\\n"')
        end)
    end)

    describe("language detection failure", function()
        before_each(function()
            ---@diagnostic disable-next-line: undefined-field
            lang_stub = stub(lang, "get_file_language").returns(nil)
            peek._use_operator = false
            peek._command = "head"
        end)

        it("returns no command and does not crash", function()
            vim.api.nvim_buf_set_lines(0, 0, -1, true, { "content" })
            vim.api.nvim_win_set_cursor(0, { 1, 0 })
            peek._send_command_to_repl()
            ---@diagnostic disable-next-line: undefined-field
            assert.stub(cmd_stub).was_not_called()
            ---@diagnostic disable-next-line: undefined-field
            assert.stub(notify_stub).was_not_called()
        end)
    end)
end)
