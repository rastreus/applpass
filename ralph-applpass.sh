#!/usr/bin/env bash
set -euo pipefail

# ralph-applpass.sh — Autonomous agent loop for applpass development
# Simplified for Swift CLI (no browser validation)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRD_FILE="$SCRIPT_DIR/prd.json"
PROGRESS_FILE="$SCRIPT_DIR/progress.txt"
AGENTS_FILE="$SCRIPT_DIR/AGENTS.md"
PROMPT_FILE="$SCRIPT_DIR/PROMPT.md"
SKILL_DIR="$SCRIPT_DIR/.agents/skills"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ ${NC}$1"
}

log_success() {
    echo -e "${GREEN}✓ ${NC}$1"
}

log_warning() {
    echo -e "${YELLOW}⚠ ${NC}$1"
}

log_error() {
    echo -e "${RED}✗ ${NC}$1"
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check Swift
    if ! command -v swift &> /dev/null; then
        log_error "Swift not found. Install Swift 6.2.3+ from swift.org"
        exit 1
    fi
    
    SWIFT_VERSION=$(swift --version | head -1)
    log_success "Found Swift: $SWIFT_VERSION"
    
    # Check jj
    if ! command -v jj &> /dev/null; then
        log_error "Jujutsu (jj) not found. Install from https://github.com/martinvonz/jj"
        exit 1
    fi
    
    JJ_VERSION=$(jj --version)
    log_success "Found Jujutsu: $JJ_VERSION"
    
    # Check jq
    if ! command -v jq &> /dev/null; then
        log_error "jq not found. Install with: brew install jq"
        exit 1
    fi
    
    # Check for required files
    for file in "$PRD_FILE" "$PROGRESS_FILE" "$AGENTS_FILE" "$PROMPT_FILE"; do
        if [ ! -f "$file" ]; then
            log_error "Required file not found: $file"
            exit 1
        fi
    done
    
    log_success "All prerequisites met"
}

# Get next incomplete story
get_next_story() {
    local next_story
    next_story=$(jq -r '.stories[] | select(.passes == false) | .id' "$PRD_FILE" | head -1)
    
    if [ -z "$next_story" ]; then
        log_success "All stories complete! 🎉"
        return 1
    fi
    
    echo "$next_story"
    return 0
}

