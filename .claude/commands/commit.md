---
description: Create a git commit following project standards and safety protocols
allowed-tools: Bash(git status:*), Bash(git log:*), Bash(git add:*), Bash(git diff:*), Bash(git commit:*), Bash(make test:*), Bash(asciidoctor:*)
---

# commit

Create a git commit following all project standards and safety protocols for pgxntool repositories.

**CRITICAL REQUIREMENTS:**

1. **Git Safety**: Never update `git config`, never force push to `main`/`master`, never skip hooks unless explicitly requested

2. **Commit Attribution**: Do NOT add "Generated with Claude Code" to commit message body. The standard Co-Authored-By trailer is acceptable per project CLAUDE.md.

3. **Testing**: ALL tests must pass before committing:
   - Run `make test`
   - Check the output carefully for any "not ok" lines
   - Count passing vs total tests
   - **If ANY tests fail: STOP. Do NOT commit. Ask the user what to do.**
   - There is NO such thing as an "acceptable" failing test
   - Do NOT rationalize failures as "pre-existing" or "unrelated"

**WORKFLOW:**

1. **If in pgxntool**: Check if `README.html` needs regeneration:
   ```bash
   if [ ! -f README.html ] || [ README.asc -nt README.html ]; then
     asciidoctor README.asc -o README.html
   fi
   ```
   - If HTML was generated, sanity-check it (exists, not empty, reasonable size, contains HTML tags)
   - If generation fails or file looks wrong: STOP and inform the user

2. Run in parallel: `git status`, `git diff --stat`, `git log -10 --oneline`

3. Check test status - THIS IS MANDATORY:
   - Run `make test 2>&1 | tee /tmp/test-output.txt`
   - Check for failing tests: `grep "^not ok" /tmp/test-output.txt`
   - If ANY tests fail: STOP immediately and inform the user
   - Only proceed if ALL tests pass

4. Analyze changes and draft concise commit message following this repo's style:
   - Look at `git log -10 --oneline` to match existing style
   - Be factual and direct (e.g., "Fix BATS dist test to create its own distribution")
   - Focus on "why" when it adds value, otherwise just describe "what"
   - List items in roughly decreasing order of impact
   - Keep related items grouped together
   - **In commit messages**: Wrap all code references in backticks - filenames, paths, commands, function names, variables, make targets, etc.
     - **CRITICAL**: Anything with markdown special characters (especially underscores `_`, but also `*`, `#`, etc.) MUST be wrapped in backticks
     - Examples: `helpers.bash`, `make test-recursion`, `setup_sequential_test()`, `TEST_REPO`, `.envs/`, `01-meta.bats`, `make_results.sh`
     - Prevents markdown parsing issues and improves clarity

5. **PRESENT the proposed commit message to the user and WAIT for approval before proceeding**

6. After receiving approval, stage changes appropriately using `git add`

7. **VERIFY staged files with `git status`**:
   - If user did NOT specify a subset: Confirm ALL modified/untracked files are staged
   - If user specified only certain files: Confirm ONLY those files are staged
   - STOP and ask user if staging doesn't match intent

8. After verification, commit using `HEREDOC` format:
```bash
git commit -m "$(cat <<'EOF'
Subject line (imperative mood, < 72 chars)

Additional context if needed, wrapped at 72 characters.

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

9. Run `git status` after commit to verify success

10. If pre-commit hook modifies files: Check authorship (`git log -1 --format='%an %ae'`) and branch status, then amend if safe or create new commit

**REPOSITORY CONTEXT:**

- **pgxntool**: The PostgreSQL extension build framework
- **pgxntool-test**: Test harness for validating pgxntool
- **pgxntool-test-template**: Template extension for testing

Key facts:
- Tests live in `tests/` directory (pgxntool-test)
- `.envs/` contains test environments (gitignored in pgxntool-test)

**RESTRICTIONS:**
- DO NOT push unless explicitly asked
- DO NOT commit files with actual secrets (`.env`, `credentials.json`, etc.)
- Never use `-i` flags (`git commit -i`, `git rebase -i`, etc.)
