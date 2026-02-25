#!/usr/bin/env bats

# Test: test/install persistence - end-to-end validation
#
# This test verifies the CORE CONTRACT of test/install: that state created by
# test/install files persists into the main test suite.
#
# The template includes:
#   test/install/create_install_marker.sql - Creates a table with a marker row
#   test/sql/verify_install_marker.sql     - Queries that table
#
# If test/install and regular tests run in the same pg_regress invocation
# (correct), the marker test passes. If they run in separate invocations
# (broken), the database gets dropped and recreated between them, and the
# marker test fails.

load ../lib/helpers

setup_file() {
  setup_topdir
  load_test_env "install-persistence"
  ensure_foundation "$TEST_DIR"
}

setup() {
  load_test_env "install-persistence"
  cd "$TEST_REPO"
}

@test "template includes install marker files" {
  assert_file_exists "test/install/create_install_marker.sql"
  assert_file_exists "test/sql/verify_install_marker.sql"
  assert_file_exists "test/expected/verify_install_marker.out"
}

@test "test/install is auto-detected as enabled" {
  # With test/install/ files present, schedule files should be generated
  run make -n test 2>&1
  assert_success
  echo "$output" | grep -q "schedule"
}

@test "install marker state persists into main test suite" {
  skip_if_no_postgres

  # pgxntool-test.sql is generated from a .source file and has no expected
  # output file. pg_regress aborts if the expected file is missing, so create
  # an empty one. (This is a pre-existing gap in the touch rule for .source tests.)
  touch test/expected/pgxntool-test.out

  run make test

  # Verify the specific marker test produced results and passed.
  # (pgxntool-test.sql is a template placeholder that always fails, so we
  # can't just check for regression.diffs — we check the specific test.)
  assert_file_exists test/results/verify_install_marker.out
  run diff test/expected/verify_install_marker.out test/results/verify_install_marker.out
  assert_success
}

# vi: expandtab sw=2 ts=2
