# indent

## indent 用来做什么

我们写代码有时候会遇到嵌套很多层等情况，而为了确定某些代码是否在同一层级，我们需要缩进线来帮助定位。

## 配置项

该 mod 的默认配置如下：

```lua
local default_conf = {
    priority = 10,
    style = { vim.api.nvim_get_hl(0, { name = "Whitespace" }) },
    use_treesitter = false,
    chars = { "│" },
    ahead_lines = 5,
    delay = 100,
}
```

独有的配置为 `use_treesitter`，`chars`，`ahead_lines`

- `use_treesitter` 是用来控制是否使用 treesitter 来判断 indent 的层数，默认为 false（因为性能问题）。如果你对缩进的精确要求很高，你可以尝试设置为 true，详情见这个 [issue](https://github.com/shellRaining/hlchunk.nvim/issues/77#issuecomment-1817530409)。同时在 `v1.2.1` 版本之后，已经不再推荐使用 treesitter 来获取缩进。

- `chars` 是一个表，其中的字符用来指示用什么字符来渲染 indent line，你可以尝试设置为下面这样：

  ```lua
  chars = {
      "│",
      "¦",
      "┆",
      "┊",
  },
  ```

实际渲染的时候，第一个层级会采用第一个字符，第二个层级会采用第二个字符，以此类推，如果层级超过了你设置的字符数，那么会循环使用这些字符。

- `ahead_lines` 是一个数字，用来控制缩进线超前查看和渲染范围，默认为 5

- `delay` 是一个用来表示毫秒值的数字，这是由于某些情况下渲染非常耗时，采用节流函数对渲染频率进行了限制，数值越大，滚动屏幕时越流畅，但同时也会看到较大部分的内容未被渲染（直到 delay 毫秒后），默认为 100

- `filter_list` 是一个 `Lua` 列表，其中可以定义一些 `filter` 函数，用来对渲染的字符进行过滤。你在这里定义的函数必须接受一个参数 `render_char_info`，这个参数包含如下字段
  - `level` 表示当前缩进层级
  - `lnum` 表示当前缩进字符所在行（0 为起始行）
  - `virt_text_win_col` 当前缩进字符在屏幕上的所在列（0 为起始列）具体信息可以看 [nvim_buf_set_extmark 函数](https://neovim.io/doc/user/api.html#nvim_buf_set_extmark())的介绍信息
  - `virt_text` 同上，这是 `nvim_buf_set_extmark` 函数的一个参数，一般来说你不需要设置这个字段。
  
  比如，如果你不希望渲染第一个 `level` 的字符，你可以按照如下方法设置
  
  ```lua
  filter_list = {
      function(v)
          return v.level ~= 1
      end,
  },
  ```


和 chunk 一样，我们需要额外注意 style 这个通用配置：

- 这里的 `style` 是一个 RGB 字符串或者一个表。如果是字符串，那么所有的缩进线将会采用这一种颜色来渲染，如果是表，可以有这两种写法：

  ```lua
    style = {
    "#FF0000",
    "#FF7F00",
    "..."
    },
  ```

  或者

  ```lua
  style = {
    { bg = "#FF0000", fg = "#FFFFFF" },
    { bg = "#FF7F00", fg = "FF7F00" },
    -- ...
  },
  ```

  如果你设置了背景颜色，那么缩进线将会采用背景颜色来渲染。

## example

下面是默认的 indent 样式

<img width="500" alt="image" src="https://raw.githubusercontent.com/shellRaining/img/main/2302/23_hlchunk1.png">

```lua
indent = {
    chars = {
        "│",
    },
    style = {
        vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID("Whitespace")), "fg", "gui"),
    },
}
```

你也可以将缩进线设置的像是彩虹一般 🌈

<img width="500" alt="image" src="https://raw.githubusercontent.com/shellRaining/img/main/2302/23_hlchunk2.png">

```lua
indent = {
    chars = {
        "│",
    },
    style = {
        "#FF0000",
        "#FF7F00",
        "#FFFF00",
        "#00FF00",
        "#00FFFF",
        "#0000FF",
        "#8B00FF",
    },
}
```

你也可以设置多种字符类型

<img width="500" alt="image" src="https://raw.githubusercontent.com/shellRaining/img/main/2303/01_hlchunk5.png">

```lua
indent = {
    chars = {
        "│",
        "¦",
        "┆",
        "┊",
    },
    style = {
        vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID("Whitespace")), "fg", "gui"),
    },
}
```

如果你喜欢更粗的显示效果，你可以设置渲染的背景颜色

<img width="500" alt="image" src="https://raw.githubusercontent.com/shellRaining/img/main/2303/13_hlindent_bg.png">

```lua
indent = {
    enable = true,
    use_treesitter = false,
    chars = {
        " ",
    },
    style = {
        { bg = vim.fn.synIDattr(vim.fn.synIDtrans(vim.fn.hlID("Whitespace")), "fg", "gui") },
    },
    exclude_filetypes = exclude_ft,
}
```
