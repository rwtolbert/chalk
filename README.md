# Chalk

A pure Janet TUI library inspired by Python's [Textual](https://github.com/Textualize/textual).

No C dependencies — uses Janet's built-in FFI to call libc directly. Targets macOS arm64.

## Features

- **Terminal control** — raw mode, alternate screen, SGR styling, mouse tracking
- **Event system** — PEG-based input parser for keys, mouse, and UTF-8; synchronous event loop
- **Virtual screen** — double-buffered screen with diff-based rendering
- **Flex layout** — box model with margin/padding, flex-grow/shrink, docking
- **Widget system** — composable widget tree with lifecycle hooks and event dispatch
- **CSS styling** — PEG CSS parser, selector matching with specificity, cascade resolution
- **App framework** — `defwidget` macro and `defapp` macro for building apps

## Requirements

- Janet 1.39.1+
- macOS arm64 (Darwin)

## Install

```sh
janet-pm install
```

## Usage

```janet
(import chalk/terminal/style)
(import chalk/layout/box)
(import chalk/layout/flex)
(import chalk/widget/proto)
(import chalk/style/cascade)
```

See the `demo/` directory for working examples:

| Demo | Description |
|------|-------------|
| `demo/hello.janet` | Interactive hello world (layers 1-5) |
| `demo/layout_test.janet` | Colored rectangles with flex layout |
| `demo/widgets_test.janet` | Widget tree with containers and text |
| `demo/css_test.janet` | Same layout styled entirely via CSS |
| `demo/counter.janet` | Counter widget using `defwidget` |
| `demo/app_demo.janet` | Full todo app with borders, list, and input |

Run a demo from the project root:

```sh
janet demo/app_demo.janet
```

## Tests

```sh
janet-pm test
```

## License

[MIT](LICENSE)
