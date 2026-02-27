local store = require("observe.core.store")
local M = {}

---Get data from extmark
---@param marks vim.api.keyset.get_extmark_item[]
---@return ExtInfo?
function M.get_extmark_data(marks)
	local source_marks = store.get_marks()

	local id
	for _, m in ipairs(marks) do
		local mid = m[1]
		if source_marks[mid] ~= nil then
			id = mid
			break
		end
	end

	if not id then
		return
	end

	return source_marks[id]
end

return M
