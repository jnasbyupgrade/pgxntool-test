#!/usr/bin/env bats

# Test: test/install feature
#
# Tests the complete test/install lifecycle:
# - Auto-detection: enabled when test/install/ has SQL files
# - Schedule generation with ../install/ relative paths
# - Core contract: install state persists into main test suite
# - Disabling via PGXNTOOL_ENABLE_TEST_INSTALL
# - Cleanup via make clean

load ../lib/helpers

setup_file() {
  setup_topdir

  load_test_env "test-install"
  ensure_foundation "$TEST_DIR"
}

setup() {
  load_test_env "test-install"
  cd "$TEST_REPO"
}

@test "template includes install marker files" {
  assert_file_exists "test/install/create_install_marker.sql"
  assert_file_exists "test/sql/verify_install_marker.sql"
  assert_file_exists "test/expected/verify_install_marker.out"
}

@test "test/install is auto-detected as enabled" {
  # With test/install/ files present from the template, schedule should be generated
  run make -n test 2>&1
  assert_success
  echo "$output" | grep -q "schedule"
}

@test "install schedule lists files with ../install/ prefix" {
  run make test/install/schedule
  assert_success
  assert_file_exists "test/install/schedule"

  # Schedule should reference install files with relative path
  run grep "../install/" test/install/schedule
  assert_success
}

@test "install marker state persists into main test suite" {
  skip_if_no_postgres

  # pgxntool-test.source has no matching expected output file, which causes
  # pg_regress to bail out before reaching verify_install_marker. Hide it so
  # REGRESS only contains verify_install_marker (the test we actually care about).
  mv test/input/pgxntool-test.source test/input/pgxntool-test.source.bak

  run make test

  mv test/input/pgxntool-test.source.bak test/input/pgxntool-test.source

  # Verify the specific marker test produced results and passed.
  assert_file_exists test/results/verify_install_marker.out
  run diff test/expected/verify_install_marker.out test/results/verify_install_marker.out
  assert_success
}

@test "test/install can be disabled via PGXNTOOL_ENABLE_TEST_INSTALL" {
  run make -n test PGXNTOOL_ENABLE_TEST_INSTALL=no 2>&1
  assert_success
  ! echo "$output" | grep -q "install/schedule"
}

@test "test/install not enabled when test/install/ is empty" {
  # Remove all SQL files from test/install
  rm -f test/install/*.sql

  run make -n test 2>&1
  assert_success
  # Should NOT reference install schedule
  ! echo "$output" | grep -q "install/schedule"
}

@test "make clean removes install schedule file" {
  # Restore install files and generate schedule
  git checkout -- test/install/
  make test/install/schedule
  assert_file_exists "test/install/schedule"

  run make clean
  assert_success

  assert_file_not_exists "test/install/schedule"
}

# vi: expandtab sw=2 ts=2
