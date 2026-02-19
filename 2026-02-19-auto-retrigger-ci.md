# Auto Retry CI & Migration Lint — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add `supabase db lint` CI to `amakaflow-db` and auto-retry-once workflow to all 8 Joshua repos.

**Architecture:** Two workflow files — `ci.yml` (amakaflow-db only) + `retrigger-ci.yml` (all 8 repos). Both deployed via GitHub Contents API. Reference copies committed to `amakaflow-dev-workspace`.

**Tech Stack:** GitHub Actions, Supabase CLI, `gh` CLI, bash

---

## Task 1: Create `retrigger-ci.yml` reference copy

**Files:**
- Create: `amakaflow-dev-workspace/.github/workflows/retrigger-ci.yml`

**Step 1: Write the workflow file**

Create `.github/workflows/retrigger-ci.yml` with this exact content:

```yaml
name: Auto Retry Failed CI (Joshua PRs)

on:
  workflow_run:
    workflows: ["CI", "PR CI (Impacted)", "Validate Linear Ticket"]
    types: [completed]

jobs:
  retry:
    if: |
      github.event.workflow_run.conclusion == 'failure' &&
      github.event.workflow_run.event == 'pull_request' &&
      github.event.workflow_run.run_attempt == 1 &&
      github.event.workflow_run.actor.login == 'openclawjoshua-eng'
    runs-on: ubuntu-latest
    permissions:
      actions: write

    steps:
      - name: Re-run failed jobs
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          gh run rerun ${{ github.event.workflow_run.id }} --failed --repo ${{ github.repository }}
```

**Step 2: Commit**

```bash
cd /Users/davidandrews/dev/AmakaFlow/amakaflow-dev-workspace
git add .github/workflows/retrigger-ci.yml
git commit -m "feat: add retrigger-ci workflow (reference copy)"
```

---

## Task 2: Create `amakaflow-db-ci.yml` reference copy

**Files:**
- Create: `amakaflow-dev-workspace/.github/workflows/amakaflow-db-ci.yml`

This is the migration lint workflow for `amakaflow-db` only. It is named `CI` when deployed so that `retrigger-ci.yml` covers it automatically.

**Step 1: Write the workflow file**

Create `.github/workflows/amakaflow-db-ci.yml` with this exact content:

```yaml
name: CI

on:
  pull_request:
    types: [opened, synchronize, reopened]
    paths:
      - 'supabase/migrations/**'
      - 'supabase/config.toml'

jobs:
  migration-lint:
    runs-on: ubuntu-latest
    permissions:
      contents: read

    steps:
      - uses: actions/checkout@v4

      - name: Setup Supabase CLI
        uses: supabase/setup-cli@v1
        with:
          version: latest

      - name: Lint migrations
        run: supabase db lint --schema public
```

**Step 2: Commit**

```bash
cd /Users/davidandrews/dev/AmakaFlow/amakaflow-dev-workspace
git add .github/workflows/amakaflow-db-ci.yml
git commit -m "feat: add amakaflow-db migration lint CI (reference copy)"
```

---

## Task 3: Deploy `retrigger-ci.yml` to all 8 Joshua repos

**Step 1: Get base64-encoded content**

```bash
CONTENT=$(base64 < /Users/davidandrews/dev/AmakaFlow/amakaflow-dev-workspace/.github/workflows/retrigger-ci.yml)
```

**Step 2: Deploy to each repo via GitHub API**

```bash
CONTENT=$(base64 < /Users/davidandrews/dev/AmakaFlow/amakaflow-dev-workspace/.github/workflows/retrigger-ci.yml)
BRANCH="feat/add-retrigger-ci"
REPOS=(
  "supergeri/mapper-api"
  "supergeri/amakaflow-ui"
  "supergeri/calendar-api"
  "supergeri/chat-api"
  "supergeri/strava-sync-api"
  "supergeri/workout-ingestor-api"
  "supergeri/amakaflow-db"
  "supergeri/amakaflow-android-app"
)

for REPO in "${REPOS[@]}"; do
  echo "--- $REPO ---"

  SHA=$(gh api "repos/$REPO/git/ref/heads/main" --jq '.object.sha' 2>/dev/null || \
        gh api "repos/$REPO/git/ref/heads/master" --jq '.object.sha')

  gh api --method POST "repos/$REPO/git/refs" \
    -f ref="refs/heads/$BRANCH" \
    -f sha="$SHA" 2>/dev/null || echo "Branch may already exist"

  FILE_SHA=$(gh api "repos/$REPO/contents/.github/workflows/retrigger-ci.yml" \
    --jq '.sha' 2>/dev/null || echo "")

  if [[ -n "$FILE_SHA" ]]; then
    gh api --method PUT "repos/$REPO/contents/.github/workflows/retrigger-ci.yml" \
      -f message="feat: add auto-retry CI workflow for Joshua PRs" \
      -f content="$CONTENT" \
      -f branch="$BRANCH" \
      -f sha="$FILE_SHA"
  else
    gh api --method PUT "repos/$REPO/contents/.github/workflows/retrigger-ci.yml" \
      -f message="feat: add auto-retry CI workflow for Joshua PRs" \
      -f content="$CONTENT" \
      -f branch="$BRANCH"
  fi

  gh pr create \
    --repo "$REPO" \
    --title "feat: add auto-retry CI for transient failures" \
    --body "Adds \`retrigger-ci.yml\` — automatically re-runs failed CI jobs on Joshua's PRs once, for transient failures (network blips, API timeouts).

Watches: \`CI\`, \`PR CI (Impacted)\`, \`Validate Linear Ticket\`
Conditions: first failure only (\`run_attempt == 1\`), Joshua PRs only (\`openclawjoshua-eng\`), silent (no comments)." \
    --base main \
    --head "$BRANCH" 2>/dev/null || echo "PR may already exist"

  echo "Done: $REPO"
done
```

