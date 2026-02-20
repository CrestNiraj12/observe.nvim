local config = require("observe.config")
local store = require("observe.core.store")
local report = require("observe.ui.report")
local autocmd_adapter = require("observe.adapters.autocmd")

local M = {}

---@class ObserveState
---@field enabled boolean
---@field config ObserveConfig

---@type ObserveState
local state = {
  enabled = false,
  config = config.defaults
}

---@param opts ObserveConfig?
function M.setup(opts)
  state.config = config.merge(opts)
  store.configure({ max_spans = state.config.max_spans })
end

function M.start()
  if state.enabled then
    vim.notify("observe.nvim is already running", vim.log.levels.WARN)
    return
  end

  state.enabled = true
  store.reset()
  store.enable()
  autocmd_adapter.enable()

  vim.notify("observe.nvim started!", vim.log.levels.INFO)
end

function M.stop()
  if not state.enabled then
    vim.notify("observe.nvim is not running", vim.log.levels.WARN)
    return
  end

  state.enabled = false
  autocmd_adapter.disable()
  store.disable()

  vim.notify("observe.nvim stopped!", vim.log.levels.INFO)
end

function M.report()
  if state.enabled then
    vim.notify("stop observe.nvim before generating report", vim.log.levels.WARN)
    return
  end

  local lines = report.render(store.get_spans())
  report.open_report(lines)
end

function M.is_enabled()
  return store.is_enabled()
end

return M
