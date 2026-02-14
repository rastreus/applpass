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
