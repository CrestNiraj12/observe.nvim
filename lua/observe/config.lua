---@class ObserveConfig
---@field adapters table<string, boolean>?
---@field max_spans integer?

---@class ObserveConfigModule
---@field defaults ObserveConfig
---@field merge fun(user: ObserveConfig?): ObserveConfig

local M = {}


---@type ObserveConfig
M.defaults = {
  adapters = {},
  max_spans = 1000
}

---@param user ObserveConfig?
---@return ObserveConfig
function M.merge(user)
  return vim.tbl_deep_extend("force", {}, M.defaults, user or {})
end

return M
