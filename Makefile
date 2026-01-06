.PHONY: all
all: test

# Capture git status once at Make parse time
GIT_DIRTY := $(shell git status --porcelain 2>/dev/null)

# Initialize BATS submodule if needed
.PHONY: init-bats
init-bats:
	@if [ ! -f "test/bats/bin/bats" ]; then \
		echo "Initializing BATS submodule..."; \
		git submodule update --init --recursive test/bats; \
	fi

# Build fresh foundation environment (clean + create)
# Foundation is the base TEST_REPO that all tests depend on
.PHONY: foundation
foundation: init-bats clean-envs
	@test/bats/bin/bats tests/foundation.bats

# Test recursion and pollution detection
# Cleans environments then runs one independent test, which auto-runs foundation
# as a prerequisite. This validates that recursion and pollution detection work correctly.
# Note: Doesn't matter which independent test we use, we just pick the fastest one (test-doc).
.PHONY: test-recursion
test-recursion: init-bats clean-envs
	@echo "Testing recursion with clean environment..."
	@test/bats/bin/bats tests/test-doc.bats

# Run all tests - sequential tests in order, then non-sequential tests
# Note: We explicitly list all sequential tests rather than just running the last one
# because BATS only outputs TAP results for the test files directly invoked.
# If we only ran the last test, prerequisite tests would run but their results
# wouldn't appear in the output.
#
# If git repo is dirty (uncommitted test code changes), runs test-recursion FIRST
# to validate that recursion/pollution detection still work with the changes.
# This is critical because changes to test infrastructure (helpers.bash, etc.) could
# break the prerequisite or pollution detection systems. By running test-recursion
# first with a clean environment, we exercise these systems before running the full suite.
# If recursion is broken, we want to know immediately, not after running all tests.
.PHONY: test
test:
ifneq ($(GIT_DIRTY),)
	@echo "Git repo is dirty (uncommitted changes detected)"
	@echo "Running recursion test first to validate test infrastructure..."
	$(MAKE) test-recursion
	@echo ""
	@echo "Recursion test passed, now running full test suite..."
endif
	@$(MAKE) init-bats clean-envs
	@test/bats/bin/bats $$(ls tests/[0-9][0-9]-*.bats 2>/dev/null | sort) tests/test-*.bats

# Individual test targets for convenience
.PHONY: test-test-build test-test-install test-verify-results
test-test-build: init-bats clean-envs
	@test/bats/bin/bats tests/test-test-build.bats
test-test-install: init-bats clean-envs
	@test/bats/bin/bats tests/test-test-install.bats
test-verify-results: init-bats clean-envs
	@test/bats/bin/bats tests/test-verify-results.bats

# Clean test environments
.PHONY: clean-envs
clean-envs:
	@echo "Removing test environments..."
	@rm -rf .envs

.PHONY: clean
clean: clean-envs

# To use this, do make print-VARIABLE_NAME
print-%	: ; $(info $* is $(flavor $*) variable set to "$($*)") @true

# List all make targets
.PHONY: list
list:
	sh -c "$(MAKE) -p no_targets__ | awk -F':' '/^[a-zA-Z0-9][^\$$#\/\\t=]*:([^=]|$$)/ {split(\$$1,A,/ /);for(i in A)print A[i]}' | grep -v '__\$$' | sort"
