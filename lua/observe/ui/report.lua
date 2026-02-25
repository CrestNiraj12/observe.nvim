local store = require("observe.core.store")
local view = require("observe.ui.view")
local path_utils = require("observe.utils.path")

local REPORT_NAME = "observe://report"
local REPORT_FILETYPE = "observe-report"
local ns = vim.api.nvim_create_namespace(REPORT_FILETYPE)
local ns_hl = vim.api.nvim_create_namespace(REPORT_FILETYPE .. "-hl")

local M = {}

local report_buf ---@type integer?
-- key - extmark id, value - source path
local source_marks = {} ---@type table<integer, string>

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

---Open a new buffer if there isn't already a valid one,
---set keymap 'q' to close and 't' to toggle timeline, and return the buffer
---@return integer
local function ensure_buf()
	if report_buf and vim.api.nvim_buf_is_valid(report_buf) then
		return report_buf
	end

	local buf = vim.api.nvim_create_buf(false, true)
	report_buf = buf
	vim.api.nvim_buf_set_name(buf, REPORT_NAME)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "hide"
	vim.bo[buf].swapfile = false
	vim.bo[buf].modifiable = false
	vim.bo[buf].filetype = REPORT_FILETYPE

	vim.keymap.set("n", "q", function()
		local wins = vim.api.nvim_list_wins()
		if #wins > 1 then
			-- if there are more than 1 window, close the current window
			pcall(vim.api.nvim_win_close, 0, false)
			return
		end

		-- if there is only 1 window,
		-- create a new buffer inside the window and close the current report buffer
		local cur_buf = vim.api.nvim_get_current_buf()
		vim.cmd("enew")
		pcall(vim.api.nvim_buf_delete, cur_buf, { force = true })
	end, { buffer = buf, nowait = true, silent = true })

	vim.keymap.set("n", "t", function()
		M.toggle_timeline()
	end, { buffer = buf, desc = "Toggle timeline in report" })

	vim.keymap.set("n", "<CR>", function()
		local row = vim.api.nvim_win_get_cursor(0)[1] - 1

		local marks = vim.api.nvim_buf_get_extmarks(report_buf, ns, { row, 0 }, { row, -1 }, {})
		if #marks == 0 then
			return
		end

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

		local source = source_marks[id]
		path_utils.open_location_enter(report_buf, source)
	end, { buffer = buf, desc = "Open source file" })

	return buf
end

---@param buf integer
---@param lines string[]
local function set_lines(buf, lines)
	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false

	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
	source_marks = {}

	local marks = view.get_extmarks()
	if marks then
		for i = 1, #lines do
			local src = marks[i]
			if src and src ~= "" then
				local ext = vim.api.nvim_buf_set_extmark(buf, ns, i - 1, 0, {})
				source_marks[ext] = src
			end
		end
	end

	apply_highlights(buf, lines)
end

---Return window that contains the buffer
---@param buf integer
---@return integer|nil
local function find_window_showing_buf(buf)
	local wins = vim.api.nvim_list_wins()
	for _, win in pairs(wins) do
		if vim.api.nvim_win_get_buf(win) == buf then
			return win
		end
	end

	return nil
end

---Open report in buffer
---@param lines string[]
function M.open_report(lines)
	local buf = ensure_buf()
	ensure_highlights()

	local cur_buf = vim.api.nvim_get_current_buf()

	-- Refresh only if user is already in report buffer
	if cur_buf == buf then
		set_lines(buf, lines)
		vim.cmd("normal! gg")
		return
	end

	local existing_win = find_window_showing_buf(buf)
	if existing_win then
		vim.api.nvim_set_current_win(existing_win)
		set_lines(buf, lines)
		vim.cmd("normal! gg")
		return
	end

	vim.cmd("botright split")
	vim.api.nvim_win_set_buf(0, buf)
	set_lines(buf, lines)
	vim.cmd("normal! gg")
end

---Toggle to view/hide timeline spans
function M.toggle_timeline()
	local buf = ensure_buf()
	local cur_buf = vim.api.nvim_get_current_buf()

	if cur_buf ~= buf then
		return
	end

	local saved_view = vim.fn.winsaveview()

	view.toggle_timeline_view()

	local spans = store.get_spans()
	local lines = view.render(spans)
	set_lines(buf, lines)

	local height = vim.api.nvim_win_get_height(0)
	local max_topline = math.max(1, #lines - height + 1)
	saved_view.topline = math.min(saved_view.topline, max_topline)

	vim.fn.winrestview(saved_view)
end

return M
