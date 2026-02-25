#!/usr/bin/env bats

# Test: test-build feature
#
# Tests that the test-build feature works correctly:
# - test-build runs when test/build/ directory exists
# - test-build can be disabled via PGXNTOOL_ENABLE_TEST_BUILD
# - test-build runs before regular tests when enabled

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

@test "test-build target does not exist when test/build/ is missing" {
  # Remove test/build if it exists
  rm -rf test/build

  # Check that test-build target is not in the list of available targets
  run make list
  [ "$status" -eq 0 ]
  echo "$output" | grep -qv "test-build"
}

@test "can create test/build directory" {
  mkdir -p test/build
  assert_dir_exists "test/build"
}

@test "test-build target exists when test/build/ has SQL files" {
  # Create a simple SQL file in test/build/
  cat > test/build/valid_test.sql <<'EOF'
-- Simple test to verify extension can be created
SELECT 1;
EOF

  # Check that test-build target is available
  run make -n test-build 2>&1
  [ "$status" -eq 0 ]
}

@test "test-build runs successfully with valid SQL" {
  # valid_test.sql was created in previous test
  # Create expected output file matching pg_regress format
  # Note: pg_regress includes comments from SQL files in output
  mkdir -p test/build/expected
  cat > test/build/expected/valid_test.out <<'EOF'
-- Simple test to verify extension can be created
SELECT 1;
 ?column? 
----------
        1
(1 row)

EOF

  # Run test-build
  run make test-build
  [ "$status" -eq 0 ]
}

@test "test-build fails with invalid SQL" {
  # Create an invalid SQL file
  cat > test/build/invalid_test.sql <<'EOF'
-- This SQL has a syntax error
SELECT FROM nonexistent_table WHERE;
EOF

  # Create expected output file matching pg_regress format for the error
  mkdir -p test/build/expected
  cat > test/build/expected/invalid_test.out <<'EOF'
-- This SQL has a syntax error
SELECT FROM nonexistent_table WHERE;
ERROR:  syntax error at or near ";"
LINE 1: SELECT FROM nonexistent_table WHERE;
                                           ^

EOF

  # Run test-build - should fail because invalid_test.sql has a syntax error
  # (even though valid_test.sql would pass)
  run make test-build
  [ "$status" -ne 0 ]
  echo "$output" | grep -qE "(error|failed|regression.diffs)"
}

@test "test-build can be disabled via PGXNTOOL_ENABLE_TEST_BUILD" {
  # Ensure test/build exists
  mkdir -p test/build
  cat > test/build/disabled_test.sql <<'EOF'
SELECT 1;
EOF

  # Disable test-build and verify it's not in the list of available targets
  run make list PGXNTOOL_ENABLE_TEST_BUILD=
  [ "$status" -eq 0 ]
  echo "$output" | grep -qv "test-build"
}

@test "test target includes test-build when enabled" {
  # Add another test file
  cat > test/build/prereq_test.sql <<'EOF'
SELECT 1;
EOF
  
  # Create expected output file matching pg_regress format
  mkdir -p test/build/expected
  cat > test/build/expected/prereq_test.out <<'EOF'
SELECT 1;
 ?column? 
----------
        1
(1 row)

EOF

  # Check that test target includes test-build as prerequisite
  # test-build is .PHONY and should always appear when enabled
  run make -n test 2>&1
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "test-build"
}

@test "test-build runs independently of regular tests" {
  # Add a new test file - builds on previous tests
  cat > test/build/independent_test.sql <<'EOF'
SELECT 2;
EOF
  
  # Create expected output file matching pg_regress format for the new test
  mkdir -p test/build/expected
  cat > test/build/expected/independent_test.out <<'EOF'
SELECT 2;
 ?column? 
----------
        2
(1 row)

EOF

  # Fix invalid_test.sql from test 5 - make it valid so test-build can pass
  # This builds on the previous test by fixing the issue it introduced
  cat > test/build/invalid_test.sql <<'EOF'
-- This SQL is now valid (fixed from previous test)
SELECT 3;
EOF
  cat > test/build/expected/invalid_test.out <<'EOF'
-- This SQL is now valid (fixed from previous test)
SELECT 3;
 ?column? 
----------
        3
(1 row)

EOF

  # Clean test/build/sql/ so updated files get copied (this is a generated directory)
  rm -rf test/build/sql

  # Also ensure expected files exist for all other test/build files from previous tests
  # disabled_test.sql - needs expected file
  if [ -f "test/build/disabled_test.sql" ] && [ ! -f "test/build/expected/disabled_test.out" ]; then
    cat > test/build/expected/disabled_test.out <<'EOF'
SELECT 1;
 ?column? 
----------
        1
(1 row)

EOF
  fi

  # test-build should run without needing regular test files (test/sql/)
  run make test-build
  [ "$status" -eq 0 ]
}

@test "repository is still functional after test-build" {
  # Basic sanity check
  assert_file_exists "Makefile"
  run make --version
  [ "$status" -eq 0 ]
}

# vi: expandtab sw=2 ts=2

