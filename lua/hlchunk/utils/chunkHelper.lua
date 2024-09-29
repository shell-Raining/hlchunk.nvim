local treesitter = vim.treesitter
local fn = vim.fn
local Scope = require("hlchunk.utils.scope")
local ft = require("hlchunk.utils.ts_node_type")

local function is_suit_type(node_type)
    local is_spec_ft = ft[vim.bo.ft]
    if is_spec_ft then
        return is_spec_ft[node_type] and true or false
    end

    for _, rgx in ipairs(ft.default) do
        if node_type:find(rgx) then
            return true
        end
    end
    return false
end

---@param bufnr number check the bufnr has treesitter parser
local function has_treesitter(bufnr)
    local has_lang, lang = pcall(treesitter.language.get_lang, vim.bo[bufnr].filetype)
    if not has_lang then
        return false
    end

    local has, parser = pcall(treesitter.get_parser, bufnr, lang)
    if not has or not parser then
        return false
    end
    return true
end

local chunkHelper = {}

---@enum CHUNK_RANGE_RETCODE
chunkHelper.CHUNK_RANGE_RET = {
    OK = 0,
    CHUNK_ERR = 1,
    NO_CHUNK = 2,
    NO_TS = 3,
}

---@param pos Pos 0-index (row, col)
local function get_chunk_range_by_context(pos)
    local base_flag = "nWz"
    local cur_row_val = vim.api.nvim_buf_get_lines(pos.bufnr, pos.row, pos.row + 1, false)[1]
    local cur_char = string.sub(cur_row_val, pos.col, pos.col)

    local beg_row = fn.searchpair("{", "", "}", base_flag .. "b" .. (cur_char == "{" and "c" or "")) --[[@as number]]
    local end_row = fn.searchpair("{", "", "}", base_flag .. (cur_char == "}" and "c" or "")) --[[@as number]]

    if beg_row <= 0 or end_row <= 0 or beg_row >= end_row then
        return chunkHelper.CHUNK_RANGE_RET.NO_CHUNK, Scope(pos.bufnr, -1, -1)
    end

    return chunkHelper.CHUNK_RANGE_RET.OK, Scope(pos.bufnr, beg_row - 1, end_row - 1)
end

---@param pos Pos 0-index for row, 0-index for col, API-indexing
local function get_chunk_range_by_treesitter(pos)
    if not has_treesitter(pos.bufnr) then
        return chunkHelper.CHUNK_RANGE_RET.NO_TS, Scope(pos.bufnr, -1, -1)
    end

    local cursor_node = treesitter.get_node({
        ignore_injections = false,
        bufnr = pos.bufnr,
        pos = { pos.row, pos.col },
    })
    -- when cursor_node is comment content (source), we should find by tree
    if cursor_node and cursor_node:type() == "source" then
        cursor_node = treesitter.get_node({
            bufnr = pos.bufnr,
            pos = { pos.row, pos.col },
        })
    end
    while cursor_node do
        local node_type = cursor_node:type()
        local node_start, _, node_end, _ = cursor_node:range()
        if node_start ~= node_end and is_suit_type(node_type) then
            return cursor_node:has_error() and chunkHelper.CHUNK_RANGE_RET.CHUNK_ERR or chunkHelper.CHUNK_RANGE_RET.OK,
                Scope(pos.bufnr, node_start, node_end)
        end
        cursor_node = cursor_node:parent()
    end
    return chunkHelper.CHUNK_RANGE_RET.NO_CHUNK, Scope(pos.bufnr, -1, -1)
end

---@param opts? {pos: Pos, use_treesitter: boolean}
---@return CHUNK_RANGE_RETCODE enum
---@return Scope
function chunkHelper.get_chunk_range(opts)
    opts = opts or { use_treesitter = false }

    if opts.use_treesitter then
        return get_chunk_range_by_treesitter(opts.pos)
    else
        return get_chunk_range_by_context(opts.pos)
    end
end

