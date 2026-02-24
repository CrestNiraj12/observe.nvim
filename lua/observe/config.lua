local constants = require("observe.constants")

local M = {}

---@class ObserveConfig
---@field adapters table<string, boolean>?
---@field max_spans integer?
---@field max_timeline_spans integer? -- minimum 10

---@type ObserveConfig
M.defaults = {
	adapters = {},
	max_spans = 1000,
	max_timeline_spans = 50,
}

---@param user ObserveConfig?
---@return ObserveConfig
function M.merge(user)
	if user and user.max_timeline_spans and user.max_timeline_spans < 10 then
		vim.notify("`max_timeline_spans` must be >= 10", vim.log.levels.WARN, { title = constants.PLUGIN_NAME })
	end

	return vim.tbl_deep_extend("force", {}, M.defaults, user or {})
end

return M
