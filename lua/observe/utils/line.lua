local metadata = require("observe.utils.metadata")

local M = {}

---Render nfo from span
---@param span ObserveSpan
---@param tree_info TreeInfo?
---@return string
function M.format_info(span, tree_info)
	local source, data = metadata.parse_info_from_meta(span.meta)
	if source ~= "" then
		if span.meta and (span.meta.type == "async_cmd" or span.meta.type == "cmd") then
			source = ""
		else
			source = string.format("(%s) ", source)
		end
	end

	local suffix = #data > 0 and ("  [" .. table.concat(data, " | ") .. "]") or ""
	local timestamp = metadata.ns_to_ms(span.duration_ns or 0)
	local line = string.format("%s %s%s%s", metadata.render_timestamp(timestamp), span.name, source, suffix)

	if tree_info and tree_info.depth >= 0 then
		local pad = string.rep("  ", tree_info.depth)
		if tree_info.has_children then
			local icon = span.collapsed and "▶" or "▼"
			line = icon .. "\t" .. line
		end
		line = pad .. line
	end

	return line
end

---Render line with left padding
---@param line string
---@return string
function M.render_line(line)
	return "\t" .. line
end

return M
