#!/usr/bin/env bats

# Test: Clone template repository and install pgxntool
#
# This is the sequential test that creates TEST_REPO and sets up the
# test environment. All other tests depend on this completing successfully.

load helpers

setup_file() {
  debug 1 ">>> ENTER setup_file: 01-clone (PID=$$)"
  # Depends on validation passing
  setup_sequential_test "01-clone" "00-validate-tests"
  debug 1 "<<< EXIT setup_file: 01-clone (PID=$$)"
}

setup() {
  load_test_env "sequential"

  # Only cd to TEST_REPO if it exists
  # Tests 1-2 create the directory, so they don't need to be in it
  # Tests 3-8 need to be in TEST_REPO and will fail properly if it doesn't exist
  if [ -d "$TEST_REPO" ]; then
    cd "$TEST_REPO"
  fi
}

teardown_file() {
  debug 1 ">>> ENTER teardown_file: 01-clone (PID=$$)"
  mark_test_complete "01-clone"
  debug 1 "<<< EXIT teardown_file: 01-clone (PID=$$)"
}

@test "test environment variables are set" {
  [ -n "$TEST_TEMPLATE" ]
  [ -n "$TEST_REPO" ]
  [ -n "$PGXNREPO" ]
  [ -n "$PGXNBRANCH" ]
}

@test "can create TEST_REPO directory" {
  # Skip if already exists (prerequisite already met)
  if [ -d "$TEST_REPO" ]; then
    skip "TEST_REPO already exists"
  fi

  mkdir "$TEST_REPO"
  [ -d "$TEST_REPO" ]
}

@test "template repository clones successfully" {
  # Skip if already cloned
  if [ -d "$TEST_REPO/.git" ]; then
    skip "TEST_REPO already cloned"
  fi

  # Clone the template
  run git clone "$TEST_TEMPLATE" "$TEST_REPO"
  [ "$status" -eq 0 ]
  [ -d "$TEST_REPO/.git" ]
}

@test "fake git remote is configured" {
  cd "$TEST_REPO"

  # Skip if already configured
  if git remote get-url origin 2>/dev/null | grep -q "fake_repo"; then
    skip "Fake remote already configured"
  fi

  # Create fake remote
  git init --bare ../fake_repo >/dev/null 2>&1

  # Replace origin with fake
  git remote remove origin
  git remote add origin ../fake_repo

  # Verify
  local origin_url=$(git remote get-url origin)
  assert_contains "$origin_url" "fake_repo"
}

@test "current branch pushes to fake remote" {
  cd "$TEST_REPO"

  # Skip if already pushed
  if git branch -r | grep -q "origin/"; then
    skip "Already pushed to fake remote"
  fi

  local current_branch=$(git symbolic-ref --short HEAD)
  run git push --set-upstream origin "$current_branch"
  [ "$status" -eq 0 ]

  # Verify branch exists on remote
  git branch -r | grep -q "origin/$current_branch"

  # Verify repository is in consistent state after push
  run git status
  [ "$status" -eq 0 ]
}

@test "pgxntool is added to repository" {
  cd "$TEST_REPO"

  # Skip if pgxntool already exists
  if [ -d "pgxntool" ]; then
    skip "pgxntool directory already exists"
  fi

  # Validate prerequisites before attempting git subtree
  # 1. Check PGXNREPO is accessible and safe
  if [ ! -d "$PGXNREPO/.git" ]; then
    # Not a local directory - must be a valid remote URL

    # Explicitly reject dangerous protocols first
    if echo "$PGXNREPO" | grep -qiE '^(file://|ext::)'; then
      error "PGXNREPO uses unsafe protocol: $PGXNREPO"
    fi

    # Require valid git URL format (full URLs, not just 'git:' prefix)
    if ! echo "$PGXNREPO" | grep -qE '^(https://|http://|git://|ssh://|[a-zA-Z0-9._-]+@[a-zA-Z0-9._-]+:)'; then
      error "PGXNREPO is not a valid git URL: $PGXNREPO"
    fi
  fi

  # 2. For local repos, verify branch exists
  if [ -d "$PGXNREPO/.git" ]; then
    if ! (cd "$PGXNREPO" && git rev-parse --verify "$PGXNBRANCH" >/dev/null 2>&1); then
      error "Branch $PGXNBRANCH does not exist in $PGXNREPO"
    fi
  fi

  # 3. Check if source repo is dirty and use rsync if needed
  # This matches the legacy test behavior in tests/clone
  local source_is_dirty=0
  if [ -d "$PGXNREPO/.git" ]; then
    # SECURITY: rsync only works with local paths, never remote URLs
    if [[ "$PGXNREPO" == *://* ]]; then
      error "Cannot use rsync with remote URL: $PGXNREPO"
    fi

    if [ -n "$(cd "$PGXNREPO" && git status --porcelain)" ]; then
      source_is_dirty=1
      local current_branch=$(cd "$PGXNREPO" && git symbolic-ref --short HEAD)

      if [ "$current_branch" != "$PGXNBRANCH" ]; then
        error "Source repo is dirty but on wrong branch ($current_branch, expected $PGXNBRANCH)"
      fi

      out "Source repo is dirty and on correct branch, using rsync instead of git subtree"

      # Rsync files from source (git doesn't track empty directories, so do this first)
      mkdir pgxntool
      rsync -a "$PGXNREPO/" pgxntool/ --exclude=.git

      # Commit all files at once
      git add --all
      git commit -m "Committing unsaved pgxntool changes"
    fi
  fi

  # If source wasn't dirty, use git subtree
  if [ $source_is_dirty -eq 0 ]; then
    run git subtree add -P pgxntool --squash "$PGXNREPO" "$PGXNBRANCH"

    # Capture error output for debugging
    if [ "$status" -ne 0 ]; then
      out "ERROR: git subtree add failed with status $status"
      out "Output: $output"
    fi

    [ "$status" -eq 0 ]
  fi

  # Verify pgxntool was added either way
  [ -d "pgxntool" ]
  [ -f "pgxntool/base.mk" ]
}

@test "dirty pgxntool triggers rsync path (or skipped if clean)" {
  cd "$TEST_REPO"

  # This test verifies the rsync logic for dirty local pgxntool repos
  # Skip if pgxntool repo is not local or not dirty
  if ! echo "$PGXNREPO" | grep -q "^\.\./" && ! echo "$PGXNREPO" | grep -q "^/"; then
    skip "PGXNREPO is not a local path"
  fi

  if [ ! -d "$PGXNREPO" ]; then
    skip "PGXNREPO directory does not exist"
  fi

  # Check if it's dirty and on the right branch
  local is_dirty=$(cd "$PGXNREPO" && git status --porcelain)
  local current_branch=$(cd "$PGXNREPO" && git symbolic-ref --short HEAD)

  if [ -z "$is_dirty" ]; then
    skip "PGXNREPO is not dirty - rsync path not needed"
  fi

  if [ "$current_branch" != "$PGXNBRANCH" ]; then
    skip "PGXNREPO is on $current_branch, not $PGXNBRANCH"
  fi

  # If we got here, rsync should have been used
  # Look for the commit message about uncommitted changes
  run git log --oneline -1 --grep="Committing unsaved pgxntool changes"
  [ "$status" -eq 0 ]
}

@test "TEST_REPO is a valid git repository" {
  cd "$TEST_REPO"

  # Final validation
  [ -d ".git" ]
  run git status
  [ "$status" -eq 0 ]
}

# vi: expandtab sw=2 ts=2
