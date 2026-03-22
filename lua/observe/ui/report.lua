-- TODO: NEED TO MAKE DESIGN DECISION OF CURRENTLY IMPLEMENTED BUFFER SYSTEM
-- MAYBE JUST LIKE OUR RIGHT SIDE OUTLINE view
-- ADD ICONS, COMMENT HIGHLIGHT OUT THE PATH, SET A WIDTH FOR THE BUFFER

local store = require("observe.core.store")
local view = require("observe.ui.view")
local win_util = require("observe.utils.win")

local REPORT_INFO = "observe://report-info"
local REPORT_TIMELINE = "observe://report-timeline"
local REPORT_FILETYPE = "observe-report"
local ns_marks = vim.api.nvim_create_namespace(REPORT_FILETYPE)
local ns_hl = vim.api.nvim_create_namespace(REPORT_FILETYPE .. "-hl")

local M = {}

local report_info_buf ---@type integer?
local report_timeline_buf ---@type integer?

---Set highlights
local function ensure_highlights()
	vim.api.nvim_set_hl(0, "ObserveMuted", { link = "Comment" })
	vim.api.nvim_set_hl(0, "ObserveTitle", { bold = true })
end

---Apply highlights to buffer
local function apply_highlights(buf, lines)
	vim.api.nvim_buf_clear_namespace(buf, ns_hl, 0, -1)

	for i, line in ipairs(lines) do
		local ln = i - 1
		if ln == 0 then
			vim.api.nvim_buf_set_extmark(buf, ns_hl, ln, 0, {
				end_col = #line,
				hl_group = "ObserveTitle",
			})
		end

		if line:find("Timeline", 1, true) then
			local start_col = line:find("%(.-%)")
			if start_col then
				vim.api.nvim_buf_set_extmark(buf, ns_hl, ln, start_col - 1, {
					end_col = #line,
					hl_group = "ObserveMuted",
				})
			end
		end
	end
end

---Create and return buffer
---@param name string
---@return integer
local function ensure_buf(name)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(buf, name)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "hide"
	vim.bo[buf].swapfile = false
	vim.bo[buf].modifiable = false
	vim.bo[buf].filetype = REPORT_FILETYPE
	return buf
end

---Open a new timeline buffer if there isn't already a valid one,
---set keymap 'q' to close, 'h' to hide, 'i' to toggle info, and return the buffer
---@param force boolean
---@return integer|nil
local function ensure_timeline_buf(force)
	if report_timeline_buf and vim.api.nvim_buf_is_valid(report_timeline_buf) then
		return report_timeline_buf
	end

	if not force then
		return nil
	end

	local buf = ensure_buf(REPORT_TIMELINE)
	report_timeline_buf = buf

	vim.keymap.set("n", "q", function()
		win_util.close_window()
	end, { buffer = buf, nowait = true, silent = true })

	vim.keymap.set("n", "<CR>", function()
		win_util.open_file(report_timeline_buf, ns_marks)
	end, { buffer = buf, desc = "Open source file" })

	vim.keymap.set("n", "e", function()
		local row = vim.api.nvim_win_get_cursor(0)[1] - 1

		local marks = vim.api.nvim_buf_get_extmarks(report_timeline_buf, ns_marks, { row, 0 }, { row, -1 }, {})
		if #marks == 0 then
			return
		end

		local source_marks = store.get_marks()
		local id
		for _, m in ipairs(marks) do
			local mid = m[1]
			if source_marks[mid] ~= nil then
				id = mid
				break
			end
		end

		if not id then
			return
		end

		local info = source_marks[id]
		if not info then
			return
		end

		M.toggle_span_and_render(info.span_id)
	end, { buffer = buf, desc = "Open source file" })
	return buf
end

