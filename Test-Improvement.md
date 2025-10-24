# Testing Strategy Analysis for pgxntool-test

**Date:** 2025-10-07
**Status:** Strategy Document
**Implementation:** See [BATS-MIGRATION-PLAN.md](BATS-MIGRATION-PLAN.md) for detailed BATS implementation plan

## Executive Summary

The current pgxntool-test system is functional but has significant maintainability and robustness issues. The primary problems are: **fragile string-based output comparison**, **poor test isolation**, **difficult debugging**, and **lack of semantic validation**.

This document analyzes these issues and provides the strategic rationale for adopting BATS (Bash Automated Testing System). For the detailed implementation plan, see [BATS-MIGRATION-PLAN.md](BATS-MIGRATION-PLAN.md).

**Critical constraint:** No test code can be added to pgxntool itself (it gets embedded in extensions via git subtree).

---

## Current System Assessment

### Architecture Overview

**Current Pattern:**
```
pgxntool-test/
├── Makefile           # Test orchestration, dependencies
├── tests/             # Bash scripts (clone, setup, meta, dist, etc.)
├── expected/          # Exact output strings to match
├── results/           # Actual output (generated)
├── diffs/             # Diff between expected/results
├── lib.sh             # Shared utilities, output redirection
└── base_result.sed    # Output normalization rules
```

### Strengths

1. **True integration testing** - Tests real user workflows end-to-end
2. **Make-based orchestration** - Familiar, explicit dependencies
3. **Comprehensive coverage** - Tests setup, build, test, dist workflows
4. **Smart pgxntool injection** - Can test uncommitted changes via rsync
5. **Selective execution** - Can run individual tests or full suite

### Critical Weaknesses

#### 1. Fragile String-Based Validation (HIGH IMPACT)

**Problem:** Tests use `diff` to compare entire output strings line-by-line.

**Example** from `expected/setup.out`:
```bash
# Running setup.sh
Copying pgxntool/_.gitignore to .gitignore and adding to git
@GIT COMMIT@ Test setup
 6 files changed, 259 insertions(+)
```

**Issues:**
- Any cosmetic change breaks tests (e.g., rewording messages, git formatting)
- Complex sed normalization required (paths, hashes, timestamps, rsync output)
- 25 sed substitution rules in base_result.sed just to normalize output
- Expected files are 516 lines total - huge maintenance burden
- Can't distinguish meaningful failures from cosmetic changes

**Impact:** High maintenance burden updating expected outputs after pgxntool changes

#### 2. Poor Test Isolation (HIGH IMPACT)

**Problem:** Tests share state through single cloned repo.

```makefile
# Hard-coded dependencies
test-setup: test-clone
test-meta: test-setup
test-dist: test-meta
test-setup-final: test-dist
test-make-test: test-setup-final
```

**Issues:**
- Tests MUST run in strict order
- Can't run `test-dist` without running all predecessors
- One failure cascades to all subsequent tests
- Impossible to parallelize
- Debugging requires running from beginning

**Impact:** Test execution time is serialized; debugging is time-consuming

#### 3. Difficult Debugging (MEDIUM IMPACT)

**Problem:** Complex output handling obscures failures.

```bash
# From lib.sh:
exec 8>&1            # Save stdout to FD 8
exec 9>&2            # Save stderr to FD 9
exec >> $LOG         # Redirect stdout to log
exec 2> >(tee -ai $LOG >&9)  # Tee stderr to log and FD 9
```

**Issues:**
- Need to understand FD redirection to debug
- Failures show as 40-line diffs, not semantic errors
- Must inspect log files, run sed manually to understand what happened
- No structured error messages ("expected X, got Y")

**Example failure output:**
```diff
@@ -45,7 +45,7 @@
-pgxntool-test.control
+pgxntool_test.control
```
vs. what it should say:
```
FAIL: Expected control file 'pgxntool-test.control' but found 'pgxntool_test.control'
```

#### 4. No Semantic Validation (MEDIUM IMPACT)

**Problem:** Tests don't validate *what* was created, just *what was printed*.

Current approach:
```bash
make dist
unzip -l ../dist.zip  # Just lists files in output
```

