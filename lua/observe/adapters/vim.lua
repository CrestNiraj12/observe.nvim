local store = require("observe.core.store")
local path_utils = require("observe.utils.path")

local M = {}

local patched = false

local original_vim_cmd = vim.cmd
local original_vim_schedule = vim.schedule
local original_vim_defer_fn = vim.defer_fn

---Patch vim.cmd
---@param cb function|table|unknown
local function wrap_callback(cb, ...)
	local parent_id = store.get_parent_id()
	local info = path_utils.determine_source()

	---@type CmdMeta
	local meta = {
		type = "cmd",
		source = path_utils.get_formatted_line(info.truncated_source, info.current_line),
		full_source = path_utils.get_formatted_line(info.full_source, info.current_line),
		cmd = "vim.cmd",
	}

	local args = ...
	if type(args) == "string" then
		local sep_index = vim.trim(args):find(" ")
		meta.cmd = sep_index and args:sub(1, sep_index - 1) or args
		if sep_index and sep_index + 1 <= #args then
			meta.args = args:sub(sep_index + 1, -1)
		end
	elseif type(args) == "table" and args.cmd then
		if args.cmd then
			meta.cmd = args.cmd
			if args.args then
				if type(args.args) == "table" then
					meta.args = table.concat(args.args, ", ")
				else
					meta.args = args.args
				end
			end
		end
	end

	local name = string.format("%s: %s", "Cmd", meta.cmd)
	store.begin_span(name, meta, parent_id)

	local results = { pcall(function(...)
		return cb(...)
	end, ...) }

	store.finish_span()
	local ok = table.remove(results, 1)
	if #results <= 0 then
		return nil
	end

	if not ok then
		error(results[1], 2)
	end

	return unpack(results)
end

---Patch vim callback for async commands like schedule, defer_fn etc
---@param cb function
---@param type string
---@return function
local function wrap_async_callback(cb, type)
	local info = path_utils.determine_source()
	local parent_id = store.get_parent_id()

	return function(...)
		---@type Meta
		local meta = {
			type = type,
			source = path_utils.get_formatted_line(info.truncated_source, info.current_line),
			full_source = path_utils.get_formatted_line(info.full_source, info.current_line),
		}

		local name = string.format("%s: %s", "Cmd", meta.source)
		store.begin_span(name, meta, parent_id)

		local results = { pcall(cb, ...) }

		store.finish_span()
		local ok = table.remove(results, 1)
		if #results <= 0 then
			return nil
		end

		if not ok then
			error(results[1], 2)
		end

		return unpack(results)
	end
end

---Patch vim cmd with our tracing wrapper
---@return function|table|unknown
local function patched_vim_cmd(...)
	return wrap_callback(original_vim_cmd, ...)
end

---Patch vim schedule callback with our tracing wrapper
---@param fn function
local function patched_vim_schedule(fn)
	return original_vim_schedule(wrap_async_callback(fn, "schedule"))
end

---Patch vim schedule callback with our tracing wrapper
---@param fn function
---@param timeout integer
---@return table
local function patched_vim_defer_fn(fn, timeout)
	return original_vim_defer_fn(wrap_async_callback(fn, "defer_fn"), timeout)
end

---Enable vim functions patching
function M.enable()
	if patched then
		return
	end

	patched = true
	vim.cmd = patched_vim_cmd
	vim.schedule = patched_vim_schedule
	vim.defer_fn = patched_vim_defer_fn
end

---Disable vim functions patching
function M.disable()
	if not patched then
		return
	end

	patched = false
	vim.cmd = original_vim_cmd
	vim.schedule = original_vim_schedule
	vim.defer_fn = original_vim_defer_fn
end

return M