---Open a new info buffer if there isn't already a valid one,
---set keymap 'q' to close, 'h' to hide, 't' to toggle timeline, and return the buffer
---@param force boolean
---@return integer|nil
local function ensure_info_buf(force)
	if report_info_buf and vim.api.nvim_buf_is_valid(report_info_buf) then
		return report_info_buf
	end

	if not force then
		return nil
	end

	local buf = ensure_buf(REPORT_INFO)
	report_info_buf = buf

	vim.keymap.set("n", "q", function()
		win_util.close_window()
	end, { buffer = buf, nowait = true, silent = true })

	vim.keymap.set("n", "<CR>", function()
		win_util.open_file(report_info_buf, ns_marks)
	end, { buffer = buf, desc = "Open source file" })

	return buf
end

---@param buf integer
---@param lines string[]
local function set_lines(buf, lines)
	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false

	vim.api.nvim_buf_clear_namespace(buf, ns_marks, 0, -1)

	local marks
	if buf == report_info_buf then
		marks = view.get_info_extmarks()
	elseif buf == report_timeline_buf then
		marks = view.get_timeline_extmarks()
	end

	for i = 1, #lines do
		local info = marks[i]
		if info then
			local ext = vim.api.nvim_buf_set_extmark(buf, ns_marks, i - 1, 0, {})
			local src
			if info.source and info.source ~= "" then
				src = info.source
			end

			local data = { source = src, span_id = info.span_id }
			store.set_mark(ext, data)
		end
	end

	apply_highlights(buf, lines)
end

---Return window that contains the buffer
---@param info_buf integer?
---@param timeline_buf integer?
---@return integer|nil
local function find_window_showing_buf(info_buf, timeline_buf)
	if not info_buf and not timeline_buf then
		return nil
	end

	local wins = vim.api.nvim_list_wins()
	for _, win in pairs(wins) do
		local curr_win = vim.api.nvim_win_get_buf(win)
		if curr_win == info_buf or curr_win == timeline_buf then
			return win
		end
	end

	return nil
end

---Set lines of info and timeline buffer
---@param info_lines string[]
---@param timeline_lines string[]
local function set_buf_lines(info_lines, timeline_lines)
	local info_buf = ensure_info_buf(false)
	local timeline_buf = ensure_timeline_buf(info_buf and false or true)

	if timeline_buf then
		set_lines(timeline_buf, timeline_lines)
	end

	if info_buf then
		set_lines(info_buf, info_lines)
	end

	vim.cmd("normal! gg")
end

---Open report in buffer
---@param info_lines string[]
---@param timeline_lines string[]
function M.open_report(info_lines, timeline_lines)
	local timeline_buf = ensure_timeline_buf(false)
	local info_buf = ensure_info_buf(false)
	ensure_highlights()

	local cur_buf = vim.api.nvim_get_current_buf()

	-- Refresh only if user is already in report buffer
	if cur_buf == timeline_buf or cur_buf == info_buf then
		set_buf_lines(info_lines, timeline_lines)
		return
	end

	local existing_win = find_window_showing_buf(timeline_buf, info_buf)
	if existing_win then
		vim.api.nvim_set_current_win(existing_win)
		set_buf_lines(info_lines, timeline_lines)
		return
	end

	timeline_buf = ensure_timeline_buf(true)
	info_buf = ensure_info_buf(true)
	if info_buf then
		vim.cmd("botright 15split")
		win_util.clean_window()
		vim.api.nvim_win_set_buf(0, info_buf)
		if timeline_buf then
			vim.cmd("botright 40vsplit")
			win_util.clean_window()
			vim.api.nvim_win_set_buf(0, timeline_buf)
		end
	end

	set_buf_lines(info_lines, timeline_lines)
end

---Toggle span in timeline and render its child
---@param span_id integer
function M.toggle_span_and_render(span_id)
	local buf = ensure_timeline_buf(false)
	local cur_buf = vim.api.nvim_get_current_buf()

	if not buf or cur_buf ~= buf then
		return
	end

	local saved_view = vim.fn.winsaveview()
	local spans = store.toggle_span_view(span_id)
	local _, lines = view.render(spans)
	set_lines(buf, lines)
	vim.fn.winrestview(saved_view)
end

return M
