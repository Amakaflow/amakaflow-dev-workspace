# Joshua Ticket Quality Enforcement — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Enforce ticket quality for Joshua's work via a CI validator that hard-blocks PR merges when the linked Linear ticket is missing required sections, plus a Claude Code skill that guarantees tickets are well-formed at creation time.

**Architecture:** Two parts — (1) a `validate-ticket.yml` GitHub Actions workflow deployed to all 8 Joshua repos that fetches the Linear ticket and checks 5 required sections, failing the CI check if any are missing; (2) a `create-joshua-ticket` Claude Code skill in `amakaflow-dev-workspace` that David uses to generate fully-formed tickets via MCP.

**Tech Stack:** GitHub Actions, Linear GraphQL API, `actions/github-script`, bash, Claude Code skills (SKILL.md)

---

## Prerequisite: Add LINEAR_API_KEY secret

**This must be done before Task 2.**

1. Go to [linear.app](https://linear.app) → Settings → API → Personal API keys → Create key
2. Add it as an **org-level** secret (applies to all repos automatically):
   ```bash
   gh secret set LINEAR_API_KEY --org supergeri
   ```
3. Verify:
   ```bash
   gh secret list --org supergeri
   # Should show: LINEAR_API_KEY
   ```

---

## Task 1: Create the `validate-ticket.yml` workflow

**Files:**
- Create: `amakaflow-dev-workspace/.github/workflows/validate-ticket.yml` (reference copy)

**Step 1: Write the workflow file**

Create `.github/workflows/validate-ticket.yml` with this exact content:

```yaml
name: Validate Linear Ticket

on:
  pull_request:
    types: [opened, synchronize, reopened]

jobs:
  validate-ticket:
    if: github.event.pull_request.user.login == 'openclawjoshua-eng'
    runs-on: ubuntu-latest
    permissions:
      pull-requests: write

    steps:
      - name: Extract ticket and validate
        id: validate
        env:
          LINEAR_API_KEY: ${{ secrets.LINEAR_API_KEY }}
          BRANCH: ${{ github.head_ref }}
        run: |
          # Extract AMA-NNN from branch name (e.g. feature/AMA-668-some-title → AMA-668)
          TICKET_ID=$(echo "$BRANCH" | grep -oE 'AMA-[0-9]+' | head -1)

          if [[ -z "$TICKET_ID" ]]; then
            echo "No AMA-NNN found in branch '$BRANCH' — skipping"
            echo "skip=true" >> "$GITHUB_OUTPUT"
            exit 0
          fi

          TICKET_NUMBER=$(echo "$TICKET_ID" | grep -oE '[0-9]+')
          echo "ticket_id=$TICKET_ID" >> "$GITHUB_OUTPUT"
          echo "skip=false" >> "$GITHUB_OUTPUT"

          # Fetch ticket description from Linear GraphQL API
          RESPONSE=$(curl -s -X POST https://api.linear.app/graphql \
            -H "Authorization: $LINEAR_API_KEY" \
            -H "Content-Type: application/json" \
            -d "{\"query\": \"{ issues(filter: { number: { eq: $TICKET_NUMBER } }) { nodes { identifier description } } }\"}")

          DESCRIPTION=$(echo "$RESPONSE" | python3 -c "
          import sys, json
          data = json.load(sys.stdin)
          nodes = data.get('data', {}).get('issues', {}).get('nodes', [])
          print(nodes[0]['description'] if nodes else '')
          ")

          if [[ -z "$DESCRIPTION" ]]; then
            echo "Could not fetch $TICKET_ID from Linear — skipping"
            echo "skip=true" >> "$GITHUB_OUTPUT"
            exit 0
          fi

          FAILURES=""

          # Check 1: Repo specified
          if ! echo "$DESCRIPTION" | grep -qi "## Repo:"; then
            FAILURES="${FAILURES}\n- Missing \`## Repo:\` — specify which repository"
          fi

          # Check 2: Explicit file paths
          if ! echo "$DESCRIPTION" | grep -qE '(src|app|api|lib|test|spec)/|\*\*File:\*\*'; then
            FAILURES="${FAILURES}\n- Missing explicit file paths — add \`**File:**\` entries"
          fi

          # Check 3: Acceptance criteria section
          if ! echo "$DESCRIPTION" | grep -qi "## Acceptance Criteria"; then
            FAILURES="${FAILURES}\n- Missing \`## Acceptance Criteria\` section"
          fi

          # Check 4: Checkboxes
          if ! echo "$DESCRIPTION" | grep -qF '- [ ]'; then
            FAILURES="${FAILURES}\n- Acceptance criteria has no \`- [ ]\` checkboxes"
          fi

          # Check 5: Test command
          if ! echo "$DESCRIPTION" | grep -qE '(pytest|gradlew|npm test|yarn test|cargo test|go test|jest)'; then
            FAILURES="${FAILURES}\n- Missing test command (pytest / gradlew / npm test / etc.)"
          fi

          if [[ -n "$FAILURES" ]]; then
            echo "has_failures=true" >> "$GITHUB_OUTPUT"
            printf "%b" "$FAILURES" > /tmp/failures.txt
          else
            echo "has_failures=false" >> "$GITHUB_OUTPUT"
          fi

      - name: Post result comment
        if: steps.validate.outputs.skip != 'true'
        uses: actions/github-script@v7
        env:
          TICKET_ID: ${{ steps.validate.outputs.ticket_id }}
          HAS_FAILURES: ${{ steps.validate.outputs.has_failures }}
        with:
          script: |
            const marker = '<!-- ticket-validator -->';
            const ticketId = process.env.TICKET_ID;
            const hasFail = process.env.HAS_FAILURES === 'true';

            let failures = '';
            if (hasFail) {
              const fs = require('fs');
              failures = fs.readFileSync('/tmp/failures.txt', 'utf8').trim();
            }

            const body = hasFail
              ? `${marker}\n## ❌ Ticket Validation Failed\n\nThe linked Linear ticket **${ticketId}** is missing required sections. Joshua cannot reliably implement this without complete specs.\n\n**Missing:**\n${failures}\n\n**Fix:** Update the ticket in Linear, then re-push to re-run this check.`
              : `${marker}\n## ✅ Ticket Validated\n\n**${ticketId}** has all required sections: repo, file paths, acceptance criteria, checkboxes, and test command.`;

            const { data: comments } = await github.rest.issues.listComments({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.issue.number
            });

            const existing = comments.find(c => c.body.includes(marker));

            if (existing) {
              await github.rest.issues.updateComment({
                owner: context.repo.owner,
                repo: context.repo.repo,
                comment_id: existing.id,
                body
              });
            } else {
              await github.rest.issues.createComment({
                owner: context.repo.owner,
                repo: context.repo.repo,
                issue_number: context.issue.number,
                body
              });
            }

            if (hasFail) {
              core.setFailed(`Ticket ${ticketId} is missing required sections — see PR comment for details.`);
            }
```

**Step 2: Commit**

```bash
cd /Users/davidandrews/dev/AmakaFlow/amakaflow-dev-workspace
git add .github/workflows/validate-ticket.yml
git commit -m "feat: add validate-ticket workflow (reference copy)"
```

---

## Task 2: Deploy validate-ticket.yml to all 8 Joshua repos

**Repos:**
- `supergeri/mapper-api`
- `supergeri/amakaflow-ui`
- `supergeri/calendar-api`
- `supergeri/chat-api`
- `supergeri/strava-sync-api`
- `supergeri/workout-ingestor-api`
- `supergeri/amakaflow-db`
- `supergeri/amakaflow-android-app`

**Step 1: Get the base64-encoded workflow content**

```bash
CONTENT=$(base64 < /Users/davidandrews/dev/AmakaFlow/amakaflow-dev-workspace/.github/workflows/validate-ticket.yml)
```

**Step 2: Deploy to each repo via GitHub API**

Run this script (deploys to a branch, creates and merges a PR in each repo):

```bash
CONTENT=$(base64 < /Users/davidandrews/dev/AmakaFlow/amakaflow-dev-workspace/.github/workflows/validate-ticket.yml)
BRANCH="feat/add-ticket-validator"
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

  # Get default branch SHA
  SHA=$(gh api "repos/$REPO/git/ref/heads/main" --jq '.object.sha' 2>/dev/null || \
        gh api "repos/$REPO/git/ref/heads/master" --jq '.object.sha')

  # Create branch
  gh api --method POST "repos/$REPO/git/refs" \
    -f ref="refs/heads/$BRANCH" \
    -f sha="$SHA" 2>/dev/null || echo "Branch may already exist"

  # Check if file already exists (get its SHA for update)
  FILE_SHA=$(gh api "repos/$REPO/contents/.github/workflows/validate-ticket.yml" \
    --jq '.sha' 2>/dev/null || echo "")

  # Create or update file
  if [[ -n "$FILE_SHA" ]]; then
    gh api --method PUT "repos/$REPO/contents/.github/workflows/validate-ticket.yml" \
      -f message="feat: add validate-ticket CI workflow" \
      -f content="$CONTENT" \
      -f branch="$BRANCH" \
      -f sha="$FILE_SHA"
  else
    gh api --method PUT "repos/$REPO/contents/.github/workflows/validate-ticket.yml" \
      -f message="feat: add validate-ticket CI workflow" \
      -f content="$CONTENT" \
      -f branch="$BRANCH"
  fi

  # Create PR
  gh pr create \
    --repo "$REPO" \
    --title "feat: add Linear ticket validator CI check" \
    --body "Adds \`validate-ticket.yml\` — checks that Joshua's linked Linear ticket has all required sections (repo, file paths, acceptance criteria, checkboxes, test command) before allowing a PR to merge.

Requires \`LINEAR_API_KEY\` org secret (already set)." \
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
  PR=$(gh pr list --repo "$REPO" --head "feat/add-ticket-validator" --json number --jq '.[0].number')
  if [[ -n "$PR" ]]; then
    gh pr merge "$PR" --repo "$REPO" --squash --delete-branch
    echo "Merged PR #$PR in $REPO"
  fi
done
```

**Step 4: Verify deployment**

```bash
for REPO in mapper-api amakaflow-ui calendar-api chat-api strava-sync-api workout-ingestor-api amakaflow-db amakaflow-android-app; do
  EXISTS=$(gh api "repos/supergeri/$REPO/contents/.github/workflows/validate-ticket.yml" --jq '.name' 2>/dev/null || echo "MISSING")
  echo "$REPO: $EXISTS"
done
```

Expected: all 8 show `validate-ticket.yml`

---

## Task 3: Create the `create-joshua-ticket` Claude Code skill

**Files:**
- Create: `amakaflow-dev-workspace/.claude/skills/create-joshua-ticket/SKILL.md`

**Step 1: Create the skill directory and file**

Create `.claude/skills/create-joshua-ticket/SKILL.md` with this content:

```markdown
---
name: create-joshua-ticket
description: Create a well-formed Linear ticket for Joshua (MiniMax/Antfarm). Ensures all required sections are present so the CI ticket validator passes and Joshua has everything needed to implement correctly. Use when creating any task to assign to Joshua.
---

# Create Joshua Ticket

You are creating a Linear issue for Joshua (MiniMax AI agent via Antfarm). Joshua needs very precise instructions — ambiguity causes wrong code.

## Required fields — ALL must be present

Every ticket MUST include:

1. `## Repo:` — exact GitHub repo (`supergeri/<name>`)
2. `## Tasks` — numbered tasks, each with `**File:**` showing the exact path
3. `## Acceptance Criteria` — `- [ ]` checkboxes, last one must contain the test command

Missing ANY of these will cause the CI validator to block Joshua's PR.

## Process

**Step 1: Gather information**

Ask David for (one question at a time if unclear):
- What is the ticket title?
- Which repo? (`supergeri/mapper-api`, `supergeri/amakaflow-ui`, `supergeri/chat-api`, etc.)
- What files need to be created or modified? (exact paths)
- What should each file do? (be specific — Joshua has no context)
- What are the acceptance criteria? (verifiable outcomes)
- What is the test command for this repo?

If David already provided this context in his message, skip to Step 2.

**Step 2: Draft the ticket**

Use this exact format:

```
## Repo: `supergeri/<repo-name>`

<1-2 sentence context explaining the why>

## Tasks

### 1. <Task name>

**File:** `<exact/path/to/file.ext>`

<Specific instructions — what to create or change, including key logic>

### 2. <Task name> (if applicable)

**File:** `<exact/path/to/file.ext>`

<Specific instructions>

## Acceptance Criteria

- [ ] <Verifiable outcome 1>
- [ ] <Verifiable outcome 2>
- [ ] All tests pass: `<test command>`
```

**Step 3: Confirm with David**

Show the drafted ticket and ask: "Does this look right, or anything to add/change?"

**Step 4: Create the ticket in Linear**

Once approved, create it using the Linear MCP tool:
- Team: `MyAmaka`
- Assignee: `openclawjoshua@gmail.com`
- Priority: as specified (default: Medium / 3)
- Title and description as drafted

Use: `mcp__claude_ai_Linear__create_issue`

**Step 5: Confirm**

Report back the ticket identifier (e.g. `AMA-701`) and URL.

## Test commands by repo

| Repo | Test command |
|------|-------------|
| `mapper-api` | `pytest` |
| `calendar-api` | `pytest` |
| `chat-api` | `pytest` |
| `strava-sync-api` | `pytest` |
| `workout-ingestor-api` | `pytest` |
| `amakaflow-ui` | `npm test` |
| `amakaflow-android-app` | `./gradlew testDebugUnitTest` |
| `amakaflow-db` | `supabase db lint` |
```

**Step 2: Commit**

```bash
cd /Users/davidandrews/dev/AmakaFlow/amakaflow-dev-workspace
git add .claude/skills/create-joshua-ticket/SKILL.md
git commit -m "feat: add create-joshua-ticket Claude Code skill"
```

**Step 3: Test the skill**

In Claude Code, type:
```
/create-joshua-ticket
```

Expected: Claude announces it's using the create-joshua-ticket skill and asks for ticket details.

---

## Task 4: Push and create PR for workspace changes

```bash
cd /Users/davidandrews/dev/AmakaFlow/amakaflow-dev-workspace
git push origin feat/branch-orphan-checker

gh pr create \
  --repo supergeri/amakaflow-dev-workspace \
  --title "feat: Joshua ticket quality enforcement" \
  --body "Adds two components for Joshua ticket quality:

1. \`.github/workflows/validate-ticket.yml\` (reference copy — also deployed to all 8 Joshua repos)
2. \`.claude/skills/create-joshua-ticket/SKILL.md\` — Claude Code skill for creating well-formed tickets

The CI workflow fetches the linked Linear ticket on every Joshua PR and hard-blocks merge if any of these are missing: \`## Repo:\`, file paths, \`## Acceptance Criteria\`, checkboxes, test command."
```
