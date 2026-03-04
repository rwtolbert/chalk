# Chalk Development Guidelines

## Code Style

- Run `janet-format` on all `.janet` files before committing (installed with spork).
- Never use em dashes (`—`) anywhere in the codebase. Use plain dashes (`-`) instead.
- Always use backtick long strings (```content```) for multi-line docstrings so Janet preserves newline formatting in `:doc` metadata. Regular "..." strings collapse newlines.

## Docstring Display

- Multi-line docstrings (those containing `\n`) are author-formatted. Never re-wrap their individual lines. Only word-wrap single-line docstrings that exceed the display width. This applies to bundle-browser's `build-detail-items` and any future code that renders `:doc` metadata.

## Testing

- Run tests with `janet-pm test`. All 10 test files in `test/` must pass.
