---@type ObserveConfigModule
local config = require("observe.config")

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
end

function M.start()
  if state.enabled then
    vim.notify("observe.nvim is already running", vim.log.levels.WARN)
    return
  end

  state.enabled = true
  vim.notify("observe.nvim started!", vim.log.levels.INFO)
end

function M.stop()
  if not state.enabled then
    vim.notify("observe.nvim is not running", vim.log.levels.WARN)
    return
  end

  state.enabled = false
  vim.notify("observe.nvim stopped!", vim.log.levels.INFO)
end

function M.report()
  if state.enabled then
    vim.notify("stop observe.nvim before generating report", vim.log.levels.WARN)
    return
  end

  vim.notify("Report is not implemented lol!", vim.log.levels.INFO)
end

function M.is_enabled()
  return state.enabled
end

return M
