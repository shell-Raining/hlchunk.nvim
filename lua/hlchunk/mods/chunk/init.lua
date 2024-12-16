local BaseMod = require("hlchunk.mods.base_mod")
local ChunkConf = require("hlchunk.mods.chunk.chunk_conf")
local chunkHelper = require("hlchunk.utils.chunkHelper")
local LoopTask = require("hlchunk.utils.loopTask")
local debounce = require("hlchunk.utils.timer").debounce
local debounce_throttle = require("hlchunk.utils.timer").debounce_throttle
local Pos = require("hlchunk.utils.position")
local Scope = require("hlchunk.utils.scope")
local cFunc = require("hlchunk.utils.cFunc")

local class = require("hlchunk.utils.class")

local api = vim.api
local fn = vim.fn
local CHUNK_RANGE_RET = chunkHelper.CHUNK_RANGE_RET
local rangeFromTo = chunkHelper.rangeFromTo
local utf8Split = chunkHelper.utf8Split
local shallowCmp = chunkHelper.shallowCmp

---@class HlChunk.ChunkMetaInfo : HlChunk.MetaInfo
---@field task HlChunk.LoopTask | nil
---@field pre_virt_text_list string[]
---@field pre_row_list number[]
---@field pre_virt_text_win_col_list number[]
---@field pre_is_error boolean

local constructor = function(self, conf, meta)
    local default_meta = {
        name = "chunk",
        augroup_name = "hlchunk_chunk",
        hl_base_name = "HLChunk",
        ns_id = api.nvim_create_namespace("chunk"),
        task = nil,
        shiftwidth = fn.shiftwidth(),
        leftcol = fn.winsaveview().leftcol,
        pre_virt_text_list = {},
        pre_row_list = {},
        pre_virt_text_win_col_list = {},
        pre_is_error = false,
    }

    BaseMod.init(self, conf, meta)
    self.meta = vim.tbl_deep_extend("force", default_meta, meta or {})
    self.conf = ChunkConf(conf)
end

---@class HlChunk.ChunkMod : HlChunk.BaseMod
---@field conf HlChunk.ChunkConf
---@field meta HlChunk.ChunkMetaInfo
---@field render fun(self: HlChunk.ChunkMod, range: HlChunk.Scope, opts?: {error: boolean, lazy: boolean})
---@overload fun(conf?: HlChunk.UserChunkConf, meta?: HlChunk.MetaInfo): HlChunk.ChunkMod
local ChunkMod = class(BaseMod, constructor)

function ChunkMod:enable()
    BaseMod.enable(self)
    self:render(Scope(0, 0, -1))
end

function ChunkMod:stopRender()
    if self.meta.task then
        self.meta.task:stop()
        self.meta.task = nil
    end
end

function ChunkMod:updatePreState(virt_text_list, row_list, virt_text_win_col_list, is_error)
    self.meta.pre_virt_text_list = virt_text_list
    self.meta.pre_row_list = row_list
    self.meta.pre_virt_text_win_col_list = virt_text_win_col_list
    self.meta.pre_is_error = is_error
end

