local constants = require("observe.constants")
local utils = require("observe.utils.metadata")

local M = {}

---@class TimelineViewState
---@field max_timeline_spans integer

---@class ReportUIState: TimelineViewState
---@field show_timeline boolean
---@field extmarks table<integer, string>

---@type ReportUIState
local state = {
	show_timeline = false,
	max_timeline_spans = 50,
	extmarks = {},
}

function M.get_extmarks()
	return state.extmarks
end

---Configure view state
---@param opts TimelineViewState
function M.configure(opts)
	if opts and opts.max_timeline_spans then
		state.max_timeline_spans = math.max(constants.MIN_TIMELINE_SPANS, opts.max_timeline_spans)
	end
end

---Toggle timeline show/hide status
function M.toggle_timeline_view()
	state.show_timeline = not state.show_timeline
end

---@class RenderLineMeta
---@field line string
---@field source? string

---Render top 10 slowest spans
---@param spans ObserveSpan[]
---@return RenderLineMeta[]
local function render_top_slow_spans(spans)
	local lines = {} ---@type RenderLineMeta[]
	lines[#lines + 1] = { line = "" }

	local header = "Top slow spans"
	lines[#lines + 1] = { line = header }
	lines[#lines + 1] = { line = string.rep("-", #header) }

	local spans_copy = vim.tbl_extend("force", {}, spans) ---@type ObserveSpan[]
	table.sort(spans_copy, function(a, b)
		return (a.duration_ns or 0) > (b.duration_ns or 0)
	end)

	for i = 1, math.min(10, #spans_copy) do
		local span = spans_copy[i]
		local index = #lines + 1
		lines[index] = { line = utils.format_info(span), source = span.meta and span.meta.full_source }
	end
	return lines
end

---Render top 10 total durations by source or name
---@param spans ObserveSpan[]
---@param key "source" | "name"
---@return RenderLineMeta[]
local function render_total_duration_by_filter(spans, key)
	local lines = {} ---@type RenderLineMeta[]
	lines[#lines + 1] = { line = "" }

	local header = "Top totals by " .. key
	lines[#lines + 1] = { line = header }
	lines[#lines + 1] = { line = string.rep("-", #header) }

	---@class MergeMeta
	---@field duration integer
	---@field source string?

	local merged_by_filter = {} ---@type table<string, MergeMeta>
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

		merged_by_filter[data] = {
			duration = ((merged_by_filter[data] or {}).duration or 0) + (span.duration_ns or 0),
			source = span.meta and span.meta.full_source,
		}
	end

	---@class TotalByKey
	---@field key string
	---@field duration integer
	---@field source string?

	local totals_by_key = {} ---@type TotalByKey[]
	for k, v in pairs(merged_by_filter) do
		totals_by_key[#totals_by_key + 1] = { key = k, duration = v.duration, source = v.source }
	end

	table.sort(totals_by_key, function(a, b)
		return a.duration > b.duration
	end)

	for i = 1, math.min(10, #totals_by_key) do
		local merge_meta = totals_by_key[i]
		local ms = utils.ns_to_ms(merge_meta.duration)
		lines[#lines + 1] =
			{ line = string.format("%s\t%s", utils.render_timestamp(ms), merge_meta.key), source = merge_meta.source }
	end
	return lines
end

---Render recent spans (up to max_timeline_spans, default 50)
---@param spans ObserveSpan[]
---@return RenderLineMeta[]
local function render_timeline(spans)
	local lines = {}

	local timeline_header = (state.show_timeline and "▼" or "►") .. " Timeline"
	local header_with_hint = timeline_header
	if not state.show_timeline then
		header_with_hint = header_with_hint .. " (press t to reveal)"
	end

	lines[#lines + 1] = { line = "" }
	lines[#lines + 1] = { line = header_with_hint }

	if state.show_timeline then
		lines[#lines + 1] = { line = string.rep("-", #timeline_header) }
		local start_i = math.max(1, #spans - state.max_timeline_spans + 1)
		for i = start_i, #spans do
			local span = spans[i]
			local index = #lines + 1
			lines[index] = { line = utils.format_info(span), source = span.meta and span.meta.full_source }
		end
	end

	return lines
end

---Generate report based on spans
---@param spans ObserveSpan[]
---@return string[]
function M.render(spans)
	state.extmarks = {}
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

	local categories = {
		render_top_slow_spans(spans),
		render_total_duration_by_filter(spans, "source"),
		render_total_duration_by_filter(spans, "name"),
		render_timeline(spans),
	}

	for _, category in ipairs(categories) do
		for _, v in ipairs(category) do
			local index = #lines + 1
			lines[index] = v.line
			state.extmarks[index] = v.source
		end
	end

	lines[#lines + 1] = ""
	return lines
end

return M
