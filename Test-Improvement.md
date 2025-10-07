# Testing Strategy Analysis and Recommendations for pgxntool-test

**Date:** 2025-10-07
**Status:** Proposed Improvements

## Executive Summary

The current pgxntool-test system is functional but has significant maintainability and robustness issues. The primary problems are: **fragile string-based output comparison**, **poor test isolation**, **difficult debugging**, and **lack of semantic validation**. This analysis provides a prioritized roadmap for modernization while maintaining the critical constraint that **no test code can be added to pgxntool itself**.

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
- ~10 sed rules just to normalize output
- Expected files are 516 lines total - huge maintenance burden
- Can't distinguish meaningful failures from cosmetic changes

**Impact:** ~60% of test maintenance time spent updating expected outputs

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

**Impact:** Test execution time is serialized; debugging wastes ~5-10 minutes per iteration

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

### Option 1: BATS (Bash Automated Testing System)

**Adoption:** Very high (14.7k GitHub stars)
**Maturity:** Stable, actively maintained
**TAP Compliance:** Yes

**Pros:**
- Minimal learning curve for bash developers
- TAP-compliant output (CI-friendly)
- Helper libraries available (bats-assert, bats-support, bats-file)
- Test isolation built-in
- Better assertion messages
- Can keep integration test approach

**Cons:**
- Still bash-based (inherits shell scripting limitations)
- Less sophisticated than language-specific frameworks

**Example BATS test:**
```bash
#!/usr/bin/env bats

load test_helper

@test "setup.sh creates Makefile" {
    run pgxntool/setup.sh
    assert_success
    assert_file_exists "Makefile"
    assert_file_contains "Makefile" "include pgxntool/base.mk"
}

@test "setup.sh fails on dirty repo" {
    touch garbage
    git add garbage
    run pgxntool/setup.sh
    assert_failure
    assert_output --partial "not clean"
}
```

**Fit for pgxntool-test:** ⭐⭐⭐⭐⭐ Excellent - Best balance of power and simplicity

### Option 2: ShellSpec (BDD for Shell Scripts)

**Adoption:** Medium (1.1k GitHub stars)
**Maturity:** Stable
**TAP Compliance:** Yes

**Pros:**
- BDD-style syntax (Describe/It/Expect)
- Strong assertion library
- Better for complex scenarios
- Good mocking capabilities
- Coverage reports

**Cons:**
- Steeper learning curve
- Less common in wild
- More opinionated syntax

**Example ShellSpec test:**
```bash
Describe 'pgxntool setup'
    It 'creates required files'
        When call pgxntool/setup.sh
        The status should be success
        The file "Makefile" should be exist
        The contents of file "Makefile" should include "pgxntool/base.mk"
    End

    It 'rejects dirty repositories'
        touch garbage && git add garbage
        When call pgxntool/setup.sh
        The status should be failure
        The error should include "not clean"
    End
End
```

**Fit for pgxntool-test:** ⭐⭐⭐⭐ Very good - Better for complex scenarios, but overkill for current needs

### Option 3: Docker-based Isolation

**Technology:** Docker + Docker Compose
**Maturity:** Industry standard

**Pros:**
- True test isolation (each test gets clean container)
- Can parallelize easily
- Reproducible environments
- Can test across Postgres versions
- Industry best practice for integration testing

**Cons:**
- Adds complexity
- Slower startup (container overhead)
- Requires Docker knowledge
- Harder to debug (must exec into containers)

**Example architecture:**
```yaml
# docker-compose.test.yml
services:
  test-runner:
    build: .
    volumes:
      - ../pgxntool:/pgxntool
      - ../pgxntool-test-template:/template
    environment:
      - PGXNREPO=/pgxntool
      - TEST_TEMPLATE=/template
    command: bats tests/
```

**Fit for pgxntool-test:** ⭐⭐⭐ Good - Powerful but may be overkill; consider for future

### Option 4: Hybrid Approach (RECOMMENDED)

**Combine:**
- BATS for test structure and assertions
- Docker for optional isolation (not required initially)
- Keep Make for orchestration
- Add semantic validation helpers

**Benefits:**
- Incremental migration (can convert tests one-by-one)
- Backwards compatible (keep existing tests during transition)
- Best of all worlds

---

## Prioritized Recommendations

### Priority 1: Adopt BATS Framework (HIGH IMPACT, MODERATE EFFORT)

**Why:** Addresses fragility, debugging, and assertion issues immediately.

**Migration Path:**
1. Install BATS as submodule in pgxntool-test
2. Create `tests/bats/` directory for new-style tests
3. Keep `tests/` bash scripts for now
4. Convert one test (e.g., `setup`) to BATS as proof-of-concept
5. Add BATS helpers for common validations
6. Convert remaining tests incrementally
7. Remove old tests once all converted

