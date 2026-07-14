#!/usr/bin/env bats

# Test: verify-results feature
#
# Validates that verify-results correctly blocks make results when tests are
# failing, detects pgtap failures, and can be disabled.
#
# NOTE: pgxntool makes verify-results depend on test (verify-results: test), so
# `make verify-results` re-runs the suite and therefore requires PostgreSQL. The
# pgtap-detection cases below plant files in test/results/ (which survive the
# fresh test run) rather than a regression.diffs (which the fresh run overwrites).

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

@test "verify-results depends on test execution" {
  # pgxntool makes verify-results depend on test (verify-results: test) so that
  # `make results` re-runs the tests and checks the FRESH regression.diffs, even
  # under make -j. Confirm the dependency is wired: a dry-run of verify-results
  # must include the installcheck recipe pulled in via the test target.
  run make -n verify-results 2>&1
  assert_success
  assert_contains "$output" "installcheck"
}

@test "verify-results blocks when a test actually fails" {
  # verify-results depends on test, so `make verify-results` re-runs the suite.
  # A planted regression.diffs would just be overwritten by that fresh run, so
  # force a REAL failure by corrupting an expected file, then confirm
  # verify-results refuses to let make results proceed.
  echo >> test/expected/base.out

  run make verify-results
  assert_failure
  assert_contains "$output" "Tests are failing"
  assert_contains "$output" "Cannot run 'make results'"

  # Restore clean state for the tests that follow.
  run git checkout -- test/expected/base.out
  assert_success
  rm -f test/regression.diffs
}

@test "verify-results can be disabled" {
  # With verify-results disabled, results depends only on test, so its dry-run
  # never mentions the verify-results block message.
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