Better approach would be:
```bash
make dist
assert_zip_contains ../dist.zip "META.json"
assert_valid_json extracted/META.json
assert_json_field META.json ".name" "pgxntool-test"
```

**Issues:**
- Can't validate file contents, only that commands ran
- No structural validation (e.g., "is META.json valid?")
- Can't test negative cases easily (e.g., "dist should fail if repo dirty")

#### 5. Limited Error Reporting (LOW IMPACT)

**Problem:** Binary pass/fail with no granularity.

```bash
cont: $(TEST_TARGETS)
    @[ "`cat $(DIFF_DIR)/*.diff 2>/dev/null | head -n1`" == "" ] \
        && (echo; echo 'All tests passed!'; echo) \
        || (echo; echo "Some tests failed:"; echo ; egrep -lR '.' $(DIFF_DIR); echo; exit 1)
```

**Issues:**
- No test timing information
- No JUnit XML for CI integration
- No indication of which aspects passed/failed within a test
- Can't track test flakiness over time

---

## Modern Testing Framework Analysis

### Selected Framework: BATS (Bash Automated Testing System)

**Decision:** BATS chosen as best fit for pgxntool-test

**Rationale:**
- ⭐⭐⭐⭐⭐ Minimal learning curve for bash developers
- TAP-compliant output (CI-friendly)
- Rich ecosystem: bats-assert, bats-support, bats-file libraries
- Built-in test isolation
- Clear assertion messages
- Preserves integration test approach
- Very high adoption (14.7k GitHub stars)

**Tradeoffs accepted:**
- Still bash-based (inherits shell scripting limitations)
- Less sophisticated than language-specific frameworks
- But: These are minor issues compared to benefits

**Implementation details:** See [BATS-MIGRATION-PLAN.md](BATS-MIGRATION-PLAN.md)

### Alternatives Considered

**ShellSpec (BDD for Shell Scripts):**
- ⭐⭐⭐⭐ Strong framework with BDD-style syntax
- **Rejected:** Steeper learning curve, less common, more opinionated
- Overkill for current needs

**Docker-based Isolation:**
- ⭐⭐⭐ Powerful, industry standard
- **Deferred:** Too complex initially, consider for future
- Container overhead, requires Docker knowledge
- Can add later if needed for multi-version testing

---

## Key Recommendations

### 1. Adopt BATS Framework (IMPLEMENTED)

**Why:** Addresses fragility, debugging, and assertion issues immediately.

**Status:** Implementation plan documented in [BATS-MIGRATION-PLAN.md](BATS-MIGRATION-PLAN.md)

**Key decisions:**
- Use standard BATS libraries (bats-assert, bats-support, bats-file)
- Two-tier architecture: sequential foundation tests + independent feature tests
- Pollution detection for shared state
- Semantic validators created as needed (when used >1x or improves clarity)

### 2. Create Semantic Validation Helpers (PLANNED)

**Why:** Makes tests robust to cosmetic changes - test behavior, not output format.

**Principle:** Create helpers when:
- Validation needed more than once, OR
- Helper makes test significantly clearer

**Examples:**
- `assert_valid_meta_json()` - Validate structure, required fields, format
- `assert_valid_distribution()` - Validate zip contents, no pgxntool docs
- `assert_json_field()` - Check specific JSON field values

**Status:** Defined in BATS-MIGRATION-PLAN.md, implement during test conversion

### 3. Test Isolation Strategy (DECIDED)

**Decision:** Use pollution detection instead of full isolation per-test

**Rationale:**
- Foundation tests share state (faster, numbered execution)
- Feature tests get isolated environments
- Pollution markers detect when environment compromised
- Auto-recovery recreates environment if needed

**Tradeoff:** More complex (pollution detection) but much faster than creating fresh environment per @test

**Status:** Architecture documented in BATS-MIGRATION-PLAN.md

---

## Future Improvements (TODO)

These improvements are deferred for future implementation. They provide additional value but are not required for the core BATS migration.

### CI/CD Integration

**Value:** Automated testing, multi-version validation

**Implementation:** GitHub Actions with matrix testing across PostgreSQL versions

**Status:** TODO - see [BATS-MIGRATION-PLAN.md](BATS-MIGRATION-PLAN.md#future-improvements-todo) for details

### Static Analysis (ShellCheck)

**Value:** Catch scripting errors early, enforce best practices

**Implementation:** Add `make lint` target

**Status:** TODO - see [BATS-MIGRATION-PLAN.md](BATS-MIGRATION-PLAN.md#future-improvements-todo) for details

### Verbose Mode for Test Execution

**Value:** Diagnose slow tests and understand what commands are actually running

**Problem:** Tests can take a long time to complete, but it's not clear what operations are happening or where the time is being spent.

**Implementation:** Add verbose mode that echoes actual commands being executed

**Features:**
- Echo commands with timestamps before execution (similar to `set -x` but more readable)
- Show duration for long-running operations
- Option to enable via environment variable (e.g., `VERBOSE=1 make test-bats`)
- Different verbosity levels:
  - `VERBOSE=1` - Show major operations (git clone, make commands, etc.)
  - `VERBOSE=2` - Show all commands
  - `VERBOSE=3` - Show commands + arguments + working directory

**Example output:**
```
[02:34:56] Running: git clone ../pgxntool-test-template .envs/sequential/repo
[02:34:58] ✓ Completed in 2.1s
[02:34:58] Running: cd .envs/sequential/repo && make dist
[02:35:12] ✓ Completed in 14.3s
```

**Status:** TODO - Needed for diagnosing slow test execution

**Priority:** Medium - Not blocking but very useful for test development and debugging

---

## Benefits of BATS Migration

**Addressing Current Weaknesses:**

1. **Fragile string comparison** → Semantic validation
   - Test what changed, not how it's displayed
   - Validators like `assert_valid_meta_json()` check structure
   - No sed normalization needed

2. **Poor test isolation** → Two-tier architecture
   - Foundation tests: Fast sequential execution with pollution detection
   - Feature tests: Independent isolated environments
   - Tests can run standalone

3. **Difficult debugging** → Clear assertions
   - `assert_file_exists "Makefile"` vs parsing 40-line diff
   - Semantic validators show exactly what failed
   - Self-documenting test names

4. **No semantic validation** → Purpose-built validators
   - `assert_valid_distribution()` checks zip structure
   - `assert_json_field()` validates specific values
   - Tests verify behavior, not output format

5. **Limited error reporting** → TAP output
   - Per-test pass/fail granularity
   - Can add JUnit XML for CI (future)
   - Clear failure messages

---

## Critical Constraints

### All Test Code Must Live in pgxntool-test

**Absolutely no test code can be added to pgxntool repository.** This is because:

1. pgxntool gets embedded into extension projects via `git subtree`
2. Any test code in pgxntool would pollute every extension project that uses it
3. The framework should be minimal - just the build system
4. All testing infrastructure belongs in the separate pgxntool-test repository

**Locations:**
- ✅ **pgxntool-test/** - All test code, BATS tests, helpers, validation functions, CI configs
- ❌ **pgxntool/** - Zero test code, stays pure framework code only
- ✅ **pgxntool-test-template/** - Can have minimal test fixtures (like the current test SQL), but no test infrastructure

---

## Summary

**Strategy:** Adopt BATS framework with semantic validation helpers and pollution-based state management.

**Key Benefits:**
- 🎯 Robust to cosmetic changes (semantic validation)
- 🐛 Easier debugging (clear assertions)
- ⚡ Faster test execution (shared state with pollution detection)
- 📝 Lower maintenance burden (no sed normalization)
- 🔌 Self-sufficient tests (run without Make)

**Implementation:** See [BATS-MIGRATION-PLAN.md](BATS-MIGRATION-PLAN.md) for complete refactoring plan

**Status:** Strategy approved, ready for implementation

---

## Related Documents

- **[BATS-MIGRATION-PLAN.md](BATS-MIGRATION-PLAN.md)** - Detailed implementation plan for BATS refactoring
- **[CLAUDE.md](CLAUDE.md)** - General guidance for working with this repository
- **[README.md](README.md)** - Project overview and requirements
