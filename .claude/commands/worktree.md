---
description: Create worktrees for both pgxntool repos
---

Create git worktrees for pgxntool and pgxntool-test using the script in bin/create-worktree.sh.

Ask the user for the worktree name if they haven't provided one, then execute:

```bash
bin/create-worktree.sh <worktree-name>
```

The worktrees will be created in ../worktrees/<worktree-name>/ with subdirectories for each repo:
- pgxntool/
- pgxntool-test/

This maintains the directory structure that the test harness expects.
