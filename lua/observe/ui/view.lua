local constants = require("observe.constants")
local utils = require("observe.ui.utils")

local M = {}

---@class TimelineViewState
---@field max_timeline_spans integer -- minimum 10

---@class ReportUIState: TimelineViewState
---@field show_timeline boolean

---@type ReportUIState
local state = {
	show_timeline = false,
	max_timeline_spans = 50,
}

---Configure view state
---@param opts TimelineViewState
function M.configure(opts)
	if opts and opts.max_timeline_spans then
		state.max_timeline_spans = math.max(10, opts.max_timeline_spans)
	end
end

---Toggle timeline show/hide status
function M.toggle_timeline_view()
	state.show_timeline = not state.show_timeline
end

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

	if state.show_timeline then
		lines[#lines + 1] = string.rep("-", #timeline_header)
		local start_i = math.max(1, #spans - state.max_timeline_spans + 1)
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
	lines[#lines + 1] = constants.PLUGIN_NAME .. " --- Report"
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

	lines[#lines + 1] = ""
	return lines
end

return M
