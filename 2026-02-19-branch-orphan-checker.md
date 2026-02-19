# Branch Orphan Checker Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a daily GitHub Actions workflow to `amakaflow-dev-workspace` that detects `feature/AMA-*` and `fix/AMA-*` branches older than 2 days with no open PR, and creates/updates a consolidated GitHub Issue as the alert.

**Architecture:** Single workflow in `amakaflow-dev-workspace/.github/workflows/branch-orphan-checker.yml`. It uses a PAT (`GH_PAT`) to scan 8 Joshua repos for orphan branches, then creates or updates one GitHub Issue (label: `branch-orphan`) in `amakaflow-dev-workspace`. Runs daily at 09:00 UTC; also has `workflow_dispatch` for manual testing.

**Tech Stack:** GitHub Actions, `gh` CLI (pre-installed on `ubuntu-latest`), bash

---

## Prerequisite: Add GH_PAT secret

Before running this workflow, David must add a GitHub PAT to `amakaflow-dev-workspace`:

1. Go to GitHub → Settings → Developer Settings → Personal Access Tokens → Fine-grained tokens (or Classic with `repo` scope)
2. Create a token with **read access** to all `supergeri/*` repos, plus **Issues: read/write** on `amakaflow-dev-workspace`
   - Classic token: `repo` scope is sufficient
3. Add it as a secret named `GH_PAT` on `supergeri/amakaflow-dev-workspace`:
   ```bash
   gh secret set GH_PAT --repo supergeri/amakaflow-dev-workspace
   ```

---

## Task 1: Create the workflow file

**Files:**
- Create: `amakaflow-dev-workspace/.github/workflows/branch-orphan-checker.yml`

**Step 1: Create the directory**

```bash
mkdir -p /Users/davidandrews/dev/AmakaFlow/amakaflow-dev-workspace/.github/workflows
```

**Step 2: Write the workflow file**

Create `.github/workflows/branch-orphan-checker.yml` with this exact content:

```yaml
name: Branch Orphan Checker

on:
  schedule:
    - cron: '0 9 * * *'  # 09:00 UTC daily
  workflow_dispatch:      # Manual trigger for testing

jobs:
  check-orphans:
    runs-on: ubuntu-latest
    permissions:
      issues: write

    steps:
      - name: Scan for orphan branches
        id: scan
        env:
          GH_TOKEN: ${{ secrets.GH_PAT }}
        run: |
          REPOS=(
            "mapper-api"
            "amakaflow-ui"
            "calendar-api"
            "chat-api"
            "strava-sync-api"
            "workout-ingestor-api"
            "amakaflow-db"
            "amakaflow-android-app"
          )

          ORPHAN_LIST=""
          CUTOFF=$(date -d '2 days ago' --iso-8601=seconds)

          for REPO in "${REPOS[@]}"; do
            echo "Scanning supergeri/$REPO ..."

            # Get all feature/AMA-* and fix/AMA-* branches
            BRANCHES=$(gh api "repos/supergeri/$REPO/branches?per_page=100" \
              --paginate \
              --jq '.[] | select(.name | test("^(feature|fix)/AMA-")) | .name' \
              2>/dev/null || true)

            while IFS= read -r BRANCH; do
              [[ -z "$BRANCH" ]] && continue

              # Get last commit date on this branch
              # URL-encode the slash in the branch name for the API path
              ENCODED=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "$BRANCH")
              COMMIT_DATE=$(gh api "repos/supergeri/$REPO/branches/$ENCODED" \
                --jq '.commit.commit.committer.date' \
                2>/dev/null || true)

              [[ -z "$COMMIT_DATE" ]] && continue

              # Skip if newer than cutoff (string comparison works for ISO-8601)
              if [[ "$COMMIT_DATE" > "$CUTOFF" ]]; then
                continue
              fi

              # Check if there is an open PR for this branch
              PR_COUNT=$(gh pr list \
                --repo "supergeri/$REPO" \
                --head "$BRANCH" \
                --state open \
                --json number \
                --jq 'length' \
                2>/dev/null || echo "0")

              if [[ "$PR_COUNT" == "0" ]]; then
                SHORT_DATE="${COMMIT_DATE:0:10}"
                ORPHAN_LIST="${ORPHAN_LIST}- \`${BRANCH}\` in \`supergeri/${REPO}\` — last commit ${SHORT_DATE}\n"
              fi
            done <<< "$BRANCHES"
          done

          # Write multiline output safely
          {
            echo "orphans<<ORPHAN_EOF"
            printf "%b" "$ORPHAN_LIST"
            echo "ORPHAN_EOF"
          } >> "$GITHUB_OUTPUT"

          if [[ -n "$ORPHAN_LIST" ]]; then
            echo "has_orphans=true" >> "$GITHUB_OUTPUT"
          else
            echo "has_orphans=false" >> "$GITHUB_OUTPUT"
          fi

      - name: Manage GitHub Issue
        env:
          GH_TOKEN: ${{ secrets.GH_PAT }}
          ORPHANS: ${{ steps.scan.outputs.orphans }}
          HAS_ORPHANS: ${{ steps.scan.outputs.has_orphans }}
        run: |
          REPO="supergeri/amakaflow-dev-workspace"
          LABEL="branch-orphan"
          TODAY=$(date +%Y-%m-%d)

          # Ensure label exists (idempotent)
          gh label create "$LABEL" \
            --repo "$REPO" \
            --color "e4e669" \
            --description "Feature/fix branch with no open PR" \
            2>/dev/null || true

          # Find existing open issue with this label
          EXISTING_NUMBER=$(gh issue list \
            --repo "$REPO" \
            --label "$LABEL" \
            --state open \
            --json number \
            --jq '.[0].number' \
            2>/dev/null || true)

          if [[ "$HAS_ORPHANS" == "false" ]]; then
            echo "No orphans found."
            if [[ -n "$EXISTING_NUMBER" ]]; then
              gh issue close "$EXISTING_NUMBER" \
                --repo "$REPO" \
                --comment "All clear as of ${TODAY} — no orphan branches detected."
              echo "Closed issue #${EXISTING_NUMBER}"
            fi
          else
            BODY="## Orphan Branches Detected\n\nThe following branches are **older than 2 days with no open PR**:\n\n${ORPHANS}\n---\n**Action required:** Either open a PR for the branch or delete it.\n\n_Last checked: ${TODAY}_"

            if [[ -n "$EXISTING_NUMBER" ]]; then
              # Update body in-place and add a comment
              gh issue edit "$EXISTING_NUMBER" \
                --repo "$REPO" \
                --body "$(printf '%b' "$BODY")"
              gh issue comment "$EXISTING_NUMBER" \
                --repo "$REPO" \
                --body "Still detecting orphan branches as of ${TODAY}. Updated issue body with current list."
              echo "Updated issue #${EXISTING_NUMBER}"
            else
              gh issue create \
                --repo "$REPO" \
                --title "Orphan branches detected — ${TODAY}" \
                --body "$(printf '%b' "$BODY")" \
                --label "$LABEL"
              echo "Created new orphan issue"
            fi
          fi
```

