#!/usr/bin/env bats

# Test: test-build feature
#
# Tests that the test-build feature works correctly. The template includes
# test/build/ with a working SQL file so most tests run against that baseline;
# later tests temporarily modify files as needed.
#
# - test-build auto-detects when test/build/ has SQL files
# - test-build runs successfully with the template SQL
# - test-build fails and reports errors when SQL has errors
# - test-build can be disabled via PGXNTOOL_ENABLE_TEST_BUILD
# - test-build runs before regular tests when enabled
# - test-build target is absent when test/build/ is removed
# - PGXNTOOL_ENABLE_TEST_BUILD=yes errors when test/build/ is empty or missing

load ../lib/helpers

setup_file() {
  # Set TOPDIR
  setup_topdir

  # Independent test - gets its own isolated environment with foundation TEST_REPO
  load_test_env "test-build"
  ensure_foundation "$TEST_DIR"
}

setup() {
  load_test_env "test-build"
  cd "$TEST_REPO"
}

@test "test-build target exists when test/build/ has SQL files" {
  # Template includes test/build/simple_build_test.sql
  run make -n test-build 2>&1
  [ "$status" -eq 0 ]
}

@test "test-build runs successfully with template SQL" {
  skip_if_no_postgres
  run make test-build
  [ "$status" -eq 0 ]
}

@test "test-build fails with invalid SQL" {
  skip_if_no_postgres
  # Temporarily add an invalid SQL file
  cat > test/build/invalid_test.sql <<'EOF'
-- This SQL has a syntax error
SELECT FROM nonexistent_table WHERE;
EOF

  run make test-build
  local status_code=$status
  # Remove the invalid file so subsequent tests start clean
  rm -f test/build/invalid_test.sql test/build/expected/invalid_test.out

  [ "$status_code" -ne 0 ]
}

@test "test-build can be disabled via PGXNTOOL_ENABLE_TEST_BUILD" {
  # Empty string on command line also disables (same as =no); see docs for why
  run make list PGXNTOOL_ENABLE_TEST_BUILD=
  assert_success
  assert_not_contains "$output" "test-build"
}

@test "test-build can be disabled via PGXNTOOL_ENABLE_TEST_BUILD=no" {
  run make list PGXNTOOL_ENABLE_TEST_BUILD=no
  assert_success
  assert_not_contains "$output" "test-build"
}

@test "test target includes test-build when enabled" {
  run make -n test 2>&1
  assert_success
  assert_contains "$output" "test-build"
}

@test "test-build target does not exist when test/build/ is removed" {
  rm -rf test/build

  run make list
  assert_success
  assert_not_contains "$output" "test-build"
}

@test "PGXNTOOL_ENABLE_TEST_BUILD=yes errors when test/build/ is missing" {
  # test/build/ was removed in the previous test
  # Setting =yes explicitly should cause an error when no files are found
  run make test-build PGXNTOOL_ENABLE_TEST_BUILD=yes
  assert_failure
}

# vi: expandtab sw=2 ts=2
