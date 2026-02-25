#!/usr/bin/env bats

# Test: test/install feature
#
# Tests that the test/install feature works correctly:
# - Schedule files are generated when test/install/ has SQL files
# - Install schedule lists files with ../install/ prefix
# - test/install can be disabled via PGXNTOOL_ENABLE_TEST_INSTALL
# - make clean removes generated schedule files

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

@test "test/install not enabled when test/install/ is empty" {
  # Remove all SQL files from test/install
  rm -f test/install/*.sql

  # Schedule files should not be generated
  run make -n installcheck 2>&1
  assert_success
  # Should NOT reference install schedule
  ! echo "$output" | grep -q "install/schedule"
}

@test "schedule files generated when test/install/ has SQL files" {
  # Create a SQL file in test/install with its expected output
  cat > test/install/setup.sql <<'EOF'
SELECT 1;
EOF
  printf 'SELECT 1;\n ?column? \n----------\n        1\n(1 row)\n\n' > test/install/setup.out

  # Dry-run should reference schedule files
  run make -n installcheck 2>&1
  assert_success
  echo "$output" | grep -q "schedule"
}

@test "install schedule lists files with ../install/ prefix" {
  # setup.sql created in previous test
  run make test/install/schedule
  assert_success
  assert_file_exists "test/install/schedule"

  # Schedule should reference install files with relative path
  run grep "../install/setup" test/install/schedule
  assert_success
}

@test "test/install can be disabled via PGXNTOOL_ENABLE_TEST_INSTALL" {
  # When disabled, schedule files should not be generated
  run make -n installcheck PGXNTOOL_ENABLE_TEST_INSTALL=no 2>&1
  assert_success
  # Should NOT reference install schedule
  ! echo "$output" | grep -q "install/schedule"
}

@test "make clean removes install schedule file" {
  # Generate schedule file first
  make test/install/schedule

  assert_file_exists "test/install/schedule"

  # Run make clean
  run make clean
  assert_success

  # Schedule file should be removed
  assert_file_not_exists "test/install/schedule"
}

@test "repository is still functional after test/install tests" {
  # Basic sanity check
  assert_file_exists "Makefile"
  run make --version
  assert_success
}

# vi: expandtab sw=2 ts=2
