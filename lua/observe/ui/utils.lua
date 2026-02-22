local M = {}

---Convert nanosecond to millisecond timestamp
---@param ns integer
---@return number
function M.ns_to_ms(ns)
  return ns / 1e6
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
  return string.format("%7.2fms\t%s%s", M.ns_to_ms(span.duration_ns or 0), span.name, suffix)
end

return M
