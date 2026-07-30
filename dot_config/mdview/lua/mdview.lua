-- mdview: helpers for a read-only markdown viewer.
-- No plugin dependencies; everything here is stock Neovim API.

local M = {}

--------------------------------------------------------------------
-- highlights
--------------------------------------------------------------------

local function set_hl()
	vim.api.nvim_set_hl(0, "MdviewDim", { link = "Comment", default = true })
	vim.api.nvim_set_hl(0, "MdviewTocCurrent", { link = "Title", default = true })
end
set_hl()
vim.api.nvim_create_autocmd("ColorScheme", { callback = set_hl })

--------------------------------------------------------------------
-- buffer scan, cached (buffers are read-only, so this runs once)
--------------------------------------------------------------------

local cache = {}

local function buf_info(buf)
	local tick = vim.api.nvim_buf_get_changedtick(buf)
	local c = cache[buf]
	if c and c.tick == tick then
		return c
	end

	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local fences, open = {}, nil
	for i, line in ipairs(lines) do
		if line:match("^%s*```") or line:match("^%s*~~~") then
			if open then
				fences[#fences + 1] = { open, i }
				open = nil
			else
				open = i
			end
		end
	end
	if open then
		fences[#fences + 1] = { open, #lines }
	end

	-- flat lookup so per-line callers (foldexpr) stay O(1)
	local fenced = {}
	for _, f in ipairs(fences) do
		for i = f[1], f[2] do
			fenced[i] = true
		end
	end

	c = { tick = tick, lines = lines, fences = fences, fenced = fenced }
	cache[buf] = c
	return c
end

--- strip inline markup so headings read cleanly in the panel and fold text
local function clean(text)
	return (text:gsub("`", ""):gsub("%*%*", ""):gsub("%[(.-)%]%b()", "%1"))
end

--- level of an ATX heading on this line, or nil
local function heading_level(info, lnum)
	if info.fenced[lnum] then
		return nil
	end
	local line = info.lines[lnum]
	if not line then
		return nil
	end
	local hashes, text = line:match("^(#+)%s+(.-)%s*#*%s*$")
	if hashes and #hashes <= 6 and text ~= "" then
		return #hashes, clean(text)
	end
	return nil
end

--------------------------------------------------------------------
-- shared side panel (used by both the TOC and the file picker)
--------------------------------------------------------------------

---@param opts table {title, lines, on_select, width, close_on_select}
local function panel(opts)
	local prev = vim.api.nvim_get_current_win()

	vim.cmd("topleft " .. (opts.width or 34) .. "vsplit")
	local win = vim.api.nvim_get_current_win()
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_win_set_buf(win, buf)

	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].swapfile = false
	vim.bo[buf].filetype = "mdviewpanel"
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, opts.lines)
	vim.bo[buf].modifiable = false

	vim.wo[win].number = false
	vim.wo[win].relativenumber = false
	vim.wo[win].wrap = false
	vim.wo[win].cursorline = true
	vim.wo[win].foldcolumn = "0"
	vim.wo[win].signcolumn = "no"
	vim.wo[win].winfixwidth = true
	vim.wo[win].winbar = "  " .. opts.title
	-- sits slightly behind the text pane; follows whatever colorscheme is loaded
	vim.wo[win].winhighlight = "Normal:NormalFloat,EndOfBuffer:NormalFloat"

	local self = { win = win, buf = buf, prev = prev }

	function self.close()
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
		if vim.api.nvim_win_is_valid(prev) then
			vim.api.nvim_set_current_win(prev)
		end
	end

	local function select(stay)
		local row = vim.api.nvim_win_get_cursor(win)[1]
		if opts.close_on_select then
			self.close()
		elseif not stay and vim.api.nvim_win_is_valid(prev) then
			vim.api.nvim_set_current_win(prev)
		end
		opts.on_select(row, prev)
	end

	local map = function(lhs, fn)
		vim.keymap.set("n", lhs, fn, { buffer = buf, nowait = true, silent = true })
	end
	map("<CR>", function()
		select(false)
	end)
	map("o", function()
		select(true)
	end) -- jump but keep focus in the panel
	map("q", self.close)
	map("<Esc>", self.close)

	return self
end

--------------------------------------------------------------------
-- table of contents
--------------------------------------------------------------------

local toc = { ns = vim.api.nvim_create_namespace("mdview_toc") }

