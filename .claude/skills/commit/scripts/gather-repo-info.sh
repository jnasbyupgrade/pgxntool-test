#!/bin/bash
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
