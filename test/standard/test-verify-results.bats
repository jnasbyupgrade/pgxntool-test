#!/usr/bin/env bats

# Test: verify-results feature
#
# Validates that verify-results correctly blocks make results when tests are
# failing, detects pgtap failures, and can be disabled.
#
# Separate from make-results.bats because verify-results is pure file-checking
# logic that doesn't require PostgreSQL. Keeping it in its own suite means these
# tests always run, even when PostgreSQL is unavailable (make-results.bats skips
# entirely in that case).

load ../lib/helpers

setup_file() {
  setup_topdir

  load_test_env "verify-results"
  ensure_foundation "$TEST_DIR"
}

setup() {
  load_test_env "verify-results"
  cd "$TEST_REPO"
}

@test "verify-results succeeds with clean template state" {
  run make verify-results
  assert_success
}

@test "verify-results has no dependencies on test execution" {
  run make -n verify-results 2>&1
  assert_success
  assert_not_contains "$output" "installcheck"
}

@test "regression.diffs blocks both verify-results and make results" {
  cat > test/regression.diffs <<'EOF'
*** test/expected/test.out
--- test/results/test.out
***************
*** 1 ****
! expected
--- 1 ----
! actual
EOF

  run make verify-results
  assert_failure
  assert_contains "$output" "Tests are failing"
  assert_contains "$output" "Cannot run 'make results'"

  # make results itself should also be blocked
  run make results
  assert_failure
  assert_contains "$output" "Cannot run 'make results'"

  # State left for next test (regression.diffs still present)
}

@test "verify-results can be disabled" {
  # regression.diffs still present from previous test
  run make -n results PGXNTOOL_ENABLE_VERIFY_RESULTS=no 2>&1
  assert_success
  # Check that verify-results recipe commands are not in the dry-run output.
  # Note: we cannot check for the string "verify-results" directly because the
  # test environment directory path contains "verify-results" and appears in
  # make's "Entering directory" messages.
  assert_not_contains "$output" "Cannot run 'make results'"

  rm -f test/regression.diffs
}

@test "verify-results detects pgtap failures in result files" {
  mkdir -p test/results
  cat > test/results/pgtap_fail.out <<'EOF'
1..2
ok 1 - passing test
not ok 2 - failing test
EOF

  run make verify-results
  assert_failure
  assert_contains "$output" "pgtap failure detected"

  rm -f test/results/pgtap_fail.out
}

@test "verify-results ignores pgtap TODO failures" {
  mkdir -p test/results
  cat > test/results/pgtap_todo.out <<'EOF'
1..1
not ok 1 - known issue # TODO fix later
EOF

  run make verify-results
  assert_success

  rm -f test/results/pgtap_todo.out
}

@test "verify-results detects pgtap plan mismatch" {
  mkdir -p test/results
  cat > test/results/pgtap_plan.out <<'EOF'
1..3
ok 1 - test one
ok 2 - test two
# Looks like you planned 3 tests but ran 2
EOF

  run make verify-results
  assert_failure
  assert_contains "$output" "pgtap plan mismatch"

  rm -f test/results/pgtap_plan.out
}

# vi: expandtab sw=2 ts=2
