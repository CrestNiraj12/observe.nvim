local store = require("observe.core.store")
local path_utils = require("observe.utils.path")

local M = {}

---@class CreateAutocmdOpts
---@field callback function|string?
---@field pattern string|string[]?
---@field group string|integer?
---@field once boolean?
---@field nested boolean?

local original_create_autocmd = vim.api.nvim_create_autocmd
local patched = false

---@class SourceLabel
---@field label string
---@field source? string

---Find the callback source and line number if possible
---and return it
---@param cb any
---@return SourceLabel
local function callback_label(cb)
	if type(cb) == "function" then
		local info = debug.getinfo(cb, "Sln")
		if info then
			local src = info.short_src or info.source or "?"
			local truncated_src = path_utils.truncate_src(src)
			local line = info.linedefined or 0

			local full_source = nil
			if info.source and info.source:sub(1, 1) == "@" then
				local source = path_utils.clean_src(info.source)
				full_source = path_utils.get_formatted_line(source, line)
			end

			return {
				label = path_utils.get_formatted_line(truncated_src, line),
				source = full_source,
			}
		end
		return { label = "function" }
	end

	if type(cb) == "string" then
		return { label = "cmd" }
	end

	return { label = "unknown" }
end

---@class Meta
---@field group string|integer
---@field pattern string|string[]
---@field once boolean
---@field nested boolean
---@field source string?
---@field full_source string?
---@field cmd string?

---Observe the callback time
---@param event any
---@param opts CreateAutocmdOpts
---@return nil|fun(...): any
local function wrap_callback(event, opts)
	local cb = opts.callback
	if not cb then
		return nil
	end

	local source_label = callback_label(cb)
	local ev = type(event) == "table" and table.concat(event, ",") or tostring(event)
	local name = "autocmd: " .. ev

	---@type Meta
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

			meta.source = source_label.label
			meta.full_source = source_label.source
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
