local store = require("observe.core.store")
local path_utils = require("observe.utils.path")

local M = {}

local patched = false

---Patch LSP handler
---@param handler lsp.Handler
---@return lsp.Handler
local function patch_lsp_function(handler)
	return function(err, result, context, config)
		local buf_path, buf_type
		if context.bufnr then
			buf_path = vim.api.nvim_buf_get_name(context.bufnr)
			buf_type = vim.bo[context.bufnr].buftype
		end

		local full_source, source
		if buf_type == "" then
			full_source = buf_path
			source = buf_path and path_utils.truncate_src(buf_path)
		elseif buf_type then
			source = buf_type
		end

		---@type LSPMeta
		local meta = vim.tbl_deep_extend(
			"force",
			{},
			context,
			{ type = "lsp", source = source or "", full_source = full_source }
		)

		local name = string.format("%s: %s", "LSP", context.method or "?")
		store.begin_span(name, meta)
		local ok, res = pcall(handler, err, result, context, config)
		store.finish_span()
		if not ok then
			error(res)
		end

		return res
	end
end

local original_lsp_handlers = vim.lsp.handlers

---Patch lsp handler with our tracing wrapper
---@return lsp.Handler | table<string, lsp.Handler>
local function patched_lsp_handlers()
	if type(original_lsp_handlers) == "function" then
		vim.lsp.handlers = patch_lsp_function(original_lsp_handlers)
	elseif type(original_lsp_handlers) == "table" then
		for method, handler in pairs(original_lsp_handlers) do
			vim.lsp.handlers[method] = patch_lsp_function(handler)
		end
	end
	return vim.lsp.handlers
end

---Enable LSP handler patching to trace LSP calls
function M.enable()
	if patched then
		return
	end

	patched = true
	vim.lsp.handlers = patched_lsp_handlers()
end

---Disable LSP handler patching and restore original handlers
function M.disable()
	if not patched then
		return
	end

	patched = false
	vim.lsp.handlers = original_lsp_handlers
end

return M