# Show story details
show_story() {
    local story_id=$1
    
    log_info "Story: $story_id"
    echo ""
    
    jq -r ".stories[] | select(.id == \"$story_id\") | 
        \"Title: \" + .title + \"\n\" +
        \"Description: \" + .description + \"\n\" +
        \"Dependencies: \" + (.dependencies | join(\", \")) + \"\n\" +
        \"Acceptance Criteria:\n\" +
        (.acceptance_criteria | map(\"  - \" + .) | join(\"\n\"))
    " "$PRD_FILE"
    
    echo ""
}

# Verify dependencies are complete
check_dependencies() {
    local story_id=$1
    local deps
    deps=$(jq -r ".stories[] | select(.id == \"$story_id\") | .dependencies[]" "$PRD_FILE" 2>/dev/null)
    
    if [ -z "$deps" ]; then
        return 0  # No dependencies
    fi
    
    for dep in $deps; do
        local dep_passes
        dep_passes=$(jq -r ".stories[] | select(.id == \"$dep\") | .passes" "$PRD_FILE")
        
        if [ "$dep_passes" != "true" ]; then
            log_error "Dependency not complete: $dep"
            log_warning "Complete $dep before starting $story_id"
            return 1
        fi
    done
    
    log_success "All dependencies complete"
    return 0
}

# Build context for the agent
build_context() {
    local story_id=$1
    
    cat << EOF
# Agent Context for Iteration

You are implementing story: $story_id

## Project Files to Read First

1. **progress.txt** (last 30 lines):
EOF
    tail -30 "$PROGRESS_FILE"
    
    cat << EOF

2. **AGENTS.md** - Project policy and TCR workflow
3. **PROMPT.md** - Per-iteration instructions
4. **.agents/skills/swift6/SKILL.md** - Swift 6 patterns (if exists)

## Your Assignment

EOF
    
    jq -r ".stories[] | select(.id == \"$story_id\")" "$PRD_FILE"
    
    cat << EOF

## Current Repository State

### Recent commits:
EOF
    jj log --limit 10 --no-pager 2>/dev/null || echo "No commits yet"
    
    cat << EOF

### Working copy status:
EOF
    jj st 2>/dev/null || echo "Clean working copy"
    
    cat << EOF

### Current file structure:
EOF
    if [ -d "$SCRIPT_DIR/Sources" ]; then
        tree -L 3 "$SCRIPT_DIR/Sources" 2>/dev/null || find "$SCRIPT_DIR/Sources" -type f | head -20
    else
        echo "No Sources directory yet (create in S01-project-setup)"
    fi
    
    cat << EOF

## Instructions

Follow the protocol in PROMPT.md:
1. **Orient**: Read context files, understand assignment
2. **Plan**: Write TCR cycle plan
3. **Implement**: Make small changes, test, commit or revert
4. **Verify**: Run full verification suite
5. **Complete**: Update prd.json and progress.txt

## Verification Commands

Before marking story complete, ALL must pass:
\`\`\`bash
swift build                    # Type checking
swift build -c release         # Release build  
swift test                     # All tests pass
swift test --verbose           # Verbose output
\`\`\`

Optional (if swift-format available):
\`\`\`bash
swift format lint --recursive Sources/ Tests/
\`\`\`

## Security Reminder

- NEVER log passwords or sensitive data
- NEVER include credentials in error messages  
- Use stdin for password input, not CLI args
- Follow AGENTS.md §7 security guidelines

---

Begin implementation following TCR discipline from AGENTS.md.
EOF
}

# Verify story completion
verify_completion() {
    local story_id=$1
    
    log_info "Verifying story completion..."
    
    # Check if story is marked as passing in prd.json
    local story_passes
    story_passes=$(jq -r ".stories[] | select(.id == \"$story_id\") | .passes" "$PRD_FILE")
    
    if [ "$story_passes" != "true" ]; then
        log_error "Story not marked as passing in prd.json"
        return 1
    fi
    
    # Check if progress.txt was updated
    if ! grep -q "$story_id" "$PROGRESS_FILE"; then
        log_warning "Story ID not found in progress.txt"
        log_warning "Did you append completion notes?"
    fi
    
    # Run verification suite
    log_info "Running verification suite..."
    
    if ! swift build; then
        log_error "swift build failed"
        return 1
    fi
    log_success "swift build passed"
    
    if ! swift build -c release; then
        log_error "swift build -c release failed"
        return 1
    fi
    log_success "Release build passed"
    
    if ! swift test; then
        log_error "swift test failed"
        return 1
    fi
    log_success "All tests passed"
    
    # Optional: swift-format check
    if command -v swift-format &> /dev/null; then
        if ! swift format lint --recursive Sources/ Tests/ 2>/dev/null; then
            log_warning "swift-format lint found style issues"
            log_warning "Run: swift format --in-place --recursive Sources/ Tests/"
        else
            log_success "Code formatting is clean"
        fi
    fi
    
    log_success "Story $story_id verification complete!"
    return 0
}

# Main iteration loop
run_iteration() {
    local story_id
    
    # Get next story
    if ! story_id=$(get_next_story); then
        return 0
    fi
    
    # Show story details
    show_story "$story_id"
    
    # Check dependencies
    if ! check_dependencies "$story_id"; then
        return 1
    fi
    
    # Confirm with user
    echo ""
    read -p "$(echo -e ${YELLOW}Implement story $story_id? [y/N] ${NC})" -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Iteration cancelled"
        return 1
    fi
    
    # Build context and pass to agent
    log_info "Building context for agent..."
    local context_file
    context_file=$(mktemp)
    build_context "$story_id" > "$context_file"
    
    log_info "Context written to: $context_file"
    log_info ""
    log_info "Next steps:"
    echo "  1. Review the context file"
    echo "  2. Implement the story following PROMPT.md"
    echo "  3. Run: $0 verify $story_id"
    echo ""
    log_warning "Agent implementation not automated in this script"
    log_warning "Use Claude/Codex with context file: $context_file"
    
    return 0
}

# Verify a specific story
verify_story() {
    local story_id=$1
    
    if [ -z "$story_id" ]; then
        log_error "Usage: $0 verify <story-id>"
        return 1
    fi
    
    log_info "Verifying story: $story_id"
    
    if verify_completion "$story_id"; then
        log_success "✓ Story $story_id is complete and verified!"
        return 0
    else
        log_error "✗ Story $story_id verification failed"
        return 1
    fi
}

# Show project status
show_status() {
    local total
    local complete
    local remaining
    
    total=$(jq '.stories | length' "$PRD_FILE")
    complete=$(jq '[.stories[] | select(.passes == true)] | length' "$PRD_FILE")
    remaining=$((total - complete))
    
    log_info "Project Status"
    echo ""
    echo "  Total stories: $total"
    echo "  Complete:      $complete"
    echo "  Remaining:     $remaining"
    echo ""
    
    if [ $remaining -gt 0 ]; then
        log_info "Next story:"
        local next
        next=$(get_next_story)
        show_story "$next"
    else
        log_success "All stories complete! 🎉"
    fi
}

# Main script logic
main() {
    local command=${1:-"run"}
    
    case "$command" in
        run)
            check_prerequisites
            run_iteration
            ;;
        verify)
            shift
            verify_story "$@"
            ;;
        status)
            show_status
            ;;
        next)
            get_next_story || exit 0
            ;;
        help|--help|-h)
            cat << EOF
Usage: $0 [command]

Commands:
  run             Run next iteration (default)
  verify <id>     Verify a story is complete
  status          Show project progress
  next            Show next story ID
  help            Show this help

Examples:
  $0 run                    # Start next iteration
  $0 verify S01-project-setup
  $0 status
EOF
            ;;
        *)
            log_error "Unknown command: $command"
            echo "Run '$0 help' for usage"
            exit 1
            ;;
    esac
}

# Run main
main "$@"
