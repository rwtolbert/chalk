# Chalk TUI Library - Architecture & Plan

Pure Janet TUI framework inspired by Python's Textual.
No C dependencies - uses Janet FFI to libc. Target: macOS arm64 (Darwin).

## Current Status

Layers 1-10 are implemented and working. The framework supports building
interactive terminal applications with CSS styling, flex layout, focus
management, and a growing set of widgets. 10 test suites pass (240+ tests).

## Layer Architecture

```
Layer 10: App framework (defapp, run) + widgets (list, input, checkbox, tree)
Layer  9: defwidget macro (declarative widget definitions)
Layer  8: CSS engine (PEG parser, property resolution, cascade)
Layer  7: Widget system (protocol, text, container, render pipeline)
Layer  6: Layout engine (box model, flex algorithm)
Layer  5: Screen buffer (virtual cells, diff-based rendering)
Layer  4: Event loop (synchronous read with VMIN/VTIME timeout)
Layer  3: Input parser (PEG grammar for keys, mouse, escape sequences)
Layer  2: Terminal protocol (SGR styles, buffered escape sequences)
Layer  1: Platform FFI (raw mode, terminal size, read/write)
```

## Platform Layer

The platform layer uses Janet FFI to libc for core terminal I/O:

- **Raw mode**: tcgetattr/tcsetattr to switch between cooked and raw mode
- **Reading**: read() + poll() on /dev/tty with VMIN=0 VTIME=1 (100ms timeout)
- **Writing**: write() to stdout fd

Terminal size uses `stty size` via os/spawn as a workaround - ioctl
TIOCGWINSZ is variadic and arm64 passes varargs on the stack, which Janet
FFI doesn't handle. Falls back to $COLUMNS/$LINES, then 80x24.

All escape sequences are hardcoded ANSI/xterm sequences: CSI for cursor
movement, SGR for colors/attributes, DEC private modes for alt screen,
mouse tracking, and cursor visibility. No termcap/terminfo lookup.

## File Map

```
chalk/
  app.janet                       # defapp macro + run lifecycle
  platform/
    posix.janet                   # FFI bindings to libc
    init.janet                    # platform abstraction
  terminal/
    style.janet                   # SGR code generation
    output.janet                  # buffered escape sequences
    input.janet                   # (stub - parsing in events/types)
    screen.janet                  # virtual screen buffer + diff render
  events/
    types.janet                   # PEG input parser + event constructors
    loop.janet                    # synchronous event loop
  layout/
    box.janet                     # layout node + box model
    flex.janet                    # flex layout algorithm
  widget/
    proto.janet                   # widget protocol, tree ops, focus, dispatch
    text.janet                    # text display widget
    container.janet               # child grouping widget
    render.janet                  # layout -> paint pipeline
    border.janet                  # border wrapper widget (legacy)
    border-util.janet             # box-drawing character tables + paint
    list.janet                    # scrollable list with selection
    input.janet                   # single-line text input
    checkbox.janet                # toggle checkbox with label
    tree.janet                    # hierarchical tree with expand/collapse
    defwidget.janet               # defwidget macro
  style/
    css-parse.janet               # PEG CSS parser
    properties.janet              # property value parsing
    cascade.janet                 # selector matching + resolution
demo/
  hello.janet                     # Layer 1-5 interactive demo
  layout_test.janet               # Layer 6 colored rect layout
  widgets_test.janet              # Layer 7 widget tree
  css_test.janet                  # Layer 8 CSS-styled UI
  counter.janet                   # Layer 9 defwidget counter
  app_demo.janet                  # Layer 10 full todo app
  bundle-browser                  # Bundle browser (installed as binscript)
test/
  test-style.janet                # SGR codes, colors
  test-box.janet                  # Box model, margin/padding
  test-flex.janet                 # Flex layout algorithm
  test-css-parse.janet            # CSS parsing
  test-properties.janet           # Property validation
  test-cascade.janet              # Selector matching
  test-input.janet                # Input parser (keys, mouse, UTF-8)
  test-proto.janet                # Widget protocol, focus, dispatch
  test-border-util.janet          # Border drawing
  test-tree.janet                 # Tree widget
```

