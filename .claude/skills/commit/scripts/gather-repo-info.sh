#!/usr/bin/env bash
set -e

# gather-repo-info.sh - Collect git info for commit preparation
#
# Gathers branch, status, diff stats, and recent log for each repo in one
# call, reducing multiple git commands to a single preprocessed summary.
#
# Usage: gather-repo-info.sh <repo-path> [<repo-path2> ...]
# Output: Structured text summary per repository

gather_info() {
    local repo_path="$1"
    local repo_name
    repo_name=$(basename "$(cd "$repo_path" && pwd)")

    echo "## $repo_name"
    echo "Path: $(cd "$repo_path" && pwd)"

    (
        cd "$repo_path" || exit 1

        echo "Branch: $(git branch --show-current 2>/dev/null || echo 'detached')"
        echo

        local status
        status=$(git status -s 2>/dev/null)
        if [ -z "$status" ]; then
            echo "Status: CLEAN (no changes)"
            echo
            return
        fi

        echo "### Changes"
        echo "$status"
        echo

        local diff_stat
        diff_stat=$(git diff --stat 2>/dev/null)
        if [ -n "$diff_stat" ]; then
            echo "### Unstaged Diff"
            echo "$diff_stat"
            echo
        fi

        local cached_stat
        cached_stat=$(git diff --cached --stat 2>/dev/null)
        if [ -n "$cached_stat" ]; then
            echo "### Staged Diff"
            echo "$cached_stat"
            echo
        fi

        echo "### Recent Commits"
        git log -10 --oneline 2>/dev/null
        echo
    )
}

# check_debug_levels: scan pgxntool shell scripts for invalid debug levels.
# Valid levels are single-digit (0-9) or multiples of 10 (10, 20, 30, ...).
# Two-digit levels that are NOT multiples of 10 (e.g., 11, 22, 25) are flagged.
check_debug_levels() {
    local pgxntool_path="$1"
    local found_invalid=0

    while IFS= read -r -d '' sh_file; do
        while IFS= read -r match; do
            # Extract the level number from "debug NN"
            local level
            level=$(echo "$match" | grep -oE 'debug [0-9]+' | grep -oE '[0-9]+$')
            # Skip single-digit levels (always valid)
            [ ${#level} -le 1 ] && continue
            # Flag multi-digit levels that are not multiples of 10
            if [ $((level % 10)) -ne 0 ]; then
                if [ "$found_invalid" -eq 0 ]; then
                    echo "### SANITY: Invalid debug levels detected"
                    found_invalid=1
                fi
                echo "  $sh_file: debug $level"
            fi
        done < <(grep -nE '\bdebug [0-9]+\b' "$sh_file" 2>/dev/null || true)
    done < <(find "$pgxntool_path" -maxdepth 1 -name "*.sh" -print0 2>/dev/null)

    if [ "$found_invalid" -eq 0 ]; then
        echo "### SANITY: debug levels OK (all single-digit or multiples of 10)"
    fi
    echo
}

if [ $# -eq 0 ]; then
    echo "Usage: gather-repo-info.sh <repo-path> [<repo-path2> ...]" >&2
    exit 1
fi

for repo in "$@"; do
    if ! git -C "$repo" rev-parse --git-dir &>/dev/null; then
        echo "## $(basename "$repo")"
        echo "WARNING: Not a git repository: $repo"
        echo
        continue
    fi
    gather_info "$repo"
    echo "---"
    echo
done

# Run debug level check for pgxntool (first arg is expected to be pgxntool path)
if [ $# -ge 1 ] && [ -f "$1/lib.sh" ]; then
    echo "## Sanity Checks"
    check_debug_levels "$1"
fi
