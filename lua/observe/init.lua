local config = require("observe.config")
local constants = require("observe.constants")
local store = require("observe.core.store")
local view = require("observe.ui.view")
local report = require("observe.ui.report")
local adapters = require("observe.adapters.adapter")

local M = {}

---@type ObserveState
local state = {
	enabled = false,
	config = config.defaults,
}

---Configure the plugin with user options
---@param opts ObserveConfig?
function M.setup(opts)
	state.config = config.merge(opts)
	store.configure({ max_spans = state.config.max_spans })
	view.configure({ max_timeline_spans = state.config.max_timeline_spans })
	adapters.configure(state.config.adapters)
end

---Start tracing
function M.start()
	if state.enabled then
		vim.notify("Tracing is already active.", vim.log.levels.WARN, { title = constants.PLUGIN_NAME })
		return
	end

	state.enabled = true
	store.reset()
	store.enable()
	adapters.enable()

	vim.notify("Tracing started!", vim.log.levels.INFO, { title = constants.PLUGIN_NAME })
end

---Stop tracing
function M.stop()
	if not state.enabled then
		vim.notify("Tracing is not active!", vim.log.levels.WARN, { title = constants.PLUGIN_NAME })
		return
	end

	state.enabled = false
	adapters.disable()
	store.disable()
	M.report()

	vim.notify("Tracing stopped!", vim.log.levels.INFO, { title = constants.PLUGIN_NAME })
end

---Generate and display report based on collected spans
function M.report()
	if state.enabled then
		vim.notify("Stop tracing before generating report.", vim.log.levels.WARN, { title = constants.PLUGIN_NAME })
		return
	end

	vim.notify("Generating report...", vim.log.levels.INFO, { title = constants.PLUGIN_NAME })
	local spans = store.get_spans()
	local info_lines, timeline_lines = view.render(spans)
	report.open_report(info_lines, timeline_lines)
end

---Check if tracing is currently active
---@re
function M.is_enabled()
	return store.is_enabled()
end

return M
