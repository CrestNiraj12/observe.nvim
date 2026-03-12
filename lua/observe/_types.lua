---@class ObserveConfig
---@field adapters table<HandlerType, boolean>?
---@field max_spans integer?
---@field max_timeline_spans integer?

---@class ObserveState
---@field enabled boolean
---@field config ObserveConfig

---@class CreateAutocmdOpts
---@field callback function|string?
---@field pattern string|string[]?
---@field group string|integer?
---@field once boolean?
---@field nested boolean?

---@class SourceLabel
---@field label string
---@field source? string

---@class StartObserveSpan
---@field id integer
---@field name string
---@field meta Meta?
---@field start_ns integer
---@field parent_id integer?
---@field depth integer

---@class ObserveSpan : StartObserveSpan
---@field collapsed boolean
---@field end_ns integer?
---@field duration_ns integer?

---@class StoreState
---@field enabled boolean
---@field max_spans integer
---@field spans ObserveSpan[]
---@field active_spans ObserveSpan[]
---@field marks table<integer, ExtInfo>

---@class ObserveStoreOpts
---@field max_spans integer?

---@class Meta
---@field type HandlerType
---@field kind string?
---@field source string
---@field full_source string?

---@class AutocmdMeta : Meta
---@field group string|integer
---@field pattern string|string[]
---@field once boolean
---@field nested boolean
---@field cmd string?

---@class LSPMeta: lsp.HandlerContext, Meta

---@class CmdMeta: Meta
---@field cmd string
---@field args string?

---@class TimelineViewState
---@field max_timeline_spans integer

---@class ExtInfo
---@field source string?
---@field span_id integer

---@class ReportUIState: TimelineViewState
---@field info_extmarks table<integer, ExtInfo>
---@field timeline_extmarks table<integer, ExtInfo>

---@class RenderLineMeta
---@field span_id integer?
---@field line string
---@field source? string

---@class MergeMeta
---@field span_id integer
---@field name string
---@field duration integer
---@field source string?

---@class TotalByKey
---@field span_id integer
---@field key string
---@field name string
---@field duration integer
---@field source string?

---@alias HandlerType "autocmd"|"lsp"|"cmd"|"async_cmd"

---@class DebugInfo
---@field line_defined integer
---@field current_line integer
---@field truncated_source string|nil
---@field full_source string|nil

--- @class TreeInfo
--- @field has_children boolean
--- @field depth integer
