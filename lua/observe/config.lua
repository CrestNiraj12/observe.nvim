local M = {}

---@class ObserveConfig
---@field adapters table<string, boolean>?
---@field max_spans integer?

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
