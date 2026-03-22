local M = {}

---Convert nanosecond to millisecond timestamp
---@param ns integer
---@return number
function M.ns_to_ms(ns)
	return ns / 1e6
end

---Render timestamp logic
---@param ms number
---@return string
function M.render_timestamp(ms)
	local time
	if ms > 0.01 then
		time = string.format("%.2fms", ms)
	else
		time = "<0.01ms"
	end

	return time
end

---Extract info from meta
---@param meta table<string, any>?
---@return string, string[]
function M.parse_info_from_meta(meta)
	if not meta then
		return "", {}
	end

	local parts = {}
	local source = vim.trim(meta.source)

	if meta.type == "autocmd" then
		if meta.group then
			parts[#parts + 1] = "group=" .. tostring(meta.group)
		end
		if meta.pattern then
			local pattern = meta.pattern
			if type(pattern) == "table" then
				pattern = table.concat(pattern, ",")
			end
			parts[#parts + 1] = "pattern=" .. tostring(pattern)
		end
	elseif meta.type == "lsp" then
		if meta.bufnr then
			parts[#parts + 1] = "bufnr=" .. tostring(meta.bufnr)
		end

		if meta.client_id then
			parts[#parts + 1] = "client_id=" .. tostring(meta.client_id)
		end
	end

	return source, parts
end

return M
