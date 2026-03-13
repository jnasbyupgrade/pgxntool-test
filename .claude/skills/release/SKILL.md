---
name: release
description: |
  Create a release for pgxntool and pgxntool-test. Handles version tagging,
  HISTORY.asc updates, and pushing to the main Postgres-Extensions GitHub repos.

  Use when user says "release", "create release", "tag version", or "/release"
allowed-tools: Bash(.claude/skills/release/scripts/release-preflight.sh:*), Bash(git tag:*), Bash(git commit:*), Bash(git push:*), Bash(git checkout:*), Bash(git status:*), Bash(git log:*), Bash(git remote:*), Bash(git rev-parse:*), Bash(git branch:*), Bash(git fetch:*), Bash(git diff:*), Read, Edit
---

# /release

Create a release for pgxntool and pgxntool-test.

**Usage:** `/release [VERSION]`

## Terminology

- **STABLE section**: The heading in `HISTORY.asc` where unreleased changes are documented. During a release, this heading is replaced with the version number. This has nothing to do with git branches.
- **UPSTREAM_REMOTE**: The local git remote pointing to the main project repos at `https://github.com/Postgres-Extensions/`. Releases must be pushed here -- never to a fork. The remote name varies; it is identified by URL pattern in the pre-flight script.

---

## Step 1: Run Pre-flight Checks

Run the pre-flight script, passing VERSION if provided:

```bash
.claude/skills/release/scripts/release-preflight.sh [VERSION]
```

The script checks:
1. Upstream remotes exist (pointing to Postgres-Extensions)
2. Both working directories are clean
3. Both repos are on master
4. Local master is in sync with upstream
5. Version format is valid and tag doesn't already exist
6. HISTORY.asc has a STABLE section

**If the script exits with errors:** STOP and show the errors to the user.

**If there are warnings:** Show them and ask the user how to proceed.

**Extract remote names** from the script output (last section):
- `PGXNTOOL_UPSTREAM` - remote name for pgxntool (e.g., "upstream")
- `PGXNTOOL_TEST_UPSTREAM` - remote name for pgxntool-test (e.g., "upstream")

## Step 2: Determine Version Number

If VERSION was not provided as an argument, ask the user:

Use AskUserQuestion:
- Header: "Version"
- Question: "What version number should this release be?"
- Provide options based on current version in pgxntool's HISTORY.asc

**Then re-run pre-flight** with the chosen version to validate it:
```bash
.claude/skills/release/scripts/release-preflight.sh VERSION
```

## Step 3: Confirm HISTORY.asc

Read `../pgxntool/HISTORY.asc` and show the user what's in the STABLE section.

**If no STABLE section exists:**
- Warn: "No STABLE section found. No changes are documented for this release."
- Ask user if they want to continue using AskUserQuestion.

## Step 4: Update HISTORY.asc and Commit

1. Edit `../pgxntool/HISTORY.asc`: Replace the `STABLE` heading with the version number

   Replace:
   ```
   STABLE
   ------
   ```
   With:
   ```
   VERSION
   -------
   ```
   (Adjust dashes to match version string length)

2. Commit:
   ```bash
   cd ../pgxntool && git commit -am "Stamp VERSION"
   ```

## Step 5: Tag and Push pgxntool

**CRITICAL: Push to the Postgres-Extensions remote, not to a fork.**

```bash
cd ../pgxntool
git tag VERSION
git push PGXNTOOL_UPSTREAM master
git push PGXNTOOL_UPSTREAM VERSION
```

## Step 6: Tag and Push pgxntool-test

**CRITICAL: Push to the Postgres-Extensions remote, not to a fork.**

```bash
cd ../pgxntool-test
git tag VERSION
```

Check if there are unpushed commits:
```bash
git rev-parse HEAD
git rev-parse PGXNTOOL_TEST_UPSTREAM/master
```

```bash
git push PGXNTOOL_TEST_UPSTREAM master  # Only if there are unpushed commits
git push PGXNTOOL_TEST_UPSTREAM VERSION
```

Note: pgxntool-test may or may not have new commits since the last release. The tag goes on whatever master currently points to. Do NOT create an empty commit just for the tag.

## Step 7: Update `release` Tag

Both repos have a `release` tag on upstream that must always point to the latest
release. This is a moving tag that requires force-push to update.

```bash
cd ../pgxntool
git tag -f release VERSION
git push PGXNTOOL_UPSTREAM -f refs/tags/release
```

```bash
cd ../pgxntool-test
git tag -f release VERSION
git push PGXNTOOL_TEST_UPSTREAM -f refs/tags/release
```

## Step 8: Verify and Report

```bash
cd ../pgxntool && git checkout master
cd ../pgxntool-test && git checkout master
```

Output:

```
Release VERSION complete!

pgxntool:
- HISTORY.asc stamped with VERSION
- Tag VERSION created and pushed to PGXNTOOL_UPSTREAM
- release tag updated to VERSION

pgxntool-test:
- Tag VERSION created and pushed to PGXNTOOL_TEST_UPSTREAM
- release tag updated to VERSION

Verify releases:
- https://github.com/Postgres-Extensions/pgxntool/releases/tag/VERSION
- https://github.com/Postgres-Extensions/pgxntool-test/releases/tag/VERSION
```

---

## Error Handling

**If any git operation fails:**
- Stop immediately
- Show the error
- Show current state of BOTH repos: `git status`, `git branch`, `git log -1`
- Provide recovery instructions
- Note which repo failed and what state the other repo is in

**Rollback guidance if partial failure:**
- If pgxntool push succeeded but pgxntool-test failed:
  - Note that pgxntool is already released
  - Provide commands to manually complete pgxntool-test release
- If failure during push:
  - Local state is complete, just need to retry push

**Common issues:**
- "Push rejected": Upstream has changes. Need to pull first.
- "Tag already exists": Version was already released. Choose different version.
- "Permission denied": Check GitHub permissions.