**Step 3: Commit**

```bash
cd /Users/davidandrews/dev/AmakaFlow/amakaflow-dev-workspace
git checkout -b feat/branch-orphan-checker
git add .github/workflows/branch-orphan-checker.yml
git commit -m "feat: add daily branch orphan checker workflow"
```

---

## Task 2: Push and create PR

**Step 1: Push branch**

```bash
cd /Users/davidandrews/dev/AmakaFlow/amakaflow-dev-workspace
git push -u origin feat/branch-orphan-checker
```

**Step 2: Create PR**

```bash
gh pr create \
  --repo supergeri/amakaflow-dev-workspace \
  --title "feat: daily branch orphan checker" \
  --body "Adds a scheduled GitHub Actions workflow that scans all Joshua repos for \`feature/AMA-*\` and \`fix/AMA-*\` branches older than 2 days with no open PR.

## What it does
- Runs daily at 09:00 UTC (+ manual trigger via \`workflow_dispatch\`)
- Scans: mapper-api, amakaflow-ui, calendar-api, chat-api, strava-sync-api, workout-ingestor-api, amakaflow-db, amakaflow-android-app
- Creates a GitHub Issue in this repo (label: \`branch-orphan\`) listing all orphans
- Updates the issue in place on subsequent runs; auto-closes when all clear

## Prerequisites
- Add \`GH_PAT\` secret to this repo (classic PAT with \`repo\` scope)"
```

---

## Task 3: Test via workflow_dispatch

After the PR is merged (or on the branch directly):

**Step 1: Trigger manually**

```bash
gh workflow run branch-orphan-checker.yml \
  --repo supergeri/amakaflow-dev-workspace
```

**Step 2: Watch the run**

```bash
gh run list --repo supergeri/amakaflow-dev-workspace --workflow branch-orphan-checker.yml --limit 1
# Get the run ID from the output, then:
gh run watch <RUN_ID> --repo supergeri/amakaflow-dev-workspace
```

**Step 3: Verify output**

Expected outcomes:
- If orphans exist: A GitHub Issue is created in `supergeri/amakaflow-dev-workspace` with label `branch-orphan` listing the branches
- If no orphans: The run completes successfully with "No orphans found." in the logs and no issue is created (or existing issue is closed)

```bash
gh issue list --repo supergeri/amakaflow-dev-workspace --label branch-orphan
```

**Step 4: Fix if scan fails**

Common failure modes:
- `GH_PAT` not set → run fails at "Scan for orphan branches" step. Fix: add the secret.
- Repo not found → check repo name spelling in the `REPOS` array
- Branch URL encoding error → the python3 URL-encode line handles `feature/AMA-*` slashes; verify python3 is available (it is on ubuntu-latest)
