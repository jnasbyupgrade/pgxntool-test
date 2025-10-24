# pgxntool-test

Test harness for [pgxntool](https://github.com/decibel/pgxntool), a PostgreSQL extension build framework.

## Requirements

- PostgreSQL with development headers
- [BATS (Bash Automated Testing System)](https://github.com/bats-core/bats-core)
- rsync
- asciidoctor (for documentation tests)

### Installing BATS

```bash
# macOS
brew install bats-core

# Linux (via git)
git clone https://github.com/bats-core/bats-core.git
cd bats-core
sudo ./install.sh /usr/local
```

## Running Tests

```bash
# Run BATS tests (recommended - fast, clear output)
make test-bats

# Run legacy tests (output comparison based)
make test-legacy
# Alias: make test

# Run individual BATS test files
test/bats/bin/bats tests-bats/clone.bats
test/bats/bin/bats tests-bats/setup.bats
# etc...
```

### BATS vs Legacy Tests

**BATS tests** (recommended):
- ✅ Clear, readable test output
- ✅ Semantic assertions (checks behavior, not text)
- ✅ Smart prerequisite handling (auto-runs dependencies)
- ✅ Individual tests can run standalone
- ✅ 59 individual test cases across 8 files

**Legacy tests**:
- String-based output comparison
- Harder to debug when failing
- Kept for validation period only

## How Tests Work

This test harness validates pgxntool by:
1. Cloning the pgxntool-test-template (a minimal PostgreSQL extension)
2. Injecting pgxntool into it via git subtree
3. Running various pgxntool operations (setup, build, test, dist)
4. Validating the results

See [CLAUDE.md](CLAUDE.md) for detailed documentation.

## Test Organization

### BATS Tests (tests-bats/)

Modern test suite with 59 individual test cases:

1. **clone.bats** (8 tests) - Repository cloning, git setup, pgxntool installation
2. **setup.bats** (10 tests) - setup.sh functionality and error handling
3. **meta.bats** (6 tests) - META.json generation from META.in.json
4. **dist.bats** (5 tests) - Distribution packaging and validation
5. **setup-final.bats** (7 tests) - setup.sh idempotence testing
6. **make-test.bats** (9 tests) - Test framework validation
7. **make-results.bats** (6 tests) - Expected output updating
8. **doc.bats** (9 tests) - Documentation generation (asciidoc/asciidoctor)

Each test file automatically runs its prerequisites if needed, so they can be run individually or as a suite.

### Legacy Tests (tests/)

Original output comparison tests (kept during validation period):
- `tests/clone`, `tests/setup`, `tests/meta`, etc.
- `expected/` - Expected text outputs
- `lib.sh` - Common utilities

## Development

When tests fail, check `diffs/*.diff` to see what changed. If the changes are correct, run `make sync-expected` to update expected outputs (legacy tests only).
