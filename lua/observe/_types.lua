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
---@field end_ns integer?
---@field duration_ns integer?

---@class StoreState
---@field enabled boolean
---@field max_spans integer
---@field spans ObserveSpan[]
---@field active_spans ObserveSpan[]

---@class ObserveStoreOpts
---@field max_spans integer?

---@class Meta
---@field type HandlerType
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

---@class ReportUIState: TimelineViewState
---@field show_timeline boolean
---@field extmarks table<integer, string>

---@class RenderLineMeta
---@field line string
---@field source? string

---@class MergeMeta
---@field name string
---@field duration integer
---@field source string?

---@class TotalByKey
---@field key string
---@field name string
---@field duration integer
---@field source string?

---@alias HandlerType "autocmd"|"lsp"|"cmd"|"schedule"

---@class DebugInfo
---@field line_defined integer
---@field current_line integer
---@field truncated_source string|nil
---@field full_source string|nil