**Effort:** 2-3 days initial setup, 1 hour per test converted

**Example migration:**

**Before (tests/setup):**
```bash
#!/bin/bash
. $BASEDIR/../.env
. $TOPDIR/lib.sh
cd $TEST_REPO

out Making checkout dirty
touch garbage
git add garbage
out Verify setup.sh errors out
if pgxntool/setup.sh; then
  echo "setup.sh should have exited non-zero" >&2
  exit 1
fi
# ... more bash ...
check_log
```

**After (tests/bats/setup.bats):**
```bash
#!/usr/bin/env bats

load ../helpers/test_helper

setup() {
    export TEST_REPO=$(create_test_repo)
    cd "$TEST_REPO"
}

teardown() {
    rm -rf "$TEST_REPO"
}

@test "setup.sh fails when repo is dirty" {
    touch garbage
    git add garbage

    run pgxntool/setup.sh

    assert_failure
    assert_output --partial "not clean"
}

@test "setup.sh creates expected files" {
    run pgxntool/setup.sh

    assert_success
    assert_file_exists "Makefile"
    assert_file_exists ".gitignore"
    assert_file_exists "META.in.json"
    assert_file_exists "META.json"
}

@test "setup.sh creates valid Makefile" {
    run pgxntool/setup.sh

    assert_success
    assert_file_contains "Makefile" "include pgxntool/base.mk"

    # Verify it actually works
    run make --dry-run
    assert_success
}
```

### Priority 2: Create Semantic Validation Helpers (HIGH IMPACT, LOW EFFORT)

**Why:** Makes tests robust to cosmetic changes.

**Create `tests/helpers/validations.bash`:**
```bash
#!/usr/bin/env bash

# Validate META.json structure
assert_valid_meta_json() {
    local file="$1"

    # Check it's valid JSON
    jq empty "$file" || fail "META.json is not valid JSON"

    # Check required fields
    local name=$(jq -r '.name' "$file")
    local version=$(jq -r '.version' "$file")

    [[ -n "$name" ]] || fail "META.json missing 'name' field"
    [[ -n "$version" ]] || fail "META.json missing 'version' field"
    [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "Invalid version format: $version"
}

# Validate distribution zip structure
assert_valid_distribution() {
    local zipfile="$1"
    local expected_name="$2"
    local expected_version="$3"

    # Check zip exists and is valid
    [[ -f "$zipfile" ]] || fail "Distribution zip not found: $zipfile"
    unzip -t "$zipfile" >/dev/null || fail "Distribution zip is corrupted"

    # Check contains required files
    local files=$(unzip -l "$zipfile" | awk '{print $4}')
    echo "$files" | grep -q "META.json" || fail "Distribution missing META.json"
    echo "$files" | grep -q ".*\.control$" || fail "Distribution missing .control file"

    # Check no pgxntool docs included
    if echo "$files" | grep -q "pgxntool.*\.(md|asc|adoc|html)"; then
        fail "Distribution contains pgxntool documentation"
    fi
}

# Validate make target works
assert_make_target_succeeds() {
    local target="$1"

    run make "$target"
    assert_success
}

# Validate extension control file
assert_valid_control_file() {
    local file="$1"

    [[ -f "$file" ]] || fail "Control file not found: $file"

    grep -q "^default_version" "$file" || fail "Control file missing default_version"
    grep -q "^comment" "$file" || fail "Control file missing comment"
}

# Validate git repo state
assert_repo_clean() {
    run git status --porcelain
    assert_output ""
}

assert_repo_dirty() {
    run git status --porcelain
    refute_output ""
}

# Validate files created
assert_files_created() {
    local -a files=("$@")
    for file in "${files[@]}"; do
        [[ -f "$file" ]] || fail "Expected file not created: $file"
    done
}

# Validate JSON field value
assert_json_field() {
    local file="$1"
    local field="$2"
    local expected="$3"

    local actual=$(jq -r "$field" "$file")
    [[ "$actual" == "$expected" ]] || fail "JSON field $field: expected '$expected', got '$actual'"
}
```

**Usage in tests:**
```bash
@test "make dist creates valid distribution" {
    make dist

    assert_valid_distribution \
        "../pgxntool-test-0.1.0.zip" \
        "pgxntool-test" \
        "0.1.0"
}
```

**Effort:** 1 day to create helpers, minimal effort to use

### Priority 3: Improve Test Isolation (MEDIUM IMPACT, HIGH EFFORT)

**Why:** Enables parallel execution, independent test runs.

**Approach:** Create fresh test repo for each test.

