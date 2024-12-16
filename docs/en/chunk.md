# how to configure chunk mod

## what can chunk do

This mod can be used to indicate the current cursor's chunk (such as function_declaration, if_statement, etc.). It also provides textobject to quickly operate on this chunk.

## Configurable items

The default configuration of this mod is as follows:

```lua
local default_conf = {
    priority = 15,
    style = {
        { fg = "#806d9c" },
        { fg = "#c21f30" },
    },
    use_treesitter = true,
    chars = {
        horizontal_line = "─",
        vertical_line = "│",
        left_top = "╭",
        left_bottom = "╰",
        right_arrow = ">",
    },
    textobject = {},
    max_file_size = 1024 * 1024,
    error_sign = true,
    -- animation related
    duration = 200,
    delay = 300,
}
```

The unique configuration options are `use_treesitter`, `chars`, `textobject`, `max_file_size`,  `error_sign`, `duration` and `delay`

- `use_treesitter` is used to control whether to use treesitter to highlight code blocks. The default is true.
  If this field is set to true, it finds the matching node type by searching the tree nodes from bottom to top to obtain the corresponding chunk range. If set to false, it will use Vim's `searchpair` to find the nearest braces to infer the position (which is why it cannot be used normally in scripting languages like Python). And after `v1.2.1`, it's no longer recommended to use `treesitter` to get indent.

- `chars` is a table, where the characters in it are used to render the chunk. This table contains five parts:

  - horizontal_line
  - vertical_line
  - left_top
  - left_bottom
  - right_arrow

- `textobject` is a table, which is empty by default. This table contains two keys, `keymap` which triggers the textobject, and `desc` useful if you use a plugin like which-key, for instance this can be setup as follows:

  ```lua
  textobject = {
      keymap = "ic",
      desc = "inner chunk",
  },
  ```

- `max_file_size` is a number, with a default of `1MB`. When the size of the opened file exceeds this value, the mod will be automatically turned off.

- `error_sign` is a boolean value, which is true by default. If you use treesitter to highlight code blocks, when there is an error in the code block, it will set the color of the chunk to maple red (or another color of your choice). To enable this option, the style should have two colors, and the default style is:

  ```lua
  style = {
      "#806d9c", -- Violet
      "#c21f30", -- maple red
  },
  ```

- `duration` is a number, with a default of `200` ms. It is used to control the duration of the animation.

- `delay` is a number, with a default of `300` ms. It is used to control the delay of the animation. If set to `0`, animation will be removed.

For the general configurations (mentioned in the [README](../../README.md)), only a few need special attention:

- `style` is a string or a Lua table. If it is a string, it must be a hexadecimal RGB string. If it is a table, it accepts one or two strings representing hexadecimal colors. If table only contain one item, only one color will be used to render the chunk. If there are two, the first color will be used to render the normal chunk, and the second color will be used to render the erroneous chunk.

In addition, you can use the following configuration to dynamically switch the color of the chunk, which is to solve this [issue](https://github.com/shellRaining/hlchunk.nvim/issues/46):

```lua
local cb = function()
    if vim.g.colors_name == "tokyonight" then
        return "#806d9c"
    else
        return "#00ffff"
    end
end
chunk = {
    style = {
        { fg = cb },
        { fg = "#f35336" },
    },
},
```

## example

The following is the default chunk style, Its configuration is:

```lua
chunk = {
    chars = {
        horizontal_line = "─",
        vertical_line = "│",
        left_top = "╭",
        left_bottom = "╰",
        right_arrow = ">",
    },
    style = "#806d9c",
},
```

<a id='chunk_gif'>You can use the following configuration to make your style look like the one demonstrated in the GIF below</a>

<img width="500" alt="image" src="https://raw.githubusercontent.com/shellRaining/img/main/2303/08_hlchunk8.gif">

```lua
chunk = {
    chars = {
        horizontal_line = "─",
        vertical_line = "│",
        left_top = "┌",
        left_bottom = "└",
        right_arrow = "─",
    },
    style = "#00ffff",
},
```
