local constants = require("observe.constants")

local M = {}

--- Clean + loosely truncate a path for display.
---@param raw string
---@return string
function M.clean_src(raw)
	local max = constants.MAX_SOURCE_WIDTH

	if type(raw) ~= "string" or raw == "" then
		return "?"
	end

	-- 1) strip debug prefixes
	local src = raw:gsub("^[@=]", ""):gsub("\\", "/")

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

return M
