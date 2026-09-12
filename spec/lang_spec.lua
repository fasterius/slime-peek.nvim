local lang = require("slime_peek.lang")

describe("get_file_language", function()
    -- Stub for `vim.notify` for checking error messages
    -- The `get_file_language` function returns `nil` for malformed or otherwise
    -- non-supported YAML headers, but also sends an error message through the
    -- `vim.notify` channel, which the stub can check.
    local notify_stub

    -- Open a scratch buffer and stub before each test and close them afterwards
    before_each(function()
        vim.cmd("enew")
        notify_stub = stub(vim, "notify")
    end)
    after_each(function()
        vim.cmd("bwipeout!")
        notify_stub:revert()
    end)

    ---Helper: set the current buffer's filetype and resolve its language
    ---@param filetype string
    ---@return string|nil
    local function get_language_for_filetype(filetype)
        vim.bo.filetype = filetype
        return lang.get_file_language(false)
    end

    ---Helper: set up a Quarto buffer with the given lines and cursor position,
    ---then resolve its language using chunk-based detection
    ---@param lines table
    ---@param cursor_line integer
    ---@return string|nil
    local function get_language_for_chunk(lines, cursor_line)
        vim.bo.filetype = "quarto"
        vim.api.nvim_buf_set_lines(0, 0, -1, true, lines)
        vim.api.nvim_win_set_cursor(0, { cursor_line, 0 })
        return lang.get_file_language(false)
    end

    ---Helper: set up a Quarto buffer with the given YAML header lines, then
    ---resolve its language using YAML-based detection
    ---@param yaml_header table
    ---@return string|nil
    local function get_language_for_yaml(yaml_header)
        vim.bo.filetype = "quarto"
        vim.api.nvim_buf_set_lines(0, 0, -1, true, yaml_header)
        return lang.get_file_language(true)
    end

    ---Assert that `vim.notify` was called with the given message, prefixed
    ---the same way `util.raise_error` prefixes every error it reports
    ---@param message string
    local function assert_notified(message)
        ---@diagnostic disable-next-line: undefined-field
        assert.stub(notify_stub).was_called_with("Error: " .. message, vim.log.levels.ERROR)
    end

    -- Filetype language specifications
    it("returns `python` for a Python filetype buffer", function()
        assert.equal("python", get_language_for_filetype("python"))
    end)
    it("returns `r` for a R filetype buffer", function()
        assert.equal("r", get_language_for_filetype("r"))
    end)
    it("returns `r` for a R Markdown filetype buffer", function()
        assert.equal("r", get_language_for_filetype("rmd"))
    end)
    it("returns `julia` for a Julia filetype buffer", function()
        assert.equal("julia", get_language_for_filetype("julia"))
    end)
    it("returns nil for a Cobol filetype buffer", function()
        assert.is_nil(get_language_for_filetype("cobol"))
        assert_notified("Filetype 'cobol' is not supported")
    end)

    -- Quarto chunk-based language specification malformations
    local malformed_chunk = {
        "first line",
        "```{cobol}",
        "chunk 1",
        "```",
        "line between chunks",
        "```{fortran}",
        "chunk 2",
        "```",
        "last line",
    }
    it("returns nil when chunk header can't be found", function()
        assert.is_nil(get_language_for_chunk(malformed_chunk, 1))
        assert_notified("Cannot find chunk header")
    end)
    it("returns nil when chunk ending can't be found", function()
        assert.is_nil(get_language_for_chunk(malformed_chunk, 9))
        assert_notified("Cannot find chunk ending")
    end)
    it("returns nil when chunk language isn't supported", function()
        assert.is_nil(get_language_for_chunk(malformed_chunk, 3))
        assert_notified("Quarto language 'cobol' is not supported")
    end)
    it("returns nil when cursor is outside a chunk", function()
        assert.is_nil(get_language_for_chunk(malformed_chunk, 5))
        assert_notified("Cursor is not inside a valid code chunk")
    end)

    -- Quarto chunk-based language specifications
    it("returns `python` when chunk language is Python", function()
        local chunk = { "```{python}", "chunk content", "```" }
        assert.equal("python", get_language_for_chunk(chunk, 2))
    end)
    it("returns `r` when chunk language is R", function()
        local chunk = { "```{r}", "chunk content", "```" }
        assert.equal("r", get_language_for_chunk(chunk, 2))
    end)
    it("returns `julia` when chunk language is Julia", function()
        local chunk = { "```{julia}", "chunk content", "```" }
        assert.equal("julia", get_language_for_chunk(chunk, 2))
    end)

    -- Quarto YAML header-based language specification malformations
    it("returns nil when YAML header is not at file beginning", function()
        assert.is_nil(get_language_for_yaml({ "malformed first line", "---", "---" }))
        assert_notified("YAML header not found; Quarto document is malformed")
    end)
    it("returns nil when YAML header ending is not found", function()
        assert.is_nil(get_language_for_yaml({ "---", "missing YAML ending" }))
        assert_notified("YAML header not found; Quarto document is malformed")
    end)
    it("returns nil when jupyter, knitr and engine are all missing", function()
        assert.is_nil(get_language_for_yaml({ "---", "---" }))
        assert_notified("Quarto language specification not found in YAML header")
    end)

    -- Quarto YAML header-based with `knitr:`
    it("returns `r` for `knitr:` using YAML", function()
        assert.equal("r", get_language_for_yaml({ "---", "knitr:", "---" }))
    end)

    -- Quarto YAML header-based with short-form `jupyter:`
    it("returns `r` for `jupyter: ir` using YAML", function()
        assert.equal("r", get_language_for_yaml({ "---", "jupyter: ir", "---" }))
    end)
    it("returns `r` for `jupyter: r` using YAML", function()
        assert.equal("r", get_language_for_yaml({ "---", "jupyter: r", "---" }))
    end)
    it("returns `python` for `jupyter: python` using YAML", function()
        assert.equal("python", get_language_for_yaml({ "---", "jupyter: python", "---" }))
    end)
    it("returns `python` for `jupyter: python3` using YAML", function()
        assert.equal("python", get_language_for_yaml({ "---", "jupyter: python3", "---" }))
    end)
    it("returns `julia` for `jupyter: julia` using YAML", function()
        assert.equal("julia", get_language_for_yaml({ "---", "jupyter: julia", "---" }))
    end)
    it("returns `julia` for `jupyter: julia-<version>` using YAML", function()
        assert.equal("julia", get_language_for_yaml({ "---", "jupyter: julia-1.0", "---" }))
    end)
    it("returns nil for `jupyter: cobol` using YAML", function()
        assert.is_nil(get_language_for_yaml({ "---", "jupyter: cobol", "---" }))
        assert_notified("'cobol' is not supported")
    end)

    -- Quarto YAML header-based with `jupyter:`, `kernelspec:` and `language:`
    it("returns `r` for `language: r` using YAML", function()
        local yaml_header = { "---", "jupyter:", "  kernelspec:", "    language: r", "---" }
        assert.equal("r", get_language_for_yaml(yaml_header))
    end)
    it("returns `r` for `language: ir` using YAML", function()
        local yaml_header = { "---", "jupyter:", "  kernelspec:", "    language: ir", "---" }
        assert.equal("r", get_language_for_yaml(yaml_header))
    end)
    it("returns `python` for `language: python` using YAML", function()
        local yaml_header = { "---", "jupyter:", "  kernelspec:", "    language: python", "---" }
        assert.equal("python", get_language_for_yaml(yaml_header))
    end)
    it("returns `python` for `language: python3` using YAML", function()
        local yaml_header = { "---", "jupyter:", "  kernelspec:", "    language: python3", "---" }
        assert.equal("python", get_language_for_yaml(yaml_header))
    end)
    it("returns `julia` for `language: julia` using YAML", function()
        local yaml_header = { "---", "jupyter:", "  kernelspec:", "    language: julia", "---" }
        assert.equal("julia", get_language_for_yaml(yaml_header))
    end)
    it("returns `julia` for `language: julia-<ver>` using YAML", function()
        local yaml_header = { "---", "jupyter:", "  kernelspec:", "    language: julia-1.0", "---" }
        assert.equal("julia", get_language_for_yaml(yaml_header))
    end)

    -- Quarto YAML header-based with `jupyter:`, `kernelspec:` and `name:`
    it("returns `r` for `name: r` using YAML", function()
        local yaml_header = { "---", "jupyter:", "  kernelspec:", "    name: r", "---" }
        assert.equal("r", get_language_for_yaml(yaml_header))
    end)
    it("returns `r` for `name: ir` using YAML", function()
        local yaml_header = { "---", "jupyter:", "  kernelspec:", "    name: ir", "---" }
        assert.equal("r", get_language_for_yaml(yaml_header))
    end)
    it("returns `python` for `name: python` using YAML", function()
        local yaml_header = { "---", "jupyter:", "  kernelspec:", "    name: python", "---" }
        assert.equal("python", get_language_for_yaml(yaml_header))
    end)
    it("returns `python` for `name: python3` using YAML", function()
        local yaml_header = { "---", "jupyter:", "  kernelspec:", "    name: python3", "---" }
        assert.equal("python", get_language_for_yaml(yaml_header))
    end)
    it("returns `julia` for `name: julia` using YAML", function()
        local yaml_header = { "---", "jupyter:", "  kernelspec:", "    name: julia", "---" }
        assert.equal("julia", get_language_for_yaml(yaml_header))
    end)
    it("returns `julia` for `name: julia-<ver>` using YAML", function()
        local yaml_header = { "---", "jupyter:", "  kernelspec:", "    name: julia-1.0", "---" }
        assert.equal("julia", get_language_for_yaml(yaml_header))
    end)

    -- Quarto YAML header-based with `jupyter:`, `kernelspec:`, `name:` and
    -- `language:`, where the `language:` is prioritised over `name:`
    it("returns `python` for `name: r` and `language: python` using YAML", function()
        local yaml_header = {
            "---",
            "jupyter:",
            "  kernelspec:",
            "    name: r",
            "    language: python",
            "---",
        }
        assert.equal("python", get_language_for_yaml(yaml_header))
    end)

    -- Quarto YAML header-based kernelspec parsing edge cases
    it("returns `r` even with unrelated `language:`/`name:` content after the kernelspec block has ended", function()
        local yaml_header = {
            "---",
            "jupyter:",
            "  kernelspec:",
            "    name: ir",
            "some_other_block:",
            "  language: cobol",
            "---",
        }
        assert.equal("r", get_language_for_yaml(yaml_header))
    end)
    it("returns `r` for `kernelspec:` with blank/whitespace lines between it and `jupyter:`", function()
        local yaml_header = {
            "---",
            "jupyter:",
            "",
            "  ",
            "  kernelspec:",
            "    name: ir",
            "---",
        }
        assert.equal("r", get_language_for_yaml(yaml_header))
    end)
    it("returns `r` with `language:` is past a blank line inside the kernelspec block", function()
        local yaml_header = {
            "---",
            "jupyter:",
            "  kernelspec:",
            "    name: python3",
            "",
            "    language: r",
            "---",
        }
        assert.equal("r", get_language_for_yaml(yaml_header))
    end)
    it("returns nil when `kernelspec:` has same indentation as `jupyter:`", function()
        local yaml_header = {
            "---",
            "jupyter:",
            "kernelspec:",
            "  language: r",
            "---",
        }
        assert.is_nil(get_language_for_yaml(yaml_header))
        assert_notified("Kernel field is empty, without a full kernelspec")
    end)
    it("returns nil when `language:`/`name:` has same indentation as `kernelspec:`", function()
        local yaml_header = {
            "---",
            "jupyter:",
            "  kernelspec:",
            "  language: r",
            "---",
        }
        assert.is_nil(get_language_for_yaml(yaml_header))
        assert_notified("Kernel field is empty, without a full kernelspec")
    end)

    -- Quarto YAML header-based with `jupyter:` and `kernelspec:` but without
    -- either `language:` or `name:`
    it("returns nil with missing language/name using YAML", function()
        local yaml_header = { "---", "jupyter:", "  kernelspec:", "---" }
        assert.is_nil(get_language_for_yaml(yaml_header))
        assert_notified("Kernel field is empty, without a full kernelspec")
    end)

    -- Quarto YAML header-based with `engine:`
    it("returns `r` for `engine: knitr`", function()
        assert.equal("r", get_language_for_yaml({ "---", "engine: knitr", "---" }))
    end)
    it("returns nil for `engine: jupyter` (no kernelspec)", function()
        assert.is_nil(get_language_for_yaml({ "---", "engine: jupyter", "---" }))
        assert_notified("Engine specifies 'jupyter' without a full kernelspec or short-form specification")
    end)
    it("returns nil for `engine:` (no kernelspec)", function()
        assert.is_nil(get_language_for_yaml({ "---", "engine:", "---" }))
        assert_notified("Engine specification is empty")
    end)
    it("returns nil for `engine: <unsupported>` (no kernelspec)", function()
        assert.is_nil(get_language_for_yaml({ "---", "engine: cobol", "---" }))
        assert_notified("Engine 'cobol' is not supported")
    end)
end)