**Step 3: Merge all PRs**

```bash
REPOS=(
  "supergeri/mapper-api"
  "supergeri/amakaflow-ui"
  "supergeri/calendar-api"
  "supergeri/chat-api"
  "supergeri/strava-sync-api"
  "supergeri/workout-ingestor-api"
  "supergeri/amakaflow-db"
  "supergeri/amakaflow-android-app"
)

for REPO in "${REPOS[@]}"; do
  PR=$(gh pr list --repo "$REPO" --head "feat/add-retrigger-ci" --json number --jq '.[0].number')
  if [[ -n "$PR" ]]; then
    gh pr merge "$PR" --repo "$REPO" --squash --delete-branch --admin 2>/dev/null || \
    gh pr merge "$PR" --repo "$REPO" --squash --delete-branch
    echo "Merged PR #$PR in $REPO"
  fi
done
```

---

## Task 4: Deploy `ci.yml` (migration lint) to `amakaflow-db`

**Step 1: Deploy via GitHub API**

```bash
CONTENT=$(base64 < /Users/davidandrews/dev/AmakaFlow/amakaflow-dev-workspace/.github/workflows/amakaflow-db-ci.yml)
BRANCH="feat/add-migration-ci"
REPO="supergeri/amakaflow-db"

SHA=$(gh api "repos/$REPO/git/ref/heads/main" --jq '.object.sha')

gh api --method POST "repos/$REPO/git/refs" \
  -f ref="refs/heads/$BRANCH" \
  -f sha="$SHA" 2>/dev/null || echo "Branch may already exist"

gh api --method PUT "repos/$REPO/contents/.github/workflows/ci.yml" \
  -f message="feat: add migration lint CI" \
  -f content="$CONTENT" \
  -f branch="$BRANCH"

gh pr create \
  --repo "$REPO" \
  --title "feat: add migration lint CI check" \
  --body "Adds \`ci.yml\` — runs \`supabase db lint --schema public\` on every Joshua PR that touches migrations.

Catches SQL syntax errors, bad RLS patterns, and type issues before merge. Fast (~30s), no secrets needed. Named \`CI\` so the \`retrigger-ci.yml\` auto-retry covers it automatically." \
  --base main \
  --head "$BRANCH"
```

**Step 2: Merge the PR**

```bash
PR=$(gh pr list --repo "supergeri/amakaflow-db" --head "feat/add-migration-ci" --json number --jq '.[0].number')
gh pr merge "$PR" --repo "supergeri/amakaflow-db" --squash --delete-branch --admin 2>/dev/null || \
gh pr merge "$PR" --repo "supergeri/amakaflow-db" --squash --delete-branch
echo "Merged PR #$PR"
```

---

## Task 5: Commit workspace changes and create PR

```bash
cd /Users/davidandrews/dev/AmakaFlow/amakaflow-dev-workspace

git add \
  .github/workflows/retrigger-ci.yml \
  .github/workflows/amakaflow-db-ci.yml \
  2026-02-19-auto-retrigger-ci.md

git commit -m "feat: add auto-retry CI and migration lint workflow reference copies"

git push origin main
```

---

## Task 6: Verify deployment

```bash
echo "=== retrigger-ci.yml ==="
for REPO in mapper-api amakaflow-ui calendar-api chat-api strava-sync-api workout-ingestor-api amakaflow-db amakaflow-android-app; do
  EXISTS=$(gh api "repos/supergeri/$REPO/contents/.github/workflows/retrigger-ci.yml" --jq '.name' 2>/dev/null || echo "MISSING")
  echo "$REPO: $EXISTS"
done

echo ""
echo "=== ci.yml (amakaflow-db) ==="
EXISTS=$(gh api "repos/supergeri/amakaflow-db/contents/.github/workflows/ci.yml" --jq '.name' 2>/dev/null || echo "MISSING")
echo "amakaflow-db: $EXISTS"
```

Expected:
- All 8 repos show `retrigger-ci.yml`
- `amakaflow-db` shows `ci.yml`
