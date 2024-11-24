local class = require("hlchunk.utils.class")
local ft = require("hlchunk.utils.filetype")

---@alias HexColor string # a rgb color string, e.g. "#ff0000"
---@alias StyleEntry { bg: HexColor, fg: HexColor }
---@alias StyleTypeBase
---| HexColor # a single color
---| HexColor[] # a rgb color string array, e.g. {"#ff0000", "#00ff00"}
---| vim.api.keyset.highlight[] # a style entry array, e.g. {{bg = "#ff0000", fg = "#00ff00"}, {bg = "#00ff00", fg = "#ff0000"}}
---| vim.api.keyset.hl_info[] # return value of `vim.api.nvim_get_hl()`
---@alias StyleTypeFunction fun(): StyleTypeBase
---@alias HlChunk.StyleType StyleTypeBase | StyleTypeFunction

---@class HlChunk.UserBaseConf
---@field enable? boolean
---@field style? HlChunk.StyleType
---@field exclude_filetypes? table<string, boolean>
---@field notify? boolean
---@field priority? number

---@class HlChunk.BaseConf
---@field enable boolean
---@field style HlChunk.StyleType
---@field exclude_filetypes table<string, boolean>
---@field notify boolean
---@field priority number
---@field init fun(self: HlChunk.UserBaseConf, conf: table)
---@overload fun(conf?: HlChunk.UserBaseConf): HlChunk.BaseConf
---@overload fun(conf?: HlChunk.BaseConf): HlChunk.BaseConf
local BaseConf = class(function(self, conf)
    local default_conf = {
        enable = false,
        style = {},
        notify = false,
        priority = 0,
        exclude_filetypes = ft.exclude_filetypes,
    }
    conf = vim.tbl_deep_extend("force", default_conf, conf or {}) --[[@as HlChunk.BaseConf]]
    self.enable = conf.enable
    self.style = conf.style
    self.exclude_filetypes = conf.exclude_filetypes
    self.notify = conf.notify
    self.priority = conf.priority
end)

return BaseConf
