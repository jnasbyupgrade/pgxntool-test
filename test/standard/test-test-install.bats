#!/usr/bin/env bats

# Test: test/install feature
#
# Tests that the test/install feature works correctly. The template includes
# test/install/create_install_marker.sql so most tests run against that baseline.
#
# - test/install is auto-detected when test/install/ has SQL files
# - Schedule files reference install files with ../install/ prefix
# - test/install can be disabled via PGXNTOOL_ENABLE_TEST_INSTALL
# - make clean removes generated schedule files
# - test/install is not enabled when test/install/ is empty
# - test/install can be disabled even when test/install/ has SQL files

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
}

@test "test/install is auto-detected when test/install/ has SQL files" {
  # Template includes test/install/create_install_marker.sql
  run make -n test 2>&1
  assert_success
  echo "$output" | grep -q "schedule"
}

@test "install schedule lists files with ../install/ prefix" {
  run make test/install/schedule
  assert_success
  assert_file_exists "test/install/schedule"

  # Schedule should reference install files with relative path
  run grep "../install/create_install_marker" test/install/schedule
  assert_success
}

@test "test/install can be disabled even when directory has SQL files" {
  # Even with files present, disabled means no schedule in the plan
  run make -n test PGXNTOOL_ENABLE_TEST_INSTALL=no 2>&1
  assert_success
  assert_not_contains "$output" "install/schedule"
}

@test "make clean removes install schedule file" {
  # Generate schedule file first
  make test/install/schedule

  assert_file_exists "test/install/schedule"

  run make clean
  assert_success

  assert_file_not_exists "test/install/schedule"
}

@test "test/install not enabled when test/install/ is empty" {
  # Temporarily remove all SQL files from test/install
  rm -f test/install/*.sql

  run make -n test 2>&1
  local status_code=$status

  # Restore committed template files
  git checkout -- test/install/

  assert_success  # make -n should succeed
  # Should NOT reference install schedule
  ! echo "$output" | grep -q "install/schedule"
}

@test "repository is still functional after test/install tests" {
  assert_file_exists "Makefile"
  run make --version
  assert_success
}

# vi: expandtab sw=2 ts=2
