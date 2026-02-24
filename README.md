# observe.nvim

> ⚠️ **Note**: This plugin is in development phase. APIs and features may change.

A performance profiling plugin for Neovim that helps you trace and measure the execution time of Neovim operations, particularly autocmd callbacks and custom Lua code.

## Features

- **Autocmd Profiling**: Automatically traces the execution time of autocommand callbacks
- **Custom Span Tracking**: Measure execution time of specific code blocks using the `time()` API
- **Real-time Report**: View performance metrics with a dedicated report buffer
- **Minimal Overhead**: Only records spans when explicitly started
- **Configurable**: Adjust max spans stored and enable/disable different adapters

## Installation

Using [packer.nvim](https://github.com/wbthomson/packer.nvim):

```lua
use 'CrestNiraj12/observe.nvim'
```

Using [vim-plug](https://github.com/junegunn/vim-plug):

```vim
Plug 'CrestNiraj12/observe.nvim'
```

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  'CrestNiraj12/observe.nvim',
  config = function()
    require('observe').setup({
      max_spans = 1000
    })
  end
}
```

## Setup

Initialize observe.nvim in your Neovim configuration:

```lua
require('observe').setup({
  max_spans = 1000,              -- Maximum number of spans to keep in memory
  max_timeline_spans = 50,       -- Maximum spans to display in the timeline section
  adapters = {}                  -- Adapter configuration
})
```

## Usage

### Commands

- **`:ObserveStart`** - Start recording performance spans
- **`:ObserveStop`** - Stop recording performance spans and automatically generate a report
- **`:ObserveReport`** - Generate and display a performance report
- **`:ObserveToggle`** - Toggle recording on/off
- **`:ObserveTestSpan`** - Record a test span (useful for testing)

### Basic Example

```lua
local observe = require('observe')

-- Start profiling
observe.start()

-- Your code runs here, all autocommands are traced automatically
-- ...

-- Stop profiling
observe.stop()

-- View the report
observe.report()
```

### Programmatic API

#### Record custom spans

```lua
local store = require('observe.core.store')

-- Measure a specific code block
store.time('my operation', function()
  -- Your code here
end)
```

#### Manual span tracking

```lua
local store = require('observe.core.store')

-- Begin a span
local span = store.begin_span('operation name', { custom = 'metadata' })

-- Do work...

-- Finish the span
store.finish_span(span)
```

#### Check if observe is enabled

```lua
local observe = require('observe')

if observe.is_enabled() then
  -- Observer is running
end
```

### Report Output

The report displays multiple sections to help you analyze performance:

**Summary Section**
- Total number of spans recorded
- Total execution time of all spans

**Top Slow Spans**
- The 10 slowest individual spans
- Helps identify the most time-consuming operations

**Top Totals by Source**
- Aggregated execution times grouped by source file and line number
- Shows which files are consuming the most time overall

**Top Totals by Event Name**
- Aggregated execution times grouped by event/operation name
- Helps identify which operations are called most frequently

**Timeline**
- Last 50 spans in chronological order
- Shows execution sequence with metadata (source, group, pattern, etc.)

Example report:
```
observe.nvim --- Report
------------------------
spans: 42 | total: 125.45ms

Top slow spans
--------------
   <0.01ms	autocmd: BufRead	[group=null | pattern=null]
    5.23ms	autocmd: FileType	[source=/path/to/config:42]
    1.05ms	my operation	[custom=metadata]

Top totals by source
--------------------
   10.45ms	/path/to/config:42
    5.12ms	/path/to/plugin:10

Top totals by name
------------------
   15.20ms	autocmd: FileType
   10.45ms	autocmd: BufRead

Timeline
--------
    5.23ms	autocmd: FileType	[source=/path/to/config:42]
    3.18ms	autocmd: BufRead	[group=null | pattern=null]
    1.05ms	my operation	[custom=metadata]
    ...
```

### Report Navigation

When viewing a report:
- Press `q` to close the report buffer
- Press `t` to toggle the timeline section (show/hide recent spans)

## How It Works

### Autocmd Tracing

When enabled, observe.nvim patches `vim.api.nvim_create_autocmd` to wrap callbacks with performance tracking. This allows automatic measurement of autocmd execution times without modification to your existing code.

### Span Storage

Spans are stored in memory with the following information:
- `name`: The span name
- `meta`: Optional metadata (source, pattern, group, etc.)
- `start_ns`: Start time in nanoseconds
- `end_ns`: End time in nanoseconds
- `duration_ns`: Duration in nanoseconds

The plugin maintains a rolling buffer, keeping only the most recent spans up to `max_spans`.

## Configuration

### Options

```lua
{
  max_spans = 1000,              -- Maximum number of spans to keep in memory
  max_timeline_spans = 50,       -- Maximum spans to display in the timeline section (minimum: 10)
  adapters = {}                  -- Adapter configuration (reserved for future use)
}
```

**Note**: `max_timeline_spans` must be at least 10. If a smaller value is provided, a warning will be shown and the default value of 50 will be used.

## Architecture

```
observe.nvim/
├── lua/observe/
│   ├── init.lua               # Main module and public API
│   ├── config.lua             # Configuration management
│   ├── constants.lua          # Centralized constants
│   ├── core/
│   │   ├── store.lua          # Span storage and recording
│   │   └── clock.lua          # High-precision timing
│   ├── adapters/
│   │   └── autocmd.lua        # Autocmd interception with path truncation
│   ├── ui/
│   │   ├── report.lua         # Report buffer management and navigation
│   │   └── view.lua           # Report rendering and timeline management
│   └── utils/
│       ├── path.lua           # Path cleaning and truncation utilities
│       └── metadata.lua       # UI utility functions and formatting
├── plugin/
│   └── observe.lua            # Plugin commands
├── LICENSE                    # MIT License
└── README.md                  # Project documentation
```

## Performance Considerations

- The plugin uses nanosecond-precision timing via Neovim's APIs
- Recording overhead is minimal when not actively collecting spans
- Spans are stored in a rolling buffer to prevent unbounded memory growth
- Report generation is fast and doesn't block the editor

## Troubleshooting

### "observe.nvim is already running"
You've called `:ObserveStart` twice. Call `:ObserveStop` first.

### "stop observe.nvim before generating report"
Reports can only be generated when observe.nvim is not recording. Call `:ObserveStop` first.

### No spans recorded
Make sure to call `:ObserveStart` before the operations you want to measure, and ensure they actually execute autocommands or code you're manually timing.

## Contributing

Contributions are welcome! Please feel free to submit issues and pull requests.

## License

MIT License - see [LICENSE](LICENSE) file for details
