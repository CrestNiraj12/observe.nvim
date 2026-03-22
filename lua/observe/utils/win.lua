local path_utils = require("observe.utils.path")
local extmarks = require("observe.utils.extmarks")

local M = {}

---Close current window
function M.close_window()
	local wins = vim.api.nvim_list_wins()
	if #wins > 1 then
		-- if there are more than 1 window, close the current window
		pcall(vim.api.nvim_win_close, 0, false)
		return
	end

	-- if there is only 1 window,
	-- create a new buffer inside the window and close the current report buffer
	local cur_buf = vim.api.nvim_get_current_buf()
	vim.cmd("enew")
	pcall(vim.api.nvim_buf_delete, cur_buf, { force = true })
end

---Open file using source from current line's extmark if there is any
---@param buf integer
---@param ns integer
function M.open_file(buf, ns)
	local row = vim.api.nvim_win_get_cursor(0)[1] - 1

	local marks = vim.api.nvim_buf_get_extmarks(buf, ns, { row, 0 }, { row, -1 }, {})
	if #marks == 0 then
		return
	end

	local info = extmarks.get_extmark_data(marks)
	if not info or not info.source then
		return
	end

	path_utils.open_location_enter(buf, info.source)
end

function M.clean_window()
	vim.wo.number = false
	vim.wo.relativenumber = false
	vim.wo.signcolumn = "no"
	vim.wo.foldcolumn = "0"
	vim.wo.cursorline = true
	vim.wo.wrap = false
	vim.wo.list = false
	vim.wo.statusline = " "
end

return M
