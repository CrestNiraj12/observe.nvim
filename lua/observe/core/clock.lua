local M = {}

---@return integer
function M.now_ns()
  return vim.uv.hrtime()
end

return M
