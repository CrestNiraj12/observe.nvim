local utils = require("observe.ui.utils")
local store = require("observe.core.store")

local M = {}

---@class ReportUIState
---@field show_timeline boolean

---@type ReportUIState
local state = {
	show_timeline = false,
}

---Render top 10 slowest spans
---@param spans ObserveSpan[]
---@return string[]
local function render_top_slow_spans(spans)
	local lines = {}
	lines[#lines + 1] = ""

	local header = "Top slow spans"
	lines[#lines + 1] = header
	lines[#lines + 1] = string.rep("-", #header)

	local spans_copy = vim.tbl_extend("force", {}, spans)
	table.sort(spans_copy, function(a, b)
		return (a.duration_ns or 0) > (b.duration_ns or 0)
	end)

	for i = 1, math.min(10, #spans_copy) do
		local span = spans_copy[i]
		lines[#lines + 1] = utils.format_info(span)
	end
	return lines
end

---Render top 10 total durations by source or name
---@param spans ObserveSpan[]
---@param key "source" | "name"
---@return string[]
local function render_total_duration_by_filter(spans, key)
	local lines = {}
	lines[#lines + 1] = ""

	local header = "Top totals by " .. key
	lines[#lines + 1] = header
	lines[#lines + 1] = string.rep("-", #header)

	local merged_by_filter = {} ---@type table<string, integer>
	if key ~= "source" and key ~= "name" then
		key = "source" -- set default filter as source
	end

	for _, span in ipairs(spans) do
		local data

		if key == "name" then
			data = span.name and span.name or "?"
		else
			data = span.meta and span.meta[key] or "?"
		end

		merged_by_filter[data] = (merged_by_filter[data] or 0) + (span.duration_ns or 0)
	end

	---@class TotalByKey
	---@field key string
	---@field duration integer

	local totals_by_key = {} ---@type TotalByKey[]
	for k, v in pairs(merged_by_filter) do
		totals_by_key[#totals_by_key + 1] = { key = k, duration = v }
	end

	table.sort(totals_by_key, function(a, b)
		return a.duration > b.duration
	end)

	for i = 1, math.min(10, #totals_by_key) do
		local span = totals_by_key[i]
		local ms = utils.ns_to_ms(span.duration)
		lines[#lines + 1] = string.format("%s\t%s", utils.render_timestamp(ms), span.key)
	end
	return lines
end

---Render top 50 recent spans
---@param spans ObserveSpan[]
---@return string[]
local function render_timeline(spans)
	local lines = {}

	local timeline_header = (state.show_timeline and "▼" or "►") .. " Timeline"
	local header_with_hint = timeline_header
	if not state.show_timeline then
		header_with_hint = header_with_hint .. " (press t to reveal)"
	end

	lines[#lines + 1] = ""
	lines[#lines + 1] = header_with_hint
	lines[#lines + 1] = string.rep("-", #timeline_header)

	if state.show_timeline then
		local start_i = math.max(1, #spans - 50 + 1)
		for i = start_i, #spans do
			local span = spans[i]
			lines[#lines + 1] = utils.format_info(span)
		end
	end

	return lines
end

---Generate report based on spans
---@param spans ObserveSpan[]
---@return string[]
function M.render(spans)
	local lines = {}
	lines[#lines + 1] = "observe.nvim --- Report"
	lines[#lines + 1] = string.rep("-", #lines[1])

	local total_ns = 0
	for _, s in ipairs(spans) do
		total_ns = total_ns + (s.duration_ns or 0)
	end

	lines[#lines + 1] = string.format("spans: %d | total: %.2fms", #spans, utils.ns_to_ms(total_ns))

	if #spans == 0 then
		lines[#lines + 1] = ""
		lines[#lines + 1] = "No spans recorded!"
		return lines
	end

	local top_slow_spans = render_top_slow_spans(spans)
	for _, v in ipairs(top_slow_spans) do
		lines[#lines + 1] = v
	end

	local total_by_duration = render_total_duration_by_filter(spans, "source")
	for _, v in ipairs(total_by_duration) do
		lines[#lines + 1] = v
	end

	local total_by_event = render_total_duration_by_filter(spans, "name")
	for _, v in ipairs(total_by_event) do
		lines[#lines + 1] = v
	end

	local timeline = render_timeline(spans)
	for _, v in ipairs(timeline) do
		lines[#lines + 1] = v
	end

	return lines
end

local REPORT_NAME = "observe://report"
local REPORT_FILETYPE = "observe-report"
local report_buf ---@type integer?

local function ensure_highlights()
	vim.api.nvim_set_hl(0, "ObserveMuted", { link = "Comment" })
	vim.api.nvim_set_hl(0, "ObserveTitle", { bold = true })
end

local function apply_highlights(buf, lines)
	local ns = vim.api.nvim_create_namespace(REPORT_FILETYPE)
	vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)

	for i, line in ipairs(lines) do
		local ln = i - 1
		if ln == 0 then
			vim.api.nvim_buf_set_extmark(buf, ns, ln, 0, {
				end_col = #line,
				hl_group = "ObserveTitle",
			})
		end

		if line:find("Timeline", 1, true) then
			local start_col = line:find("%(.-%)")
			if start_col then
				vim.api.nvim_buf_set_extmark(buf, ns, ln, start_col - 1, {
					end_col = #line,
					hl_group = "ObserveMuted",
				})
			end
		end
	end
end

---Open a new buffer if there isnt already a valid one,
---set keymap 'q' to close, and return the buffer
---@return integer
local function ensure_buf()
	if report_buf and vim.api.nvim_buf_is_valid(report_buf) then
		return report_buf
	end

	local buf = vim.api.nvim_create_buf(false, true)
	report_buf = buf
	vim.api.nvim_buf_set_name(buf, REPORT_NAME)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
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

	return buf
end

---@param buf integer
---@param lines string[]
local function set_lines(buf, lines)
	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false

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

	local cur_win = vim.api.nvim_get_current_win()
	local cur_buf = vim.api.nvim_win_get_buf(cur_win)

	-- Refresh only if user is already in report buffer
	if cur_buf == buf then
		set_lines(buf, lines)
		return
	end

	local existing_win = find_window_showing_buf(buf)
	if existing_win then
		vim.api.nvim_set_current_win(existing_win)
		set_lines(buf, lines)
		return
	end

	vim.cmd("botright split")
	vim.api.nvim_win_set_buf(0, buf)
	set_lines(buf, lines)
end

function M.toggle_timeline()
	state.show_timeline = not state.show_timeline

	local view = vim.fn.winsaveview()

	local spans = store.get_spans()
	local lines = M.render(spans)

	M.open_report(lines)

	local height = vim.api.nvim_win_get_height(0)
	if view.topline > #lines - height + 1 then
		view.topline = math.max(1, #lines - vim.fn.winheight(0) + 1)
	end

	vim.fn.winrestview(view)
end

return M
