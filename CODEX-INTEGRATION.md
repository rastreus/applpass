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

The script attempts to detect your Codex CLI configuration automatically. You may need to customize it based on your setup.

### Option 1: Standard Codex CLI

If you have the OpenAI Codex CLI installed:

```bash
# Default configuration (script will use these)
./ralph-codex.sh run
```

The script uses:
- Model: `gpt-5.3-codex` (change via `CODEX_MODEL`)
- Timeout: 1800 seconds (30 minutes)
- Max tokens: 8000

### Option 2: Custom Codex Command

If your Codex CLI has a different name or path:

```bash
# Set custom command
export CODEX_CMD="/path/to/your/codex"
./ralph-codex.sh run

# Or inline
CODEX_CMD="my-codex" ./ralph-codex.sh run
```

### Option 3: Different Model

```bash
# Use a different model
export CODEX_MODEL="gpt-4-codex"
./ralph-codex.sh run

# Or inline
CODEX_MODEL="gpt-4" ./ralph-codex.sh run
```

## Codex CLI Flags Detection

The script detects which invocation pattern your Codex CLI supports:

### Pattern 1: File Input (Preferred)
```bash
codex --model gpt-5.3-codex --file context.txt --timeout 1800
```

### Pattern 2: Stdin Input
```bash
cat context.txt | codex --model gpt-5.3-codex --timeout 1800
```

### Pattern 3: Interactive
```bash
# Falls back to interactive mode
codex --model gpt-5.3-codex
# You'll need to paste context manually
```

## Customizing the Codex Invocation

If the auto-detection doesn't work, edit `ralph-codex.sh` line ~230 in the `invoke_codex()` function:

```bash
# Find this section and modify:
$codex_cmd \
    --model "$CODEX_MODEL" \
    --file "$context_file" \        # Adjust flags here
    --timeout "$CODEX_TIMEOUT" \
    --max-tokens "$CODEX_MAX_TOKENS" \
    > "$codex_output" 2>&1
```

Common flag variations:
```bash
# OpenAI CLI style
codex --model X --input context.txt --timeout Y

# Alternative style
codex -m X -f context.txt -t Y

# Chat-based API
codex chat --model X < context.txt

# Custom wrapper
my-codex-wrapper context.txt --model X
```

## Workflow Example

Here's a complete iteration workflow:

### 1. Start Iteration
```bash
$ ./ralph-codex.sh run

ℹ Checking prerequisites...
✓ Found Codex: CLI installed
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
✓ Context built: /tmp/applpass-context-S01.abc123
ℹ Context size: 1247 lines

Invoke Codex for story S01-project-setup? [y/N] y

🤖 Invoking Codex for story: S01-project-setup
🤖 Model: gpt-5.3-codex
🤖 Context file: /tmp/applpass-context-S01.abc123
🤖 Starting Codex session...
```

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
✗ Codex CLI not found. Install from OpenAI.
```

**Solution**: Install Codex CLI or set `CODEX_CMD`:
```bash
export CODEX_CMD="/usr/local/bin/codex"
```

### Context Too Large

If context exceeds model limits:

**Solution 1**: Adjust max tokens:
```bash
export CODEX_MAX_TOKENS=16000
```

**Solution 2**: Use a larger model:
```bash
export CODEX_MODEL="gpt-5.3-codex-extended"
```

### Verification Fails

```bash
✗ swift test failed
✗ Verification failed
```

**Solution**: Review Codex output:
```bash
cat .codex-outputs/S##-story-id-*.txt
```

Then either:
1. Fix manually and run `./ralph-codex.sh verify S##-story-id`
2. Re-run iteration if Codex made an error

### Codex Times Out

```bash
✗ Codex invocation failed with exit code: 124
```

**Solution**: Increase timeout:
```bash
# Edit ralph-codex.sh, line ~10
CODEX_TIMEOUT=3600  # 60 minutes
```

## Environment Variables Reference

| Variable | Default | Description |
|----------|---------|-------------|
| `CODEX_CMD` | `codex` | Path to Codex CLI executable |
| `CODEX_MODEL` | `gpt-5.3-codex` | Model to use |
| `CODEX_TIMEOUT` | `1800` | Timeout in seconds (30 min) |
| `CODEX_MAX_TOKENS` | `8000` | Max tokens in response |

## Advanced: Custom Codex Wrapper

If you need special handling, create a wrapper script:

```bash
#!/bin/bash
# my-codex-wrapper.sh

context_file=$1
model=${2:-gpt-5.3-codex}

# Your custom Codex invocation
curl -X POST https://api.openai.com/v1/chat/completions \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"model\": \"$model\",
    \"messages\": [{
      \"role\": \"user\",
      \"content\": \"$(cat $context_file | jq -Rs .)\"
    }],
    \"max_tokens\": 8000
  }" | jq -r '.choices[0].message.content'
```

Then:
```bash
export CODEX_CMD="./my-codex-wrapper.sh"
./ralph-codex.sh run
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
