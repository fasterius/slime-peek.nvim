rockspec_format = "3.0"
package = "slime-peek.nvim"
version = "scm-1"
source = {
    url = "git+https://github.com/fasterius/slime-peek.nvim",
}
dependencies = {}
test_dependencies = {
    "nlua",
}
build = {
    type = "builtin",
    copy_directories = {
        "plugin",
    },
}
