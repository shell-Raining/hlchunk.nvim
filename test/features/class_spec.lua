local class = require("hlchunk.utils.class")
local ChunkConf = require("hlchunk.mods.chunk.chunk_conf")
local exclude_filetypes = require("hlchunk.utils.filetype").exclude_filetypes
local assert = require("luassert")

describe("class", function()
    local base_user_ctor, base_ctor
    local derived_user_ctor, derived_ctor
    local method = function(self)
        return self.a + self.b
    end

    before_each(function()
        base_user_ctor = function(self, a, b)
            self.a = a
            self.b = b
        end
        base_ctor = class(base_user_ctor)
        base_ctor.method = method

        derived_user_ctor = function(self, a, b, c)
            base_ctor.init(self, a, b)
            self.c = c
        end
        derived_ctor = class(base_ctor, derived_user_ctor)
    end)

    it("should init a base class", function()
        local obj = base_ctor(1, 2)
        assert.equals(obj.a, 1)
        assert.equals(obj.b, 2)
        assert.equals(obj:method(), 3)
        assert.equals(obj.init, base_user_ctor)
    end)

    it("should derive a class from a base class", function()
        local obj = derived_ctor(1, 2, 3)
        assert.equals(obj.a, 1)
        assert.equals(obj.b, 2)
        assert.equals(obj.c, 3)
        assert.equals(obj:method(), 3)
        assert.equals(obj.init, derived_user_ctor)
    end)
end)

describe("ChunkConf class", function()
    local user_priority, user_style, user_use_treesitter, user_chars, user_textobject, user_max_file_size, user_error_sign, user_duration, user_delay
    before_each(function()
        user_priority = 100
        user_style = "happy"
        user_use_treesitter = true
        user_chars = {
            left_arrow = "━",
            horizontal_line = "━",
            vertical_line = "┃",
            left_top = "┏",
            left_bottom = "┗",
            right_arrow = "━",
        }
        user_textobject = { keymap = "ic", desc = "scope" }
        user_max_file_size = 10 * 1024 * 1024
        user_error_sign = true
        user_duration = 300
        user_delay = 500
    end)

    it("ChunkConf happy path", function()
        local user_conf = {
            priority = user_priority,
            style = user_style,
            use_treesitter = user_use_treesitter,
            chars = user_chars,
            textobject = user_textobject,
            max_file_size = user_max_file_size,
            error_sign = user_error_sign,
            duration = user_duration,
            delay = user_delay,
        }
        local actual = ChunkConf(user_conf)

        assert.equals(actual.priority, user_priority)
        assert.equals(actual.style, user_style)
        assert.equals(actual.use_treesitter, user_use_treesitter)
        assert.are.same(actual.chars, user_chars)
        assert.equals(actual.textobject, user_textobject)
        assert.equals(actual.max_file_size, user_max_file_size)
        assert.equals(actual.error_sign, user_error_sign)
        assert.equals(actual.duration, user_duration)
        assert.equals(actual.delay, user_delay)
    end)

    it("ChunkConf add exclude_filetypes", function()
        local user_conf = {
            exclude_filetypes = {
                less = true,
            },
            chars = {
                left_top = "┏",
            },
        }
        local actual = ChunkConf(user_conf)
        assert.are.same(
            vim.tbl_deep_extend("force", exclude_filetypes, user_conf.exclude_filetypes),
            actual.exclude_filetypes
        )
        assert.equals(actual.chars.left_top, "┏")
        assert.equals(actual.chars.left_bottom, "╰")
    end)
end)
