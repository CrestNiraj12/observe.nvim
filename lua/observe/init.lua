local config = require("observe.config")
local constants = require("observe.constants")
local store = require("observe.core.store")
local view = require("observe.ui.view")
local report = require("observe.ui.report")
local autocmd_adapter = require("observe.adapters.autocmd")

local M = {}

---@class ObserveState
---@field enabled boolean
---@field config ObserveConfig

---@type ObserveState
local state = {
	enabled = false,
	config = config.defaults,
}

---@param opts ObserveConfig?
function M.setup(opts)
	state.config = config.merge(opts)
	store.configure({ max_spans = state.config.max_spans })
	view.configure({ max_timeline_spans = state.config.max_timeline_spans })
end

function M.start()
	if state.enabled then
		vim.notify("Tracing is already active.", vim.log.levels.WARN, { title = constants.PLUGIN_NAME })
		return
	end

	state.enabled = true
	store.reset()
	store.enable()
	autocmd_adapter.enable()

	vim.notify("Tracing started!", vim.log.levels.INFO, { title = constants.PLUGIN_NAME })
end

function M.stop()
	if not state.enabled then
		vim.notify("Tracing is not active!", vim.log.levels.WARN, { title = constants.PLUGIN_NAME })
		return
	end

	state.enabled = false
	autocmd_adapter.disable()
	store.disable()

	vim.notify("Tracing stopped. Generating report...", vim.log.levels.INFO, { title = constants.PLUGIN_NAME })
end

function M.report()
	if state.enabled then
		vim.notify("Stop tracing before generating report.", vim.log.levels.WARN, { title = constants.PLUGIN_NAME })
		return
	end

	local spans = store.get_spans()
	local lines = view.render(spans)
	report.open_report(lines)
end

function M.is_enabled()
	return store.is_enabled()
end

return M
