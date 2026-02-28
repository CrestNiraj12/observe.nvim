---@diagnostic disable: duplicate-set-field

local store = require("observe.core.store")
local path_utils = require("observe.utils.path")

local M = {}
local patched = false

local orig_nvim_command = vim.api.nvim_command
local orig_nvim_cmd = vim.api.nvim_cmd
local orig_schedule = vim.schedule
local orig_defer_fn = vim.defer_fn

local function wrap_callback(cb, kind, ...)
	local parent_id = store.get_parent_id()
	local info = path_utils.determine_source()

	local meta = {
		type = "cmd",
		kind = kind, -- "nvim_command" | "nvim_cmd"
		source = path_utils.get_formatted_line(info.truncated_source, info.current_line),
		full_source = path_utils.get_formatted_line(info.full_source, info.current_line),
	}

	-- nice cmd name extraction
	local args1 = ...
	if type(args1) == "string" then
		meta.cmd = args1:match("^%s*(%S+)") or "?"
	elseif type(args1) == "table" and args1.cmd then
		meta.cmd = args1.cmd
	else
		meta.cmd = kind
	end

	store.begin_span(("Cmd: %s"):format(meta.cmd), meta, parent_id)

	local results = { pcall(cb, ...) }

	store.finish_span()

	local ok = table.remove(results, 1)
	if not ok then
		error(results[1], 2)
	end
	return unpack(results)
end

local function wrap_async_callback(cb, kind)
	local info = path_utils.determine_source()
	local parent_id = store.get_parent_id()

	return function(...)
		local source = "async_cmd"
		if info.truncated_source and info.current_line then
			source = path_utils.get_formatted_line(info.truncated_source, info.current_line)
		end

		local full_source
		if info.full_source and info.current_line then
			full_source = path_utils.get_formatted_line(info.full_source, info.current_line)
		end

		local meta = {
			type = "async_cmd",
			kind = kind,
			source = source,
			full_source = full_source,
		}

		store.begin_span(("Async: %s"):format(kind), meta, parent_id)
		local results = { pcall(cb, ...) }
		store.finish_span()

		local ok = table.remove(results, 1)
		if not ok then
			error(results[1], 2)
		end
		return unpack(results)
	end
end

function M.enable()
	if patched then
		return
	end
	patched = true

	vim.api.nvim_command = function(cmd_string)
		return wrap_callback(orig_nvim_command, "nvim_command", cmd_string)
	end

	vim.api.nvim_cmd = function(cmd_tbl, opts)
		return wrap_callback(orig_nvim_cmd, "nvim_cmd", cmd_tbl, opts)
	end

	vim.schedule = function(fn)
		return orig_schedule(wrap_async_callback(fn, "schedule"))
	end

	vim.defer_fn = function(fn, timeout)
		return orig_defer_fn(wrap_async_callback(fn, "defer_fn"), timeout)
	end
end

function M.disable()
	if not patched then
		return
	end
	patched = false

	vim.api.nvim_command = orig_nvim_command
	vim.api.nvim_cmd = orig_nvim_cmd
	vim.schedule = orig_schedule
	vim.defer_fn = orig_defer_fn
end

return M
