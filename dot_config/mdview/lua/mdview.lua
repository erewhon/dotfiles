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

--- fenced code blocks as {first, last} pairs, plus a per-line lookup
local function scan_fences(lines)
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
	return fences, fenced
end

local function buf_info(buf)
	local tick = vim.api.nvim_buf_get_changedtick(buf)
	local c = cache[buf]
	if c and c.tick == tick then
		return c
	end

	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local fences, fenced = scan_fences(lines)

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

--------------------------------------------------------------------
-- tables: wrap cell text so wide tables fit the window
--------------------------------------------------------------------
-- render-markdown pads cells but never wraps them, so a table wider than
-- the window soft-wraps into noise. A table that won't fit is rewritten in
-- the buffer: each cell is word-wrapped to its column and spread over
-- continuation rows, with a rule drawn between logical rows. The file's
-- own text is kept, re-wrapped on resize and put back for a write.

local tables = { ns = vim.api.nvim_create_namespace("mdview_tables"), src = {} }

local MIN_COL = 8 -- narrower than this, wrapping stops helping

--- cells of a table row, split on unescaped pipes and trimmed
local function split_cells(line)
	local body = vim.trim(line)
	local cells, cur, i = {}, {}, 1
	while i <= #body do
		local c = body:sub(i, i)
		if c == "\\" then
			cur[#cur + 1] = body:sub(i, i + 1)
			i = i + 2
		elseif c == "|" then
			cells[#cells + 1] = vim.trim(table.concat(cur))
			cur, i = {}, i + 1
		else
			cur[#cur + 1] = c
			i = i + 1
		end
	end
	cells[#cells + 1] = vim.trim(table.concat(cur))
	if body:sub(1, 1) == "|" then
		table.remove(cells, 1)
	end
	if #body > 1 and body:sub(-1) == "|" and body:sub(-2, -2) ~= "\\" then
		table.remove(cells)
	end
	return cells
end

--- alignment of each column if this is a delimiter row (|:--|--:|), else nil
local function delimiter(line)
	if not line or not line:find("-", 1, true) then
		return nil
	end
	local aligns = {}
	for n, cell in ipairs(split_cells(line)) do
		local l, r = cell:match("^(:?)%-+(:?)$")
		if not l then
			return nil
		end
		aligns[n] = { l == ":", r == ":" }
	end
	return aligns
end

--- words of a cell; code spans and links stay whole
local function tokens(text)
	local out, i, n = {}, 1, #text
	while true do
		local s = text:find("%S", i)
		if not s then
			break
		end
		local j = s
		while j <= n and not text:sub(j, j):match("%s") do
			local c = text:sub(j, j)
			if c == "`" then
				local ticks = text:match("^`+", j)
				local close = text:find(ticks, j + #ticks, true)
				j = close and close + #ticks or j + #ticks
			elseif c == "[" then
				j = text:match("^%b[]%b()()", j) or text:match("^%b[]%b[]()", j) or j + 1
			elseif c == "\\" then
				j = j + 2
			else
				j = j + 1
			end
		end
		out[#out + 1] = text:sub(s, j - 1)
		i = j
	end
	return out
end

--- text as rendered, minus the icon render-markdown puts before each link
local function bare(text)
	local t, links = text, 0
	for _, pat in ipairs({ "%[(.-)%]%b()", "%[(.-)%]%b[]" }) do
		local n
		t, n = t:gsub(pat, "%1")
		links = links + n
	end
	t = t:gsub("`", ""):gsub("%*%*", ""):gsub("~~", "")
	return t, links
end

--- rendered width, erring wide
local function width(text)
	local t, links = bare(text)
	return vim.fn.strdisplaywidth(t) + 2 * links
end

--- columns hidden by conceal, which Neovim still counts when it wraps
local function concealed(text)
	return vim.fn.strdisplaywidth(text) - vim.fn.strdisplaywidth((bare(text)))
end

--- split a word too long for its column into column-sized pieces
local function chop(word, w)
	local parts = {}
	while vim.fn.strdisplaywidth(word) > w do
		local n = w
		while n > 1 and vim.fn.strdisplaywidth(vim.fn.strcharpart(word, 0, n)) > w do
			n = n - 1
		end
		parts[#parts + 1] = vim.fn.strcharpart(word, 0, n)
		word = vim.fn.strcharpart(word, n)
	end
	parts[#parts + 1] = word
	return parts
end

--- word-wrap a cell to w columns
local function wrap(text, w)
	local lines, cur, cw = {}, {}, 0
	local function push()
		if #cur > 0 then
			lines[#lines + 1] = table.concat(cur, " ")
		end
		cur, cw = {}, 0
	end
	-- a word too wide for the column is split without cutting its markup: a
	-- footnoted link loses its link styling, a code span becomes several
	local words = {}
	for _, tok in ipairs(tokens(text)) do
		local label = tok:match("^!?%[(.-)%]%b[]$")
		local code = tok:match("^`([^`]+)`$")
		if width(tok) <= w then
			words[#words + 1] = tok
		elseif label then
			vim.list_extend(words, tokens(label))
		elseif code then
			for _, part in ipairs(chop(code, w)) do
				words[#words + 1] = "`" .. part .. "`"
			end
		else
			words[#words + 1] = tok
		end
	end

	for _, tok in ipairs(words) do
		local tw = width(tok)
		if tw > w then
			push()
			local parts = chop(tok, w)
			for k = 1, #parts - 1 do
				lines[#lines + 1] = parts[k]
			end
			cur, cw = { parts[#parts] }, vim.fn.strdisplaywidth(parts[#parts])
		else
			if cw > 0 and cw + 1 + tw > w then
				push()
			end
			cur[#cur + 1] = tok
			cw = cw + (cw > 0 and 1 or 0) + tw
		end
	end
	push()

	-- bold or struck text broken across lines is closed and reopened, or
	-- each line would show the bare markers
	for _, mark in ipairs({ "**", "~~" }) do
		local open = false
		for k, l in ipairs(lines) do
			if open then
				l = mark .. l
			end
			local _, count = l:gsub("`[^`]*`", ""):gsub(vim.pesc(mark), "")
			open = count % 2 == 1
			if open and k < #lines then
				l = l .. mark
			end
			lines[k] = l
		end
	end

	return #lines > 0 and lines or { "" }
end

--- column widths summing to at most budget: columns narrower than a fair
--- share keep their width, the wide ones split what is left. nil if even
--- MIN_COL per column won't fit.
local function fit(natural, budget)
	local n = #natural
	local widths, left, count = {}, budget, n
	local settled = true
	while settled and count > 0 do
		settled = false
		local share = math.floor(left / count)
		for i = 1, n do
			if not widths[i] and natural[i] <= share then
				widths[i], left, count = natural[i], left - natural[i], count - 1
				settled = true
			end
		end
	end
	if count == 0 then
		return widths
	end
	local share, extra = math.floor(left / count), left % count
	if share < MIN_COL then
		return nil
	end
	for i = 1, n do
		if not widths[i] then
			widths[i] = share + (extra > 0 and 1 or 0)
			extra = extra - 1
		end
	end
	return widths
end

local SUPERSCRIPT = { "⁰", "¹", "²", "³", "⁴", "⁵", "⁶", "⁷", "⁸", "⁹" }

--- a footnote marker: 12 -> ¹²
local function superscript(n)
	return (tostring(n):gsub("%d", function(d)
		return SUPERSCRIPT[tonumber(d) + 1]
	end))
end

--- the wrapped table, or nil when it already fits: its lines, the source
--- line each came from, and virtual lines to draw ({row, above, lines}, row
--- 0-based into the returned lines). notes counts footnotes across the
--- buffer so their labels stay unique.
local function reflow(t, budget, notes)
	local n = #t.aligns
	local function natural_widths(rows)
		local natural = {}
		for i = 1, n do
			natural[i] = 3
			for _, row in ipairs(rows) do
				natural[i] = math.max(natural[i], width(row[i] or ""))
			end
		end
		return natural
	end
	local function sum(list)
		local total = 0
		for _, v in ipairs(list) do
			total = total + v
		end
		return total
	end

	-- each column costs a border and a space either side; one closing border
	-- and a spare column, since render-markdown conceals a space in some
	-- empty cells and Neovim still counts it
	local room = budget - vim.fn.strdisplaywidth(t.indent) - 2 - 3 * n
	-- concealed markup counts too: a long link URL alone can wrap a row
	local hidden = 0
	for _, row in ipairs(t.rows) do
		local h = 0
		for i = 1, n do
			h = h + concealed(row[i] or "")
		end
		hidden = math.max(hidden, h)
	end
	if sum(natural_widths(t.rows)) + hidden <= room then
		return nil
	end

	-- a URL is concealed but still counts toward where Neovim wraps the
	-- line, so links move it into a footnote under the table
	local defs, rows = {}, {}
	for r, row in ipairs(t.rows) do
		rows[r] = {}
		for i = 1, n do
			rows[r][i] = (row[i] or ""):gsub("(!?)%[([^%]]*)%]%(([^%)]*)%)", function(bang, text, url)
				notes.n = notes.n + 1
				local mark = superscript(notes.n)
				defs[#defs + 1] = t.indent .. "[" .. mark .. "]: " .. url
				return bang .. "[" .. text .. mark .. "][" .. mark .. "]"
			end)
		end
	end
	local natural = natural_widths(rows)

	-- wrap, then shrink until the widest line's concealed markup fits too
	local widths, wrapped
	local target = room
	for _ = 1, 8 do
		local w = fit(natural, target)
		if not w then
			-- too narrow to make room for it all: settle for the last fit
			if not widths then
				return nil
			end
			break
		end
		widths, wrapped = w, {}
		local over = 0
		for r, row in ipairs(rows) do
			local cells, height = {}, 1
			for i = 1, n do
				cells[i] = wrap(row[i], widths[i])
				height = math.max(height, #cells[i])
			end
			for k = 1, height do
				local hidden = 0
				for i = 1, n do
					hidden = hidden + concealed(cells[i][k] or "")
				end
				over = math.max(over, hidden)
			end
			wrapped[r] = { cells = cells, height = height }
		end
		if sum(widths) + over <= room then
			break
		end
		target = math.min(target - 1, room - over)
	end

	local out, map, marks = {}, {}, {}
	local function emit(r, src)
		local row = wrapped[r]
		for k = 1, row.height do
			local parts = {}
			for i = 1, n do
				parts[i] = row.cells[i][k] or ""
			end
			out[#out + 1] = t.indent .. "| " .. table.concat(parts, " | ") .. " |"
			map[#out] = src
		end
	end

	-- a table has one header row, so the rest of a wrapped header is drawn
	-- as virtual lines between it and the delimiter
	local head = wrapped[1]
	local first = {}
	for i = 1, n do
		first[i] = head.cells[i][1]
	end
	out[1], map[1] = t.indent .. "| " .. table.concat(first, " | ") .. " |", t.first
	local extra = {}
	for k = 2, head.height do
		local chunks = { { t.indent }, { "│", "RenderMarkdownTableHead" } }
		for i = 1, n do
			local text = bare(head.cells[i][k] or "")
			local fill = widths[i] - vim.fn.strdisplaywidth(text)
			local a = t.aligns[i]
			local left = (a[1] and a[2]) and math.floor(fill / 2) or (a[2] and fill or 0)
			local cell = string.rep(" ", left + 1) .. text .. string.rep(" ", fill - left + 1)
			chunks[#chunks + 1] = { cell, "@markup.heading" }
			chunks[#chunks + 1] = { "│", "RenderMarkdownTableHead" }
		end
		extra[#extra + 1] = chunks
	end
	if #extra > 0 then
		marks[#marks + 1] = { row = 0, above = false, lines = extra }
	end

	-- the delimiter fixes each column's width, so render-markdown pads every
	-- cell to exactly what was wrapped to
	local delim = {}
	for i, a in ipairs(t.aligns) do
		delim[i] = (a[1] and ":" or "-") .. string.rep("-", widths[i]) .. (a[2] and ":" or "-")
	end
	out[#out + 1] = t.indent .. "|" .. table.concat(delim, "|") .. "|"
	map[#out] = t.first + 1

	local rule = {}
	for i = 1, n do
		rule[i] = string.rep("─", widths[i] + 2)
	end
	rule = { { { t.indent .. "├" .. table.concat(rule, "┼") .. "┤", "RenderMarkdownTableRow" } } }

	for r = 2, #rows do
		-- the first body row already sits on the delimiter's rule
		if r > 2 then
			marks[#marks + 1] = { row = #out, above = true, lines = rule }
		end
		emit(r, t.first + r)
	end

	if #defs > 0 then
		table.insert(defs, 1, "")
		for _, d in ipairs(defs) do
			out[#out + 1] = d
			map[#out] = t.last
		end
	end

	return out, map, marks
end

--- tables in a list of lines, skipping fenced code
local function find_tables(lines)
	local _, fenced = scan_fences(lines)
	local found, i = {}, 1
	while i < #lines do
		local aligns = not fenced[i] and lines[i]:find("|", 1, true) and delimiter(lines[i + 1])
		local header = aligns and split_cells(lines[i])
		if header and #header == #aligns then
			local t = {
				first = i,
				indent = lines[i]:match("^%s*"),
				aligns = aligns,
				rows = { header },
			}
			local j = i + 2
			while j <= #lines and not fenced[j] and lines[j]:find("|", 1, true) do
				t.rows[#t.rows + 1] = split_cells(lines[j])
				j = j + 1
			end
			t.last = j - 1
			found[#found + 1] = t
			i = j
		else
			i = i + 1
		end
	end
	return found
end

local function set_lines(buf, lines)
	local bo = vim.bo[buf]
	local undolevels, modifiable, modified = bo.undolevels, bo.modifiable, bo.modified
	bo.undolevels, bo.modifiable = -1, true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	bo.undolevels, bo.modifiable, bo.modified = undolevels, modifiable, modified
end

--- wrap the wide tables in buf to fit win; a no-op when nothing changes
function M.tables(buf, win)
	buf = buf or vim.api.nvim_get_current_buf()
	win = win or vim.fn.bufwinid(buf)
	if win == -1 then
		return
	end
	local info = vim.fn.getwininfo(win)[1]
	local budget = info.width - info.textoff
	local s = tables.src[buf]
	if s and s.budget == budget then
		return
	end

	local src = s and s.lines or vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local out, map, marks = {}, {}, {}
	local next_src, notes, changed = 1, { n = 0 }, false
	local function copy(upto)
		for k = next_src, upto do
			out[#out + 1] = src[k]
			map[#out] = k
		end
		next_src = upto + 1
	end
	for _, t in ipairs(find_tables(src)) do
		local lines, tmap, tmarks = reflow(t, budget, notes)
		if lines then
			copy(t.first - 1)
			local base = #out
			for k, l in ipairs(lines) do
				out[base + k] = l
				map[base + k] = tmap[k]
			end
			for _, m in ipairs(tmarks) do
				m.row = base + m.row
				marks[#marks + 1] = m
			end
			next_src, changed = t.last + 1, true
		end
	end
	copy(#src)

	if not s and not changed then
		return -- nothing too wide, and never touched: leave the buffer alone
	end

	-- keep the reader on the same source line across a re-wrap
	local cursor = vim.api.nvim_win_get_cursor(win)[1]
	local at = s and s.map[cursor] or cursor

	set_lines(buf, out)
	tables.src[buf] = { lines = src, map = map, budget = budget }

	vim.api.nvim_buf_clear_namespace(buf, tables.ns, 0, -1)
	for _, m in ipairs(marks) do
		vim.api.nvim_buf_set_extmark(buf, tables.ns, m.row, 0, {
			virt_lines = m.lines,
			virt_lines_above = m.above,
		})
	end

	for k = 1, #out do
		if map[k] >= at then
			pcall(vim.api.nvim_win_set_cursor, win, { k, 0 })
			break
		end
	end

	-- heading line numbers moved under the contents panel
	if toc.src == buf then
		toc.items = headings(buf)
	end
end

local aug = vim.api.nvim_create_augroup("MdviewTables", { clear = true })

vim.api.nvim_create_autocmd({ "BufWinEnter", "VimResized", "WinResized" }, {
	group = aug,
	callback = function()
		for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
			local buf = vim.api.nvim_win_get_buf(win)
			if vim.bo[buf].filetype == "markdown" then
				M.tables(buf, win)
			end
		end
	end,
})

-- a write saves the file's own text, never the wrapped copy
vim.api.nvim_create_autocmd("BufWritePre", {
	group = aug,
	callback = function(a)
		local s = tables.src[a.buf]
		if s then
			set_lines(a.buf, s.lines)
			vim.api.nvim_buf_clear_namespace(a.buf, tables.ns, 0, -1)
			tables.src[a.buf] = nil
		end
	end,
})
vim.api.nvim_create_autocmd("BufWritePost", {
	group = aug,
	callback = function(a)
		M.tables(a.buf)
	end,
})
vim.api.nvim_create_autocmd({ "BufReadPre", "BufWipeout" }, {
	group = aug,
	callback = function(a)
		tables.src[a.buf] = nil
	end,
})

return M