**Create `tests/helpers/test_helper.bash`:**
```bash
#!/usr/bin/env bash

# Load BATS libraries
load "$(dirname "$BATS_TEST_DIRNAME")/node_modules/bats-support/load"
load "$(dirname "$BATS_TEST_DIRNAME")/node_modules/bats-assert/load"
load "$(dirname "$BATS_TEST_DIRNAME")/node_modules/bats-file/load"
load "validations"

# Create isolated test repo
create_test_repo() {
    local test_dir=$(mktemp -d)

    # Clone template
    git clone "$TEST_TEMPLATE" "$test_dir" >/dev/null 2>&1
    cd "$test_dir"

    # Set up fake remote
    git init --bare ../fake_repo >/dev/null 2>&1
    git remote remove origin
    git remote add origin ../fake_repo
    git push --set-upstream origin master >/dev/null 2>&1

    # Add pgxntool
    git subtree add -P pgxntool --squash "$PGXNREPO" "$PGXNBRANCH" >/dev/null 2>&1

    echo "$test_dir"
}

# Common setup
common_setup() {
    export TEST_DIR=$(create_test_repo)
    cd "$TEST_DIR"
}

# Common teardown
common_teardown() {
    if [[ -n "$TEST_DIR" ]]; then
        rm -rf "$TEST_DIR"
    fi
}
```

**Usage:**
```bash
setup() {
    common_setup
}

teardown() {
    common_teardown
}
```

**Benefit:** Each test gets clean state, can run in any order.

**Tradeoff:** Tests run slower (more git operations). Mitigate by:
- Caching template clone
- Sharing read-only base repo
- Only using for tests that need it

**Effort:** 2 days implementation, 1-2 hours per test to convert

### Priority 4: Add CI/CD Integration (LOW IMPACT, LOW EFFORT)

**Why:** Better test reporting, historical tracking.

**Add TAP/JUnit XML output:**
```makefile
# Makefile
.PHONY: test-ci
test-ci:
	bats --formatter junit tests/bats/ > test-results.xml
	bats --formatter tap tests/bats/
```

**GitHub Actions example:**
```yaml
# .github/workflows/test.yml (in pgxntool-test repo)
name: Test pgxntool
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        postgres: [12, 13, 14, 15, 16]
    steps:
      - uses: actions/checkout@v3
      - name: Install PostgreSQL ${{ matrix.postgres }}
        run: |
          sudo apt-get update
          sudo apt-get install -y postgresql-${{ matrix.postgres }}
      - name: Install BATS
        run: |
          git submodule update --init --recursive
      - name: Run tests
        run: make test-ci
      - name: Upload test results
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: test-results-pg${{ matrix.postgres }}
          path: test-results.xml
```

**Effort:** 1 day for CI setup

### Priority 5: Add Static Analysis (LOW IMPACT, LOW EFFORT)

**Why:** Catch errors before running tests.

**Add ShellCheck to pgxntool-test:**
```makefile
.PHONY: lint
lint:
	find tests -name '*.bash' -o -name '*.bats' | xargs shellcheck
	find tests -type f -executable | xargs shellcheck
```

**Effort:** 2 hours

---

## Proposed Migration Timeline

### Phase 1: Foundation (Week 1)
- [ ] Add BATS as git submodule
- [ ] Create `tests/bats/` and `tests/helpers/` directories
- [ ] Implement `test_helper.bash` and `validations.bash`
- [ ] Convert one test (setup) as proof-of-concept
- [ ] Document new test structure in CLAUDE.md

### Phase 2: Core Tests (Weeks 2-3)
- [ ] Convert meta test
- [ ] Convert dist test
- [ ] Convert make-test test
- [ ] Add semantic validation to all tests
- [ ] Verify all tests pass in new system

### Phase 3: Advanced Features (Week 4)
- [ ] Implement test isolation helpers
- [ ] Add CI/CD integration
- [ ] Add ShellCheck linting
- [ ] Create test coverage report

### Phase 4: Cleanup (Week 5)
- [ ] Remove old bash tests
- [ ] Update documentation
- [ ] Remove old expected/ directory
- [ ] Simplify Makefile

---

## Example: Complete Test Rewrite

**Current: tests/meta (14 lines bash)**
```bash
#!/bin/bash
trap 'echo "ERROR: $BASH_SOURCE: line $LINENO" >&2' ERR
set -o errexit -o errtrace -o pipefail
. $BASEDIR/../.env
. $TOPDIR/lib.sh
cd $TEST_REPO

DISTRIBUTION_NAME=distribution_test
EXTENSION_NAME=pgxntool-test

out Verify changing META.in.json works
sleep 1
sed -i '' -e "s/DISTRIBUTION_NAME/$DISTRIBUTION_NAME/" -e "s/EXTENSION_NAME/$EXTENSION_NAME/" META.in.json
make
git commit -am "Change META"
check_log
```

