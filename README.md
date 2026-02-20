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
use 'niraj.shrestha/observe.nvim'
```

Using [vim-plug](https://github.com/junegunn/vim-plug):

```vim
Plug 'niraj.shrestha/observe.nvim'
```

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  'niraj.shrestha/observe.nvim',
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
  max_spans = 1000,  -- Maximum number of spans to keep in memory
  adapters = {}      -- Adapter configuration
})
```

## Usage

### Commands

- **`:ObserveStart`** - Start recording performance spans
- **`:ObserveStop`** - Stop recording performance spans
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

The report displays:
- Total number of spans recorded
- Total execution time of all spans
- Last 50 spans (or fewer if less than 50 have been recorded)
- Execution time for each span
- Metadata including source file, line number, and event type (for autocommands)

Example report:
```
observe.nvim --- Report
------------------------
spans: 42 | total: 125.45ms

  5.23ms	autocmd: BufRead	[group=null | pattern=null]
  2.18ms	autocmd: FileType	[source=/path/to/config:42]
  1.05ms	my operation	[custom=metadata]
  ...
```

### Report Navigation

When viewing a report:
- Press `q` to close the report buffer

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
  max_spans = 1000,     -- Maximum number of spans to keep in memory
  adapters = {}         -- Adapter configuration (reserved for future use)
}
```

## Architecture

```
observe.nvim/
├── lua/observe/
│   ├── init.lua               # Main module and public API
│   ├── config.lua             # Configuration management
│   ├── core/
│   │   ├── store.lua          # Span storage and recording
│   │   └── clock.lua          # High-precision timing
│   ├── adapters/
│   │   └── autocmd.lua        # Autocmd interception
│   └── ui/
│       └── report.lua         # Report rendering and display
└── plugin/
    └── observe.lua            # Plugin commands
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
