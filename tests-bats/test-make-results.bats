#!/usr/bin/env bats

# Test: make results functionality
#
# Tests that make results correctly updates expected output files:
# - Modifies expected output to create a mismatch
# - Verifies make test fails with the mismatch
# - Runs make results to update expected output
# - Verifies make test now passes

load helpers

setup_file() {
  # Non-sequential test - gets its own isolated environment
  # **CRITICAL**: This test DEPENDS on sequential tests completing first!
  # It copies the completed sequential environment, then tests make results functionality.
  # Prerequisites: needs a fully set up repo with test outputs
  setup_nonsequential_test "test-make-results" "make-results" "01-clone" "02-setup" "03-meta" "04-dist" "05-setup-final"
}

setup() {
  load_test_env "make-results"
  cd "$TEST_REPO"
}

@test "make results establishes baseline expected output" {
  # Skip if expected output already exists and has content
  if [ -f "test/expected/pgxntool-test.out" ] && [ -s "test/expected/pgxntool-test.out" ]; then
    skip "Expected output already established"
  fi

  # Run make results (which depends on make test, so both will run)
  # This establishes the baseline expected output
  run make results
  [ "$status" -eq 0 ]

  # Verify expected output now exists with content
  assert_file_exists "test/expected/pgxntool-test.out"
  [ -s "test/expected/pgxntool-test.out" ]
}

@test "expected output file exists with content" {
  assert_file_exists "test/expected/pgxntool-test.out"
  [ -s "test/expected/pgxntool-test.out" ]
}

@test "expected output can be committed to git" {
  # Check if file is already tracked and clean
  local status_output=$(git status --porcelain test/expected/pgxntool-test.out)

  if [ -z "$status_output" ]; then
    skip "Expected output already committed"
  fi

  # Add and commit the expected output
  git add test/expected/pgxntool-test.out
  run git commit -m "Add baseline expected output"
  [ "$status" -eq 0 ]
}

@test "can modify expected output to create mismatch" {
  # Add a blank line to create a difference
  echo >> test/expected/pgxntool-test.out

  # Verify file was modified (now it should show as modified since it's committed)
  run git status --porcelain test/expected/pgxntool-test.out
  [ -n "$output" ]
  echo "$output" | grep -qE "^.M"
}

@test "make test shows diff with modified expected output" {
  # Run make test (should show diffs due to mismatch)
  # Note: make test doesn't exit non-zero due to .IGNORE: installcheck
  run make test

  # Check that diff output was produced (either in output or test/output directory exists)
  # test/output is created when tests fail
  [ -d "test/output" ] || echo "$output" | grep -q "diff"
}

@test "make results updates expected output" {
  # Run make results to fix the expected output
  run make results
  [ "$status" -eq 0 ]
}

@test "make test succeeds after make results" {
  # Now make test should pass
  run make test
  [ "$status" -eq 0 ]
}

@test "repository is still functional after make results" {
  # Final validation
  assert_file_exists "test/expected/pgxntool-test.out"
  assert_file_exists "Makefile"
}

# vi: expandtab sw=2 ts=2
