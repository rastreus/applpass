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
