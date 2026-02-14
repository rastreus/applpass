# Using ralph-codex.sh with OpenAI Codex

This guide explains how to configure and use the Codex-integrated workflow for applpass.

## Quick Start

```bash
# Run next iteration with Codex
./ralph-codex.sh run

# Check status
./ralph-codex.sh status

# Verify a completed story
./ralph-codex.sh verify S01-project-setup
```

## Codex CLI Configuration

The script uses the **Codex CLI `exec` subcommand** for non-interactive execution.

### Default Configuration

```bash
codex exec \
  --full-auto \
  --model gpt-5.3-codex \
  --add-dir .git \
  --add-dir .jj \
  -o .ralph-codex-output.txt \
  - < context-file.txt
```

**Flags explained:**
- `exec` - Non-interactive mode (vs interactive TUI)
- `--full-auto` - workspace-write sandbox + on-request approvals (no prompts)
- `--model` - Which model to use
- `--add-dir .git` - Grant write access to .git directory (for git operations)
- `--add-dir .jj` - Grant write access to .jj directory (for jj commits)
- `-o` - Output final message to file
- `-` - Read prompt from stdin

**Note:** JSON streaming (`--json`) is disabled by default. Enable with `CODEX_STREAM_JSON=true`.

### Customizing the Model

```bash
# Use a different model
export CODEX_MODEL="gpt-4"
./ralph-codex.sh run

# Or inline
CODEX_MODEL="gpt-4o" ./ralph-codex.sh run
```

### Enabling JSON Event Streaming

```bash
# Enable JSON streaming and JSONL logs
export CODEX_STREAM_JSON=true
./ralph-codex.sh run

# Or inline
CODEX_STREAM_JSON=true ./ralph-codex.sh run
```

When enabled, full execution logs are saved to `.codex-outputs/<story-id>-<timestamp>.jsonl`.

### Custom Codex Command Path

```bash
# If codex is not in PATH
export CODEX_CMD="/usr/local/bin/codex"
./ralph-codex.sh run
```

## How It Works

When you run `./ralph-codex.sh run`:

1. **Builds context** - Creates a comprehensive context file (~1000-1500 lines) with:
   - Recent progress
   - AGENTS.md policy
   - PROMPT.md instructions
   - Swift 6 SKILL.md
   - Story details
   - Repository state

2. **Invokes Codex** - Runs:
   ```bash
   codex exec --full-auto --model <model> --add-dir .git -o <output> - < context.txt
   ```

3. **Codex executes** - Codex reads the context and:
   - Writes TCR plan
   - Implements in small steps
   - Runs `swift build && swift test` after each change
   - Uses `jj new` (commit) or `jj restore` (revert)
   - Updates prd.json and progress.txt

4. **Verification** - Script runs full test suite:
   - `swift build`
   - `swift build -c release`
   - `swift test --verbose`
   - Checks prd.json was updated

5. **Completion** - Story marked complete, ready for next iteration

## Workflow Example

Here's a complete iteration workflow:

### 1. Start Iteration (Fully Automated)
```bash
$ ./ralph-codex.sh run

ℹ Checking prerequisites...
✓ Found Codex CLI: codex
✓ Found Swift: Swift version 6.2.3
✓ Found Jujutsu: jj 0.23.0
✓ All prerequisites met

ℹ Story: S01-project-setup

Title: Project scaffolding and Package.swift
Description: Create initial Swift package structure...

Dependencies: 
Acceptance Criteria:
  - Package.swift targets Swift 6.2.3...
  - swift build succeeds with zero warnings
  ...

✓ All dependencies complete

ℹ Building context for Codex...
✓ Context built: /path/to/applpass/context-S01.abc123
ℹ Context size: 1247 lines

ℹ Starting automated Codex execution...

🤖 Invoking Codex for story: S01-project-setup
🤖 Model: gpt-5.3-codex
🤖 Starting Codex session...
```

**No prompt** - fully automated execution begins immediately.

### 2. Codex Works

Codex receives the full context including:
- Recent progress (last 30 lines)
- AGENTS.md policy
- PROMPT.md instructions
- Swift 6 SKILL.md
- Story details
- Repository state

Codex then:
1. Writes TCR plan
2. Implements in small steps
3. Runs tests after each change
4. Updates prd.json and progress.txt

### 3. Verification

```bash
✓ Codex completed

ℹ Codex has completed. Verifying results...
ℹ Verifying story completion...
ℹ Running verification suite...
✓ swift build passed
✓ Release build passed
✓ All tests passed
✓ Code formatting clean
✓ Story S01-project-setup verification complete! ✓
✓ Story S01-project-setup complete and verified!
```

### 4. Continue

```bash
$ ./ralph-codex.sh status

ℹ applpass Project Status

  Total stories:     20
  Complete:          1
  Remaining:         19
  Progress:          5%

ℹ Next story:
ℹ Story: S02-data-models
...

$ ./ralph-codex.sh run
# Continues with S02...
```

## Context File Structure

The context file passed to Codex contains:

