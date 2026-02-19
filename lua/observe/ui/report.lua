local M = {}

---Convert nanosecond to millisecond timestamp
---@param ns integer
---@return number
local function ns_to_ms(ns)
  return ns / 1e6
end

---Generate report based on spans
---@param spans ObserveSpan[]
---@return string[]
function M.render(spans)
  local lines = {}
  lines[#lines + 1] = 'observe.nvim --- Report'
  lines[#lines + 1] = string.rep('-', #(lines[1]))

  local total_ns = 0
  for _, s in ipairs(spans) do
    total_ns = total_ns + (s.duration_ns or 0)
  end

  lines[#lines + 1] = string.format("spans: %d | total: %.2fms", #spans, ns_to_ms(total_ns))
  lines[#lines + 1] = ""

  if #spans == 0 then
    lines[#lines + 1] = "No spans recorded!"
  end

  local start_i = math.max(1, #spans - 50 + 1)
  for i = start_i, #spans do
    local span = spans[i]
    lines[#lines + 1] = string.format("%7.2fms\t%s", ns_to_ms(span.duration_ns or 0), span.name)
  end

  return lines
end

---Open report in buffer
---@param lines string[]
function M.open_report(lines)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, "observe://report")
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_set_current_buf(buf)

  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = false
end

return M
