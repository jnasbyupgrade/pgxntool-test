#!/bin/bash
# release-preflight.sh - Pre-flight checks for pgxntool release
#
# Validates both repositories are ready for release and outputs
# structured results. Run from the pgxntool-test directory.
#
# Usage: release-preflight.sh [VERSION]
#
# Exit codes:
#   0 - All checks passed (warnings may exist)
#   1 - Errors found (must fix before release)

set -euo pipefail

PGXNTOOL_DIR="../pgxntool"
PGXNTOOL_TEST_DIR="."
VERSION="${1:-}"

errors=()
warnings=()

# Find the git remote pointing to Postgres-Extensions for a repo.
# Uses [./] anchor to prevent "pgxntool" from matching "pgxntool-test".
find_upstream_remote() {
    local repo_path="$1"
    local repo_name="$2"
    git -C "$repo_path" remote -v \
        | grep "Postgres-Extensions/${repo_name}[./]" \
        | head -1 \
        | awk '{print $1}'
}

echo "=== Pre-flight Checks ==="
echo

# 1. Identify upstream remotes
echo "--- Upstream Remotes ---"
PGXNTOOL_UPSTREAM=$(find_upstream_remote "$PGXNTOOL_DIR" "pgxntool")
PGXNTOOL_TEST_UPSTREAM=$(find_upstream_remote "$PGXNTOOL_TEST_DIR" "pgxntool-test")

if [ -n "$PGXNTOOL_UPSTREAM" ]; then
    pgxntool_url=$(git -C "$PGXNTOOL_DIR" remote get-url "$PGXNTOOL_UPSTREAM")
    echo "pgxntool: remote=\"$PGXNTOOL_UPSTREAM\" url=$pgxntool_url"
else
    echo "pgxntool: ERROR - no remote pointing to Postgres-Extensions/pgxntool"
    echo "  Fix: cd $PGXNTOOL_DIR && git remote add upstream https://github.com/Postgres-Extensions/pgxntool.git"
    errors+=("pgxntool: no upstream remote")
fi

if [ -n "$PGXNTOOL_TEST_UPSTREAM" ]; then
    pgxntool_test_url=$(git -C "$PGXNTOOL_TEST_DIR" remote get-url "$PGXNTOOL_TEST_UPSTREAM")
    echo "pgxntool-test: remote=\"$PGXNTOOL_TEST_UPSTREAM\" url=$pgxntool_test_url"
else
    echo "pgxntool-test: ERROR - no remote pointing to Postgres-Extensions/pgxntool-test"
    echo "  Fix: git remote add upstream https://github.com/Postgres-Extensions/pgxntool-test.git"
    errors+=("pgxntool-test: no upstream remote")
fi
echo

# 2. Check working directories
echo "--- Working Directories ---"
pgxntool_status=$(git -C "$PGXNTOOL_DIR" status --porcelain)
pgxntool_test_status=$(git -C "$PGXNTOOL_TEST_DIR" status --porcelain)

if [ -z "$pgxntool_status" ]; then
    echo "pgxntool: clean"
else
    echo "pgxntool: DIRTY"
    echo "$pgxntool_status" | sed 's/^/  /'
    errors+=("pgxntool: working directory is dirty")
fi

if [ -z "$pgxntool_test_status" ]; then
    echo "pgxntool-test: clean"
else
    echo "pgxntool-test: DIRTY"
    echo "$pgxntool_test_status" | sed 's/^/  /'
    errors+=("pgxntool-test: working directory is dirty")
fi
echo

# 3. Check branches
echo "--- Branches ---"
pgxntool_branch=$(git -C "$PGXNTOOL_DIR" branch --show-current)
pgxntool_test_branch=$(git -C "$PGXNTOOL_TEST_DIR" branch --show-current)

echo "pgxntool: $pgxntool_branch"
echo "pgxntool-test: $pgxntool_test_branch"
[ "$pgxntool_branch" = "master" ] || errors+=("pgxntool: on branch '$pgxntool_branch', not master")
[ "$pgxntool_test_branch" = "master" ] || errors+=("pgxntool-test: on branch '$pgxntool_test_branch', not master")
echo

