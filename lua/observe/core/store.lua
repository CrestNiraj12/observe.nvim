local clock = require("observe.core.clock")

local M = {}

---@class ObserveSpan
---@field name string
---@field start_ns integer
---@field end_ns integer?
---@field duration_ns integer?
---@field meta table?

---@class StoreState
---@field enabled boolean
---@field max_spans integer
---@field spans ObserveSpan[]

---@type StoreState
local state = {
  enabled = false,
  max_spans = 1000,
  spans = {}
}


---@class ObserveStoreOpts
---@field max_spans integer?

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
---@param meta table?
---@return ObserveSpan?
function M.begin_span(name, meta)
  if not state.enabled then
    return
  end

  return {
    name = name,
    meta = meta,
    start_ns = clock.now_ns()
  }
end

--- Finishes a span and returns it or nil if disabled.
---@param h ObserveSpan?
function M.finish_span(h)
  if not h or not state.enabled then
    return
  end

  local end_ns = clock.now_ns()

  local span = {
    name = h.name,
    meta = h.meta,
    start_ns = h.start_ns,
    end_ns = end_ns,
    duration_ns = end_ns - h.start_ns,
  }

  local spans = state.spans
  spans[#spans + 1] = span

  if #spans > state.max_spans then
    table.remove(spans, 1)
  end
end

---@param name string
---@param fn function
---@param meta table?
---@return any
function M.time(name, fn, meta)
  local h = M.begin_span(name, meta)
  local ok, result = pcall(fn)
  M.finish_span(h)
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
