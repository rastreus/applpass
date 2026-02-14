### TCR Plan
1. Create `README.md` foundation (overview, requirements, installation, quick start, usage).
2. Add command reference sections with examples for all commands.
3. Add security, troubleshooting, developer build, contributing, and license sections.
4. Add MIT `LICENSE`.
5. Add `examples/` scripts.
6. Add example agent skill file under `examples/skills/`.
7. Run full verification suite.
8. Mark `S19-readme-docs` complete in tracking files and commit.

### Implementation
1. Added README foundation in `README.md`.
- Verification: `swift build --disable-sandbox && swift test --disable-sandbox`
- Decision: commit (`docs(readme): add README foundation sections`)

2. Added command reference for `get` and `list` in `README.md`.
- Verification: build/tests passed
- Decision: commit (`docs(readme): add get and list command reference`)

3. Added command reference for `add` and `update` in `README.md`.
- Verification: build/tests passed
- Decision: commit (`docs(readme): add add and update command reference`)

4. Added command reference for `delete` and `generate`, plus output formats in `README.md`.
- Verification: build/tests passed
- Decision: commit (`docs(readme): add delete and generate command reference`)

5. Added security best practices and troubleshooting in `README.md`.
- Verification: build/tests passed
- Decision: commit (`docs(readme): add security and troubleshooting`)

6. Added developer build instructions, contributing/TCR guidance, and license section in `README.md`.
- Verification: build/tests passed
- Decision: commit (`docs(readme): add developer build and contributing guidance`)

7. Added MIT license text in `LICENSE`.
- Verification: build/tests passed
- Decision: commit (`docs(readme): add MIT LICENSE`)

8. Added sample scripts:
- `examples/quick-start.sh`
- `examples/update-with-generate.sh`
- `examples/list-json.sh`
- Verification: build/tests passed
- Decision: commit (`docs(examples): add sample usage scripts`)

9. Added examples index and agent skill:
- `examples/README.md`
- `examples/skills/applpass-commands/SKILL.md`
- Updated `README.md` to point to examples
- Verification: build/tests passed
- Decision: commit (`docs(examples): add examples index and agent skill`)

10. Updated tracking files:
- Set `S19-readme-docs` to passed in `prd.json`
- Appended Iteration 19 summary to `progress.txt`
- Decision: commit (`chore(ralph): complete story S19-readme-docs`)

Note: I hit one shell-escaping issue while appending `progress.txt` (backticks triggered command substitution). I repaired it by rewriting the iteration block cleanly.

### Verification
Final suite passed:
1. `swift build --disable-sandbox`
2. `swift build -c release --disable-sandbox`
3. `swift test --disable-sandbox --verbose`
4. `swift format lint --recursive .`

### Completion
1. `prd.json` updated: `S19-readme-docs` now has `"passes": true`.
2. `progress.txt` updated with Iteration 19 completion entry.
3. Completion commit created: `chore(ralph): complete story S19-readme-docs`.
4. Working copy is clean at new empty head commit after `jj new`.