local constants = require("observe.constants")
local utils = require("observe.utils.metadata")

local M = {}

---@type ReportUIState
local state = {
	show_timeline = false,
	max_timeline_spans = 0,
	extmarks = {},
}

---Get current extmarks for rendered lines, used for source preview on line hover
---@return table<integer, ExtInfo>
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
		lines[index] =
			{ span_id = span.id, line = utils.format_info(span), source = span.meta and span.meta.full_source }
	end
	return lines
end

---Render top 10 total durations by span or span.meta key
---@param spans ObserveSpan[]
---@param key string
---@return RenderLineMeta[]
local function render_total_duration_by_key(spans, key)
	local lines = {} ---@type RenderLineMeta[]
	lines[#lines + 1] = { line = "" }

	local header = "Top totals by " .. key
	lines[#lines + 1] = { line = header }
	lines[#lines + 1] = { line = string.rep("-", #header) }

	local merged_by_filter = {} ---@type table<string, MergeMeta>

	for _, span in ipairs(spans) do
		local data, val

		if span[key] ~= nil then
			val = span[key]
			if type(val) ~= "string" then
				val = tostring(val)
			end
		else
			val = span.meta[key]
			if not val then
				-- No key found inside span and span.meta
				return {}
			end

			if type(val) ~= "string" then
				val = tostring(val)
			end
		end
		data = vim.trim(val)
		data = data ~= "" and data or "?"

		local splitted_name = vim.split(span.name, ":")

		local type_label
		if #splitted_name > 1 then
			type_label = splitted_name[1]
		end

		merged_by_filter[data] = {
			span_id = span.id,
			name = type_label or "?",
			duration = ((merged_by_filter[data] or {}).duration or 0) + (span.duration_ns or 0),
			source = span.meta and span.meta.full_source,
		}
	end

	local totals_by_key = {} ---@type TotalByKey[]
	for k, v in pairs(merged_by_filter) do
		totals_by_key[#totals_by_key + 1] =
			{ span_id = v.span_id, key = k, name = v.name, duration = v.duration, source = v.source }
	end

	table.sort(totals_by_key, function(a, b)
		return a.duration > b.duration
	end)

	for i = 1, math.min(10, #totals_by_key) do
		local merge_meta = totals_by_key[i]
		local label = ""
		if key ~= "name" then
			label = merge_meta.name .. ": "
		end

		local ms = utils.ns_to_ms(merge_meta.duration)
		lines[#lines + 1] = {
			span_id = merge_meta.span_id,
			line = string.format("%s %s%s", utils.render_timestamp(ms), label, merge_meta.key),
			source = merge_meta.source,
		}
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

		if #spans <= 0 then
			lines[#lines + 1] = { line = "No spans recorded!" }
			return lines
		end

		table.sort(spans, function(a, b)
			return a.start_ns < b.start_ns
		end)

		local roots = {} ---@type integer[]
		local children = {} ---@type table<integer, integer[]>
		for i, v in ipairs(spans) do
			if v.parent_id then
				children[v.parent_id] = children[v.parent_id] or {}
				table.insert(children[v.parent_id], i)
			else
				table.insert(roots, i)
			end
		end

		local seen_ids = {}
		for ri = 1, #roots do
			local depth = 0
			local root_si = roots[ri]
			local stack = { root_si } -- stack of indices

			while #stack > 0 do
				local span_index = table.remove(stack)
				local curr_span = spans[span_index]

				if curr_span and not seen_ids[curr_span.id] then
					seen_ids[curr_span.id] = true

					local kids = children[curr_span.id]
					local has_children = kids and #kids > 0
					if has_children and not curr_span.collapsed then
						for ci = #kids, 1, -1 do
							local child_i = kids[ci]
							local child_span = spans[child_i]
							if not seen_ids[child_span.id] then
								table.insert(stack, child_i)
							end
						end
					end

					---@type TreeInfo
					local tree_info = {
						depth = depth,
						has_children = has_children,
					}

					lines[#lines + 1] = {
						span_id = curr_span.id,
						line = utils.format_info(curr_span, tree_info),
						source = curr_span.meta and curr_span.meta.full_source,
					}

					if has_children and not curr_span.collapsed then
						depth = depth + 1
					end
				end
			end
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
		render_total_duration_by_key(spans, "source"),
		render_total_duration_by_key(spans, "name"),
		render_timeline(spans),
	}

	for _, category in ipairs(categories) do
		for _, v in ipairs(category) do
			local index = #lines + 1
			lines[index] = v.line
			state.extmarks[index] = { source = v.source, span_id = v.span_id }
		end
	end

	lines[#lines + 1] = ""
	return lines
end

return M
