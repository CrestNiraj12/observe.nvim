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

  return string.format("%7s", time)
end

---Extract info from meta
---@param meta table?
---@return string[]
function M.parse_info_from_meta(meta)
  if not meta then
    return {}
  end

  local parts = {}
  if meta.source then parts[#parts + 1] = meta.source end
  if meta.group then parts[#parts + 1] = "group=" .. tostring(meta.group) end
  if meta.pattern then
    local pattern = meta.pattern
    if type(pattern) == "table" then
      pattern = table.concat(pattern, ",")
    end
    parts[#parts + 1] = "pattern=" .. tostring(pattern)
  end
  return parts
end

---Render info from span
---@param span ObserveSpan
---@return string
function M.format_info(span)
  local data = M.parse_info_from_meta(span.meta)
  local suffix = #data > 0 and ("  [" .. table.concat(data, " | ") .. "]") or ""
  local timestamp = M.ns_to_ms(span.duration_ns or 0)
  return string.format("%s\t%s%s", M.render_timestamp(timestamp), span.name, suffix)
end

return M
