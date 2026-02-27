local autocmd_adapter = require("observe.adapters.autocmd")
local lsp_adapter = require("observe.adapters.lsp")
local vim_adapter = require("observe.adapters.vim")

local M = {}

function M.enable()
	autocmd_adapter.enable()
	lsp_adapter.enable()
	vim_adapter.enable()
end

function M.disable()
	autocmd_adapter.disable()
	lsp_adapter.disable()
	vim_adapter.disable()
end

return M
