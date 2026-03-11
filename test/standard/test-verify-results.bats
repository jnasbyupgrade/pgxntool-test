#!/usr/bin/env bats

# Test: verify-results feature
#
# Tests that the verify-results feature works correctly:
# - verify-results blocks make results when regression.diffs exists
# - verify-results allows make results when no failures exist
# - verify-results detects pgtap failures in result files
# - verify-results can be disabled
#
# This test is independent of whether PostgreSQL is running. It only
# manipulates files that verify-results checks (regression.diffs and
# result .out files).

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

@test "verify-results succeeds when no test failures exist" {
  # Template starts clean - no regression.diffs, no failing results
  run make verify-results
  assert_success
}

@test "verify-results fails when regression.diffs exists" {
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
  [ "$status" -ne 0 ]
  echo "$output" | grep -q "Tests are failing"
  echo "$output" | grep -q "Cannot run 'make results'"

  rm -f test/regression.diffs
}

@test "verify-results blocks make results when tests are failing" {
  echo "test failure" > test/regression.diffs

  run make results
  [ "$status" -ne 0 ]
  echo "$output" | grep -q "Cannot run 'make results'"

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
  [ "$status" -ne 0 ]
  echo "$output" | grep -q "pgtap failure detected"

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
  [ "$status" -ne 0 ]
  echo "$output" | grep -q "pgtap plan mismatch"

  rm -f test/results/pgtap_plan.out
}

@test "verify-results can be disabled" {
  echo "test failure" > test/regression.diffs

  # With verify-results disabled, results target should not block
  # (it will still run 'make test' which may fail, but verify-results won't block)
  run make -n results PGXNTOOL_ENABLE_VERIFY_RESULTS=no 2>&1
  assert_success
  ! echo "$output" | grep -q "verify-results"

  rm -f test/regression.diffs
}

@test "verify-results has no dependencies" {
  # verify-results should be fast - just file checks, no test execution
  run make -n verify-results 2>&1
  assert_success
  # Should not trigger installcheck or test targets
  ! echo "$output" | grep -q "installcheck"
}

# vi: expandtab sw=2 ts=2
