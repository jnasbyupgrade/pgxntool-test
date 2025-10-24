#!/usr/bin/env bats

# Test: setup.sh functionality
#
# Tests that pgxntool/setup.sh works correctly:
# - Fails when repository is dirty (safety check)
# - Creates necessary files (Makefile, META.json, etc.)
# - Changes can be committed

load helpers

setup_file() {
  debug 1 ">>> ENTER setup_file: 02-setup (PID=$$)"
  setup_sequential_test "02-setup" "01-clone"
  debug 1 "<<< EXIT setup_file: 02-setup (PID=$$)"
}

setup() {
  load_test_env "sequential"
  cd "$TEST_REPO"
}

teardown_file() {
  debug 1 ">>> ENTER teardown_file: 02-setup (PID=$$)"
  mark_test_complete "02-setup"
  debug 1 "<<< EXIT teardown_file: 02-setup (PID=$$)"
}

@test "setup.sh fails on dirty repository" {
  # Skip if Makefile already exists (setup already ran)
  if [ -f "Makefile" ]; then
    skip "setup.sh already completed"
  fi

  # Make repo dirty
  touch garbage
  git add garbage

  # setup.sh should fail
  run pgxntool/setup.sh
  [ "$status" -ne 0 ]

  # Clean up
  git reset HEAD garbage
  rm garbage
}

@test "setup.sh runs successfully on clean repository" {
  # Skip if Makefile already exists
  if [ -f "Makefile" ]; then
    skip "Makefile already exists"
  fi

  # Repository should be clean
  run git status --porcelain
  [ -z "$output" ]

  # Run setup.sh
  run pgxntool/setup.sh
  [ "$status" -eq 0 ]
}

@test "setup.sh creates Makefile" {
  assert_file_exists "Makefile"

  # Should include pgxntool/base.mk
  grep -q "include pgxntool/base.mk" Makefile
}

@test "setup.sh creates .gitignore" {
  # Check if .gitignore exists (either in . or ..)
  [ -f ".gitignore" ] || [ -f "../.gitignore" ]
}

@test "setup.sh creates META.in.json" {
  assert_file_exists "META.in.json"
}

@test "setup.sh creates META.json" {
  assert_file_exists "META.json"
}

@test "setup.sh creates meta.mk" {
  assert_file_exists "meta.mk"
}

@test "setup.sh creates test directory structure" {
  assert_dir_exists "test"
  assert_file_exists "test/deps.sql"
}

@test "setup.sh changes can be committed" {
  # Skip if already committed (check for modified/staged files, not untracked)
  local changes=$(git status --porcelain | grep -v '^??')
  if [ -z "$changes" ]; then
    skip "No changes to commit"
  fi

  # Commit the changes
  run git commit -am "Test setup"
  [ "$status" -eq 0 ]

  # Verify no tracked changes remain (ignore untracked files)
  local remaining=$(git status --porcelain | grep -v '^??')
  [ -z "$remaining" ]
}

@test "repository is in valid state after setup" {
  # Final validation
  assert_file_exists "Makefile"
  assert_file_exists "META.json"
  assert_dir_exists "pgxntool"

  # Should be able to run make
  run make --version
  [ "$status" -eq 0 ]
}

# vi: expandtab sw=2 ts=2
