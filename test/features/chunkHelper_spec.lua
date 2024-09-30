local assert = require("luassert")
local chunkHelper = require("hlchunk.utils.chunkHelper")

describe("indentHelper", function()
    it("calc function happy path", function()
        local str, col, leftcol, expect_res, expect_offset
        local testCaseList = {
            { str = "----", col = 0, leftcol = 0, render_res = "----", offset = 0 },
            { str = "----", col = 1, leftcol = 0, render_res = "----", offset = 1 },
            { str = "────", col = 1, leftcol = 0, render_res = "────", offset = 1 },
            { str = "────", col = 0, leftcol = 2, render_res = "──", offset = 0 },
            { str = "────", col = 0, leftcol = 3, render_res = "─", offset = 0 },
            { str = "────", col = 0, leftcol = 4, render_res = "", offset = 0 },
            { str = "────", col = 4, leftcol = 4, render_res = "────", offset = 0 },
            { str = "────", col = 4, leftcol = 5, render_res = "───", offset = 0 },
            { str = "────", col = 8, leftcol = 4, render_res = "────", offset = 4 },
        }

        for _, testCase in ipairs(testCaseList) do
            str = testCase.str
            col = testCase.col
            leftcol = testCase.leftcol
            expect_res = testCase.render_res
            expect_offset = testCase.offset

            local render_res, render_offset = chunkHelper.calc(str, col, leftcol, 1)
            assert.equals(render_res, expect_res)
            assert.equals(render_offset, expect_offset)
        end
    end)

    it("utf8Split happy path", function()
        local inputList = {
            { input = "a", res = { "a" } },
            { input = "ab", res = { "a", "b" } },
            { input = "你好", res = { "你", "好" } },
            { input = "你好a", res = { "你", "好", "a" } },
            { input = "你好a你", res = { "你", "好", "a", "你" } },
            { input = "a好a你", res = { "a", "好", "a", "你" } },
            { input = "────", res = { "─", "─", "─", "─" } },
        }

        for _, testCase in ipairs(inputList) do
            local res = chunkHelper.utf8Split(testCase.input)
            assert.same(res, testCase.res)
        end
    end)

    it("rangeFromTo happy path", function()
        local inputList = {
            { from = 1, to = 3, res = { 1, 2, 3 } },
            { from = 1, to = 3, step = 1, res = { 1, 2, 3 } },
            { from = 1, to = 3, step = 2, res = { 1, 3 } },
            { from = 1, to = 4, step = 2, res = { 1, 3 } },
            { from = 1, to = 3, step = -1, res = {} },
            { from = 3, to = 1, step = -1, res = { 3, 2, 1 } },
        }

        for _, testCase in ipairs(inputList) do
            local res = chunkHelper.rangeFromTo(testCase.from, testCase.to, testCase.step)
            assert.same(res, testCase.res)
        end
    end)

    it("shallowCmp happy path", function()
        local inputList = {
            { t1 = { 1, 2, 3 }, t2 = { 1, 2, 3 }, res = true },
            { t1 = { 1, 2, 3 }, t2 = { 1, 2, 4 }, res = false },
            { t1 = { 1, 2, 3 }, t2 = { 1, 2 }, res = false },
            { t1 = { "a", "b", "c" }, t2 = { "a", "b", "c" }, res = true },
            { t1 = { "a", "b", "c" }, t2 = { "a", "b", "d" }, res = false },
            { t1 = { "a", "b", "c" }, t2 = { "a", "b" }, res = false },
            { t1 = { "你好", "你好" }, t2 = { "你好", "你好" }, res = true },
            { t1 = { "你好", "你好" }, t2 = { "你好", "你好1" }, res = false },
            { t1 = { true, false }, t2 = { 1, false }, res = false },
            { t1 = { { 1, 2 }, 3 }, t2 = { { 1, 2 }, 3 }, res = false },
            { t1 = {}, t2 = { 1 }, res = false },
            { t1 = { 1 }, t2 = {}, res = false },
            { t1 = {}, t2 = {}, res = true },
        }

        for _, testCase in ipairs(inputList) do
            local res = chunkHelper.shallowCmp(testCase.t1, testCase.t2)
            assert.equals(res, testCase.res)
        end
    end)

    it("getColList happy path", function()
        local inputList = {
            { char_list = { "a", "b", "c" }, text_width = 3, leftcol = 0, res = { 0, 1, 2 } },
            { char_list = { "a", "b", "c" }, text_width = 3, leftcol = 2, res = { 2, 3, 4 } },
            -- ascii gt
            { char_list = { "╰", "─", "─", ">" }, text_width = 4, leftcol = 0, res = { 0, 1, 2, 3 } },
            -- unicode box drawings light left
            { char_list = { "╰", "─", "─", "╴" }, text_width = 4, leftcol = 2, res = { 2, 3, 4, 5 } },
            -- nerdfont nf-fa-arrow_circle_right + whitespace
            { char_list = { "╰", "─", "", " " }, text_width = 4, leftcol = 4, res = { 4, 5, 6, 7 } },
            -- cjk
            { char_list = { "你", "好" }, text_width = 4, leftcol = 0, res = { 0, 2 } },
            -- emoji
            { char_list = { ">", "⏩", ">" }, text_width = 4, leftcol = 2, res = { 2, 3, 5 } },
            {
                char_list = { "1", "⏫", "-", "2", "3" },
                text_width = 5,
                leftcol = 0,
                res = { 0, 1, 3, 4, 5 },
            },
        }

        for _, testCase in ipairs(inputList) do
            local res = chunkHelper.getColList(testCase.char_list, testCase.leftcol, 1)
            assert.same(res, testCase.res)
        end
    end)

    it("repeatToWidth happy path", function()
        local inputList = {
            { str = "1", width = 4, res = "1111" },
            { str = "12", width = 4, res = "1212" },
            { str = "12", width = 9, res = "121212121" },
            { str = "１", width = 1, res = " " },
            { str = "１", width = 9, res = "１１１１ " },
            { str = "１2", width = 9, res = "１2１2１2" },
            { str = "1２", width = 9, res = "1２1２1２" },
            { str = "１2", width = 10, res = "１2１2１2 " },
            { str = "1２", width = 10, res = "1２1２1２1" },
            { str = "⏻ ", width = 8, res = "⏻ ⏻ ⏻ ⏻ " },
            { str = "⏻ ", width = 9, res = "⏻ ⏻ ⏻ ⏻  " },
        }

        for _, testCase in ipairs(inputList) do
            local res = chunkHelper.repeatToWidth(testCase.str, testCase.width, 1)
            assert.same(res, testCase.res)
        end
    end)

    it("listReverse happy path", function()
        local inputList = {
            { t = {}, res = {} },
            { t = { 1 }, res = { 1 } },
            { t = { 1, 2, 3 }, res = { 3, 2, 1 } },
            { t = { 1, 2, 3, 4 }, res = { 4, 3, 2, 1 } },
        }

        for _, testCase in ipairs(inputList) do
            local res = chunkHelper.listReverse(testCase.t)
            assert.same(res, testCase.res)
        end
    end)

    it("repeated happy path", function()
        local inputList = {
            { input = 1, repeat_to = 1, res = { 1 } },
            { input = 1, repeat_to = 3, res = { 1, 1, 1 } },
        }

        for _, testCase in ipairs(inputList) do
            local res = chunkHelper.repeated(testCase.input, testCase.repeat_to)
            assert.same(res, testCase.res)
        end
    end)

    it("checkCellsBlank happy path", function()
        -- bunch of edge cases
        local inputList = {
            { line = "", start_col = 1, end_col = 4, shiftwidth = 4, res = true },
            { line = "", start_col = 3, end_col = 3, shiftwidth = 4, res = true },
            { line = " ", start_col = 1, end_col = 4, shiftwidth = 4, res = true },
            { line = " ", start_col = 3, end_col = 3, shiftwidth = 4, res = true },
            { line = "    a", start_col = 1, end_col = 4, shiftwidth = 4, res = true },
            { line = "    a", start_col = 3, end_col = 3, shiftwidth = 4, res = true },
            { line = "a    ", start_col = 2, end_col = 5, shiftwidth = 4, res = true },
            { line = "a    a", start_col = 2, end_col = 5, shiftwidth = 4, res = true },
            { line = "　   a", start_col = 1, end_col = 5, shiftwidth = 4, res = true },
            { line = "　   a", start_col = 1, end_col = 6, shiftwidth = 4, res = false },
            { line = "a　  a", start_col = 2, end_col = 5, shiftwidth = 4, res = true },
            { line = "a　  a", start_col = 2, end_col = 6, shiftwidth = 4, res = false },
            { line = "     a", start_col = 1, end_col = 5, shiftwidth = 4, res = true },
            { line = "     a", start_col = 1, end_col = 6, shiftwidth = 4, res = false },
            { line = "a    a", start_col = 2, end_col = 5, shiftwidth = 4, res = true },
            { line = "a    a", start_col = 2, end_col = 6, shiftwidth = 4, res = false },
            { line = "aaaa a", start_col = 5, end_col = 5, shiftwidth = 4, res = true },
            { line = "aaaa a", start_col = 5, end_col = 6, shiftwidth = 4, res = false },
            { line = "a你a a", start_col = 5, end_col = 5, shiftwidth = 4, res = true },
            { line = "a你a a", start_col = 5, end_col = 6, shiftwidth = 4, res = false },
            { line = "aa　 a", start_col = 2, end_col = 5, shiftwidth = 4, res = false },
            { line = "aa　 a", start_col = 3, end_col = 3, shiftwidth = 4, res = true },
            { line = "aa　 a", start_col = 3, end_col = 5, shiftwidth = 4, res = true },
            { line = "aa　 a", start_col = 3, end_col = 6, shiftwidth = 4, res = false },
            { line = "aa　 a", start_col = 4, end_col = 4, shiftwidth = 4, res = true },
            { line = "\ta ", start_col = 1, end_col = 4, shiftwidth = 4, res = true },
            { line = "\ta ", start_col = 1, end_col = 4, shiftwidth = 3, res = false },
            { line = " \ta", start_col = 1, end_col = 4, shiftwidth = 3, res = true },
            { line = "\0   a", start_col = 1, end_col = 5, shiftwidth = 4, res = false },
            { line = "\0   a", start_col = 2, end_col = 5, shiftwidth = 4, res = false },
            { line = "\0   a", start_col = 3, end_col = 5, shiftwidth = 4, res = true },
            { line = "你　 a", start_col = 1, end_col = 5, shiftwidth = 4, res = false },
            { line = "你　 a", start_col = 2, end_col = 5, shiftwidth = 4, res = false },
            { line = "你　 a", start_col = 3, end_col = 5, shiftwidth = 4, res = true },
            { line = " 　 a", start_col = 1, end_col = 5, shiftwidth = 4, res = false },
            { line = " 　 a", start_col = 2, end_col = 5, shiftwidth = 4, res = false },
            { line = " 　 a", start_col = 3, end_col = 5, shiftwidth = 4, res = true },
            { line = "你　 好", start_col = 3, end_col = 5, shiftwidth = 4, res = true },
            { line = "你　 好", start_col = 2, end_col = 5, shiftwidth = 4, res = false },
            { line = "你　 好", start_col = 3, end_col = 6, shiftwidth = 4, res = false },
            { line = " 　  ", start_col = 3, end_col = 5, shiftwidth = 4, res = true },
            { line = " 　  ", start_col = 2, end_col = 5, shiftwidth = 4, res = false },
            { line = " 　  ", start_col = 3, end_col = 6, shiftwidth = 4, res = false },
        }

        for _, testCase in ipairs(inputList) do
            local res =
                chunkHelper.checkCellsBlank(testCase.line, testCase.start_col, testCase.end_col, testCase.shiftwidth)
            assert.same(res, testCase.res)
        end
    end)

    it("virtTextStrWidth happy path", function()
        local inputList = {
            { input = "\0", shiftwidth = 4, res = 0 },
            { input = "\1", shiftwidth = 4, res = 2 },
            { input = "\127", shiftwidth = 4, res = 2 },
            { input = " ", shiftwidth = 4, res = 1 },
            { input = "\t", shiftwidth = 4, res = 4 },
            { input = "a", shiftwidth = 4, res = 1 },
            { input = "A", shiftwidth = 4, res = 1 },
            { input = "你", shiftwidth = 4, res = 2 },
            { input = " ", shiftwidth = 4, res = 2 },
            { input = "\0\0", shiftwidth = 4, res = 0 },
            { input = "\1\1", shiftwidth = 4, res = 4 },
            { input = "\127\127", shiftwidth = 4, res = 4 },
            { input = "  ", shiftwidth = 4, res = 2 },
            { input = "\t\t", shiftwidth = 4, res = 8 },
            { input = "ab", shiftwidth = 4, res = 2 },
            { input = "AB", shiftwidth = 4, res = 2 },
            { input = "你好", shiftwidth = 4, res = 4 },
            { input = "  ", shiftwidth = 4, res = 4 },
            { input = "a\0b", shiftwidth = 4, stop_on_null = false, res = 2 },
            { input = "a\0b", shiftwidth = 4, stop_on_null = true, res = 1 },
        }

        for _, testCase in ipairs(inputList) do
            local res = chunkHelper.virtTextStrWidth(testCase.input, testCase.shiftwidth, testCase.stop_on_null)
            assert.same(res, testCase.res)
        end
    end)

    it("list_extend happy path", function()
        local inputList = {
            { dst = { 1, 2, 3 }, src = {}, res = { 1, 2, 3 } },
            { dst = {}, src = { 4, 5, 6 }, res = { 4, 5, 6 } },
            { dst = { 1, 2, 3 }, src = { 4, 5, 6 }, res = { 1, 2, 3, 4, 5, 6 } },
        }

        for _, testCase in ipairs(inputList) do
            chunkHelper.list_extend(testCase.dst, testCase.src)
            assert.same(testCase.dst, testCase.res)
        end
    end)
end)
