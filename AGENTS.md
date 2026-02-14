# AGENTS.md — Project Policy & Workflow

> **Project**: applpass — Swift CLI for macOS Keychain password management
> **Stack**: Swift 6.2.3, Swift Argument Parser, Swift Testing
> **VCS**: Jujutsu (jj)
> **Workflow**: TCR (test || commit || revert)

---

## §1 — Project Identity

**applpass** is a command-line tool for accessing passwords stored in Apple's iCloud Keychain via the Security framework. It supports shared password groups from the Passwords app (iOS 18+, macOS Sequoia+).

**Target users**: Bot accounts, automation scripts, CLI workflows
**Target platform**: macOS 14.0+ (Sonoma or later)
**Binary name**: `applpass`

---

## §2 — Code Organization

### File Structure
```
applpass/
├── Package.swift                    # SPM manifest
├── .swift-format                    # Code style config
├── Sources/
│   └── ApplPass/
│       ├── ApplPass.swift           # Entry point (@main)
│       ├── Commands/                # Subcommands
│       ├── KeychainManager/         # Keychain operations
│       ├── Output/                  # Formatters
│       └── Utilities/               # Helpers
├── Tests/
│   └── ApplPassTests/
└── .github/workflows/               # CI/CD
```

### Module Dependencies (respects Swift's single-pass compilation)
- Utilities (bottom layer)
- KeychainManager (depends on Utilities)
- Output (depends on KeychainManager)
- Commands (depends on all above)
- ApplPass.swift (top layer, depends on Commands)

**Rule**: Lower layers cannot import higher layers.

---

## §3 — TCR Workflow (Test || Commit || Revert)

Every code change follows this loop:

```bash
# 1. Describe your change
jj desc -m "feat(keychain): add query builder"

# 2. Make ONE small change

# 3. Verify
swift build && swift test

# 4. Result:
#    ✅ ALL PASS → jj new (commit)
#    ❌ ANY FAIL → jj restore (revert)
```

### TCR Rules
- **Small steps**: Each change should be < 50 lines
- **Always green**: Never commit failing tests
- **No stubs**: Every commit must be fully functional
- **No TODOs**: Finish what you start or don't commit it
- **Test first**: Write test, see it fail, make it pass, commit

### Verification Checklist (run before every commit)
```bash
swift build                          # Type checking
swift test                           # Unit tests pass
swift format lint --recursive .      # No style violations (if format installed)
```

For final story verification, also run:
```bash
swift build -c release               # Production build
swift test --verbose                 # All tests with output
```

---

## §4 — Commit Conventions

Use Conventional Commits with these types:

- `feat(scope)`: New feature
- `fix(scope)`: Bug fix
- `test(scope)`: Test-only changes
- `refactor(scope)`: Code restructure, no behavior change
- `docs(scope)`: Documentation only
- `chore(scope)`: Tooling, dependencies, non-code

**Scopes**: `keychain`, `commands`, `output`, `utils`, `cli`, `tests`, `ci`

**Examples**:
```
feat(keychain): implement query builder
test(keychain): add query construction tests
fix(commands): handle missing password gracefully
refactor(output): extract table formatter
docs(readme): add installation instructions
chore(ralph): complete story S03-keychain-manager
```

---

## §5 — Testing Standards

### Framework: Swift Testing
- Use `@Test` macros, NOT XCTest
- Organize tests with `@Suite`
- Use `#expect` for assertions
- Use parameterized tests with `arguments:`

### Coverage Requirements
- All public APIs must have tests
- Error paths must be tested
- Edge cases must be covered
- Target: >80% coverage

### Test Organization
```swift
import Testing
@testable import ApplPass

@Suite("Keychain Manager Tests")
struct KeychainManagerTests {
  
  @Test("Build query for internet password")
  func buildInternetPasswordQuery() {
    // Test implementation
  }
  
  @Test("Handle missing item error")
  func missingItemError() throws {
    #expect(throws: KeychainError.itemNotFound) {
      // Test code
    }
  }
}
```

### Test File Naming
- Implementation: `Sources/ApplPass/KeychainManager/KeychainManager.swift`
- Tests: `Tests/ApplPassTests/KeychainManagerTests.swift`
- Suffix tests with `Tests`

---

## §6 — Code Style & Quality

### Swift 6 Standards
- Enable strict concurrency checking
- All types crossing isolation boundaries are `Sendable`
- Use value types (struct/enum) over reference types (class)
- Protocol-oriented design where appropriate
- No force unwrapping (`!`) in production code

### Formatting (swift-format)
If swift-format is available, code must pass:
```bash
swift format lint --recursive Sources/ Tests/
```

If not available, follow these conventions:
- 100 character line length
- 2-space indentation
- No trailing whitespace
- One blank line between declarations
- PascalCase for types, camelCase for functions/variables

### Documentation
- Triple-slash (`///`) comments for public APIs
- Include parameter descriptions
- Provide usage examples for complex functions

```swift
/// Generates a cryptographically secure random password.
///
/// - Parameters:
///   - length: Password length (default: 32)
///   - includeSymbols: Include special characters (default: true)
/// - Returns: Random password string
/// - Throws: `PasswordGeneratorError` if length is invalid
func generate(length: Int = 32, includeSymbols: Bool = true) throws -> String
```

---

## §7 — Security Guidelines

### Critical Rules
- **NEVER** log passwords or sensitive data
- **NEVER** include passwords in error messages
- **NEVER** write credentials to disk outside keychain
- Use `SecureString` wrapper for in-memory passwords
- Zero out password strings after use when possible
- Respect macOS keychain access controls

