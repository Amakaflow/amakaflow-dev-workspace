---
name: finish-issue
description: Use when implementation of a Linear issue is complete and you need to run tests, get a testing gap analysis, get a code review, create the PR, and confirm CI is green before declaring done. Invoke with the Linear issue ID (e.g. /finish-issue AMA-653).
---

# Finish Issue — Quality Gate Before PR

## Overview

Chains steps in order: run tests → testing-strategist gap analysis → code-reviewer → create PR → watch CI → fix any failures. The issue is not done until CI is green.

**Invoke as:** `/finish-issue AMA-NNN` (or just `/finish-issue` if already on the right branch)

---

## Step 1: Confirm Branch and Diff

```bash
git status
git diff main...HEAD --stat
```

Confirm you are on the feature branch for the issue. If on `main`, stop and ask David which branch to use.

---

## Step 2: Run Tests

Use the repo-specific command from this table:

| Repo | Test command | Run from |
|------|-------------|----------|
| `chat-api` | `pytest` | repo root |
| `amakaflow-ios-app` | `xcodebuild test -scheme AmakaFlowCompanion -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` | repo root |
| `amakaflow-android-app` | `./gradlew test` | repo root |
| `amakaflow-db` | `supabase db lint --schema public` | repo root |
| `amakaflow-automation` | `~/.maestro/bin/maestro test flows/` | repo root |
| other repos | `pytest` or check repo `CLAUDE.md` | repo root |

**If tests fail:** Fix failures before proceeding. Do NOT skip to PR creation.

Also run the linter:

| Repo | Lint command |
|------|-------------|
| `chat-api` | `ruff check . && ruff format --check .` |
| `amakaflow-android-app` | `./gradlew lint` |
| iOS/Swift repos | `swiftlint` (if configured) |

---

## Step 3: Dispatch testing-strategist Agent

Dispatch a `testing-strategist` subagent with this prompt (fill in the blanks):

```
Review the changes on branch [BRANCH_NAME] for Linear issue [AMA-NNN].

Diff summary:
[paste output of: git diff main...HEAD --stat]

Changed files (key ones):
[list key files changed]

Task: Identify any test coverage gaps. Are critical paths, edge cases, and error conditions covered? What's missing that should be tested before this ships?

Repo: [REPO_NAME]
```

**If the agent identifies critical gaps:** Add the missing tests before proceeding.
**If gaps are minor/cosmetic:** Note them in the PR description as follow-up work.

---

## Step 4: Dispatch code-reviewer Agent

Dispatch a `code-reviewer` subagent with this prompt:

```
Review the changes on branch [BRANCH_NAME] for Linear issue [AMA-NNN]: [ISSUE_TITLE].

Changed files:
[paste git diff main...HEAD --stat]

Focus on:
- Correctness and logic errors
- Security issues (auth bypasses, injection, secrets)
- Performance (N+1 queries, missing indexes, unbounded loops)
- API contract changes that could break mobile clients
- Code style and maintainability

Repo: [REPO_NAME]
Test results: All passing ✅
```

**If the reviewer flags blocking issues:** Fix them and re-run tests before proceeding.
**If the reviewer flags minor issues:** Include them in the PR description as follow-up.

---

## Step 5: (Optional) Dispatch e2e-qa-automation Agent

Only invoke this if the issue touches **user-facing flows** (new endpoints, changed request/response shapes, auth changes, or new UI screens).

Prompt:

```
Review the changes for [AMA-NNN] and identify which E2E test flows (if any) need to be added or updated.

Changed surfaces: [brief description — e.g. "new POST /knowledge/ingest endpoint"]
Existing E2E suite: amakaflow-automation/flows/
```

---

## Step 6: Create PR

```bash
git push -u origin [BRANCH_NAME]

gh pr create \
  --repo supergeri/[REPO] \
  --title "[type](ama-NNN): [short description]" \
  --body "..." \
  --base main \
  --head [BRANCH_NAME]
```

**PR body must include:**
- Summary (2-3 bullets: what changed and why)
- Test plan (checklist of what was tested)
- Any follow-up items flagged by testing-strategist or code-reviewer
- `Closes AMA-NNN`
- `🤖 Generated with [Claude Code](https://claude.com/claude-code)`

---

## Step 7: Watch CI and Fix Failures

After the PR is created, wait for CI and resolve any failures **before declaring the issue done**.

```bash
# Get the run ID for this branch (wait a few seconds after push for it to register)
RUN_ID=$(gh run list \
  --repo supergeri/[REPO] \
  --branch [BRANCH_NAME] \
  --limit 1 \
  --json databaseId \
  --jq '.[0].databaseId')

# Watch until complete (blocks until done)
gh run watch "$RUN_ID" --repo supergeri/[REPO]

# Check all PR checks
gh pr checks [PR_NUMBER] --repo supergeri/[REPO]
```

**If any check fails:**

```bash
# See exactly what failed
gh run view "$RUN_ID" --repo supergeri/[REPO] --log-failed
```

Then:
1. Read the failure output and identify the root cause
2. Fix the issue locally
3. Re-run tests (Step 2) to confirm the fix
4. Commit and push the fix
5. Repeat Step 7 — watch the new run until green

**Do NOT declare the issue done until `gh pr checks` shows all green.**

**Exception — transient CI crash** (e.g. `SDK execution error`, `rate limited`, network timeout): These are infrastructure failures, not code failures. Re-run with:

```bash
gh run rerun "$RUN_ID" --repo supergeri/[REPO] --failed
```

If the re-run passes, that's a transient failure — no code change needed.

---

## Quick Reference

```
/finish-issue AMA-NNN
  ↓
1. git diff main...HEAD --stat       ← confirm branch + scope
2. pytest / xcodebuild / gradlew     ← tests must pass locally
3. testing-strategist agent          ← coverage gaps
4. code-reviewer agent               ← code quality
5. e2e-qa-automation agent           ← only if user-facing changes
6. gh pr create                      ← PR with full body
7. gh run watch → gh pr checks       ← CI must be green
   └─ if fails: fix → push → repeat
```

---

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Declaring done before CI is green | Always run Step 7 — local tests ≠ CI |
| Re-running CI without reading the logs | Always read `--log-failed` first |
| Treating transient crash as a code bug | Check if it's infrastructure (SDK error, timeout) — just rerun |
| Creating PR before tests pass | Always run tests first — no exceptions |
| Skipping testing-strategist because "tests already exist" | Run it anyway — it catches gaps the implementer misses |
| Skipping code-reviewer on "small" changes | Small diffs have security issues too |
| PR body with no test plan | Always include a test plan checklist |
| Forgetting `Closes AMA-NNN` | Linear won't auto-close the ticket |
