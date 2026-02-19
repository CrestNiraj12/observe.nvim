local clock = require("observe.core.clock")

local M = {}

---@class ObserveSpan
---@field name string
---@field start_ns integer
---@field end_ns integer
---@field duration_ns integer
---@field meta table|nil

---@class StoreState
---@field enabled boolean
---@field max_spans integer
---@field spans ObserveSpan[]?

---@type StoreState
local state = {
  enabled = false,
  max_spans = 1000,
  spans = {}
}

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

function M.reset()
  state.spans = {}
end

return M
