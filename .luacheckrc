std = "luajit"
max_line_length = 80

read_globals = {
    "vim",
}

files["spec/"] = {
    std = "+busted",
}