### Safe Patterns
```swift
// ✅ GOOD: Read from stdin
let password = readLine() ?? ""

// ✅ GOOD: Use SecureString wrapper
let secure = SecureString(password)
defer { secure.clear() }

// ❌ BAD: Password in command line argument
// Users should never do: applpass add --password "secret123"

// ❌ BAD: Password in print statement
print("Password: \(password)")  // NEVER DO THIS
```

---

## §8 — Jujutsu (jj) Workflow

### Basic Operations
```bash
# Start new work
jj new -m "feat(scope): description"

# Check status
jj st

# Commit (automatic with jj new)
jj new -m "next change"

# Revert uncommitted changes
jj restore

# View history
jj log --limit 10

# Amend current description
jj desc -m "better description"
```

### Working Copy Model
- `jj new` creates a new commit and moves to it (auto-commits previous work)
- `jj restore` reverts working directory to last commit
- No explicit `git add` or `git commit` needed

### TCR Integration
```bash
# Make change
jj desc -m "feat(keychain): add get operation"

# Edit code...

# Test
swift build && swift test

# If pass:
jj new

# If fail:
jj restore
```

---

## §9 — Story Completion Protocol

Before marking a story complete in `prd.json`, verify:

### Build Verification
```bash
swift build                    # ✅ Zero errors
swift build -c release         # ✅ Release build succeeds
swift test                     # ✅ All tests pass
swift test --verbose           # ✅ No warnings in test output
```

### Optional (if swift-format installed)
```bash
swift format lint --recursive Sources/ Tests/  # ✅ No violations
```

### Manual Verification
- [ ] All acceptance criteria met
- [ ] Tests added for new functionality
- [ ] Error paths tested
- [ ] Documentation updated
- [ ] No force unwrapping in production code
- [ ] No TODO comments
- [ ] Security guidelines followed

### Update Tracking Files
1. Set `"passes": true` in `prd.json`
2. Append completion entry to `progress.txt`
3. Commit tracking files:
```bash
jj desc -m "chore(ralph): complete story S##-story-id"
jj new
```

---

## §10 — Dependencies

### Required
- Swift 6.2.3+ (check with `swift --version`)
- macOS 14.0+ (Sonoma or later)
- Xcode 16.0+ (for development)

### Swift Packages
- Swift Argument Parser 1.5+ (CLI framework)
- swift-format 600.0.0+ (optional, for formatting)

### System Frameworks
- Security.framework (Keychain Services)
- Foundation

---

## §11 — CI/CD Integration

### GitHub Actions
On push to `main`:
- Run `swift build`
- Run `swift test --verbose`
- Run `swift format lint` (if available)
- Build release binary
- Upload artifact

### Local Pre-push Check
```bash
swift build -c release && swift test --verbose
```

If this passes, push is safe.

---

## §12 — Discovered Patterns

> This section is appended to by iterations when they discover conventions,
> gotchas, or patterns that future work should follow.

### Pattern: Keychain Query Construction
Always use the builder pattern for queries to ensure required fields are set:
```swift
let query = KeychainQuery(
  service: "github.com",
  account: "bot@example.com"
)
let dict = KeychainManager.buildQuery(for: query)
```

### Pattern: Error Handling
Use typed errors with `LocalizedError` for user-friendly messages:
```swift
enum KeychainError: Error, LocalizedError {
  case itemNotFound
  
  var errorDescription: String? {
    switch self {
    case .itemNotFound: "Password not found in keychain"
    }
  }
}
```

### Pattern: Sendable Types
All data models crossing isolation boundaries must be `Sendable`:
```swift
struct KeychainItem: Sendable {
  let service: String
  let password: String
}
```

---

## §13 — Anti-Patterns (Don't Do This)

### ❌ Force Unwrapping
```swift
// BAD
let password = dict[key]!

// GOOD
guard let password = dict[key] else {
  throw KeychainError.invalidData
}
```

### ❌ Large Commits
```swift
// BAD: Implementing entire Get command in one commit

// GOOD: 
// 1. Add KeychainManager.getPassword() + test
// 2. Add GetCommand structure + test
// 3. Wire command into CLI + test
```

### ❌ Skipping Tests
```swift
// BAD: "I'll add tests later"

// GOOD: Test-first development
// 1. Write failing test
// 2. Implement feature
// 3. See test pass
// 4. Commit
```

### ❌ Passwords in Logs
```swift
// BAD
print("Retrieved password: \(password)")

// GOOD
print("Successfully retrieved password for \(account)")
```

---

## §14 — Quick Reference

### Daily Workflow
```bash
# Read progress.txt for context
cat progress.txt | tail -20

# Check assigned story
jq '.stories[] | select(.passes == false) | .id' prd.json | head -1

# Read story details
jq '.stories[] | select(.id == "S01")' prd.json

# Create commit description
jj desc -m "feat(scope): what you're doing"

# Make small change, test, commit or revert
swift build && swift test && jj new || jj restore

# Mark story complete
# Edit prd.json, append to progress.txt, commit
```

### Verification Commands
```bash
swift build                           # Type check
swift test                            # Unit tests
swift test --verbose                  # Verbose test output
swift build -c release                # Production build
swift format lint --recursive .       # Style check (if available)
```

### Jujutsu Commands
```bash
jj new -m "message"                   # Create new commit
jj desc -m "message"                  # Update commit message
jj st                                 # Status
jj log --limit 10                     # Recent history
jj restore                            # Revert working directory
```

---

**Last Updated**: 2026-02-13
**Version**: 1.0