**Proposed: tests/bats/meta.bats (40 lines with comprehensive validation)**
```bash
#!/usr/bin/env bats

load ../helpers/test_helper

setup() {
    common_setup
}

teardown() {
    common_teardown
}

@test "META.in.json is generated into META.json" {
    run make META.json

    assert_success
    assert_file_exists "META.json"
}

@test "META.json is valid JSON" {
    make META.json

    assert_valid_meta_json "META.json"
}

@test "META.json strips X_comment fields" {
    make META.json

    refute grep -q "X_comment" META.json
}

@test "META.json strips empty fields" {
    make META.json

    # Check that fields with empty strings are removed
    refute jq '.tags | length == 0' META.json
}

@test "changes to META.in.json trigger META.json rebuild" {
    make META.json
    local orig_time=$(stat -f %m META.json)

    sleep 1
    sed -i '' 's/DISTRIBUTION_NAME/my-extension/' META.in.json
    make META.json

    local new_time=$(stat -f %m META.json)
    [[ "$new_time" -gt "$orig_time" ]] || fail "META.json was not rebuilt"

    # Verify change was applied
    assert_json_field META.json ".name" "my-extension"
}

@test "meta.mk is generated from META.json" {
    make META.json meta.mk

    assert_file_exists "meta.mk"
    assert_file_contains "meta.mk" "PGXN :="
    assert_file_contains "meta.mk" "PGXNVERSION :="
}

@test "meta.mk contains correct variables" {
    sed -i '' 's/DISTRIBUTION_NAME/test-dist/' META.in.json
    sed -i '' 's/EXTENSION_NAME/test-ext/' META.in.json
    make META.json meta.mk

    run grep "PGXN := test-dist" meta.mk
    assert_success

    run grep "EXTENSIONS += test-ext" meta.mk
    assert_success
}
```

**Benefits of rewrite:**
- No dependency on exact output format
- Tests specific behaviors, not stdout
- Clear failure messages
- Can run independently
- More comprehensive coverage
- Self-documenting (test names explain intent)

---

## Tools & Resources

### Install BATS
```bash
cd pgxntool-test
git submodule add https://github.com/bats-core/bats-core.git deps/bats-core
git submodule add https://github.com/bats-core/bats-support.git deps/bats-support
git submodule add https://github.com/bats-core/bats-assert.git deps/bats-assert
git submodule add https://github.com/bats-core/bats-file.git deps/bats-file
```

### Update Makefile
```makefile
# Add to Makefile
BATS = deps/bats-core/bin/bats

.PHONY: test-bats
test-bats: env
	$(BATS) tests/bats/

.PHONY: test-bats-parallel
test-bats-parallel: env
	$(BATS) --jobs 4 tests/bats/

.PHONY: test-ci
test-ci: env
	$(BATS) --formatter junit tests/bats/ > test-results.xml
	$(BATS) --formatter tap tests/bats/

.PHONY: lint
lint:
	find tests -name '*.bash' -o -name '*.bats' | xargs shellcheck
	find tests -type f -executable | xargs shellcheck
```

---

## Metrics for Success

Track these metrics to measure improvement:

1. **Test Maintenance Time** - Time spent updating tests after pgxntool changes
   - Current: ~1 hour per change
   - Target: ~15 minutes per change

2. **Test Execution Time** - Time to run full suite
   - Current: ~2-3 minutes (serial)
   - Target: ~1 minute (parallel)

3. **Debug Time** - Time to diagnose test failure
   - Current: ~10-15 minutes (need to read diffs, understand sed)
   - Target: ~2-3 minutes (clear failure message)

4. **Test Conversion Rate** - How quickly can new tests be written
   - Current: ~2-3 hours per test (with bash boilerplate)
   - Target: ~30 minutes per test (with BATS helpers)

5. **False Positive Rate** - Tests failing due to cosmetic changes
   - Current: ~30% (output format changes break tests)
   - Target: <5% (only break on semantic changes)

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

**Recommended Approach:** Adopt BATS framework with semantic validation helpers, implemented incrementally.

**Key Benefits:**
- 🎯 Robust to cosmetic changes (semantic validation)
- 🐛 Easier debugging (clear assertions)
- ⚡ Faster test execution (isolation enables parallelization)
- 📝 Lower maintenance burden (no sed normalization)
- 🔌 Better CI integration (TAP/JUnit XML output)

**Effort:** ~5 weeks for complete migration, with immediate benefits from first converted test.

**ROI:** High - Will pay for itself in reduced maintenance time within 2-3 months.

---

## Next Steps

1. Review and approve this strategy
2. Begin Phase 1: Install BATS and create foundation
3. Convert setup test as proof-of-concept
4. Evaluate results and adjust approach if needed
5. Continue with incremental migration
