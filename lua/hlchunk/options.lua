local opts = {}

opts.config = {
    -- settings for this plugin
    enabled = true,
    hlchunk_supported_files = { "*.ts", "*.js", "*.json", "*.go", "*.c", "*.cpp", "*.rs", "*.h", "*.hpp", "*.lua" },

    -- setttings for hl_chunk

    hl_chunk = {
        enable = true,
        chars = {
            horizontal_line = "─",
            vertical_line = "│",
            left_top = "╭",
            left_bottom = "╰",
            right_arrow = ">",
        },
        style = {
            hibiscus = "#806d9c",
            primrose = "#c06f98",
        },

        enable_hl_line_num = true,
        hl_line_num_style = {
            hibiscus = "#806d9c",
        },
    },

    -- settings for hl_indent
    hl_indent = {
        enable = true,
        chars = {
            vertical_line = "│",
        },
        style = {
            vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID("Whitespace")), "fg", "gui"),
        },
        exclude_filetype = {
            dashboard = true,
            help = true,
            lspinfo = true,
            packer = true,
            checkhealth = true,
            man = true,
            mason = true,
        },
    },
}

return opts