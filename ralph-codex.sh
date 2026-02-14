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
CODEX_MODEL="${CODEX_MODEL:-gpt-5.3-codex}"  # Override with env var
CODEX_OUTPUT_FILE="$SCRIPT_DIR/.ralph-codex-output.txt"
CODEX_OUTPUTS_DIR="$SCRIPT_DIR/.codex-outputs"
CODEX_STREAM_JSON="${CODEX_STREAM_JSON:-false}"  # set true to enable --json + jsonl

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
    local codex_cmd="${CODEX_CMD:-codex}"
    if ! command -v "$codex_cmd" &> /dev/null; then
        log_error "Codex CLI not found."
        log_info "Install from: https://platform.openai.com/docs/codex"
        log_info "Or set CODEX_CMD environment variable"
        exit 1
    fi
    
    # Verify it's the right Codex (has exec subcommand)
    if ! $codex_cmd --help 2>&1 | grep -q 'exec'; then
        log_error "Codex CLI found but doesn't have 'exec' subcommand"
        log_info "Make sure you have the official OpenAI Codex CLI"
        exit 1
    fi
    
    log_success "Found Codex CLI: $codex_cmd"
    
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
    
    # Get story data without color codes in jq
    local story_data
    story_data=$(jq -r ".stories[] | select(.id == \"$story_id\") | 
        \"TITLE:\" + .title + \"\n\" +
        \"DESC:\" + .description + \"\n\" +
        \"DEPS:\" + (.dependencies | join(\", \")) + \"\n\" +
        \"CRITERIA\n\" +
        (.acceptance_criteria | map(\"  - \" + .) | join(\"\n\"))
    " "$PRD_FILE")
    
    # Format with colors using bash
    echo "$story_data" | while IFS= read -r line; do
        case "$line" in
            TITLE:*)
                echo -e "${CYAN}Title:${NC} ${line#TITLE:}"
                ;;
            DESC:*)
                echo -e "${CYAN}Description:${NC} ${line#DESC:}"
                ;;
            DEPS:*)
                echo -e "${CYAN}Dependencies:${NC} ${line#DEPS:}"
                ;;
            CRITERIA)
                echo -e "${CYAN}Acceptance Criteria:${NC}"
                ;;
            *)
                echo "$line"
                ;;
        esac
    done
    
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
    
    # Build Codex exec command
    local codex_cmd="${CODEX_CMD:-codex}"
    
    # Create outputs directory before tee tries to write to it
    mkdir -p "$CODEX_OUTPUTS_DIR"
    local ts
    ts="$(date +%s)"
    
    log_codex "Starting Codex session..."
    
    # Use codex exec with proper flags
    # - reads prompt from stdin
    # --full-auto: workspace-write sandbox + on-request approvals
    # --add-dir .git: allow git operations
    # --add-dir .jj: allow jj to write commits
    # -o: capture final message for verification
    # --json: optional, get structured output events (controlled by CODEX_STREAM_JSON)
    
    local json_flags=()
    if [ "$CODEX_STREAM_JSON" = "true" ]; then
        json_flags=(--json)
    fi
    
    # Run codex exec, optionally streaming to JSONL file
    if [ "$CODEX_STREAM_JSON" = "true" ]; then
        # shellcheck disable=SC2294
        if ! $codex_cmd exec \
            --full-auto \
            --model "$CODEX_MODEL" \
            --add-dir .git \
            --add-dir .jj \
            --add-dir "$HOME/.cache" \
            -o "$CODEX_OUTPUT_FILE" \
            "${json_flags[@]}" \
            - < "$context_file" 2>&1 | tee "$CODEX_OUTPUTS_DIR/${story_id}-${ts}.jsonl"; then
            
            log_error "Codex invocation failed"
            return 1
        fi
    else
        # No JSON streaming, just run directly
        if ! $codex_cmd exec \
            --full-auto \
            --model "$CODEX_MODEL" \
            --add-dir .git \
            --add-dir .jj \
            --add-dir "$HOME/.cache" \
            -o "$CODEX_OUTPUT_FILE" \
            - < "$context_file" 2>&1; then
            
            log_error "Codex invocation failed"
            return 1
        fi
    fi
    
    log_success "Codex completed"
    
    # Show final output
    if [ -f "$CODEX_OUTPUT_FILE" ]; then
        echo ""
        log_info "Codex Final Output:"
        echo "=============================================="
        cat "$CODEX_OUTPUT_FILE"
        echo "=============================================="
        echo ""
        
        # Save to archive
        local output_file="$CODEX_OUTPUTS_DIR/${story_id}-final-${ts}.txt"
        cp "$CODEX_OUTPUT_FILE" "$output_file"
        log_info "Final output saved to: $output_file"
    fi
    
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
    
    if ! swift test --verbose; then
        log_error "swift test failed"
        return 1
    fi
    log_success "All tests passed"
    
    # Optional: swift format (Swift PM plugin)
    if swift format --help &> /dev/null; then
        if ! swift format lint --recursive Sources/ Tests/ 2>/dev/null; then
            log_warning "swift format lint found issues"
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
    
    # Invoke Codex (fully automated, no prompt)
    log_info "Starting automated Codex execution..."
    
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
        
        # Clean up context and output files
        rm -f "$context_file" "$CODEX_OUTPUT_FILE"
        
        return 0
    else
        log_error "✗ Verification failed"
        log_warning "Review Codex output and fix issues"
        log_info "Context file preserved: $context_file"
        log_info "Output file preserved: $CODEX_OUTPUT_FILE"
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
    
    # Make behavior deterministic regardless of where script is launched from
    cd "$SCRIPT_DIR"
    
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
  CODEX_CMD           Path to Codex CLI (default: codex)
  CODEX_MODEL         Codex model to use (default: gpt-5.3-codex)
  CODEX_STREAM_JSON   Enable JSON streaming (default: false)
                      Set to 'true' to save JSONL event logs

Examples:
  $0 run                              # Start next iteration
  $0 verify S01-project-setup         # Verify story
  CODEX_MODEL=gpt-4 $0 run            # Use different model
  CODEX_STREAM_JSON=true $0 run       # Enable JSON streaming
  
Codex Flags Used:
  codex exec --full-auto --model <model> --add-dir .git --add-dir .jj -o <file> - < context.txt
  
  --full-auto: workspace-write sandbox + on-request approvals
  --add-dir .git: allows git operations
  --add-dir .jj: allows jj to write commits
  -o: captures final message for verification
  --json: (optional) enable with CODEX_STREAM_JSON=true
  -: reads prompt from stdin
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
