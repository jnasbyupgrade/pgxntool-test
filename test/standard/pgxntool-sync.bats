#!/usr/bin/env bats

# Test: make pgxntool-sync end-to-end
#
# This test validates the full `make pgxntool-sync` flow:
#   git subtree pull → update-setup-files.sh
#
# Unlike the unit tests in update-setup-files.bats (which test 3-way merge
# scenarios in isolation), this test exercises the complete sync pipeline
# including the Makefile target and git subtree pull mechanics.
#
# A dedicated source repo is needed because git subtree pull requires the
# initial add to have been done via `git subtree add`. During normal test
# runs, pgxntool may be dirty (uncommitted changes), causing
# build_test_repo_from_template to use rsync instead. This test creates
# its own clean source repo to guarantee git subtree add is used.

load ../lib/helpers
load ../lib/assertions

setup_file() {
  # Note: BATS runs with set -eET, so any command failure here (including
  # inside subshells) will abort setup_file and BATS will report the failure.
  setup_topdir

  # Always start fresh - this test creates its own repos from scratch
  clean_env "pgxntool-sync"
  load_test_env "pgxntool-sync"

  # =========================================================================
  # Step 1: Create a clean pgxntool source repo
  # =========================================================================
  local source_repo="$TEST_DIR/pgxntool-source"
  mkdir "$source_repo"
  (
    cd "$source_repo"
    git init
    # Copy current pgxntool files (excluding .git)
    rsync -a --exclude='.git' "$PGXNREPO/" ./
    git add .
    git commit -m "Initial pgxntool"
    git tag v1

    # Modify _.gitignore with a marker line for sync detection
    echo "# pgxntool-sync-test-marker" >> _.gitignore
    git add _.gitignore
    git commit -m "Update gitignore"
    git tag v2
  )

  # =========================================================================
  # Step 2: Create test extension repo using subtree add from source at v1
  # =========================================================================
  mkdir "$TEST_REPO"
  (
    cd "$TEST_REPO"
    git init

    # Copy template files and commit
    rsync -a --exclude='.DS_Store' "$TEST_TEMPLATE"/ ./
    git add .
    git commit -m "Initial extension files"

    # Add pgxntool via git subtree (forces subtree path, not rsync)
    git subtree add -P pgxntool --squash "$source_repo" v1

    # Run setup.sh to generate Makefile, .gitignore, etc.
    ./pgxntool/setup.sh

    # Fix META.in.json placeholders
    sed -i.bak -e 's/DISTRIBUTION_NAME/pgxntool-test/g' -e 's/EXTENSION_NAME/pgxntool-test/g' META.in.json
    rm -f META.in.json.bak

    # Regenerate META.json from updated META.in.json (make auto-rebuilds this
    # as an included file prerequisite, which would dirty the tree during sync)
    ./pgxntool/build_meta.sh META.in.json META.json

    # Ignore generated files so repo stays clean
    echo "*.html" >> .gitignore
    echo "meta.mk" >> .gitignore

    # Commit everything
    git add .
    git commit -m "Add pgxntool setup"
  )

  # Store source repo path in env file for test access
  echo "export SOURCE_REPO=\"$source_repo\"" >> "$TEST_DIR/.env"

  # Wait for filesystem timestamps to settle, then refresh git index cache.
  # git subtree pull internally uses 'git diff-index --quiet HEAD' which can
  # fail due to filesystem timestamp granularity causing stale index entries.
  (cd "$TEST_REPO" && sleep 1 && git update-index --refresh)
}

setup() {
  load_test_env "pgxntool-sync"
  cd "$TEST_REPO"
}

# =============================================================================
# Tests
# =============================================================================

@test "pgxntool subtree was added correctly" {
  assert_file_exists "pgxntool/base.mk"

  # Verify git log shows the subtree merge commit
  run git log --oneline -- pgxntool/
  assert_success
  assert_contains "$output" "pgxntool"
}

@test ".gitignore does not have v2 marker before sync" {
  ! grep -q "pgxntool-sync-test-marker" .gitignore
}

@test "make pgxntool-sync pulls new changes" {
  run make pgxntool-sync-test "pgxntool-sync-test=$SOURCE_REPO v2"
  assert_success
  assert_contains "$output" "Checking setup files for updates"
}

@test ".gitignore was auto-updated after sync" {
  grep -q "pgxntool-sync-test-marker" .gitignore
}

@test "pgxntool files reflect v2 after sync" {
  grep -q "pgxntool-sync-test-marker" pgxntool/_.gitignore
}

@test "sync created a merge commit" {
  run git log --oneline -1
  assert_success
  assert_contains "$output" "Pull pgxntool from"
}

# vi: expandtab sw=2 ts=2
