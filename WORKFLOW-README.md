# applpass Agent Workflow Setup

Complete agent-driven development workflow for the `applpass` Swift CLI project, adapted from the ElmishPaint methodology.

## Files Created

### Core Workflow Files
- **AGENTS.md** - Project policy document covering TCR workflow, commit conventions, testing standards, code style, security guidelines, and jj usage
- **PROMPT.md** - Per-iteration instructions for the agent: orient → plan → implement (TCR) → verify → complete
- **prd.json** - 20 user stories derived from the design document, with acceptance criteria and dependencies
- **progress.txt** - Append-only log of iteration completions (starts with bootstrap entry)

### Automation
- **ralph-applpass.sh** - Bash script for iteration management (simplified for Swift CLI, no browser validation)
  - Commands: `run`, `verify <id>`, `status`, `next`, `help`
  - Checks prerequisites (Swift, jj, jq)
  - Validates story dependencies
  - Runs verification suite (swift build, swift test)

### Skills Documentation
- **.agents/skills/swift6/SKILL.md** - Swift 6 best practices guide covering:
  - Sendable conformance and strict concurrency
  - Swift Testing framework (NOT XCTest)
  - macOS Security framework patterns
  - Swift Argument Parser patterns
  - Common pitfalls and anti-patterns

### Design Reference
- **applpass-design.md** - Updated comprehensive design document v2.0

## Directory Structure

```
applpass/
├── AGENTS.md                          # Project policy
├── PROMPT.md                          # Per-iteration instructions
├── prd.json                           # User stories backlog
├── progress.txt                       # Iteration log
├── ralph-applpass.sh                  # Automation script
├── applpass-design.md                 # Design document
├── .agents/
│   └── skills/
│       └── swift6/
│           └── SKILL.md               # Swift 6 patterns
│
└── (to be created by S01-project-setup):
    ├── Package.swift
    ├── .swift-format
    ├── Sources/ApplPass/
    ├── Tests/ApplPassTests/
    └── .github/workflows/
```

## Quick Start

### 1. Initialize Repository
```bash
# If using jj (recommended)
jj git init
jj new -m "chore: initial commit with agent workflow"

# Or if using git first
git init
git add .
git commit -m "chore: initial commit with agent workflow"
```

### 2. Check Prerequisites
```bash
./ralph-applpass.sh status
```

This verifies:
- Swift 6.2.3+ installed
- Jujutsu (jj) installed
- jq installed
- All workflow files present

### 3. View Next Story
```bash
./ralph-applpass.sh next
# Shows: S01-project-setup

./ralph-applpass.sh status
# Shows full project status
```

### 4. Run Iteration
```bash
./ralph-applpass.sh run
```

This will:
1. Show the next incomplete story
2. Verify dependencies are met
3. Build context for the agent
4. Prompt for confirmation

### 5. Implement Story (Manual)

The script doesn't automate implementation. Instead:

1. Read the context (displayed by script or in temp file)
2. Follow PROMPT.md protocol:
   - **Orient**: Read progress.txt, SKILL.md, understand story
   - **Plan**: Write TCR cycle plan
   - **Implement**: Small changes with `swift build && swift test` after each
   - **Verify**: Run full suite before completion
   - **Complete**: Update prd.json and progress.txt

### 6. Verify Completion
```bash
./ralph-applpass.sh verify S01-project-setup
```

Runs:
- `swift build` (type checking)
- `swift build -c release` (optimized build)
- `swift test` (all tests)
- `swift format lint` (if available)

### 7. Continue with Next Story
```bash
./ralph-applpass.sh run
```

## TCR Workflow with Jujutsu

Every code change follows this loop:

```bash
# Describe your change
jj desc -m "feat(keychain): add query builder"

# Make ONE small change (< 50 lines)
# Edit code...

# Verify
swift build && swift test

# Result:
#   ✅ PASS → jj new (commit and move forward)
#   ❌ FAIL → jj restore (revert and try smaller change)
```

## User Stories Overview

The prd.json contains 20 stories:

1. **S01-project-setup** - Package.swift, directory structure, CI/CD
2. **S02-data-models** - KeychainItem, KeychainQuery, errors (Sendable)
3. **S03-keychain-manager** - Query building
4. **S04-keychain-get** - Password retrieval
5. **S05-keychain-list** - List passwords
6. **S06-keychain-add** - Add passwords
7. **S07-keychain-update** - Update passwords
8. **S08-keychain-delete** - Delete passwords
9. **S09-password-generator** - Random password generation
10. **S10-output-formatter** - Table/JSON/CSV formatting
11. **S11-get-command** - CLI get command
12. **S12-list-command** - CLI list command
13. **S13-add-command** - CLI add command
14. **S14-update-command** - CLI update command
15. **S15-delete-command** - CLI delete command
16. **S16-generate-command** - CLI generate command
17. **S17-main-cli** - Main CLI integration
18. **S18-integration-tests** - E2E test suite
19. **S19-readme-docs** - Documentation
20. **S20-ci-polish** - CI/CD polish and release

## Key Differences from ElmishPaint Workflow

### Simplified
- ❌ No agent-browser validation (this is a CLI tool)
- ❌ No Fable/Vite/pnpm workflow
- ❌ No frontend-specific concerns

### Swift-Specific
- ✅ Swift 6.2.3 with strict concurrency
- ✅ Swift Testing framework (NOT XCTest)
- ✅ Swift Package Manager
- ✅ macOS Security framework patterns
- ✅ swift-format for code style

### Maintained
- ✅ TCR discipline (test || commit || revert)
- ✅ Jujutsu (jj) for version control
- ✅ Small, atomic commits
- ✅ Story-driven development
- ✅ progress.txt for continuity
- ✅ SKILL.md for framework guardrails

## Security Notes

From AGENTS.md §7:
- **NEVER** log passwords or sensitive data
- **NEVER** include credentials in error messages
- Use stdin for password input, not CLI arguments
- Follow macOS keychain access controls
- See SKILL.md for Security framework best practices

## Testing Philosophy

From AGENTS.md §5:
- Use Swift Testing with `@Test` macros
- All public APIs must have tests
- Target >80% coverage
- Test error paths and edge cases
- Follow test patterns in SKILL.md

## Next Steps

1. Review all files to understand the workflow
2. Run `./ralph-applpass.sh status` to verify setup
3. Begin with S01-project-setup:
   ```bash
   ./ralph-applpass.sh run
   ```
4. Follow PROMPT.md protocol for implementation
5. Use AGENTS.md as reference for conventions
6. Consult SKILL.md before writing Swift code

---

**Happy building with agents! 🤖**
