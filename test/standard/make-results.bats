#!/usr/bin/env bats

# Test: make results functionality
#
# Tests that make results correctly updates expected output files:
# - Modifies expected output to create a mismatch
# - Verifies make test detects the mismatch
# - Runs make results to update expected output
# - Verifies make test now passes
#
# Not tested here:
# - make results when already up-to-date (idempotent case). Safe to re-run,
#   but the extra make test invocation adds non-trivial time for little value.
# - verify-results behavior (blocking make results when tests fail) is tested
#   separately in test-verify-results.bats.

load ../lib/helpers

setup_file() {
  setup_topdir

  # Independent test - gets its own isolated environment with foundation TEST_REPO
  load_test_env "make-results"
  ensure_foundation "$TEST_DIR"

  # Every test in this file requires PostgreSQL. Skip expensive setup if unavailable.
  if ! check_postgres_available; then
    return 0
  fi

  cd "$TEST_REPO"

  # State modification: Ensure expected output exists.
  # The template should already have it, but guard against it being missing or empty.
  if [ ! -f "test/expected/pgxntool-test.out" ] || [ ! -s "test/expected/pgxntool-test.out" ]; then
    make results
  fi

  # State modification: Ensure expected output is committed to git.
  # Later tests create a mismatch and check git status to verify it,
  # which only works if the baseline is committed.
  local status_output
  status_output=$(git status --porcelain test/expected/pgxntool-test.out)
  if [ -n "$status_output" ]; then
    git add test/expected/pgxntool-test.out
    git commit -m "Add baseline expected output"
  fi
}

setup() {
  skip_if_no_postgres
  load_test_env "make-results"
  cd "$TEST_REPO"
}

@test "can modify expected output to create mismatch" {
  # Add a blank line to create a difference
  echo >> test/expected/pgxntool-test.out

  # Verify file was modified (should show as modified since it's committed)
  run git status --porcelain test/expected/pgxntool-test.out
  [ -n "$output" ]
  echo "$output" | grep -qE "^.M"
}

@test "make test shows diff with modified expected output" {
  # Run make test (should show diffs due to mismatch)
  # Note: make test doesn't exit non-zero due to .IGNORE: installcheck
  run make test

  # Check that diff output was produced (either in output or test/output directory exists)
  # test/output is created when tests fail
  [ -d "test/output" ] || echo "$output" | grep -q "diff"
}

@test "make results updates expected output" {
  # Run make results to fix the expected output.
  # Must disable verify-results: the previous test created a mismatch, which caused
  # make test to generate regression.diffs. verify-results blocks make results when
  # regression.diffs exists, so we bypass it here to test the fix-mismatch workflow.
  run make PGXNTOOL_ENABLE_VERIFY_RESULTS=no results
  assert_success
}

@test "make test succeeds after make results" {
  # Now make test should pass
  run make test
  assert_success
}

# vi: expandtab sw=2 ts=2
