#!/usr/bin/env bats

# Test: test-build feature
#
# The template includes a working test/build/ directory (build_check.sql with
# matching expected output). Tests validate the working state first, then
# modify for edge cases.

load ../lib/helpers

setup_file() {
  setup_topdir

  load_test_env "test-build"
  ensure_foundation "$TEST_DIR"
}

setup() {
  load_test_env "test-build"
  cd "$TEST_REPO"
}

@test "template includes test/build files" {
  assert_file_exists "test/build/build_check.sql"
  assert_file_exists "test/build/expected/build_check.out"
}

@test "test-build is auto-detected as enabled" {
  run make -n test 2>&1
  assert_success
  echo "$output" | grep -q "test-build"
}

@test "test-build runs successfully with template files" {
  skip_if_no_postgres

  run make test-build
  assert_success
}

@test "test-build fails with invalid SQL" {
  skip_if_no_postgres

  # Add an invalid SQL file alongside the valid template one
  cat > test/build/invalid_test.sql <<'EOF'
SELECT FROM nonexistent_table WHERE;
EOF
  mkdir -p test/build/expected
  # Create expected output that would match if there were no error
  echo > test/build/expected/invalid_test.out

  # Clean generated sql/ so updated files get copied
  rm -rf test/build/sql

  run make test-build
  [ "$status" -ne 0 ]

  # Clean up
  rm -f test/build/invalid_test.sql test/build/expected/invalid_test.out
  rm -rf test/build/sql
}

@test "PGXNTOOL_ENABLE_TEST_BUILD=yes errors when test/build/ is missing" {
  # Remove test/build directory entirely
  rm -rf test/build

  # Explicitly enabling should error when directory has no files
  run make test-build PGXNTOOL_ENABLE_TEST_BUILD=yes 2>&1
  [ "$status" -ne 0 ]

  # Restore from git
  git checkout -- test/build/
}

@test "test-build can be disabled via PGXNTOOL_ENABLE_TEST_BUILD=no" {
  run make -n test PGXNTOOL_ENABLE_TEST_BUILD=no 2>&1
  assert_success
  ! echo "$output" | grep -q "test-build"
}

@test "test-build target absent when test/build/ is removed" {
  rm -rf test/build

  run make -n test 2>&1
  assert_success
  ! echo "$output" | grep -q "test-build"

  # Restore
  git checkout -- test/build/
}

# vi: expandtab sw=2 ts=2
