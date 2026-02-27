local clock = require("observe.core.clock")

local id = 1

local M = {}

---@type StoreState
local state = {
	enabled = false,
	max_spans = 1000,
	spans = {},
	active_spans = {},
}

--- Get parent id
--- @return integer?
function M.get_parent_id()
	local recent_span = state.active_spans[#state.active_spans]
	return recent_span and recent_span.id or nil
end

---@param opts ObserveStoreOpts?
function M.configure(opts)
	if opts and type(opts.max_spans) == "number" then
		state.max_spans = math.max(1, math.floor(opts.max_spans))
	end
end

function M.enable()
	state.enabled = true
end

function M.disable()
	state.enabled = false
end

---@return boolean
function M.is_enabled()
	return state.enabled
end

--- Reset spans
function M.reset()
	state.spans = {}
end

--- Begin a span and returns it or nil if disabled.
---@param name string
---@param meta Meta?
---@param parent_id integer?
function M.begin_span(name, meta, parent_id)
	if not state.enabled then
		return nil
	end

	---@type StartObserveSpan
	local span = {
		id = id,
		name = name,
		meta = meta,
		start_ns = clock.now_ns(),
		depth = #state.active_spans,
		parent_id = parent_id or M.get_parent_id(),
	}

	table.insert(state.active_spans, span)
	id = id + 1
end

--- Finishes a span and stores it in state
function M.finish_span()
	if not state.enabled or #state.active_spans < 1 then
		return
	end

	local h = table.remove(state.active_spans) ---@type StartObserveSpan
	local end_ns = clock.now_ns()

	---@type ObserveSpan
	local span = vim.tbl_deep_extend("force", {}, h, { end_ns = end_ns, duration_ns = end_ns - h.start_ns })

	local spans = state.spans
	spans[#spans + 1] = span

	if #spans > state.max_spans then
		table.remove(spans, 1)
	end
end

---@param name string
---@param fn fun(): any
---@param meta Meta?
---@return any
function M.time(name, fn, meta)
	M.begin_span(name, meta)
	local ok, result = pcall(fn)
	M.finish_span()
	if not ok then
		error(result, 0)
	end

	return result
end

---@return ObserveSpan[]
function M.get_spans()
	return state.spans
end

return M
