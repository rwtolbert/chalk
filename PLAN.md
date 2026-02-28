# Chalk TUI Library — Architecture & Implementation Plan

Pure Janet TUI framework inspired by Python's Textual.
No C dependencies — uses Janet FFI to libc. Target: macOS arm64 (Darwin).

## Layer Architecture

```
Layer 10: App framework (defapp, run) + rich widgets (border, list, input)
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

## File Map

```
src/
├── platform/
│   ├── posix.janet            # Layer 1: FFI bindings to libc
│   └── init.janet             # Layer 1: platform abstraction
├── terminal/
│   ├── style.janet            # Layer 2: SGR code generation
│   ├── output.janet           # Layer 2: buffered escape sequences
│   ├── input.janet            # Layer 3: (unused — parsing in events/types)
│   └── screen.janet           # Layer 5: virtual screen buffer + diff render
├── events/
│   ├── types.janet            # Layer 3: PEG input parser + event constructors
│   └── loop.janet             # Layer 4: synchronous event loop
├── layout/
│   ├── box.janet              # Layer 6: layout node + box model
│   └── flex.janet             # Layer 6: flex layout algorithm
├── widget/
│   ├── proto.janet            # Layer 7: widget protocol + tree ops
│   ├── text.janet             # Layer 7: text widget
│   ├── container.janet        # Layer 7: container widget
│   ├── render.janet           # Layer 7: layout → paint pipeline
│   ├── defwidget.janet        # Layer 9: defwidget macro
│   ├── border.janet           # Layer 10: border widget (box-drawing)
│   ├── list.janet             # Layer 10: scrollable list
│   └── input.janet            # Layer 10: text input field
├── style/
│   ├── css-parse.janet        # Layer 8: PEG CSS parser
│   ├── properties.janet       # Layer 8: property value parsing
│   └── cascade.janet          # Layer 8: selector matching + resolution
└── app.janet                  # Layer 10: defapp macro + run function
demo/
├── hello.janet                # Layer 1-5 demo (manual cell drawing)
├── layout_test.janet          # Layer 6 demo
├── widgets_test.janet         # Layer 7 demo
├── css_test.janet             # Layer 8 demo
├── counter.janet              # Layer 9 demo
└── app_demo.janet             # Layer 10 demo (full todo app)
```

---

## Layer 6: Layout Engine

### `box.janet` — Layout node + box model

A layout node is a mutable table with size constraints, box model, and a computed `:rect`:

```janet
@{:tag "container"
  :width :auto          # :auto | integer (cells) | float 0.0-1.0 (%)
  :height :auto
  :min-width 0  :max-width math/inf
  :min-height 0 :max-height math/inf
  :margin-top 0 :margin-right 0 :margin-bottom 0 :margin-left 0
  :padding-top 0 :padding-right 0 :padding-bottom 0 :padding-left 0
  :flex-direction :column   # :row | :column
  :flex-grow 0  :flex-shrink 1
  :dock nil                 # nil | :top | :bottom | :left | :right
  :children @[]
  :rect nil}               # computed: @{:col :row :width :height}
```

Public API: `make-node`, `content-rect`, `outer-width`, `outer-height`, `clamp-size`.
Margin/padding accept single int (all sides) or `[v h]`.

### `flex.janet` — Flex layout algorithm

`(layout node available-width available-height)` — recursive, sets `:rect` on every node.

Algorithm:
1. Resolve own size (auto → fill available, percentage → compute, clamp min/max)
2. Process docked children first (top/bottom take full width; left/right take remaining height)
3. Flex-distribute remaining children: sum natural sizes, distribute remaining by `flex-grow`, shrink by `flex-shrink`
4. Cross axis: stretch to fill
5. Assign rects, recurse into children

All coordinates 1-based.

---

## Layer 7: Widget System

### `proto.janet` — Widget protocol

A widget is a mutable table with well-known keys:

```janet
@{:type "text"  :id nil  :classes @[]
  :state @{}  :style nil  :layout-node nil
  :children @[]  :parent nil  :mounted false
  :mount nil  :unmount nil  :render nil
  :paint nil  :handle-event nil  :update nil}