---@param str string
---@param col integer
---@param leftcol integer
---@param shiftwidth integer
---@return string, integer
function chunkHelper.calc(str, col, leftcol, shiftwidth)
    local len = chunkHelper.virtTextStrWidth(str, shiftwidth)
    if col < leftcol then
        local byte_idx = math.min(leftcol - col, len)
        local utf_beg = vim.str_byteindex(str, byte_idx)
        str = str:sub(utf_beg + 1)
    end

    col = math.max(col - leftcol, 0)

    return str, col
end

---@param inputstr string
---@return string[]
function chunkHelper.utf8Split(inputstr)
    local list = {}
    for uchar in string.gmatch(inputstr, "[^\128-\191][\128-\191]*") do
        table.insert(list, uchar)
    end
    return list
end

---@param i number
---@param j number
---@return table
function chunkHelper.rangeFromTo(i, j, step)
    local t = {}
    step = step or 1
    for x = i, j, step do
        table.insert(t, x)
    end
    return t
end

---@param char_list table<integer, string>
---@param leftcol integer
---@param shiftwidth integer
---@return integer[]
function chunkHelper.getColList(char_list, leftcol, shiftwidth)
    local t = {}
    local next_col = leftcol
    for i = 1, #char_list do
        table.insert(t, next_col)
        next_col = next_col + chunkHelper.virtTextStrWidth(char_list[i], shiftwidth)
    end
    return t
end

---@param str string
---@param width integer
---@param shiftwidth integer
function chunkHelper.repeatToWidth(str, width, shiftwidth)
    local str_width = chunkHelper.virtTextStrWidth(str, shiftwidth)

    -- "1" -> "1111"
    if str_width == 1 then
        return str:rep(width)
    end

    -- "12" -> "1212"
    if width % str_width == 0 then
        return str:rep(width / str_width)
    end

    -- "12" -> "12121"
    -- "１" -> "１１ "
    -- "⏻ " -> "⏻ ⏻  "
    local repeatable_len = math.floor(width / str_width)
    local s = str:rep(repeatable_len)
    local chars = chunkHelper.utf8Split(str)
    local current_width = str_width * repeatable_len
    local i = 1
    while i <= #chars do
        local char_width = chunkHelper.virtTextStrWidth(chars[i], shiftwidth)
        ---assumed to be an out-of-bounds char (like in nerd fonts) followed by a whitespace if true
        local likely_oob_char =
            -- single-cell
            char_width == 1
            -- followed by a whitespace
            and chars[i + 1] == " "
            -- non-ASCII
            and chars[i]:byte(1) > 0x7F
        local char = likely_oob_char and chars[i] .. " " or chars[i]
        local next_width = current_width + (likely_oob_char and 2 or char_width)
        if next_width < width then
            s = s .. char
            current_width = next_width
        elseif next_width == width then
            s = s .. char
            break
        else
            s = s .. string.rep(" ", width - current_width)
            break
        end
        if likely_oob_char then
            -- skip the whitespace part of out-of-bounds char + " "
            i = i + 2
        else
            i = i + 1
        end
    end
    return s
end

function chunkHelper.shallowCmp(t1, t2)
    if #t1 ~= #t2 then
        return false
    end
    local flag = true
    for i, v in ipairs(t1) do
        if t2[i] ~= v then
            flag = false
            break
        end
    end
    return flag
end

