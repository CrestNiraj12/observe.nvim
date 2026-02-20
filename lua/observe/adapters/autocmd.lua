local store = require("observe.core.store")

local M = {}

---@class CreateAutocmdOpts
---@field callback function|string?
---@field pattern string|string[]?
---@field group string|integer?
---@field once boolean?
---@field nested boolean?

local original_create_autocmd = vim.api.nvim_create_autocmd
local patched = false

---Find the callback source and line number if possible
---and return it
---@param cb any
---@return string
local function callback_label(cb)
  if type(cb) == "function" then
    local info = debug.getinfo(cb, "Sln")
    if info then
      local src = info.short_src or info.source or "?"
      local line = info.linedefined or 0
      return string.format("%s:%d", src, line)
    end
    return "function"
  end

  if type(cb) == "string" then
    return "cmd"
  end

  return "unknown"
end

---Observe the callback time
---@param event any
---@param opts CreateAutocmdOpts
---@return nil|fun(...): any
local function wrap_callback(event, opts)
  local cb = opts.callback
  if not cb then
    return nil
  end

  local label = callback_label(cb)
  local ev = type(event) == "table" and table.concat(event, ",") or tostring(event)
  local name = "autocmd: " .. ev
  local meta = {
    group = opts.group,
    pattern = opts.pattern,
    once = opts.once,
    nested = opts.nested,
  }

  if type(cb) == "function" then
    return function(...)
      if not store.is_enabled() then
        return cb(...)
      end

      meta.source = label
      local h = store.begin_span(name, meta)

      local ok, result = pcall(cb, ...)
      store.finish_span(h)

      if not ok then
        error(result, 0)
      end

      return result
    end
  end

  if type(cb) == "string" then
    return function()
      if not store.is_enabled() then
        return vim.cmd(cb)
      end

      meta.source = "cmd"
      meta.cmd = cb
      local h = store.begin_span(name, meta)

      local ok, result = pcall(function()
        return vim.cmd(cb)
      end)

      store.finish_span(h)

      if not ok then
        error(result, 0)
      end

      return result
    end
  end

  return nil
end

---Patch autocmd with our tracing wrapper
---@param event any
---@param opts CreateAutocmdOpts
---@return integer
local function patched_create_autocmd(event, opts)
  if type(opts) == "table" and opts.callback then
    local new_opts = vim.tbl_deep_extend("force", {}, opts)
    new_opts.callback = wrap_callback(event, new_opts) or new_opts.callback
    return original_create_autocmd(event, new_opts)
  end
  return original_create_autocmd(event, opts)
end

function M.enable()
  if patched then
    return
  end

  patched = true
  vim.api.nvim_create_autocmd = patched_create_autocmd
end

function M.disable()
  if not patched then
    return
  end

  patched = false
  vim.api.nvim_create_autocmd = original_create_autocmd
end

return M
