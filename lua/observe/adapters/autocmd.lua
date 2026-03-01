local store = require("observe.core.store")
local path_utils = require("observe.utils.path")

local M = {}

local original_create_autocmd = vim.api.nvim_create_autocmd
local patched = false

---Find the callback source and line number if possible
---and return it
---@param cb any
---@return SourceLabel|nil
local function callback_label(cb)
	if type(cb) == "function" then
		local info = path_utils.determine_source()
		if not info then
			return nil
		end

		local label = "function"
		if info.truncated_source and info.line_defined then
			label = path_utils.get_formatted_line(info.truncated_source, info.line_defined)
		end

		local source
		if info.full_source and info.line_defined then
			source = path_utils.get_formatted_line(info.full_source, info.line_defined)
		end

		return {
			label = label,
			source = source,
		}
	end

	if type(cb) == "string" then
		return { label = "cmd" }
	end

	return { label = "unknown" }
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

	local ev = type(event) == "table" and table.concat(event, ",") or tostring(event)
	local name = string.format("%s: %s", "Autocmd", ev)

	---@type AutocmdMeta
	local meta = {
		group = opts.group,
		pattern = opts.pattern,
		once = opts.once,
		nested = opts.nested,
		type = "autocmd",
		source = "?",
	}

	local source_label = callback_label(cb)

	if type(cb) == "function" then
		return function(...)
			if not store.is_enabled() or not source_label then
				return cb(...)
			end

			meta.source = source_label.label
			meta.full_source = source_label.source
			store.begin_span(name, meta)

			local ok, result = pcall(cb, ...)
			store.finish_span()

			if not ok then
				error(result, 0)
			end

			return result
		end
	end

	if type(cb) == "string" then
		return function()
			if not store.is_enabled() or not source_label then
				return vim.cmd(cb)
			end

			meta.source = "cmd"
			meta.cmd = cb
			store.begin_span(name, meta)

			local ok, result = pcall(function()
				return vim.cmd(cb)
			end)

			store.finish_span()

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

---Enable autocmd patching to trace autocmd callbacks
function M.enable()
	if patched then
		return
	end

	patched = true
	vim.api.nvim_create_autocmd = patched_create_autocmd
end

---Disable autocmd patching and restore original functions
function M.disable()
	if not patched then
		return
	end

	patched = false
	vim.api.nvim_create_autocmd = original_create_autocmd
end

return M
