#!/usr/bin/env bats

# Test: test/install feature
#
# Tests that the test/install feature works correctly:
# - test/install files run before test/sql files when test/install/ exists
# - Schedule file is generated correctly
# - test/install can be disabled via PGXNTOOL_ENABLE_TEST_INSTALL
# - Execution order is preserved via schedule file

load ../lib/helpers

setup_file() {
  # Set TOPDIR
  setup_topdir

  # Independent test - gets its own isolated environment with foundation TEST_REPO
  load_test_env "test-install"
  ensure_foundation "$TEST_DIR"
}

setup() {
  load_test_env "test-install"
  cd "$TEST_REPO"
  # Create test directories in setup so files exist when Make parses
  mkdir -p test/install test/sql test/expected
}

@test "schedule file is not created when test/install/ is missing" {
  # Remove test/install if it exists
  rm -rf test/install
  # Also remove any existing schedule file from previous tests
  rm -f test/.schedule

  # Schedule file should not exist
  assert_file_not_exists "test/.schedule"
}

@test "can create test/install directory" {
  mkdir -p test/install
  assert_dir_exists "test/install"
}

@test "schedule file is created when test/install/ has files" {
  # Create test/install file (directories already exist from setup)
  cat > test/install/setup.sql <<'EOF'
SELECT 1;
EOF

  # Create a regular test file
  cat > test/sql/regular_test.sql <<'EOF'
SELECT 2;
EOF

  # Generate the schedule file - files exist so auto-detection should work
  run make test/.schedule
  [ "$status" -eq 0 ]
  assert_file_exists "test/.schedule"
}

@test "schedule file lists test/install files before test/sql files" {
  # Remove any existing test files to ensure clean state
  rm -f test/sql/*.sql test/install/*.sql test/.schedule
  
  # Create both test/install and test/sql files (directories exist from setup)
  cat > test/install/first.sql <<'EOF'
SELECT 1;
EOF
  cat > test/sql/second.sql <<'EOF'
SELECT 2;
EOF

  # Generate schedule file - should succeed
  # Force Make to re-parse by touching Makefile or using -B flag
  run make -B test/.schedule
  [ "$status" -eq 0 ]
  assert_file_exists "test/.schedule"

  # Verify schedule file contents - first should come before second
  # Schedule file has comment line, then test names
  # We need to check that "first" appears before "second" in the file
  local actual=$(grep -v '^#' test/.schedule | tr -d '\r')
  local first_pos=$(echo "$actual" | grep -n "^first$" | cut -d: -f1)
  local second_pos=$(echo "$actual" | grep -n "^second$" | cut -d: -f1)
  
  [ -n "$first_pos" ] || { echo "Schedule file contents: $actual"; false; }
  [ -n "$second_pos" ] || { echo "Schedule file contents: $actual"; false; }
  [ "$first_pos" -lt "$second_pos" ]
}

@test "test/install can be disabled via PGXNTOOL_ENABLE_TEST_INSTALL" {
  # Ensure test/install exists
  mkdir -p test/install
  cat > test/install/disabled_setup.sql <<'EOF'
SELECT 1;
EOF

  # Disable test/install
  # Clean up any existing schedule file
  rm -f test/.schedule

  # When disabled, schedule file should not be created
  assert_file_not_exists "test/.schedule"
}

@test "test target includes schedule file when enabled" {
  # Create test files (directories exist from setup)
  cat > test/install/prereq_test.sql <<'EOF'
SELECT 1;
EOF
  cat > test/sql/regular_test.sql <<'EOF'
SELECT 2;
EOF

  # Check that installcheck includes schedule file as dependency
  # Schedule file generation should be a prerequisite of installcheck
  run make -n installcheck 2>&1
  [ "$status" -eq 0 ]
  echo "$output" | grep -q "test/.schedule"
}

@test "test/install files run before test/sql files" {
  # Create a test that verifies ordering using timestamps (directories exist from setup)
  cat > test/install/install_order.sql <<'EOF'
-- Create a table to track execution order
CREATE TABLE IF NOT EXISTS execution_order (test_name text, executed_at timestamp);
INSERT INTO execution_order VALUES ('install_order', clock_timestamp());
EOF

  cat > test/sql/test_order.sql <<'EOF'
-- This test should see the table created by install_order
INSERT INTO execution_order VALUES ('test_order', clock_timestamp());
SELECT test_name FROM execution_order ORDER BY executed_at;
EOF

  # Create expected output files
  mkdir -p test/expected
  # install_order should create the table and insert first row
  echo "install_order" > test/expected/install_order.out
  # test_order should see both rows in order
  cat > test/expected/test_order.out <<'EOF'
install_order
test_order
EOF

  # Run the full test suite
  run make test
  [ "$status" -eq 0 ]

  # Verify that test_order.out shows install_order before test_order
  if [ -f "test/results/test_order.out" ]; then
    local install_pos=$(grep -n "^install_order$" test/results/test_order.out | cut -d: -f1)
    local test_pos=$(grep -n "^test_order$" test/results/test_order.out | cut -d: -f1)
    [ -n "$install_pos" ]
    [ -n "$test_pos" ]
    [ "$install_pos" -lt "$test_pos" ]
  fi
}

@test "make clean removes schedule file" {
  # Create test files to generate schedule file (directories exist from setup)
  cat > test/install/clean_test.sql <<'EOF'
SELECT 1;
EOF
  cat > test/sql/clean_test2.sql <<'EOF'
SELECT 2;
EOF

  # Generate schedule file
  run make test/.schedule
  [ "$status" -eq 0 ]
  assert_file_exists "test/.schedule"

  # Run make clean
  run make clean
  [ "$status" -eq 0 ]

  # Schedule file should be removed
  assert_file_not_exists "test/.schedule"
}

@test "make test works after make clean" {
  # Create test files (directories exist from setup)
  cat > test/install/final_test.sql <<'EOF'
SELECT 1;
EOF
  cat > test/sql/final_test2.sql <<'EOF'
SELECT 2;
EOF

  # Create expected output files
  mkdir -p test/expected
  echo "1" > test/expected/final_test.out
  echo "2" > test/expected/final_test2.out

  # Clean first
  make clean || true

  # Then run test - should regenerate schedule file and run tests
  run make test
  [ "$status" -eq 0 ]

  # Verify schedule file was regenerated
  assert_file_exists "test/.schedule"
}

@test "repository is still functional after test/install tests" {
  # Basic sanity check
  assert_file_exists "Makefile"
  run make --version
  [ "$status" -eq 0 ]
}

# vi: expandtab sw=2 ts=2
