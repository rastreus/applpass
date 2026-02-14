#!/usr/bin/env bash
set -euo pipefail

# ralph-codex.sh — Codex-integrated autonomous loop for applpass
# Adapted from ElmishPaint ralph-codex.sh for Swift CLI development

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRD_FILE="$SCRIPT_DIR/prd.json"
PROGRESS_FILE="$SCRIPT_DIR/progress.txt"
AGENTS_FILE="$SCRIPT_DIR/AGENTS.md"
PROMPT_FILE="$SCRIPT_DIR/PROMPT.md"
SKILL_DIR="$SCRIPT_DIR/.agents/skills"

# Codex configuration
CODEX_MODEL="gpt-5.3-codex"  # Adjust to your Codex model
CODEX_TIMEOUT=1800           # 30 minutes timeout
CODEX_MAX_TOKENS=8000        # Adjust based on model

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ ${NC}$1"; }
log_success() { echo -e "${GREEN}✓ ${NC}$1"; }
log_warning() { echo -e "${YELLOW}⚠ ${NC}$1"; }
log_error() { echo -e "${RED}✗ ${NC}$1"; }
log_codex() { echo -e "${CYAN}🤖 ${NC}$1"; }

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check Codex
    if ! command -v codex &> /dev/null; then
        log_error "Codex CLI not found. Install from OpenAI."
        log_info "Alternative: Set CODEX_CMD environment variable to your Codex command"
        exit 1
    fi
    
    log_success "Found Codex: $(codex --version 2>/dev/null || echo 'CLI installed')"
    
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
    
    log_success "Found Jujutsu: $(jj --version)"
    
    # Check jq
    if ! command -v jq &> /dev/null; then
        log_error "jq not found. Install with: brew install jq"
        exit 1
    fi
    
    # Check required files
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
        \"${CYAN}Title:${NC} \" + .title + \"\n\" +
        \"${CYAN}Description:${NC} \" + .description + \"\n\" +
        \"${CYAN}Dependencies:${NC} \" + (.dependencies | join(\", \")) + \"\n\" +
        \"${CYAN}Acceptance Criteria:${NC}\n\" +
        (.acceptance_criteria | map(\"  - \" + .) | join(\"\n\"))
    " "$PRD_FILE"
    
    echo ""
}

# Check dependencies
check_dependencies() {
    local story_id=$1
    local deps
    deps=$(jq -r ".stories[] | select(.id == \"$story_id\") | .dependencies[]" "$PRD_FILE" 2>/dev/null)
    
    if [ -z "$deps" ]; then
        return 0
    fi
    
    for dep in $deps; do
        local dep_passes
        dep_passes=$(jq -r ".stories[] | select(.id == \"$dep\") | .passes" "$PRD_FILE")
        
        if [ "$dep_passes" != "true" ]; then
            log_error "Dependency not complete: $dep"
            return 1
        fi
    done
    
    log_success "All dependencies complete"
    return 0
}

# Build context file for Codex
build_context_file() {
    local story_id=$1
    local context_file=$2
    
    cat > "$context_file" << 'EOF'
# Codex Agent Context

You are implementing a user story for the applpass project. This is a Swift CLI tool
for macOS Keychain password management.

## Critical Instructions

1. **Read ALL context files below before starting**
2. **Follow PROMPT.md protocol exactly**: Orient → Plan → Implement (TCR) → Verify → Complete
3. **Use Swift 6.2.3 with strict concurrency** - check SKILL.md for patterns
4. **Use Swift Testing** (NOT XCTest) - see SKILL.md for syntax
5. **Follow TCR discipline**: small changes, test after each, commit or revert
6. **Security first**: Never log passwords, use stdin for input, follow AGENTS.md §7

---

EOF

    # Add recent progress
    cat >> "$context_file" << EOF
## Recent Progress (last 30 lines of progress.txt)

EOF
    tail -30 "$PROGRESS_FILE" >> "$context_file"
    
    # Add full policy documents
    cat >> "$context_file" << EOF

---

## AGENTS.md — Project Policy

EOF
    cat "$AGENTS_FILE" >> "$context_file"
    
    cat >> "$context_file" << EOF

---

## PROMPT.md — Per-Iteration Instructions

EOF
    cat "$PROMPT_FILE" >> "$context_file"
    
    # Add Swift 6 skill
    if [ -f "$SKILL_DIR/swift6/SKILL.md" ]; then
        cat >> "$context_file" << EOF

---

## Swift 6 SKILL.md — Technical Reference

EOF
        cat "$SKILL_DIR/swift6/SKILL.md" >> "$context_file"
    fi
    
    # Add story assignment
    cat >> "$context_file" << EOF

---

## Your Assignment: $story_id

EOF
    jq -r ".stories[] | select(.id == \"$story_id\")" "$PRD_FILE" >> "$context_file"
    
    # Add repository state
    cat >> "$context_file" << EOF

---

## Current Repository State

### Recent commits:
EOF
    jj log --limit 10 --no-pager 2>/dev/null >> "$context_file" || echo "No commits yet" >> "$context_file"
    
    cat >> "$context_file" << EOF

### Working copy status:
EOF
    jj st 2>/dev/null >> "$context_file" || echo "Clean working copy" >> "$context_file"
    
    cat >> "$context_file" << EOF

### Current file structure:
EOF
    if [ -d "$SCRIPT_DIR/Sources" ]; then
        tree -L 3 "$SCRIPT_DIR/Sources" 2>/dev/null >> "$context_file" || \
            find "$SCRIPT_DIR/Sources" -type f >> "$context_file"
    else
        echo "No Sources directory yet (will be created in S01-project-setup)" >> "$context_file"
    fi
    
    # Add execution instructions
    cat >> "$context_file" << 'EOF'

---

## Execution Instructions

### Phase 1: Orient
1. Read progress.txt context above
2. Read AGENTS.md policy
3. Read PROMPT.md protocol
4. Read Swift 6 SKILL.md
5. Understand your story assignment completely

### Phase 2: Plan
Write your TCR cycle plan. List 5-10 atomic steps:
```
TCR Plan for <STORY_ID>:
  1. Step 1 description — what will be tested
  2. Step 2 description — what will be tested
  ...
```

### Phase 3: Implement (TCR Loop)
For each step:
```bash
jj desc -m "feat(scope): description"
# Make small change (< 50 lines)
swift build && swift test
# ✅ Pass → jj new
# ❌ Fail → jj restore
```

### Phase 4: Verify Story Completion
Before marking complete, ALL must pass:
```bash
swift build                    # ✅
swift build -c release         # ✅
swift test --verbose           # ✅
swift format lint --recursive . # ✅ (if available)
```

### Phase 5: Complete
1. Update prd.json: set "passes": true for your story
2. Append to progress.txt (follow format from previous entries)
3. Commit tracking files:
   ```bash
   jj desc -m "chore(ralph): complete story <STORY_ID>"
   jj new
   ```

---

## Output Format

Provide your response in this structure:

### TCR Plan
[Your step-by-step plan]

### Implementation
[Show each TCR cycle with:
- What changed
- Test results
- Commit or revert decision]

### Verification
[Show results of final verification suite]

### Completion
[Show prd.json update and progress.txt entry]

---

Begin implementation now. Be methodical. Follow TCR discipline. Test everything.
EOF
}

# Call Codex with context
invoke_codex() {
    local story_id=$1
    local context_file=$2
    
    log_codex "Invoking Codex for story: $story_id"
    log_codex "Model: $CODEX_MODEL"
    log_codex "Context file: $context_file"
    
    # Determine Codex command
    local codex_cmd="${CODEX_CMD:-codex}"
    
    # Build Codex invocation
    # Adjust these flags based on your Codex CLI
    local codex_output
    codex_output=$(mktemp)
    
    log_codex "Starting Codex session..."
    
    # Option 1: If your Codex CLI supports file input
    if $codex_cmd --help 2>&1 | grep -q '\--file'; then
        $codex_cmd \
            --model "$CODEX_MODEL" \
            --file "$context_file" \
            --timeout "$CODEX_TIMEOUT" \
            --max-tokens "$CODEX_MAX_TOKENS" \
            > "$codex_output" 2>&1
    
    # Option 2: If it reads from stdin
    elif $codex_cmd --help 2>&1 | grep -q 'stdin'; then
        cat "$context_file" | $codex_cmd \
            --model "$CODEX_MODEL" \
            --timeout "$CODEX_TIMEOUT" \
            --max-tokens "$CODEX_MAX_TOKENS" \
            > "$codex_output" 2>&1
    
    # Option 3: Interactive mode (you may need to customize this)
    else
        log_warning "Codex CLI doesn't support file input or stdin"
        log_info "Starting interactive session. Paste context manually or adjust script."
        
        # You might need to use 'expect' or similar for full automation
        $codex_cmd --model "$CODEX_MODEL" > "$codex_output" 2>&1
    fi
    
    local exit_code=$?
    
    if [ $exit_code -ne 0 ]; then
        log_error "Codex invocation failed with exit code: $exit_code"
        cat "$codex_output"
        return 1
    fi
    
    log_success "Codex completed"
    
    # Show Codex output
    echo ""
    log_info "Codex Output:"
    echo "=============================================="
    cat "$codex_output"
    echo "=============================================="
    echo ""
    
    # Save output for review
    local output_file="$SCRIPT_DIR/.codex-outputs/${story_id}-$(date +%s).txt"
    mkdir -p "$SCRIPT_DIR/.codex-outputs"
    cp "$codex_output" "$output_file"
    log_info "Output saved to: $output_file"
    
    rm "$codex_output"
    return 0
}

# Verify story completion
verify_completion() {
    local story_id=$1
    
    log_info "Verifying story completion..."
    
    # Check if story is marked as passing
    local story_passes
    story_passes=$(jq -r ".stories[] | select(.id == \"$story_id\") | .passes" "$PRD_FILE")
    
    if [ "$story_passes" != "true" ]; then
        log_error "Story not marked as passing in prd.json"
        log_warning "Did Codex update prd.json?"
        return 1
    fi
    
    # Check if progress.txt was updated
    if ! grep -q "$story_id" "$PROGRESS_FILE"; then
        log_warning "Story ID not found in progress.txt"
        log_warning "Did Codex append completion notes?"
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
    
    # Optional: swift-format
    if command -v swift-format &> /dev/null; then
        if ! swift format lint --recursive Sources/ Tests/ 2>/dev/null; then
            log_warning "swift-format lint found issues"
            log_warning "Run: swift format --in-place --recursive Sources/ Tests/"
        else
            log_success "Code formatting clean"
        fi
    fi
    
    log_success "Story $story_id verification complete! ✓"
    return 0
}

# Main iteration loop
run_iteration() {
    local story_id
    
    # Get next story
    if ! story_id=$(get_next_story); then
        return 0
    fi
    
    # Show story
    show_story "$story_id"
    
    # Check dependencies
    if ! check_dependencies "$story_id"; then
        log_error "Complete dependencies first"
        return 1
    fi
    
    # Build context
    log_info "Building context for Codex..."
    local context_file
    context_file=$(mktemp -t "applpass-context-${story_id}.XXXXXX")
    
    build_context_file "$story_id" "$context_file"
    
    log_success "Context built: $context_file"
    log_info "Context size: $(wc -l < "$context_file") lines"
    
    # Confirm before invoking Codex
    echo ""
    read -p "$(echo -e ${YELLOW}Invoke Codex for story $story_id? [y/N] ${NC})" -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Iteration cancelled"
        log_info "Context file preserved: $context_file"
        return 1
    fi
    
    # Invoke Codex
    if ! invoke_codex "$story_id" "$context_file"; then
        log_error "Codex invocation failed"
        log_info "Context file preserved: $context_file"
        return 1
    fi
    
    # Verify completion
    echo ""
    log_info "Codex has completed. Verifying results..."
    
    if verify_completion "$story_id"; then
        log_success "✓ Story $story_id complete and verified!"
        
        # Clean up context file
        rm "$context_file"
        
        return 0
    else
        log_error "✗ Verification failed"
        log_warning "Review Codex output and fix issues"
        log_info "Context file preserved: $context_file"
        return 1
    fi
}

# Manual verification
verify_story() {
    local story_id=$1
    
    if [ -z "$story_id" ]; then
        log_error "Usage: $0 verify <story-id>"
        return 1
    fi
    
    if verify_completion "$story_id"; then
        log_success "✓ Story $story_id verified"
        return 0
    else
        log_error "✗ Story $story_id verification failed"
        return 1
    fi
}

# Show project status
show_status() {
    local total complete remaining
    
    total=$(jq '.stories | length' "$PRD_FILE")
    complete=$(jq '[.stories[] | select(.passes == true)] | length' "$PRD_FILE")
    remaining=$((total - complete))
    
    log_info "applpass Project Status"
    echo ""
    echo "  Total stories:     $total"
    echo "  Complete:          $complete"
    echo "  Remaining:         $remaining"
    echo "  Progress:          $((complete * 100 / total))%"
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

# Main
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
  run             Run next iteration with Codex (default)
  verify <id>     Verify a story is complete
  status          Show project progress
  next            Show next story ID
  help            Show this help

Environment Variables:
  CODEX_CMD       Path to Codex CLI (default: codex)
  CODEX_MODEL     Codex model to use (default: gpt-5.3-codex)

Examples:
  $0 run                          # Start next iteration
  $0 verify S01-project-setup     # Verify story
  CODEX_MODEL=gpt-4 $0 run        # Use different model
EOF
            ;;
        *)
            log_error "Unknown command: $command"
            echo "Run '$0 help' for usage"
            exit 1
            ;;
    esac
}

main "$@"
