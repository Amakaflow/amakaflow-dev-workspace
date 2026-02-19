---
name: finish-issue
description: Use when implementation of a Linear issue is complete and you need to run tests, get a testing gap analysis, get a code review, and create the PR. Invoke with the Linear issue ID (e.g. /finish-issue AMA-653).
---

# Finish Issue — Quality Gate Before PR

## Overview

Chains four steps in order: run tests → testing-strategist gap analysis → code-reviewer → create PR. Ensures no issue ships without passing tests, reviewed coverage, and a code quality pass.

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

## Quick Reference

```
/finish-issue AMA-NNN
  ↓
1. git diff main...HEAD --stat       ← confirm branch + scope
2. pytest / xcodebuild / gradlew     ← tests must pass
3. testing-strategist agent          ← coverage gaps
4. code-reviewer agent               ← code quality
5. e2e-qa-automation agent           ← only if user-facing changes
6. gh pr create                      ← PR with full body
```

---

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Creating PR before tests pass | Always run tests first — no exceptions |
| Skipping testing-strategist because "tests already exist" | Run it anyway — it catches gaps the implementer misses |
| Skipping code-reviewer on "small" changes | Small diffs have security issues too |
| PR body with no test plan | Always include a test plan checklist |
| Forgetting `Closes AMA-NNN` | Linear won't auto-close the ticket |
