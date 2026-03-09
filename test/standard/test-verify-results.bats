#!/usr/bin/env bats

# Test: verify-results feature
#
# Tests that the verify-results feature works correctly:
# - verify-results succeeds when no test failures exist
# - verify-results fails and blocks make results when tests are failing
# - verify-results can be disabled via PGXNTOOL_ENABLE_VERIFY_RESULTS
# - verify-results has no dependencies (doesn't run tests itself)

load ../lib/helpers

setup_file() {
  # Set TOPDIR
  setup_topdir

  # Independent test - gets its own isolated environment with foundation TEST_REPO
  load_test_env "verify-results"
  ensure_foundation "$TEST_DIR"
}

setup() {
  load_test_env "verify-results"
  cd "$TEST_REPO"
}

@test "make results succeeds when tests are passing" {
  skip_if_no_postgres
  # Template is in clean state, no regression.diffs should exist
  run make results
  assert_success
}

@test "verify-results target exists (pgTap is default)" {
  run make -n verify-results 2>&1
  assert_success
}

@test "verify-results succeeds when no test failures exist" {
  # Template is in clean state, no regression.diffs
  run make verify-results
  assert_success
}

@test "verify-results fails and blocks make results when tests are failing" {
  # COMBINED: test both verify-results failure AND make results being blocked
  echo "test diff" > test/regression.diffs

  run make verify-results
  assert_failure

  # Check the expected error messages using assert_contains
  assert_contains "$output" "ERROR: Tests are failing. Cannot run 'make results'."
  assert_contains "$output" "Fix test failures first, then run 'make results'."
  assert_contains "$output" "See test/regression.diffs for details:"
  assert_contains "$output" "test diff"

  # make results should also be blocked (regression.diffs still present from above)
  run make results
  assert_failure
}

@test "verify-results can be disabled via PGXNTOOL_ENABLE_VERIFY_RESULTS" {
  run make list PGXNTOOL_ENABLE_VERIFY_RESULTS=
  assert_success
  assert_not_contains "$output" "verify-results"
}

@test "verify-results has no dependencies" {
  # verify-results should not trigger make test or installcheck
  run make -n verify-results 2>&1
  assert_success
  # Should not print pg_regress or installcheck commands
  assert_not_contains "$output" "pg_regress"
  assert_not_contains "$output" "installcheck"
}

@test "verify-results only checks file existence, not test results" {
  # regression.diffs still present from "fails and blocks" test above — no need to recreate
  start_time=$(date +%s)
  run make verify-results 2>&1
  end_time=$(date +%s)
  elapsed=$((end_time - start_time))

  [ "$elapsed" -lt 2 ]
  assert_failure
}

@test "repository is still functional after verify-results tests" {
  assert_file_exists "Makefile"
  run make --version
  assert_success
}

# vi: expandtab sw=2 ts=2
