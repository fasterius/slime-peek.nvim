std = "luajit"
max_line_length = 80

globals = {
    "vim",
}

files["spec/"] = {
    std = "+busted",
}
