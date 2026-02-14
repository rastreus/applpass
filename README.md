# applpass

`applpass` is a Swift CLI for reading and managing passwords in macOS Keychain,
including shared iCloud Passwords entries.

## Overview

`applpass` is designed for automation, bot accounts, and scriptable command-line
workflows. It supports listing, retrieving, adding, updating, deleting, and
generating passwords.

## Requirements

- macOS 14.0+ (Sonoma or later)
- Swift 6.2.3+
- Xcode 16.0+ (for local development)

## Installation

Build from source:

```bash
git clone <repo-url>
cd applpass
swift build -c release
```

Run without installing:

```bash
.build/release/applpass --help
```

Optionally install to your `PATH`:

```bash
cp .build/release/applpass /usr/local/bin/applpass
```

## Quick Start

```bash
# 1) Show available commands
applpass --help

# 2) Add a password from stdin
printf '%s' 'token-123' | applpass add --service github.com --account bot@example.com --stdin

# 3) Read it back
applpass get --service github.com --account bot@example.com --value-only
```

## Usage

Use `applpass <command> [options]` and run `applpass <command> --help` for
command-specific options and examples.

## Examples Directory

See `examples/` for runnable sample scripts and
`examples/skills/applpass-commands/SKILL.md` for an agent-oriented command
pattern example.

## Command Reference

### `get`

Retrieve one keychain password by service and account.

```bash
applpass get --service github.com --account bot@example.com
applpass get -s github.com -a bot@example.com --value-only
applpass get -s github.com -a bot@example.com --clipboard
```

Key options:
- `--service`, `--account` (required)
- `--format table|json|csv|plain` (default: `plain`)
- `--value-only` to print only the password
- `--clipboard` to copy the password with `pbcopy`

### `list`

List keychain items with optional filtering and multiple output formats.

```bash
applpass list
applpass list --service github.com --format table
applpass list --search github --shared-only --format json
```

Key options:
- `--service`, `--account`, `--search`
- `--format table|json|csv|plain` (default: `table`)
- `--shared-only`, `--personal-only`
- `--show-passwords` to include password values in output

### `add`

Add a new keychain password item.

```bash
# read from stdin
printf '%s' 'token-123' | applpass add --service github.com --account bot@example.com --stdin

# generate and store a random password
applpass add --service github.com --account bot@example.com --generate --length 48
```

Key options:
- `--service`, `--account` (required)
- `--stdin` to read password from standard input
- `--generate` and optional `--length` for auto-generated values
- `--label` to set a custom item label
- `--sync` to enable iCloud keychain synchronization

### `update`

Update an existing password for a service/account pair.

```bash
# interactive confirmation (default)
printf '%s' 'new-token' | applpass update --service github.com --account bot@example.com --stdin

# non-interactive automation
applpass update --service github.com --account bot@example.com --generate --force
```

Key options:
- `--service`, `--account` (required)
- `--stdin` or `--generate` (mutually exclusive)
- `--length` for generated password size
- `--force` to skip confirmation prompt

### `delete`

Delete one account password or all passwords for a service.

```bash
# delete a single account
applpass delete --service github.com --account bot@example.com --force

# show all accounts under a service, then delete them
applpass delete --service github.com --all-accounts
```

Key options:
- `--service` (required)
- `--account` for single delete
- `--all-accounts` for service-wide deletion
- `--force` to skip confirmation prompt

### `generate`

Generate one or more passwords without storing them in keychain.

```bash
applpass generate --length 32
applpass generate --count 3 --no-symbols
applpass generate --length 40 --clipboard
```

Key options:
- `--length` (default: `32`)
- `--count` (default: `1`)
- `--no-uppercase`, `--no-lowercase`, `--no-digits`, `--no-symbols`
- `--clipboard` to copy generated output with `pbcopy`

### Output Formats

Commands that support `--format` accept:
- `table` for human-readable columns
- `json` for scripting and API workflows
- `csv` for spreadsheet imports
- `plain` for compact tab-separated output

## Security Best Practices

- Never pass passwords as CLI arguments; use `--stdin` or interactive prompts.
- Avoid storing secrets in shell history (`printf` pipe or read from a secure source).
- Use `--clipboard` only when needed and clear clipboard contents after use.
- Do not run with `--show-passwords` unless output is going to a trusted sink.
- Rely on macOS Keychain prompts and do not disable access controls.
- Keep automation logs free of password values.

## Troubleshooting

Common errors and resolutions:

- `Missing required option: --service.` or `--account.`  
  Provide required flags for the selected command.
- `Unknown command '<name>'. Available commands: ...`  
  Run `applpass --help` and use one of: `get`, `list`, `add`, `update`, `delete`, `generate`.
- `Interactive password entry requires a TTY. Use --stdin or --generate.`  
  Use `--stdin` in non-interactive shells or CI.
- `Interactive confirmation requires a TTY. Use --force to skip confirmation.`  
  Add `--force` for non-interactive `update` and `delete` flows.
- `A password with these credentials already exists.`  
  Use `update` instead of `add`, or choose a different service/account pair.
- `Password not found in keychain.`  
  Verify the exact `--service` and `--account` values; try `applpass list --search <text>`.
- `Access denied. Please allow access when prompted.`  
  Approve the keychain access prompt and retry.
- `Failed to copy password to clipboard.`  
  Confirm `/usr/bin/pbcopy` is available and permitted in the current session.

## Developer Build Instructions

```bash
# Debug build
swift build

# Release build
swift build -c release

# Run tests
swift test --verbose
```

In constrained environments where SwiftPM sandboxing is blocked:

```bash
swift build --disable-sandbox
swift build -c release --disable-sandbox
swift test --disable-sandbox --verbose
```

Optional formatting lint:

```bash
swift format lint --recursive Sources/ Tests/
```

## Contributing

Project workflow uses TCR (`test || commit || revert`) with Jujutsu (`jj`):

```bash
jj desc -m "feat(scope): describe one small change"
swift build && swift test
jj new || jj restore
```

Contribution expectations:
- Keep changes small and test-backed.
- Follow Swift 6 strict concurrency patterns.
- Use Swift Testing (`@Suite`, `@Test`, `#expect`) instead of XCTest.
- Follow code style (`.swift-format`) and avoid force unwrapping in production code.
- Never log password values or commit sensitive material.

## License

This project is licensed under the MIT License. See `LICENSE`.
