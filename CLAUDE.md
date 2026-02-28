# Chalk Development Guidelines

## Code Style

- Run `janet-format` on all `.janet` files before committing (installed with spork).
- Never use em dashes (`—`) anywhere in the codebase. Use plain dashes (`-`) instead.
- Always use backtick long strings (```content```) for multi-line docstrings so Janet preserves newline formatting in `:doc` metadata. Regular "..." strings collapse newlines.

## Testing

- Run tests with `janet-pm test`. All 7 test files in `test/` must pass.