# 4. Fetch and check sync
echo "--- Sync Status ---"
if [ -n "$PGXNTOOL_UPSTREAM" ]; then
    git -C "$PGXNTOOL_DIR" fetch "$PGXNTOOL_UPSTREAM" 2>/dev/null
    local_head=$(git -C "$PGXNTOOL_DIR" rev-parse HEAD)
    upstream_head=$(git -C "$PGXNTOOL_DIR" rev-parse "$PGXNTOOL_UPSTREAM/master" 2>/dev/null || echo "unknown")
    if [ "$local_head" = "$upstream_head" ]; then
        echo "pgxntool: in sync with $PGXNTOOL_UPSTREAM/master ($local_head)"
    else
        echo "pgxntool: DIVERGED from $PGXNTOOL_UPSTREAM/master"
        echo "  local:    $local_head"
        echo "  upstream: $upstream_head"
        warnings+=("pgxntool: local master diverges from $PGXNTOOL_UPSTREAM/master")
    fi
fi

if [ -n "$PGXNTOOL_TEST_UPSTREAM" ]; then
    git -C "$PGXNTOOL_TEST_DIR" fetch "$PGXNTOOL_TEST_UPSTREAM" 2>/dev/null
    local_head=$(git -C "$PGXNTOOL_TEST_DIR" rev-parse HEAD)
    upstream_head=$(git -C "$PGXNTOOL_TEST_DIR" rev-parse "$PGXNTOOL_TEST_UPSTREAM/master" 2>/dev/null || echo "unknown")
    if [ "$local_head" = "$upstream_head" ]; then
        echo "pgxntool-test: in sync with $PGXNTOOL_TEST_UPSTREAM/master ($local_head)"
    else
        echo "pgxntool-test: DIVERGED from $PGXNTOOL_TEST_UPSTREAM/master"
        echo "  local:    $local_head"
        echo "  upstream: $upstream_head"
        warnings+=("pgxntool-test: local master diverges from $PGXNTOOL_TEST_UPSTREAM/master")
    fi
fi
echo

# 5. Version checks
if [ -n "$VERSION" ]; then
    echo "--- Version: $VERSION ---"

    # Validate format
    if [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "Format: valid"
    else
        echo "Format: INVALID (must be X.Y.Z)"
        errors+=("Version '$VERSION' is not in X.Y.Z format")
    fi

    # Check existing tags
    pgxntool_tag=$(git -C "$PGXNTOOL_DIR" tag -l "$VERSION")
    pgxntool_test_tag=$(git -C "$PGXNTOOL_TEST_DIR" tag -l "$VERSION")

    if [ -n "$pgxntool_tag" ]; then
        echo "pgxntool tag: ALREADY EXISTS"
        errors+=("Tag $VERSION already exists in pgxntool")
    else
        echo "pgxntool tag: available"
    fi

    if [ -n "$pgxntool_test_tag" ]; then
        echo "pgxntool-test tag: ALREADY EXISTS"
        errors+=("Tag $VERSION already exists in pgxntool-test")
    else
        echo "pgxntool-test tag: available"
    fi
    echo
fi

# 6. HISTORY.asc
echo "--- HISTORY.asc ---"
if grep -q '^STABLE$' "$PGXNTOOL_DIR/HISTORY.asc"; then
    echo "STABLE section: found"
    # Show entries under STABLE (between STABLE header and next section)
    sed -n '/^STABLE$/,/^[^ ]/{ /^STABLE$/d; /^------$/d; /^$/d; /^[^ ]/q; p; }' "$PGXNTOOL_DIR/HISTORY.asc" | head -20
else
    echo "STABLE section: NOT FOUND"
    warnings+=("No STABLE section in HISTORY.asc - no changes documented for release")
fi
echo

# Summary
echo "=== Summary ==="
if [ ${#errors[@]} -gt 0 ]; then
    echo "ERRORS (must fix before release):"
    for e in "${errors[@]}"; do
        echo "  - $e"
    done
fi
if [ ${#warnings[@]} -gt 0 ]; then
    echo "WARNINGS (may need attention):"
    for w in "${warnings[@]}"; do
        echo "  - $w"
    done
fi
if [ ${#errors[@]} -eq 0 ] && [ ${#warnings[@]} -eq 0 ]; then
    echo "All checks passed!"
fi

# Output remote names for use by caller
echo
echo "=== Remote Names ==="
echo "PGXNTOOL_UPSTREAM=$PGXNTOOL_UPSTREAM"
echo "PGXNTOOL_TEST_UPSTREAM=$PGXNTOOL_TEST_UPSTREAM"

[ ${#errors[@]} -eq 0 ]
