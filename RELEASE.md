# RELEASE.md

How to cut a release of pgxntool, and what pgxntool-test's part in that is.
Written to be followed standalone, without Claude Code.

**This is not the general Postgres-Extensions release process.** That's
`../ai/RELEASE.md`, and it doesn't apply here mechanically: it's written for
repos that publish a PGXN-distributed extension via `make tag`/`make
dist`/a manual PGXN Manager upload. pgxntool is a build framework that gets
`git subtree`'d into *other* projects — it is not itself published to PGXN,
so none of that machinery (`META.in.json` version bookkeeping, `.zip`
uploads, per-extension version tracking) applies to pgxntool's own release.
A pgxntool release is just: a `HISTORY.asc` entry and a GitHub tag, gated by
CI in both this repo and pgxntool. This file documents that process — the
one genuine reason pgxntool-test carries a local `RELEASE.md` at all (see
`ai/RELEASE.md`'s own guidance on when that's warranted).

There is also a Claude Code skill (`.claude/skills/release/SKILL.md`) that
automates everything below when run with Claude Code. This document is the
same process, for a human running it by hand — read this if you're not
using that skill, or if you want to understand what it's actually doing.

## What "releasing pgxntool-test" actually means

**pgxntool-test has no version of its own.** It has no `HISTORY.asc`, no
version file, nothing that gets stamped. Releasing it does not change
anything in this repo's master branch at all.

What "release" means for this repo is two things, both purely mechanical:

1. **A throwaway pull request that exists only to trigger this repo's CI**
   against the real release content, and gets closed unmerged once its CI
   run is green.
2. **A git tag**, placed directly on pgxntool-test's current master, with
   the exact same version number as the pgxntool release it's paired with.

### Why the throwaway PR is necessary

pgxntool's release PR only ever touches `HISTORY.asc`/`README.asc`/
`README.html` — it's doc-only. pgxntool's own CI (`check-test-pr` job)
unconditionally skips the real Postgres test matrix for a doc-only PR, with
no fallback to testing against master, regardless of whether a paired
pgxntool-test PR exists. Left alone, that means the actual release content
would get **zero** real test coverage before merging.

pgxntool-test's CI provides that coverage instead. An empty commit on a
same-named `release-VERSION` branch here is *not* doc-only by this repo's
own check (zero changed files trips a different guard), so its `test` job
runs for real — and that job resolves and tests against the paired
`release-VERSION` branch in pgxntool by name and account. So the actual
release content gets exercised through pgxntool-test's test job, not
pgxntool's.

This PR must never be merged — it changes nothing pgxntool-test wants on
its master. It exists purely to make CI run.

## Deciding the version number

There is exactly one version number per release, decided once, for
pgxntool. pgxntool-test never makes an independent version decision — its
tag is just a marker that reuses whatever number was picked for pgxntool.

Pick the number by reading pgxntool's `HISTORY.asc` `STABLE` section (the
heading holding unreleased changes) and applying ordinary semantic
versioning to what's actually in it:

- Anything that could break an existing consumer's build, tests, or
  behavior → bump the **major** version.
- A new backward-compatible feature or addition (new target, variable,
  script) with no breaking change → bump the **minor** version.
- Bugfixes only, nothing added or changed in behavior → bump the **patch**
  version.

If the `STABLE` section mixes categories, the highest one that applies
wins (a release with one breaking change and five bugfixes is still a
major bump). Version numbers are unprefixed (`2.3.0`, never `v2.3.0`).

If `HISTORY.asc`'s top section is already a real version number (nothing
unreleased yet), there is nothing to release — add a `STABLE` section
first, even if it starts out documenting nothing.

## Before you start

- [ ] Both `../pgxntool` and this repo (`pgxntool-test`) have a clean
      working tree, are on `master`, and are up to date with their
      `Postgres-Extensions` remote (fetch and fast-forward both; if either
      has genuinely diverged, resolve that by hand before continuing — do
      not force or merge past it).
- [ ] Confirm the remote name pointing at `Postgres-Extensions/<repo>` in
      each checkout — `git remote -v`. It's `upstream` in a typical setup,
      but don't assume; the commands below call it `UPSTREAM` as a
      placeholder for whatever `git remote -v` actually shows.
- [ ] The chosen version isn't already tagged in either repo (`git tag -l
      VERSION`).
- [ ] **Confirm pgxntool-test's CI still runs the full test suite** — this
      whole process leans on it for real Postgres coverage of the release
      (see above), and this has silently regressed once before (found
      running only `make test`, silently excluding `test/extra/`).
      Check `.github/workflows/run-tests.yml` — the `Run tests` step must
      read `make test-all`, not `make test` or `make test-extra`. Then
      check a recent successful CI run actually agrees: `make test`/`make
      test-extra` both print a `Tip: Use 'make test-extra' ... or 'make
      test-all' for everything` banner; `make test-all` never does. Pull a
      recent green run's log and confirm that banner is absent. If either
      check disagrees with `make test-all`, stop and fix `run-tests.yml`
      before releasing — this is a testing-infrastructure gap, not
      something to route around release by release.
- [ ] Optional but recommended: review pgxntool's user-facing surface
      (make targets, `PGXNTOOL_*` variables, scripts — see this repo's
      `CLAUDE.md`, "User-Facing API Surface of pgxntool") against
      `README.asc` and against the `STABLE` section, looking for behavior
      changes that aren't documented anywhere. Fix any gaps you find
      before stamping.

## 1. Create the release branches

Same branch name in both repos:

```bash
cd ../pgxntool && git checkout -b release-VERSION
cd ../pgxntool-test && git checkout -b release-VERSION
```

## 2. Stamp pgxntool's HISTORY.asc

In `../pgxntool/HISTORY.asc`, replace the `STABLE` heading with the version
number you picked above (match the dashes underneath to the new heading's
length):

```text
STABLE           VERSION
------    ->     -------
```

Commit:

```bash
cd ../pgxntool && git commit -am "Stamp VERSION"
```

Sanity-check it took effect — this is what lets CI catch a bad stamp before
it ever reaches a PR:

```bash
../pgxntool/bin/version
```

The output must be exactly `VERSION`. If it prints `STABLE`, an old
version, or errors, the edit above didn't take effect — fix it before
continuing.

## 3. Push both branches and open both PRs

**Never push either branch straight to master.** Both repos' CI only
triggers on `pull_request` — a direct push to `master` never runs CI at
all.

pgxntool-test's branch carries no real change, just an empty commit to
trigger CI:

```bash
cd ../pgxntool-test
git commit --allow-empty -m "Stamp VERSION"
git push UPSTREAM release-VERSION
gh pr create --repo Postgres-Extensions/pgxntool-test \
  --base master --head release-VERSION \
  --title "DO NOT MERGE: Release VERSION (CI trigger only)" \
  --body "This PR exists only to trigger a real CI test run of the paired \
pgxntool release-VERSION branch — pgxntool's own release PR is doc-only \
and skips the Postgres test matrix entirely. It changes nothing in \
pgxntool-test (empty commit) and must NOT be merged. Close it once its CI \
is green.

Companion PR (should be merged normally once CI is green): \
Postgres-Extensions/pgxntool#<pgxntool-pr-number>"
```

```bash
cd ../pgxntool
git push UPSTREAM release-VERSION
gh pr create --repo Postgres-Extensions/pgxntool \
  --base master --head release-VERSION \
  --title "Release VERSION" \
  --body "Stamps HISTORY.asc for VERSION. This PR should be merged normally.

Companion PR (must NOT be merged — exists only to trigger a real CI test \
run): Postgres-Extensions/pgxntool-test#<pgxntool-test-pr-number>"
```

Once both PRs exist, edit whichever body was written first to fill in the
other PR's now-known number (`gh pr edit --body`).

## 4. Wait for CI, then hand off for human review

Watch both PRs' checks (`gh pr checks`). **pgxntool-test's run is where the
real Postgres test coverage of this release actually lives** — treat a
failure there as a real failure of the release content, not a formality.
pgxntool's own test job is expected to show as skipped (doc-only PR) —
that's normal, not a problem.

If pgxntool's `check-test-pr` job fails instead of skipping (shouldn't
happen for a doc-only diff, but possible if this release needed a non-doc
file change): a maintainer needs to apply the `commit-with-no-tests` label
to that PR by hand. That's a maintainer-gated action, not something to
route around.

**Then stop and wait for a human to actually merge pgxntool's release PR
through the normal GitHub review process.** Nothing past this point
happens until that merge lands.

## 5. Tag both repos

Only after pgxntool's release PR is merged, and pgxntool-test's CI-trigger
PR's CI is green.

pgxntool's tag must point at what actually landed on master, not the
pre-merge branch tip — a squash or rebase-on-merge can change that:

```bash
cd ../pgxntool
git fetch UPSTREAM master
git checkout master
git merge --ff-only UPSTREAM/master
head -n1 HISTORY.asc   # must read exactly VERSION — stop if it doesn't
git tag VERSION
git push UPSTREAM VERSION
```

pgxntool-test's master never changed — its PR is never merged — so this is
just confirming local master hasn't drifted before tagging it directly:

```bash
cd ../pgxntool-test
git fetch UPSTREAM master
git checkout master
git merge --ff-only UPSTREAM/master
git tag VERSION
git push UPSTREAM VERSION
```

## 6. Move the floating `release` tag

Both repos keep a moving `release` tag pointing at the latest release.
Force-pushing a tag is expected here — this is the one place in this
process it's the correct action:

```bash
cd ../pgxntool
git tag -f release VERSION
git push UPSTREAM -f refs/tags/release
```

```bash
cd ../pgxntool-test
git tag -f release VERSION
git push UPSTREAM -f refs/tags/release
```

## 7. Clean up

pgxntool: delete the now-merged local release branch.

```bash
cd ../pgxntool && git branch -d release-VERSION
```

pgxntool-test: the release branch was never merged. Close its CI-trigger
PR without merging and delete the branch on both ends:

```bash
cd ../pgxntool-test
gh pr close --repo Postgres-Extensions/pgxntool-test --delete-branch release-VERSION
git branch -D release-VERSION   # if still checked out locally
```

## 8. Verify

- <https://github.com/Postgres-Extensions/pgxntool/releases/tag/VERSION>
- <https://github.com/Postgres-Extensions/pgxntool-test/releases/tag/VERSION>

Both should show the new tag. pgxntool-test's tag will show no file
changes versus its previous release — that's expected; nothing in this
repo's content is part of what's being released.

## If something goes wrong partway through

- **A release PR's CI fails**: fix the problem on the `release-VERSION`
  branch and push again — don't close the PR and open a new one, and don't
  fall back to pushing straight to master.
- **pgxntool's PR is merged but pgxntool-test's CI-trigger PR hasn't gone
  green yet (or vice versa)**: expected with a manual hand-off, not a
  failure. Wait for both before tagging either repo — don't tag one
  without the other.
- **The push of a release branch itself fails**: local state is fine, just
  retry the push.