```

Public API: `make-widget`, `widget-add-child`, `widget-remove-child`,
`build-layout-tree`, `mount-tree`, `unmount-tree`, `dispatch-event`,
`find-by-id`, `in-rect?`.

### `text.janet` — Text widget

Inherits style from parent chain. Width defaults to `:auto` (fills parent).
Paint fills full rect with inherited style as background, then overlays text.

### `container.janet` — Container widget

Groups children. Paint fills rect with background if style has `:bg`.
Children painted by depth-first tree walker in `render.janet`.

### `render.janet` — Render pipeline

`(render-tree screen root width height)` orchestrates:
`build-layout-tree` → `flex/layout` → `screen-clear` → `paint-tree` → `screen-render`.

---

## Layer 8: CSS Engine

### `css-parse.janet` — PEG CSS parser

Parses subset: element/class/id selectors, descendant combinator, comma groups,
`property: value;` declarations. No comments, no @rules, no quoted values.

### `properties.janet` — Property value parsing

Supported: `color`, `background`, `bold`/`dim`/`italic`/`underline`/`reverse`,
`width`, `height`, `min-width`/`max-width`/`min-height`/`max-height`,
`margin`/`padding` (shorthand + individual sides),
`flex-direction`, `flex-grow`, `flex-shrink`, `dock`.

### `cascade.janet` — Selector matching + cascade

Matches rules against each widget, sorts by specificity then source order, merges.
Inline `:style` on widget overrides CSS.

---

## Layer 9: `defwidget` Macro

Body forms: `(state {...})`, `(render [self] ...)`, `(on :event [self msg] ...)`,
`(paint [self screen rect] ...)`, `(mount [self] ...)`, `(unmount [self] ...)`.

Expands to a constructor function. Imported with alias: `(import .../defwidget :as dw)`,
then `(dw/defwidget name ...)`.

---

## Layer 10: App Framework + Rich Widgets

### `border.janet` — Box-drawing border wrapper

ASCII box-drawing (`+`, `-`, `|`). Wraps one child, shrinks content area by 1 each side.
Optional title with alignment in top border.

### `list.janet` — Scrollable list

State: `{:items :selected :scroll-offset}`. Handles up/down/j/k/enter.
Scrolls when selection exits visible area. Clears all visible rows on paint
(including empty rows below items) to avoid stale artifacts.

### `input.janet` — Text input field

State: `{:value :cursor-pos :scroll}`. Handles printable chars, backspace, delete,
arrows, home/end, enter, ctrl-u (clear). Cursor shown with reverse style.

### `app.janet` — defapp + run

`defapp` is `defwidget` plus a `:css-text` field. `run` handles full lifecycle:
raw mode, alt screen, mount tree, parse CSS, render loop, cleanup in defer.

---

## Demos

Each layer has a standalone demo:

| Demo | Layer | What it tests |
|------|-------|---------------|
| `janet demo/hello.janet` | 1-5 | Manual cell drawing, raw input |
| `janet demo/layout_test.janet` | 6 | Colored rects from computed layout |
| `janet demo/widgets_test.janet` | 7 | Widget tree with inline styles |
| `janet demo/css_test.janet` | 8 | Same UI styled via CSS string |
| `janet demo/counter.janet` | 9 | defwidget with reactive state |
| `janet demo/app_demo.janet` | 10 | Full todo app with CSS, borders, list, input |

All demos: q or ctrl-c to quit, defer-based cleanup, alt screen.

---

## Implementation Notes & Pitfalls

### Janet language gotchas

- **`match` is a reserved macro** — never use it as a variable name. `(match :key)` is parsed as a match expression, not a table lookup. Use `m` or another name, and `(get m :key)`.
- **Structs (`{}`) are immutable** — `put` only works on tables (`@{}`). Use `@{}` for any data you need to modify.
- **`set` doesn't support destructuring** — `(set [a b] (f))` fails. Use individual `(set a (get result 0))` calls.
- **PEG `range` uses 2-byte strings** — `(range "AZ")` not `(range "A" "Z")`.
- **Macros from imported modules need namespace prefix** — `(import ../widget/defwidget :as dw)` then `(dw/defwidget ...)`.

### arm64 / macOS FFI gotchas

- **ioctl is variadic** — arm64 passes varargs on stack. Janet FFI doesn't handle this. Use `stty -f /dev/tty size` via `os/spawn` for terminal size.
- **`ffi/context nil`** for libc (not `ffi/context (ffi/native nil)`).
- **FFI returns `core/s64`/`core/u64`** — must `int/to-number` before passing to `buffer/slice`, `put`, etc.
- **`bnot` on regular ints gives negative** — use `int/u64` for unsigned bitmask ops.

### Rendering & style

- **SGR codes are additive** — `style-sgr` must always emit reset (`0`) first, then set desired attributes. Without this, switching from reverse-video to normal leaves reverse stuck on, causing stale highlights.
- **Style inheritance** — widgets must walk the parent chain to find inherited styles. Text and list widgets resolve effective style by merging ancestor + own styles.
- **List widget must clear all visible rows** — including empty rows below items, to prevent stale content from previous frames bleeding through.

### Process lifecycle

- **`os/spawn` activates Janet's event loop** — `get-terminal-size` uses `os/spawn` with `{:out :pipe}`, which activates Janet's internal event loop for pipe I/O. After `main` returns, the event loop lingers and the process doesn't exit. Fix: `(os/exit 0)` after `(main)` in all demos/apps.
- **`read()` can be interrupted by SIGCHLD** — from stty subprocesses. `read-tty` retries up to 3 times on failure.
- **Terminal size polling** — checked every ~500ms (every 5 event loop iterations) to reduce subprocess overhead.
