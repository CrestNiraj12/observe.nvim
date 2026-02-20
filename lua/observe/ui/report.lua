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
    return lines
  end

  local start_i = math.max(1, #spans - 50 + 1)
  for i = start_i, #spans do
    local span = spans[i]
    local meta = span.meta or {}

    local parts = {}
    if meta.source then parts[#parts + 1] = meta.source end
    if meta.group then parts[#parts + 1] = "group=" .. tostring(meta.group) end
    if meta.pattern then parts[#parts + 1] = "pattern=" .. tostring(meta.pattern) end
    local suffix = #parts > 0 and ("  [" .. table.concat(parts, " | ") .. "]") or ""

    lines[#lines + 1] = string.format("%7.2fms\t%s%s", ns_to_ms(span.duration_ns or 0), span.name, suffix)
  end

  return lines
end

local REPORT_NAME = "observe://report"
local REPORT_FILETYPE = "observe-report"
local report_buf ---@type integer?

---Open a new buffer if there isnt already a valid one,
---set keymap 'q' to close, and return the buffer
---@return integer
local function ensure_buf()
  if report_buf and vim.api.nvim_buf_is_valid(report_buf) then
    return report_buf
  end

  local buf = vim.api.nvim_create_buf(false, true)
  report_buf = buf
  vim.api.nvim_buf_set_name(buf, REPORT_NAME)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = false
  vim.bo[buf].filetype = REPORT_FILETYPE

  vim.keymap.set("n", "q", function()
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
  end, { buffer = buf, nowait = true, silent = true })

  return buf
end

local function set_lines(buf, lines)
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
end

local function find_window_showing_buf(buf)
  local wins = vim.api.nvim_list_wins()
  for _, win in pairs(wins) do
    if vim.api.nvim_win_get_buf(win) == buf then
      return win
    end
  end

  return nil
end

---Open report in buffer
---@param lines string[]
function M.open_report(lines)
  local buf = ensure_buf()
  local cur_win = vim.api.nvim_get_current_win()
  local cur_buf = vim.api.nvim_win_get_buf(cur_win)

  -- Refresh only if user is already in report buffer
  if cur_buf == buf then
    set_lines(buf, lines)
    vim.cmd('normal! gg')
    return
  end


  local existing_win = find_window_showing_buf(buf)
  if existing_win then
    vim.api.nvim_set_current_win(existing_win)
    set_lines(buf, lines)
    vim.cmd('normal! gg')
    return
  end

  vim.cmd("botright split")
  vim.api.nvim_win_set_buf(0, buf)
  set_lines(buf, lines)
  vim.cmd('normal! gg')
end

return M
