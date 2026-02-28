local autocmd_adapter = require("observe.adapters.autocmd")
local lsp_adapter = require("observe.adapters.lsp")
local cmd_adapter = require("observe.adapters.cmd")

local M = {}

---@type table<HandlerType, boolean>
local state = {
	autocmd = true,
	lsp = true,
	cmd = true,
}

---Configure adapters
---@param config table<HandlerType, boolean>
function M.configure(config)
	if not config or type(config) ~= "table" or not next(config) then
		return
	end

	state = vim.tbl_deep_extend("force", {}, state, config)
end

function M.enable()
	if state.autocmd then
		autocmd_adapter.enable()
	end

	if state.lsp then
		lsp_adapter.enable()
	end

	if state.cmd then
		cmd_adapter.enable()
	end
end

function M.disable()
	autocmd_adapter.disable()
	lsp_adapter.disable()
	cmd_adapter.disable()
end

return M