local function headings(buf)
	local info = buf_info(buf)
	local items = {}
	for i = 1, #info.lines do
		local level, text = heading_level(info, i)
		if level then
			items[#items + 1] = { lnum = i, label = string.rep("  ", level - 1) .. text }
		end
	end
	return items
end

--- index of the heading a given line falls under
local function section_of(items, lnum)
	local idx = 1
	for n, item in ipairs(items) do
		if item.lnum <= lnum then
			idx = n
		else
			break
		end
	end
	return idx
end

--- highlight a section entry and keep it on screen
local function toc_mark(idx)
	if idx == toc.current then
		return
	end
	toc.current = idx

	vim.api.nvim_buf_clear_namespace(toc.buf, toc.ns, 0, -1)
	vim.api.nvim_buf_set_extmark(toc.buf, toc.ns, idx - 1, 0, {
		line_hl_group = "MdviewTocCurrent",
		priority = 200,
	})

	-- scroll the panel if the entry has drifted out of view
	vim.api.nvim_win_call(toc.win, function()
		local view = vim.fn.winsaveview()
		local height = vim.api.nvim_win_get_height(toc.win)
		if idx < view.topline or idx > view.topline + height - 1 then
			vim.fn.winrestview({ topline = math.max(1, idx - math.floor(height / 2)) })
		end
	end)
end

--- track the section the reader is in
local function toc_follow()
	if not (toc.win and vim.api.nvim_win_is_valid(toc.win)) then
		return
	end
	local win = vim.api.nvim_get_current_win()
	if win == toc.win then
		return
	end -- don't fight manual browsing
	if vim.api.nvim_win_get_buf(win) ~= toc.src then
		return
	end

	toc_mark(section_of(toc.items, vim.api.nvim_win_get_cursor(win)[1]))
end
function M.toc()
	if toc.panel then
		if toc.aug then
			pcall(vim.api.nvim_del_augroup_by_id, toc.aug)
		end
		local p = toc.panel
		toc.panel, toc.win, toc.buf = nil, nil, nil
		toc.items, toc.src, toc.aug, toc.current = nil, nil, nil, nil
		p.close()
		return
	end

	local src = vim.api.nvim_get_current_buf()
	local items = headings(src)
	if #items == 0 then
		vim.notify("mdview: no headings found", vim.log.levels.INFO)
		return
	end

	local lines = {}
	for n, item in ipairs(items) do
		lines[n] = item.label
	end

	local p = panel({
		title = "contents",
		lines = lines,
		width = 34,
		on_select = function(row, target)
			if not vim.api.nvim_win_is_valid(target) then
				return
			end
			vim.api.nvim_win_set_cursor(target, { items[row].lnum, 0 })
			-- zv opens just enough folds to reveal the heading
			vim.api.nvim_win_call(target, function()
				vim.cmd("normal! zvzt")
			end)
		end,
	})

	toc.panel, toc.win, toc.buf, toc.items, toc.src = p, p.win, p.buf, items, src

	-- open on the section you were already reading
	local here = section_of(items, vim.api.nvim_win_get_cursor(p.prev)[1])
	vim.api.nvim_win_set_cursor(p.win, { here, 0 })
	toc_mark(here)

	toc.aug = vim.api.nvim_create_augroup("MdviewToc", { clear = true })
	vim.api.nvim_create_autocmd({ "CursorMoved", "BufEnter" }, {
		group = toc.aug,
		callback = toc_follow,
	})
end

--------------------------------------------------------------------
-- file picker
--------------------------------------------------------------------

function M.files(dir)
	dir = vim.fn.fnamemodify(dir and dir ~= "" and dir or vim.fn.getcwd(), ":p")
	local found = vim.fn.globpath(dir, "**/*.{md,markdown}", false, true)
	table.sort(found)
	if #found == 0 then
		vim.notify("mdview: no markdown under " .. dir, vim.log.levels.INFO)
		return
	end

	local labels = {}
	for n, path in ipairs(found) do
		labels[n] = vim.fn.fnamemodify(path, ":.")
	end

	panel({
		title = "files",
		lines = labels,
		width = 44,
		close_on_select = true,
		on_select = function(row)
			vim.cmd("edit " .. vim.fn.fnameescape(found[row]))
		end,
	})
end

--------------------------------------------------------------------
-- folding by section
--------------------------------------------------------------------

--- 'foldexpr': a heading opens a fold at its own level, everything else
--- inherits. Headings inside fenced code are ignored.
function M.foldexpr(lnum)
	lnum = lnum or vim.v.lnum
	local level = heading_level(buf_info(vim.api.nvim_get_current_buf()), lnum)
	return level and (">" .. level) or "="
end

--- 'foldtext': the heading, plus how much is hidden underneath it
function M.foldtext()
	local info = buf_info(vim.api.nvim_get_current_buf())
	local _, text = heading_level(info, vim.v.foldstart)
	text = text or vim.trim(info.lines[vim.v.foldstart] or "")
	local count = vim.v.foldend - vim.v.foldstart + 1
	return "  " .. text .. "  ⋯ " .. count .. " lines"
end

--- toggle the section under the cursor
function M.fold_toggle()
	pcall(vim.cmd, "normal! za") -- E490 when there is no fold here; harmless
end

--- collapse everything, or expand everything
local folded_all = false
function M.fold_all()
	folded_all = not folded_all
	vim.cmd("normal! " .. (folded_all and "zM" or "zR"))
end

--------------------------------------------------------------------
-- dim: fade everything except the block under the cursor
--------------------------------------------------------------------

local dim = { on = false, ns = vim.api.nvim_create_namespace("mdview_dim") }

--- first and last line of the block the cursor sits in
local function block_range(buf, lnum)
	local info = buf_info(buf)
	local lines, n = info.lines, #info.lines

	for _, f in ipairs(info.fences) do
		if lnum >= f[1] and lnum <= f[2] then
			return f[1], f[2]
		end
	end

	if lines[lnum] == nil or lines[lnum]:match("^%s*$") then
		return lnum, lnum
	end

	local s, e = lnum, lnum
	while s > 1 and not lines[s - 1]:match("^%s*$") and not info.fenced[s - 1] do
		s = s - 1
	end
	while e < n and not lines[e + 1]:match("^%s*$") and not info.fenced[e + 1] do
		e = e + 1
	end
	return s, e
end
M._block_range = block_range

local function dim_apply()
	local win = vim.api.nvim_get_current_win()
	local buf = vim.api.nvim_win_get_buf(win)
	if vim.bo[buf].filetype == "mdviewpanel" then
		return
	end

	vim.api.nvim_buf_clear_namespace(buf, dim.ns, 0, -1)
	if not dim.on then
		return
	end

	local s, e = block_range(buf, vim.api.nvim_win_get_cursor(win)[1])
	local last = vim.api.nvim_buf_line_count(buf)

	-- one extmark spans any number of lines, so the whole file costs two marks
	local function mark(a, b)
		if a > b or a < 1 or b > last then
			return
		end
		local tail = vim.api.nvim_buf_get_lines(buf, b - 1, b, false)[1] or ""
		vim.api.nvim_buf_set_extmark(buf, dim.ns, a - 1, 0, {
			end_row = b - 1,
			end_col = #tail,
			hl_group = "MdviewDim",
			priority = 200,
		})
	end
	mark(1, s - 1)
	mark(e + 1, last)
end

function M.dim(enable)
	if enable == nil then
		enable = not dim.on
	end
	dim.on = enable

	if dim.aug then
		pcall(vim.api.nvim_del_augroup_by_id, dim.aug)
		dim.aug = nil
	end

	if dim.on then
		dim.aug = vim.api.nvim_create_augroup("MdviewDim", { clear = true })
		vim.api.nvim_create_autocmd({ "CursorMoved", "BufEnter" }, {
			group = dim.aug,
			callback = dim_apply,
		})
	end
	dim_apply()
end

--------------------------------------------------------------------
-- zen: narrow centred column, with the rest of the page faded
--------------------------------------------------------------------

local zen = { wins = {}, main = nil, margin = "yes:3" }

function M.zen(target_width)
	if #zen.wins > 0 then
		for _, w in ipairs(zen.wins) do
			pcall(vim.api.nvim_win_close, w, true)
		end
		zen.wins = {}
		M.dim(false)
		if zen.main and vim.api.nvim_win_is_valid(zen.main) then
			vim.wo[zen.main].signcolumn = zen.margin
			vim.api.nvim_set_current_win(zen.main)
		end
		return
	end

	local target = target_width or 86
	-- the two vertical separators cost a column each
	local pad = math.floor((vim.o.columns - 2 - target) / 2)
	if pad < 6 then
		vim.notify("mdview: terminal too narrow for zen", vim.log.levels.WARN)
		return -- bail before touching the layout
	end

	-- a sidebar and a centred column can't both have the screen
	if toc.panel then
		M.toc()
	end

	local main = vim.api.nvim_get_current_win()
	zen.main = main
	vim.wo[main].signcolumn = "no"

	for _, cmd in ipairs({ "topleft vnew", "botright vnew" }) do
		vim.cmd(cmd)
		local w, b = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()
		vim.bo[b].buftype = "nofile"
		vim.bo[b].bufhidden = "wipe"
		vim.bo[b].swapfile = false
		vim.api.nvim_win_set_width(w, pad)
		vim.wo[w].winfixwidth = true
		vim.wo[w].number = false
		vim.wo[w].relativenumber = false
		vim.wo[w].foldcolumn = "0"
		vim.wo[w].signcolumn = "no"
		vim.wo[w].cursorline = false
		vim.wo[w].winbar = ""
		zen.wins[#zen.wins + 1] = w
	end

	vim.api.nvim_set_current_win(main)
	M.dim(true)
end

return M
