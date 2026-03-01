local constants = require("observe.constants")

local M = {}

---Render line with line number
---@param src string
---@param line integer
---@return string
function M.get_formatted_line(src, line)
	return string.format("%s:%d", src, line)
end

--- Strip debug prefixes from source
---@param src string
---@return string
function M.clean_src(src)
	local path = src:gsub("^[@=]", ""):gsub("\\", "/")
	return path
end

--- Loosely truncate a path for display.
---@param raw string
---@return string
function M.truncate_src(raw)
	local max = constants.MAX_SOURCE_WIDTH

	if type(raw) ~= "string" or raw == "" then
		return "?"
	end

	local src = M.clean_src(raw)

	-- 2) drop everything up to and including "/nvim/"
	do
		local parts = vim.split(src, "/", { plain = true, trimempty = true })
		local cut
		for i, p in ipairs(parts) do
			if p:lower() == "nvim" then
				cut = i
				break
			end
		end
		if cut and cut < #parts then
			parts = vim.list_slice(parts, cut + 1, #parts)
			src = table.concat(parts, "/")
			src = ".../" .. src
		end
	end

	if #src <= max then
		return src
	end

	-- 3) loose truncate: keep adding parents from the end until it would exceed max
	local parts = vim.split(src, "/", { plain = true, trimempty = true })
	if #parts == 0 then
		return "?"
	end
	if #parts == 1 then
		return "..." .. parts[1]:sub(math.max(1, #parts[1] - max + 4))
	end

	local out = parts[#parts - 1] .. "/" .. parts[#parts] -- parent/file
	for i = #parts - 2, 1, -1 do
		local candidate = parts[i] .. "/" .. out
		if #candidate > max then
			break
		end
		out = candidate
	end

	-- add ellipsis if we truncated
	if #out < #src and (#out + 4) <= max then
		if out:sub(1, 4) ~= ".../" then
			out = ".../" .. out
		end
	elseif #out > max then
		out = out:sub(#out - max + 1)
		out = "..." .. out:sub(4)
	end

	return out
end

local function is_real_editing_window(win, report_buf)
	if not vim.api.nvim_win_is_valid(win) then
		return false
	end

	local buf = vim.api.nvim_win_get_buf(win)
	if buf == report_buf then
		return false
	end

	local bt = vim.bo[buf].buftype
	if bt ~= "" then
		-- "" means normal file buffer
		return false
	end

	return true
end

local function get_target_win(report_win, report_buf)
	-- Prefer previous window in this tabpage
	local prev = vim.fn.win_getid(vim.fn.winnr("#"))
	if is_real_editing_window(prev, report_buf) then
		return prev
	end

	-- Otherwise pick any window in current tab that isn't the report window
	local tabwins = vim.api.nvim_tabpage_list_wins(0)
	for _, win in ipairs(tabwins) do
		if win ~= report_win and is_real_editing_window(win) then
			return win
		end
	end

	-- Fallback: create a split and use it
	vim.cmd("belowright split")
	return vim.api.nvim_get_current_win()
end

function M.open_location_enter(report_buf, source)
	local file, ln = source:match("^(.*):(%d+)$")
	file = file or source

	local report_win = vim.api.nvim_get_current_win()
	local target_win = get_target_win(report_win, report_buf)

	vim.api.nvim_set_current_win(target_win)
	vim.cmd("keepalt keepjumps edit " .. vim.fn.fnameescape(file))
	if ln then
		vim.api.nvim_win_set_cursor(target_win, { tonumber(ln), 0 })
	end
end

local function is_noise_source(src)
	if not src or src == "" or src == "[C]" then
		return true
	end
	-- your plugin
	if src:find("/observe", 1, true) then
		return true
	end
	-- neovim runtime lua
	if src:find("^vim/") or src:find("/vim/") then
		return true
	end
	-- also runtime vimscript-ish
	if src:find("$VIMRUNTIME", 1, true) then
		return true
	end
	return false
end

---Get truncated and full source of command from debug info
---@return DebugInfo|nil
function M.determine_source()
	local is_noise = true

	local info, source
	for i = 2, 20 do
		info = debug.getinfo(i, "Sl")
		if not info then
			break
		end

		if info.source:sub(1, 1) == "@" then
			source = M.clean_src(info.source)
		end

		if not is_noise_source(source) then
			is_noise = false
			break
		end
	end

	if is_noise then
		return nil
	end

	local truncated_src ---@type string|nil

	if info then
		local src = info.short_src or source or "?"
		truncated_src = M.truncate_src(src)
	end

	return {
		line_defined = info and info.linedefined or nil,
		current_line = info and info.currentline or nil,
		truncated_source = truncated_src,
		full_source = source,
	}
end

return M