## Widget System

### Built-in Widgets

| Widget | Module | Key Features |
|--------|--------|-------------|
| text | `chalk/widget/text` | Text display, alignment (:left/:center/:right), style inheritance |
| container | `chalk/widget/container` | Groups children, flex-direction, background fill |
| list | `chalk/widget/list` | Scrollable selection, per-item styles, keyboard+mouse, events |
| input | `chalk/widget/input` | Cursor, placeholder, horizontal scroll, ctrl-u clear |
| checkbox | `chalk/widget/checkbox` | Three styles (:ascii/:square/:round), space/enter/click toggle |
| tree | `chalk/widget/tree` | Expand/collapse, filtering, auto-expand, auto-width |

### Widget Properties

All widgets support these layout/display properties via `make-widget`:

- **Layout**: width, height, min-width, max-width, min-height, max-height,
  flex-grow, flex-shrink, flex-direction, margin, padding, dock
- **Border**: border-style (:single/:double/:rounded/:heavy/:ascii),
  border-color, border-title, border-title-align
- **Identity**: id, classes, style, focusable

Borders are first-class widget properties - any widget can have a border
without needing a wrapper. The render pipeline draws borders and computes
inner content rects automatically.

### Focus System

- `init-focus` / `build-focus-ring` - depth-first walk collects focusable widgets
- Tab/Shift-Tab cycles focus ring
- Click-to-focus finds nearest focusable ancestor
- `:focus-changed` message dispatched on focus transitions
- `set-focus` / `refresh-focus-ring` for programmatic control

### Event Dispatch

- Mouse: hit-test rects (deepest match), focus-on-click, route to target
- Keyboard: route to focused widget, fallback to root app handler
- Messages: `:msg` from widget handlers bubbles up via `:update` hooks
- Resize: routed to root handler

### defwidget / defapp Macros

Body forms: `(state {...})`, `(render [self] ...)`, `(on :event [self msg] ...)`,
`(paint [self screen rect] ...)`, `(mount [self] ...)`, `(unmount [self] ...)`.

`defapp` extends `defwidget` with `(css "...")` for root-level CSS styling.
`run` handles lifecycle: raw mode, alt screen, mount, CSS cascade, event loop,
cleanup in defer.

---

## Next Steps

### Terminal Environment Detection

Currently all escape sequences are hardcoded ANSI/xterm. This works on
modern macOS terminals (Terminal.app, iTerm2, Ghostty, Kitty, WezTerm)
but there are gaps to address:

**Background color detection (light vs dark mode):**
The bundle-browser and other demos assume a dark terminal background - they
use light foreground colors (:white, :cyan) that become invisible or ugly
on light-background terminals.

Options to explore:
- **OSC 11 query**: Send `\e]11;?\e\\`, terminal responds with
  `\e]11;rgb:RRRR/GGGG/BBBB\e\\` reporting the background color. Parse the
  response and compute luminance to determine light/dark. Supported by most
  modern terminals (iTerm2, Kitty, WezTerm, Ghostty, Terminal.app 14+).
- **$COLORFGBG**: Some terminals (rxvt-derived) set this to "fg;bg" where
  bg < 8 means dark. Unreliable but cheap to check.
- **Default to dark, allow override**: Provide a config mechanism
  (env var like `CHALK_THEME=light`, or API flag) so users can force it.

The detection should happen once at startup in the platform layer. The result
should be available to CSS (perhaps as a pseudo-class or variable) so apps
can define both light and dark color schemes.

**terminfo/termcap:**
We don't currently use terminfo at all. For the common case (xterm-compatible
terminals on macOS/Linux) this is fine - ANSI escape sequences are universal.
Cases where terminfo might matter:
- Terminals that don't support 256-color or RGB (rare today)
- Unusual $TERM values (screen, tmux - though these are xterm-compatible)
- True oddball terminals (serial consoles, very old terms)

