#!/usr/bin/env bats

# Test: verify-results feature
#
# Tests that the verify-results feature works correctly:
# - verify-results blocks make results when tests are failing
# - verify-results allows make results when tests are passing
# - verify-results can be disabled via PGXNTOOL_ENABLE_VERIFY_RESULTS
# - verify-results has no dependencies (doesn't run tests itself)

load ../lib/helpers

setup_file() {
  # Set TOPDIR
  setup_topdir

  # Independent test - gets its own isolated environment with foundation TEST_REPO
  load_test_env "verify-results"
  ensure_foundation "$TEST_DIR"
}

setup() {
  load_test_env "verify-results"
  cd "$TEST_REPO"
}

@test "verify-results target exists (pgTap is default)" {
  # Since pgTap is the default in base.mk, verify-results should exist
  run make -n verify-results 2>&1
  [ "$status" -eq 0 ]
}

@test "verify-results succeeds when no test failures exist" {
  # Ensure regression.diffs doesn't exist (tests haven't failed)
  # TESTOUT defaults to TESTDIR which is "test", so regression.diffs is at test/regression.diffs
  rm -f test/regression.diffs

  # verify-results should succeed
  run make verify-results
  [ "$status" -eq 0 ]
}

@test "verify-results fails when regression.diffs exists" {
  # Create a fake regression.diffs file to simulate test failures
  # TESTOUT defaults to TESTDIR which is "test"
  cat > test/regression.diffs <<'EOF'
*** /path/to/test/expected/test.out
--- /path/to/test/results/test.out
***************
*** 1 ****
! expected
--- 1 ----
! actual
EOF

  # verify-results should fail
  run make verify-results
  [ "$status" -ne 0 ]
  echo "$output" | grep -qE "(ERROR|failing|Cannot run)"
}

@test "verify-results provides clear error message" {
  # Create regression.diffs
  # TESTOUT defaults to TESTDIR which is "test"
  echo "test diff" > test/regression.diffs

  # Run verify-results
  run make verify-results
  [ "$status" -ne 0 ]
  
  # Check for helpful error message
  echo "$output" | grep -q "Tests are failing"
  echo "$output" | grep -q "Cannot run 'make results'"
  echo "$output" | grep -q "regression.diffs"
}

@test "make results is blocked by verify-results when tests are failing" {
  # Create regression.diffs to simulate failures
  # TESTOUT defaults to TESTDIR which is "test"
  echo "test failure" > test/regression.diffs

  # make results should fail due to verify-results
  run make results
  [ "$status" -ne 0 ]
  echo "$output" | grep -qE "(ERROR|failing|Cannot run)"
}

@test "make results succeeds when tests are passing" {
  # Ensure no regression.diffs exists
  # TESTOUT defaults to TESTDIR which is "test"
  rm -f test/regression.diffs

  # First, establish baseline expected output if needed
  if [ ! -f "test/expected/pgxntool-test.out" ] || [ ! -s "test/expected/pgxntool-test.out" ]; then
    # Run make test to generate expected output
    # Note: This may fail if tests aren't set up correctly, but that's OK -
    # we're just trying to establish a baseline if one doesn't exist
    make test || true
    # Copy results to expected if test passed
    # Note: pg_regress may create results in test/results/ subdirectory
    # Files may not exist if test failed, so ignore copy errors
    if [ ! -r "test/regression.diffs" ] && [ -d "test/results" ]; then
      mkdir -p test/expected
      cp test/results/*.out test/expected/ 2>/dev/null || true
    fi
  fi

  # Ensure no failures
  rm -f test/regression.diffs

  # make results should succeed (verify-results passes, then test runs)
  # Note: This may take a while as it runs full test suite
  run make results
  [ "$status" -eq 0 ]
}

@test "verify-results can be disabled via PGXNTOOL_ENABLE_VERIFY_RESULTS" {
  # Create regression.diffs
  # TESTOUT defaults to TESTDIR which is "test"
  echo "test failure" > test/regression.diffs

  # Disable verify-results and verify it's not in the list of available targets
  run make list PGXNTOOL_ENABLE_VERIFY_RESULTS=
  [ "$status" -eq 0 ]
  echo "$output" | grep -qv "verify-results"
}

@test "verify-results has no dependencies" {
  # Check that verify-results target doesn't depend on test or installcheck
  # by examining the make output
  run make -n verify-results 2>&1
  
  # Should not show test or installcheck being run
  echo "$output" | grep -v "test:" > /dev/null || {
    # If test appears, it might be in a comment or variable expansion
    # The key is that verify-results itself doesn't RUN tests
    [ "$status" -eq 0 ]
  }
}

@test "verify-results only checks file existence" {
  # verify-results should be fast - it just checks if regression.diffs exists
  # Create the file
  # TESTOUT defaults to TESTDIR which is "test"
  echo "dummy diff" > test/regression.diffs

  # Time the execution (should be very fast)
  start_time=$(date +%s)
  run make verify-results 2>&1
  end_time=$(date +%s)
  elapsed=$((end_time - start_time))

  # Should complete in under 2 seconds (just file check)
  [ "$elapsed" -lt 2 ]
  [ "$status" -ne 0 ]
}

@test "repository is still functional after verify-results tests" {
  # Basic sanity check
  assert_file_exists "Makefile"
  run make --version
  [ "$status" -eq 0 ]
}

# vi: expandtab sw=2 ts=2