---@param line string
---@param start_col integer
---@param end_col integer
---@param shiftwidth integer
---@return boolean
function chunkHelper.checkCellsBlank(line, start_col, end_col, shiftwidth)
    local current_col = 1
    local current_byte = 1
    local current_char = 1
    while current_byte <= #line and current_col <= end_col do
        local final_byte = vim.str_byteindex(line, current_char)
        local char = line:sub(current_byte, final_byte)
        local b1, b2, b3 = char:byte(1, 3)
        if char == "" then
            break
        end
        ---@type integer
        local next_col
        local next_byte = final_byte + 1
        local next_char = current_char + 1
        if char == " " then
            next_col = current_col + 1
        elseif char == "\t" then
            next_col = current_col + shiftwidth
        elseif b1 <= 0x1F or char == "\127" then
            -- despite nvim_strwidth returning 0 or 1, control chars are 2 cells wide
            next_col = current_col + 2
        elseif b1 <= 0x7F then
            -- other ASCII chars are single cell wide
            next_col = current_col + 1
        else
            local char_width = vim.api.nvim_strwidth(char)
            local next_byte_peek = line:byte(final_byte + 1)
            if char_width == 1 and next_byte_peek == 0x20 then
                -- the char is assumed to be an out-of-bounds char (like in nerd fonts)
                -- followed by a whitespace
                next_col = current_col + 2
                -- skip the whitespace part of out-of-bounds char + " "
                next_byte = next_byte + 1
                next_char = next_char + 1
            else
                next_col = current_col + char_width
            end
        end
        -- we're going to match these characters manually
        -- as we can't use "%s" to check blank cells
        -- (e.g. "%s" matches to "\v" but it will be printed as ^K)
        if
            (current_col >= start_col or next_col - 1 >= start_col)
            -- Singles
            --
            -- Indent characters
            -- Unicode Scripts Z*
            -- 0020 - SPACE
            and char ~= " "
            --
            -- Unicode Scripts C*
            -- 0009 - TAB
            -- control characters except TAB should be rendered like "^[" or "<200b>"
            and char ~= "	"
            --
            -- Non indent characters
            -- Unicode Scripts Z*
            -- 00A0 - NO-BREAK SPACE
            and char ~= " "
            --[[
            -- 1680 - OGHAM SPACE MARK
            -- usually rendered as "-"
            -- see https://www.unicode.org/charts/PDF/U1680.pdf
            and char ~= " "
            ]]
            -- 2000..200A - EN QUAD..HAIR SPACE
            -- " ", " ", " ", " ", " ", " ", " ", " ", " ", " ", " "
            and not (b1 == 0xe2 and b2 == 0x80 and b3 >= 0x80 and b3 <= 0x8a)
            -- 202F - NARROW NO-BREAK SPACE
            and char ~= " "
            -- 205F - MEDIUM MATHEMATICAL SPACE
            and char ~= " "
            -- 3000 - IDEOGRAPHIC SPACE
            and char ~= "　"
            --[[
            -- 2028 - LINE SEPARATOR
            -- some fonts lacks this and may render it as "?" or "█"
            -- as this character is usually treated as a line-break
            and char ~= " "
            ]]
            --[[
            -- 2029 - PARAGRAPH SEPARATOR
            -- some fonts lacks this and may render it as "?" or "█"
            -- as this character is usually treated as a line-break
            and char ~= " "
            ]]
            --
            -- Others
            -- 2800 - BRAILLE PATTERN BLANK
            and char ~= "⠀"
            --[[
            -- 3164 - HANGUL FILLER
            -- technically "blank" but can easily break the rendering
            and "\227\133\164" -- do not replace this with a literal notation
            ]]
            --[[
            -- FFA0 - HALFWIDTH HANGUL FILLER
            -- technically "blank" but can easily break the rendering
            and "\239\190\160" -- do not replace this with a literal notation
            ]]
        then
            return false
        end
        current_col = next_col
        current_byte = next_byte
        current_char = next_char
    end
    return true
end

---@param str string
---@param shiftwidth integer
---@param stop_on_null? boolean
---@return integer
function chunkHelper.virtTextStrWidth(str, shiftwidth, stop_on_null)
    local current_width = 0
    for _, char in ipairs(chunkHelper.utf8Split(str)) do
        if char == "\0" then
            if stop_on_null then
                return current_width
            end
            -- just ignore otherwise
        elseif char == "\t" then
            current_width = current_width + shiftwidth
        else
            local b1 = char:byte(1)
            if b1 <= 0x1F or b1 == 0x7F then
                -- control chars other than NULL and TAB are two cells wide
                current_width = current_width + 2
            elseif b1 <= 0x7F then
                -- other ASCII chars are single cell wide
                current_width = current_width + 1
            else
                current_width = current_width + vim.api.nvim_strwidth(char)
            end
        end
    end
    return current_width
end

return chunkHelper
