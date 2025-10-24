#!/usr/bin/env bats

# Test distribution packaging
#
# This validates that 'make dist' creates a properly structured distribution
# archive with correct file inclusion/exclusion rules.

load helpers

setup_file() {
  debug 1 ">>> ENTER setup_file: 04-dist (PID=$$)"
  setup_sequential_test "04-dist" "03-meta"

  export DISTRIBUTION_NAME=distribution_test
  export DIST_FILE="$TEST_REPO/../${DISTRIBUTION_NAME}-0.1.0.zip"
  debug 1 "<<< EXIT setup_file: 04-dist (PID=$$)"
}

setup() {
  load_test_env "sequential"
  cd "$TEST_REPO"
}

teardown_file() {
  debug 1 ">>> ENTER teardown_file: 04-dist (PID=$$)"
  mark_test_complete "04-dist"
  debug 1 "<<< EXIT teardown_file: 04-dist (PID=$$)"
}

@test "make dist creates distribution archive" {
  # Run make dist to create the distribution
  make dist
  [ -f "$DIST_FILE" ]
}

@test "distribution contains documentation files" {
  # Extract list of files from zip (created by legacy test)
  local files=$(unzip -l "$DIST_FILE" | awk '{print $4}')

  # Should contain at least one doc file
  echo "$files" | grep -E '\.(asc|adoc|asciidoc|html|md|txt)$'
}

@test "distribution excludes pgxntool documentation" {
  local files=$(unzip -l "$DIST_FILE" | awk '{print $4}')

  # Should NOT contain any pgxntool docs
  # Use ! with run to assert command should fail (no matches found)
  run bash -c "echo '$files' | grep -E 'pgxntool/.*\.(asc|adoc|asciidoc|html|md|txt)$'"
  [ "$status" -eq 1 ]
}

@test "distribution includes expected extension files" {
  local files=$(unzip -l "$DIST_FILE" | awk '{print $4}')

  # Check for key files
  echo "$files" | grep -q "\.control$"
  echo "$files" | grep -q "\.sql$"
}

@test "distribution includes test documentation" {
  local files=$(unzip -l "$DIST_FILE" | awk '{print $4}')

  # Should have test docs
  echo "$files" | grep -q "t/TEST_DOC\.asc"
  echo "$files" | grep -q "t/doc/asc_doc\.asc"
  echo "$files" | grep -q "t/doc/asciidoc_doc\.asciidoc"
}

# vi: expandtab sw=2 ts=2
