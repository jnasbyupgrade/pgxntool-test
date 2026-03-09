#!/usr/bin/env bats

# Test: verify-results feature
#
# Tests that the verify-results feature works correctly:
# - verify-results succeeds when no test failures exist
# - verify-results blocks make results when tests are failing
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
  rm -f test/regression.diffs

  run make results
  [ "$status" -eq 0 ]
}

@test "verify-results target exists (pgTap is default)" {
  # Since pgTap is the default in base.mk, verify-results should exist
  run make -n verify-results 2>&1
  [ "$status" -eq 0 ]
}

@test "verify-results succeeds when no test failures exist" {
  rm -f test/regression.diffs

  run make verify-results
  [ "$status" -eq 0 ]
}

@test "verify-results fails with clear error when regression.diffs exists" {
  echo "test diff" > test/regression.diffs

  run make verify-results
  [ "$status" -ne 0 ]

  # Check the full expected error messages (stdout only; make's own error goes to stderr)
  echo "$output" | grep -qF "ERROR: Tests are failing. Cannot run 'make results'."
  echo "$output" | grep -qF "Fix test failures first, then run 'make results'."
  echo "$output" | grep -qF "See test/regression.diffs for details:"
  echo "$output" | grep -qF "test diff"
}

@test "make results is blocked by verify-results when tests are failing" {
  # regression.diffs is still present from the previous test
  run make results
  [ "$status" -ne 0 ]
}

@test "verify-results can be disabled via PGXNTOOL_ENABLE_VERIFY_RESULTS" {
  run make list PGXNTOOL_ENABLE_VERIFY_RESULTS=
  [ "$status" -eq 0 ]
  echo "$output" | grep -qv "verify-results"
}

@test "verify-results has no dependencies" {
  # verify-results should not trigger make test or installcheck
  run make -n verify-results 2>&1
  echo "$output" | grep -vqE "^(pg_regress|installcheck|make test)"
  [ "$status" -eq 0 ]
}

@test "verify-results only checks file existence" {
  echo "dummy diff" > test/regression.diffs

  # Should complete very fast — just a file check, no test suite run
  start_time=$(date +%s)
  run make verify-results 2>&1
  end_time=$(date +%s)
  elapsed=$((end_time - start_time))

  [ "$elapsed" -lt 2 ]
  [ "$status" -ne 0 ]
}

@test "repository is still functional after verify-results tests" {
  assert_file_exists "Makefile"
  run make --version
  [ "$status" -eq 0 ]
}

# vi: expandtab sw=2 ts=2
