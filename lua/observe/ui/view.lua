local constants = require("observe.constants")
local utils = require("observe.utils.metadata")

local M = {}

---@type ReportUIState
local state = {
	show_timeline = true,
	max_timeline_spans = 0,
	info_extmarks = {},
	timeline_extmarks = {},
}

---Get current extmarks for rendered info
---@return table<integer, ExtInfo>
function M.get_info_extmarks()
	return state.info_extmarks
end

---Get extmarks for rendered timeline
---@return table<integer, ExtInfo>
function M.get_timeline_extmarks()
	return state.timeline_extmarks
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

	for i = 1, math.min(10, #spans) do
		local span = spans[i]
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
			val = (span.meta or {})[key]
			if not val then
				-- No key found inside span and span.meta
				goto continue
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
		::continue::
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
			line = string.format(" %s %s%s", utils.render_timestamp(ms), label, merge_meta.key),
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
	-- TODO: idk what to do with this now
	-- if not state.show_timeline then
	-- 	header_with_hint = header_with_hint .. " (press t to reveal)"
	-- end

	lines[#lines + 1] = { line = "" }
	lines[#lines + 1] = { line = header_with_hint }

	if not state.show_timeline then
		return lines
	end

	lines[#lines + 1] = { line = string.rep("-", #timeline_header) }

	if #spans <= 0 then
		lines[#lines + 1] = { line = "No spans recorded!" }
		return lines
	end

	local spans_copy = vim.tbl_deep_extend("force", {}, spans)
	table.sort(spans_copy, function(a, b)
		return (a.start_ns or 0) < (b.start_ns or 0)
	end)

	-- Build tree by parent_id (REAL nesting)
	local roots = {} ---@type integer[]
	local children = {} ---@type table<integer, integer[]>

	for i, s in ipairs(spans_copy) do
		if s.parent_id then
			children[s.parent_id] = children[s.parent_id] or {}
			table.insert(children[s.parent_id], i)
		else
			table.insert(roots, i)
		end
	end

	local seen_ids = {} ---@type table<integer, boolean>

	for _, root_i in ipairs(roots) do
		local stack = { { idx = root_i, depth = 0 } }

		while #stack > 0 do
			local node = table.remove(stack) -- pop
			local span_index = node.idx
			local depth = node.depth

			local curr_span = spans_copy[span_index]
			if curr_span and not seen_ids[curr_span.id] then
				seen_ids[curr_span.id] = true

				local kids = children[curr_span.id]
				local has_children = kids and #kids > 0

				if has_children and not curr_span.collapsed then
					for ci = #kids, 1, -1 do
						table.insert(stack, { idx = kids[ci], depth = depth + 1 })
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
			end
		end
	end

	return lines
end

---Generate report based on spans
---returns top 10s and timeline
---@param spans ObserveSpan[]
---@return string[], string[]
function M.render(spans)
	state.info_extmarks = {}
	state.timeline_extmarks = {}
	local lines = {}
	local timeline = {}

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
		return lines, {}
	end

	table.sort(spans, function(a, b)
		return a.duration_ns > b.duration_ns
	end)

	local categories = {
		render_top_slow_spans(spans),
		render_total_duration_by_key(spans, "source"),
		render_total_duration_by_key(spans, "name"),
		render_timeline(spans), -- always keep at bottom
	}

	local buf_lines = lines
	local extmarks = state.info_extmarks
	for i, category in ipairs(categories) do
		if i == #categories then
			buf_lines = timeline
			extmarks = state.timeline_extmarks
		end

		for _, v in ipairs(category) do
			local index = #buf_lines + 1
			buf_lines[index] = v.line
			extmarks[index] = { source = v.source, span_id = v.span_id }
		end
	end

	lines[#lines + 1] = ""
	return lines, timeline
end

return M