For now, the pragmatic choice is to stay with hardcoded sequences and add
terminfo lookup only if real users hit compatibility issues. If we do add it,
Janet can shell out to `tput` for individual capabilities, similar to how we
use `stty` for terminal size.

### Dialog System

Provide a base dialog widget and convenience functions for common dialog
patterns, inspired by FLTK's fl_message/fl_question and Qt's standard
dialogs. The API should feel natural in Janet and be easy to use.

**Base dialog widget:**
A modal overlay that floats centered over the app content. Built on existing
primitives (container, text, border, button).

```janet
(dialog/dialog
  :title "My Dialog"
  :border-style :rounded
  :width 50
  :height 12
  :children @[...custom content...])
```

Core behavior:
- Renders centered over parent content (not a new screen)
- Captures all keyboard/mouse input while open (modal)
- Escape closes by default (configurable)
- Returns a result value when closed

**Convenience dialogs:**
One-call functions that show a dialog, block for input, and return a result.

```janet
# Simple message - just OK button, returns nil
(dialog/message app "File saved successfully.")
(dialog/message app "File saved." :title "Save")

# Alert/warning - message with attention styling
(dialog/alert app "Connection lost. Retrying...")

# Question - Yes/No, returns true/false
(dialog/question app "Save changes before closing?")
(dialog/question app "Delete this item?" :title "Confirm Delete")

# Choice - custom button labels, returns selected label as keyword
(dialog/choice app "Unsaved changes."
               :buttons [:save :discard :cancel])

# Text input - returns string or nil on cancel
(dialog/input app "Enter filename:" :value "untitled.janet")

# Select from list - returns selected item or nil on cancel
(dialog/select app "Choose a color:" :items ["red" "green" "blue"])
```

**Implementation approach:**

1. `chalk/widget/button.janet` - button widget (needed for dialogs, useful standalone)
   - Text label with bracketed display: `[ OK ]` `[ Cancel ]`
   - Focusable, activates on enter/space/click
   - Emits :button-pressed message

2. `chalk/widget/dialog.janet` - base dialog widget + convenience functions
   - Centered overlay positioning (computed from terminal size)
   - Modal input capture
   - Border with title, button row at bottom

3. Overlay support in render pipeline
   - `render.janet` or `app.janet` paints dialog on top of main tree
   - `dispatch-event` routes all input to dialog when one is active

4. Blocking API via nested event sub-loop
   - Convenience functions run their own read/dispatch/render cycle
   - Returns result inline when user responds

### Other Widgets to Consider

| Widget | Description | Priority |
|--------|-------------|----------|
| button | Clickable labeled button (needed for dialogs) | High |
| progress | Progress bar with percentage/label | Medium |
| table | Multi-column data table with headers | Medium |
| radio | Radio button group (single selection) | Medium |
| tabs | Tab bar for switching between views | Medium |
| textarea | Multi-line text editor | Low |
| sparkline | Inline mini-chart | Low |

---

## Implementation Notes

### Janet Language Gotchas

- `match` is a reserved macro - never use as variable name
- Structs `{}` are immutable - use tables `@{}` for mutable data
- `set` doesn't support destructuring
- PEG `range` uses 2-byte strings: `(range "AZ")` not `(range "A" "Z")`
- Macros from imports need namespace prefix
- `break` inside `each`/`for` only exits the loop, not the enclosing function

### arm64 / macOS FFI Gotchas

- ioctl is variadic - arm64 passes varargs on stack, use `stty` instead
- `ffi/context nil` for libc (not `ffi/context (ffi/native nil)`)
- FFI returns `core/s64`/`core/u64` - must `int/to-number` before buffer ops
- `bnot` on regular ints gives negative - use `int/u64` for unsigned masks

### Rendering

- SGR codes are additive - `style-sgr` must emit reset first
- Style inheritance walks parent chain for inherited properties
- List widget must clear all visible rows including empty ones below items

### Process Lifecycle

- `os/spawn` activates Janet's event loop - call `(os/exit 0)` after `(main)`
- `read()` can be interrupted by SIGCHLD - retry on failure
- Terminal size polled every ~500ms to reduce subprocess overhead