function ChunkMod:get_chunk_data(range, virt_text_list, row_list, virt_text_win_col_list)
    local beg_blank_len = cFunc.get_indent(range.bufnr, range.start)
    local end_blank_len = cFunc.get_indent(range.bufnr, range.finish)
    local start_col = math.max(math.min(beg_blank_len, end_blank_len) - self.meta.shiftwidth, 0)

    if beg_blank_len > 0 then
        local virt_text_len = beg_blank_len - start_col
        local beg_virt_text = self.conf.chars.left_top
            .. self.conf.chars.horizontal_line:rep(virt_text_len - 2)
            .. self.conf.chars.left_arrow
        local virt_text, virt_text_win_col = chunkHelper.calc(beg_virt_text, start_col, self.meta.leftcol)
        local char_list = fn.reverse(utf8Split(virt_text))
        vim.list_extend(virt_text_list, char_list)
        vim.list_extend(row_list, vim.fn["repeat"]({ range.start }, #char_list))
        vim.list_extend(virt_text_win_col_list, rangeFromTo(virt_text_win_col + #char_list - 1, virt_text_win_col, -1))
    end

    local mid_char_nums = range.finish - range.start - 1
    vim.list_extend(row_list, rangeFromTo((range.start + 1), (range.finish - 1)))
    vim.list_extend(virt_text_win_col_list, vim.fn["repeat"]({ start_col - self.meta.leftcol }, mid_char_nums))
    local mid = self.conf.chars.vertical_line:rep(mid_char_nums)
    local chars
    if start_col - self.meta.leftcol < 0 then
        chars = vim.fn["repeat"]({ "" }, mid_char_nums)
    else
        chars = utf8Split(mid)
        -- when use click `<<` or `>>` to indent, we should make sure the line would not encounter the indent char
        for i = 1, mid_char_nums do
            local char = Pos.get_char_at_pos(Pos(range.bufnr, range.start + i, start_col), self.meta.shiftwidth)
            if not char:match("%s") and #char ~= 0 then
                chars[i] = ""
            end
        end
    end
    vim.list_extend(virt_text_list, chars)

    if end_blank_len > 0 then
        local virt_text_len = end_blank_len - start_col
        local end_virt_text = self.conf.chars.left_bottom
            .. self.conf.chars.horizontal_line:rep(virt_text_len - 2)
            .. self.conf.chars.right_arrow
        local virt_text, virt_text_win_col = chunkHelper.calc(end_virt_text, start_col, self.meta.leftcol)
        local char_list = utf8Split(virt_text)
        vim.list_extend(virt_text_list, char_list)
        vim.list_extend(row_list, vim.fn["repeat"]({ range.finish }, virt_text_len))
        vim.list_extend(virt_text_win_col_list, rangeFromTo(virt_text_win_col, virt_text_win_col + virt_text_len - 1))
    end
end

function ChunkMod:render(range, opts)
    opts = opts or { error = false, lazy = false }
    if not self:shouldRender(range.bufnr) then
        return
    end

    local virt_text_list = {}
    local row_list = {}
    local virt_text_win_col_list = {}
    self:get_chunk_data(range, virt_text_list, row_list, virt_text_win_col_list)

    if
        opts.lazy
        and shallowCmp(virt_text_list, self.meta.pre_virt_text_list)
        and shallowCmp(row_list, self.meta.pre_row_list)
        and shallowCmp(virt_text_win_col_list, self.meta.pre_virt_text_win_col_list)
        and self.meta.pre_is_error == opts.error
    then
        return
    end

    self:stopRender()
    self:updatePreState(virt_text_list, row_list, virt_text_win_col_list, opts.error)
    self:clear(Scope(range.bufnr, 0, api.nvim_buf_line_count(range.bufnr)))

    local row_opts = {
        virt_text_pos = "overlay",
        hl_mode = "combine",
        priority = 100,
    }
    local text_hl = opts.error and "HLChunk2" or "HLChunk1"
    if self.conf.delay == 0 or opts.lazy == false then
        for i, vt in ipairs(virt_text_list) do
            row_opts.virt_text = { { vt, text_hl } }
            row_opts.virt_text_win_col = virt_text_win_col_list[i]
            local row = row_list[i]
            if row and api.nvim_buf_is_valid(range.bufnr) and api.nvim_buf_line_count(range.bufnr) > row then
                api.nvim_buf_set_extmark(range.bufnr, self.meta.ns_id, row, 0, row_opts)
            end
        end
    else
        self.meta.task = LoopTask(function(vt, row, vt_win_col)
            row_opts.virt_text = { { vt, text_hl } }
            row_opts.virt_text_win_col = vt_win_col
            if api.nvim_buf_is_valid(range.bufnr) and api.nvim_buf_line_count(range.bufnr) > row then
                api.nvim_buf_set_extmark(range.bufnr, self.meta.ns_id, row, 0, row_opts)
            end
        end, "linear", self.conf.duration, virt_text_list, row_list, virt_text_win_col_list)
        self.meta.task:start()
    end
end

function ChunkMod:createAutocmd()
    BaseMod.createAutocmd(self)
    local render_cb = function(event, opts)
        local bufnr = event.buf
        if not api.nvim_buf_is_valid(bufnr) then
            return
        end
        local winid = api.nvim_get_current_win()
        local pos = api.nvim_win_get_cursor(winid)

        local ret_code, range = chunkHelper.get_chunk_range({
            pos = Pos(bufnr, pos[1] - 1, pos[2]),
            use_treesitter = self.conf.use_treesitter,
        })
        api.nvim_win_call(winid, function()
            self.meta.shiftwidth = cFunc.get_sw(bufnr)
            self.meta.leftcol = fn.winsaveview().leftcol
        end)
        if ret_code == CHUNK_RANGE_RET.OK then
            self:render(range, { error = false, lazy = opts.lazy })
        elseif ret_code == CHUNK_RANGE_RET.NO_CHUNK then
            self:clear(Scope(bufnr, 0, api.nvim_buf_line_count(bufnr)))
            self:updatePreState({}, {}, {}, false)
        elseif ret_code == CHUNK_RANGE_RET.CHUNK_ERR then
            self:render(range, { error = self.conf.error_sign, lazy = opts.lazy })
        elseif ret_code == CHUNK_RANGE_RET.NO_TS then
            self:notify("[hlchunk.chunk]: no parser for " .. vim.bo[bufnr].ft, nil, { once = true })
        end
    end
    local db_render_cb = debounce(render_cb, self.conf.delay, false)
    local db_render_cb_imm = debounce_throttle(render_cb, self.conf.delay)
    local db_render_cb_with_pre_hook = function(event, opts)
        opts = opts or { lazy = false }
        local bufnr = event.buf
        if not self:shouldRender(bufnr) then
            return
        end
        if opts.lazy then
            db_render_cb(event, opts)
        else
            db_render_cb_imm(event, opts)
        end
    end
    api.nvim_create_autocmd({ "CursorMovedI", "CursorMoved" }, {
        group = self.meta.augroup_name,
        callback = function(e)
            db_render_cb_with_pre_hook(e, { lazy = true })
        end,
    })
    api.nvim_create_autocmd({ "TextChangedI", "TextChanged" }, {
        group = self.meta.augroup_name,
        callback = function(e)
            db_render_cb_with_pre_hook(e, { lazy = false })
        end,
    })
    api.nvim_create_autocmd({ "UIEnter", "BufWinEnter" }, {
        group = self.meta.augroup_name,
        callback = function()
            -- get the file size of the current buffer
            local ok, status = pcall(fn.getfsize, fn.expand("%"))
            if ok and status >= self.conf.max_file_size then
                self:notify("File is too large, chunk.nvim will not be loaded")
                self:disable()
            end
        end,
    })
    api.nvim_create_autocmd("Filetype", {
        group = self.meta.augroup_name,
        callback = function()
            -- chunk_mod can use text object, so add a new function extra to handle it
            local ft = vim.bo[0].filetype
            if not self.conf.exclude_filetypes[ft] then
                self:extra()
            end
        end,
    })
end

function ChunkMod:extra()
    local textobject = self.conf.textobject
    local keymap = textobject.keymap
    local desc = textobject.desc

    if not keymap then
        return
    end

    vim.keymap.set({ "x", "o" }, keymap, function()
        local pos = api.nvim_win_get_cursor(0)
        local retcode, cur_chunk_range = chunkHelper.get_chunk_range({
            pos = { bufnr = 0, row = pos[1] - 1, col = pos[2] },
            use_treesitter = self.conf.use_treesitter,
        })
        if retcode ~= CHUNK_RANGE_RET.OK then
            return
        end
        local s_row = cur_chunk_range.start + 1
        local e_row = cur_chunk_range.finish + 1
        local ctrl_v = api.nvim_replace_termcodes("<C-v>", true, true, true)
        local cur_mode = vim.fn.mode()
        if cur_mode == "v" or cur_mode == "V" or cur_mode == ctrl_v then
            vim.cmd("normal! " .. cur_mode)
        end

        api.nvim_win_set_cursor(0, { s_row, 0 })
        vim.cmd("normal! V")
        api.nvim_win_set_cursor(0, { e_row, 0 })
    end, { desc = desc, buffer = true })
end

return ChunkMod
