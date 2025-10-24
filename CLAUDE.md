# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Git Commit Guidelines

**IMPORTANT**: When creating commit messages, do not attribute commits to yourself (Claude). Commit messages should reflect the work being done without AI attribution in the message body. The standard Co-Authored-By trailer is acceptable.

## Expected Output Files

**CRITICAL**: NEVER modify files in `expected/` or run `make sync-expected` yourself. These files define what the tests expect to see, and changing them requires human review and approval.

When tests fail and you believe the new output in `results/` is correct:
1. Explain what changed and why the new output is correct
2. Tell the user to run `make sync-expected` themselves
3. Wait for explicit approval before proceeding

## What This Repo Is

**pgxntool-test** is the test harness for validating **../pgxntool/** (a PostgreSQL extension build framework).

This repo tests pgxntool by:
1. Cloning **../pgxntool-test-template/** (a minimal "dummy" extension with pgxntool embedded)
2. Running pgxntool operations (setup, build, test, dist, etc.)
3. Comparing outputs against expected results
4. Reporting differences

## The Three-Repository Pattern

- **../pgxntool/** - The framework being tested (embedded into extension projects via git subtree)
- **../pgxntool-test-template/** - A minimal PostgreSQL extension that serves as test subject
- **pgxntool-test/** (this repo) - The test harness that validates pgxntool's behavior

**Key insight**: pgxntool cannot be tested in isolation because it's designed to be embedded in other projects. So we clone a template project, inject pgxntool, and test the combination.

## How Tests Work

### Two Test Systems

**Legacy Tests** (tests/*): String-based output comparison
- Captures all output and compares to expected/*.out
- Fragile: breaks on cosmetic changes
- See "Legacy Test System" section below

**BATS Tests** (tests-bats/*.bats): Semantic assertions
- Tests specific behaviors, not output format
- Easier to understand and maintain
- **Preferred for new tests**
- See "BATS Test System" section below for overview

**For detailed BATS development guidance, see @tests-bats/CLAUDE.md**

### Legacy Test Execution Flow

1. **make test** (or **make cont** to continue interrupted tests)
2. For each test in `tests/*`:
   - Sources `.env` (created by `make-temp.sh`)
   - Runs test script (bash)
   - Captures output to `results/*.out`
   - Compares to `expected/*.out`
   - Writes differences to `diffs/*.diff`
3. Reports success or shows failed test names

### BATS Test Execution Flow

1. **make test-bats** (or individual test like **make test-bats-clone**)
2. Each .bats file:
   - Checks if prerequisites are met (e.g., TEST_REPO exists)
   - Auto-runs prerequisite tests if needed (smart dependencies)
   - Runs semantic assertions (not string comparisons)
   - Reports pass/fail per assertion
3. All tests share same temp environment for speed

### Test Environment Setup

**make-temp.sh**:
- Creates temporary directory for test workspace
- Sets `TEST_DIR`, `TOPDIR`, `RESULT_DIR`
- Writes environment to `.env`

**lib.sh** (sourced by all tests):
- Configures `PGXNREPO` (defaults to `../pgxntool`)
- Configures `PGXNBRANCH` (defaults to `master`)
- Configures `TEST_TEMPLATE` (defaults to `../pgxntool-test-template`)
- Handles output redirection to log files
- Provides utilities: `out()`, `debug()`, `die()`, `check_log()`
- Special handling: if pgxntool repo is dirty and on correct branch, uses `rsync` instead of git subtree

### Test Sequence

Tests run in dependency order (see `Makefile`):
1. **test-clone** - Clone template repo into temp directory, set up fake remote, add pgxntool via git subtree
2. **test-setup** - Run `pgxntool/setup.sh`, verify it errors on dirty repo, commit results
3. **test-meta** - Verify META.json generation
4. **test-dist** - Test distribution packaging
5. **test-setup-final** - Final setup validation
6. **test-make-test** - Run `make test` in the cloned extension
7. **test-doc** - Verify documentation generation
8. **test-make-results** - Test `make results` (updating expected outputs)

## Common Commands

### Legacy Tests
```bash
make test              # Clean temp environment and run all legacy tests (no need for 'make clean' first)
make cont              # Continue running tests (skip cleanup)
make sync-expected     # Copy results/*.out to expected/ (after verifying correctness!)
make clean             # Remove temporary directories and results
make print-VARNAME     # Debug: print value of any make variable
make list              # List all make targets
```

### BATS Tests
```bash
make test-bats         # Run dist.bats test (current default)
make test-bats-clone   # Run clone test (foundation)
make test-bats-setup   # Run setup test
make test-bats-meta    # Run meta test
# Individual tests auto-run prerequisites if needed

# Run multiple tests in sequence
test/bats/bin/bats tests-bats/clone.bats
test/bats/bin/bats tests-bats/setup.bats
test/bats/bin/bats tests-bats/meta.bats
test/bats/bin/bats tests-bats/dist.bats
```

**Note:** `make test` automatically runs `clean-temp` as a prerequisite, so there's no need to run `make clean` before testing.

## Test Development Workflow

When fixing a test or updating pgxntool:

1. **Make changes** in `../pgxntool/`
2. **Run tests**: `make test` (or `make cont` to skip cleanup)
3. **Examine failures**:
   - Check `diffs/*.diff` for differences
   - Review `results/*.out` for actual output
   - Compare with `expected/*.out` for expected output
4. **Debug**:
   - Set `LOG` environment variable to see verbose output
   - Tests redirect to log files (see lib.sh redirect mechanism)
   - Use `verboseout=1` for live output during test runs
5. **Update expectations** (only if changes are correct!): `make sync-expected`
6. **Commit** once tests pass

## File Structure

```
pgxntool-test/
├── Makefile                  # Test orchestration
├── make-temp.sh              # Creates temp test environment
├── clean-temp.sh             # Cleans up temp environment
├── lib.sh                    # Common utilities for all tests
├── util.sh                   # Additional utilities
├── base_result.sed           # Sed script for normalizing outputs
├── README.md                 # Requirements and usage
├── BATS-MIGRATION-PLAN.md    # Plan for migrating to BATS
├── tests/                    # Legacy string-based tests
│   ├── clone                 # Test: Clone template and add pgxntool
│   ├── setup                 # Test: Run setup.sh
│   ├── meta                  # Test: META.json generation
│   ├── dist                  # Test: Distribution packaging
│   ├── make-test             # Test: Run make test
│   ├── make-results          # Test: Run make results
│   └── doc                   # Test: Documentation generation
├── tests-bats/               # BATS semantic tests (preferred)
│   ├── helpers.bash          # Shared BATS utilities
│   ├── clone.bats            # ✅ Foundation test (8 tests)
│   ├── setup.bats            # ✅ Setup validation (10 tests)
│   ├── meta.bats             # ✅ META.json generation (6 tests)
│   ├── dist.bats             # ✅ Distribution packaging (5 tests)
│   ├── setup-final.bats      # TODO: Setup idempotence
│   ├── make-test.bats        # TODO: make test validation
│   ├── make-results.bats     # TODO: make results validation
│   └── doc.bats              # TODO: Documentation generation
├── test/bats/                # BATS framework (git submodule)
├── expected/                 # Expected test outputs (legacy only)
├── results/                  # Actual test outputs (generated, legacy only)
└── diffs/                    # Differences (generated, legacy only)
```

## BATS Test System

### Architecture

**Smart Prerequisites:**
Each .bats file checks if required state exists and auto-runs prerequisite tests if needed:
- `clone.bats` checks if .env exists → creates it if needed
- `setup.bats` checks if TEST_REPO/pgxntool exists → runs clone.bats if needed
- `meta.bats` checks if Makefile exists → runs setup.bats if needed
- `dist.bats` checks if META.json exists → runs meta.bats if needed

**Benefits:**
- Run full suite: Fast - prerequisites already met, skips them
- Run individual test: Safe - auto-runs prerequisites
- No duplicate work in either case

**Example from setup.bats:**
```bash
setup_file() {
  load_test_env || return 1

  # Ensure clone test has completed
  if [ ! -d "$TEST_REPO/pgxntool" ]; then
    echo "Prerequisites missing, running clone.bats..."
    "$BATS_TEST_DIRNAME/../test/bats/bin/bats" "$BATS_TEST_DIRNAME/clone.bats"
  fi
}
```

### Writing New BATS Tests

1. Load helpers: `load helpers`
2. Check/run prerequisites in `setup_file()`
3. Write semantic assertions (not string comparisons)
4. Use `skip` for conditional tests
5. Test standalone and as part of chain

**Example test:**
```bash
@test "setup.sh creates Makefile" {
  assert_file_exists "Makefile"
  grep -q "include pgxntool/base.mk" Makefile
}
```

### BATS vs Legacy Tests

**Use BATS when:**
- Testing specific behavior (file exists, command succeeds)
- Want readable, maintainable tests
- Writing new tests

**Use Legacy when:**
- Comparing complete output logs
- Already have expected output files
- Testing output format itself

## Key Implementation Details (Legacy Tests)

### Dynamic Test Discovery
- `TESTS` auto-discovered from `tests/*` directory
- Can override: `make test TESTS="clone setup meta"`
- Test targets: `test-%` depends on `diffs/%.diff`

### Output Normalization (result.sed)
- Strips temporary paths (`$TEST_DIR` → `@TEST_DIR@`)
- Normalizes git remotes/branches
- Removes PostgreSQL installation paths
- Handles version-specific differences (e.g., Postgres < 9.2)

### Smart pgxntool Injection
The `tests/clone` script has special logic:
- If `$PGXNREPO` is local and dirty (uncommitted changes)
- AND on the expected branch
- Then use `rsync` to copy files instead of `git subtree`
- This allows testing uncommitted pgxntool changes

### Environment Variables

From `.env` (created by make-temp.sh):
- `TOPDIR` - pgxntool-test repo root
- `TEST_DIR` - Temporary workspace
- `RESULT_DIR` - Where test outputs are written

From `lib.sh`:
- `PGXNREPO` - Location of pgxntool (default: `../pgxntool`)
- `PGXNBRANCH` - Branch to use (default: `master`)
- `TEST_TEMPLATE` - Template repo (default: `../pgxntool-test-template`)
- `TEST_REPO` - Cloned test project location (`$TEST_DIR/repo`)

## Debugging Tests

### Verbose Output
```bash
# Live output while tests run
verboseout=1 make test

# Keep temp directory for inspection
make test
# (temp dir path shown in output, inspect before next run)
```

### Single Test Execution
```bash
# Run just one test
make test-setup

# Or manually:
./make-temp.sh > .env
. .env
. lib.sh
./tests/setup
```

### Log File Inspection
Tests use file descriptors 8 & 9 to preserve original stdout/stderr while redirecting to log files. See `lib.sh` `redirect()` and `reset_redirect()` functions.

## Test Gotchas

1. **Temp Directory Cleanup**: `make test` always cleans temp; use `make cont` to preserve
2. **Git Chattiness**: Tests redirect git output to avoid cluttering logs (uses `2>&9` redirects)
3. **Postgres Version Differences**: `base_result.sed` handles version-specific output variations
4. **Path Sensitivity**: All paths in expected outputs use placeholders like `@TEST_DIR@`
5. **Fake Remote**: Tests create a fake git remote to prevent accidental pushes to real repos

## Related Repositories

- **../pgxntool/** - The framework being tested
- **../pgxntool-test-template/** - The minimal extension used as test subject
- You should never have to run rm -rf .envs; the test system should always know how to handle .envs