```
# Codex Agent Context

## Critical Instructions
[Security, testing, Swift 6 reminders]

## Recent Progress (last 30 lines)
[From progress.txt]

## AGENTS.md — Project Policy
[Full AGENTS.md content]

## PROMPT.md — Per-Iteration Instructions
[Full PROMPT.md content]

## Swift 6 SKILL.md
[Full skill file content]

## Your Assignment: S##-story-id
[Story JSON from prd.json]

## Current Repository State
[jj log, jj st, file structure]

## Execution Instructions
[Phase-by-phase protocol]

## Output Format
[Expected response structure]
```

Total size: ~1000-1500 lines depending on story

## Codex Output

Codex outputs are saved in `.codex-outputs/` directory:

```bash
.codex-outputs/
├── S01-project-setup-1234567890.txt
├── S02-data-models-1234567891.txt
└── ...
```

Each file contains:
- TCR plan
- Implementation details
- Test results
- Verification output
- prd.json and progress.txt updates

## Troubleshooting

### Codex Not Found

```bash
✗ Codex CLI not found.
ℹ Install from: https://platform.openai.com/docs/codex
```

**Solution**: Install Codex CLI from OpenAI, or set custom path:
```bash
export CODEX_CMD="/usr/local/bin/codex"
```

### Missing 'exec' Subcommand

```bash
✗ Codex CLI found but doesn't have 'exec' subcommand
```

**Solution**: You may have a different tool named `codex`. Ensure you have the official OpenAI Codex CLI installed.

### Authentication Error

```bash
Error: Not authenticated
```

**Solution**: Run `codex login` first:
```bash
codex login
# Follow authentication flow
```

### Verification Fails

```bash
✗ swift test failed
✗ Verification failed
```

**Solution**: Check the output files:
```bash
cat .ralph-codex-output.txt                    # Final message
cat .codex-outputs/S##-story-id-*.jsonl        # Full execution log
```

Then either:
1. Fix manually and run `./ralph-codex.sh verify S##-story-id`
2. Re-run iteration if Codex made an error

### Network Access Issues

If Codex can't install dependencies:

**Solution**: Check that `--full-auto` enables network access. If needed, you can add:
```bash
# Edit ralph-codex.sh, in invoke_codex function:
-c sandbox_workspace_write.network_access=true
```

### Permission Denied for .git

```bash
Error: Permission denied: .git/...
```

**Solution**: The `--add-dir .git` flag should handle this. If not, check that your `jj` is working:
```bash
jj st  # Should show working copy status
```

## Environment Variables Reference

| Variable | Default | Description |
|----------|---------|-------------|
| `CODEX_CMD` | `codex` | Path to Codex CLI executable |
| `CODEX_MODEL` | `gpt-5.3-codex` | Model to use for execution |
| `CODEX_STREAM_JSON` | `false` | Enable JSON event streaming to .jsonl files |

## Advanced: Adding Custom Codex Flags

If you need additional configuration, edit the `invoke_codex()` function in `ralph-codex.sh`:

```bash
# Around line 165, in invoke_codex():
if ! $codex_cmd exec \
    --full-auto \
    --model "$CODEX_MODEL" \
    --add-dir .git \
    --add-dir "$HOME/.cache" \    # Add more directories here
    -c sandbox_workspace_write.network_access=true \  # Add custom configs
    -o "$CODEX_OUTPUT_FILE" \
    --json \
    - < "$context_file" 2>&1 | tee ".codex-outputs/${story_id}-$(date +%s).jsonl"; then
```

**Common additions:**
```bash
# More cache directories for Swift
--add-dir "$HOME/Library/Caches/org.swift.swiftpm" \
--add-dir "$HOME/.swiftpm" \

# Enable network for package downloads (if needed)
-c sandbox_workspace_write.network_access=true \

# Higher reasoning effort
-c model_reasoning_effort=xhigh \

# Different approval mode
--ask-for-approval never \  # Very dangerous!
```

## Tips for Best Results

1. **Review context before invoking**: The context file is preserved in `/tmp`. Review it to ensure all info is present.

2. **Monitor first iteration**: Watch S01-project-setup closely to ensure Codex understands the workflow.

3. **Adjust model parameters**: If Codex truncates output, increase max tokens.

4. **Keep dependencies in order**: The script checks dependencies, but ensure stories are done sequentially when possible.

5. **Review progress.txt**: After each iteration, verify Codex wrote good notes for future iterations.

## Comparison to Manual Workflow

| Aspect | ralph-applpass.sh (manual) | ralph-codex.sh (automated) |
|--------|---------------------------|----------------------------|
| Context building | ✓ Automatic | ✓ Automatic |
| Agent invocation | ✗ Manual | ✓ Automatic |
| Implementation | ✗ Manual | ✓ Codex does it |
| Verification | ✓ Automatic | ✓ Automatic |
| Iteration time | ~2-4 hours | ~30-60 minutes |

## Next Steps

1. Configure your Codex CLI settings
2. Test with a dry run: `./ralph-codex.sh status`
3. Start first iteration: `./ralph-codex.sh run`
4. Review Codex output after completion
5. Continue iterating through all 20 stories

---

**Happy autonomous building! 🤖🚀**
