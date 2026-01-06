# Fix: `--gather-test-outputs-in` fails when tests change directory

Fixes #1132

## Problem

When using `--gather-test-outputs-in` with a relative path, if a test changes directory using `cd`, the `cp` command fails with:

```
cp: cannot create regular file 'out/1-test_that_does_cd.log': No such file or directory
```

This happens because relative paths are resolved relative to the current working directory, which changes when tests execute `cd`.

## Solution

Convert relative paths to absolute paths when the `--gather-test-outputs-in` option is processed in the `bats` script, before it's passed to `bats-exec-test`. This ensures the path remains valid regardless of directory changes within tests.

## Changes

### 1. `libexec/bats-core/bats` (lines 273-285)

Added logic to convert relative paths to absolute paths:

```bash
# Convert relative path to absolute to handle tests that change directory
# This ensures the path remains valid even if tests use 'cd'
if [[ ${output_dir:0:1} != / ]]; then
  # Path is relative - convert to absolute using current working directory
  # Handle both directory paths and simple filenames
  if [[ "$output_dir" == */* ]]; then
    # Has directory component
    output_dir="$(cd "$(dirname "$output_dir")" 2>/dev/null && pwd)/$(basename "$output_dir")" 2>/dev/null || output_dir="$PWD/$output_dir"
  else
    # Just a filename/directory name, resolve relative to current directory
    output_dir="$PWD/$output_dir"
  fi
fi
```

### 2. `test/fixtures/bats/cd_in_test.bats` (new file)

Created a test fixture that reproduces the bug:

```bash
#!/usr/bin/env bats

@test "test_that_does_cd" {
  mkdir -p test
  cd test
  echo "yey from test directory"
}
```

### 3. `test/bats.bats` (lines 1157-1175)

Added a test case to verify the fix:

```bash
@test "--gather-test-outputs-in works with tests that change directory" {
  local OUTPUT_DIR="$BATS_TEST_TMPDIR/logs"
  bats_require_minimum_version 1.5.0

  # Test with relative path (the bug case from issue #1132)
  local relative_output_dir="relative-out"
  rm -rf "$relative_output_dir"
  
  reentrant_run -0 bats --gather-test-outputs-in "$relative_output_dir" "$FIXTURE_ROOT/cd_in_test.bats"
  
  # Verify the output file was created despite the test changing directory
  [ -f "$relative_output_dir/1-test_that_does_cd.log" ]
  
  # Verify the content is correct
  OUTPUT=$(<"$relative_output_dir/1-test_that_does_cd.log")
  [ "$OUTPUT" == "yey from test directory" ]
  
  # Cleanup
  rm -rf "$relative_output_dir"
}
```

## Testing

- ✅ Test passes with relative paths when tests change directory
- ✅ Test passes with absolute paths (backward compatible)
- ✅ Existing tests continue to pass
- ✅ Output files are created correctly with correct content

## Backward Compatibility

This fix is fully backward compatible:
- Absolute paths continue to work as before
- Relative paths are now converted to absolute, which is the correct behavior
- No changes to the API or expected behavior

## Related

- GitHub issue #1132: https://github.com/bats-core/bats-core/issues/1132

