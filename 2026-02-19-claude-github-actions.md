# Claude Code GitHub Actions Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add `claude-code.yml` (@claude mentions) and `claude-code-review.yml` (auto PR review) to all 9 AmakaFlow repos using Claude Max OAuth token.

**Architecture:** Two workflow files per repo — one for @claude mention handling (identical across all repos), one for automatic PR review (repo-specific prompt). Existing `claude-code-review.yml` files in `workout-ingestor-api` and `amakaflow-db` are updated in-place. All 9 repos get both files. Auth switches from `ANTHROPIC_API_KEY` to `CLAUDE_CODE_OAUTH_TOKEN`.

**Tech Stack:** GitHub Actions, `anthropics/claude-code-action@v1`, Claude Max OAuth

---

## Prerequisites (Manual — David only)

These steps cannot be automated. Complete before running any tasks below.

**Step 1: Generate OAuth token**
```bash
claude setup-token
# Follow the prompts — copies token to clipboard
# Save it somewhere safe (1Password etc.) — you'll need it for all 9 repos
```

**Step 2: Install Claude GitHub App**
- Go to: https://github.com/apps/claude
- Install on the `supergeri` org (or each repo individually)

**Step 3: Add secret to each repo**
For each of the 9 repos below, go to:
`https://github.com/supergeri/<repo>/settings/secrets/actions/new`

Add secret: `CLAUDE_CODE_OAUTH_TOKEN` = your token

Repos to add secret to:
- supergeri/mapper-api
- supergeri/amakaflow-ui
- supergeri/calendar-api
- supergeri/chat-api
- supergeri/strava-sync-api
- supergeri/workout-ingestor-api
- supergeri/amakaflow-db
- supergeri/amakaflow-ios-app
- supergeri/amakaflow-android-app

**Step 4: Verify git remotes are set up locally**

Each sub-repo under `amakaflow-dev-workspace/` needs a remote. Check and fix:
```bash
for dir in mapper-api amakaflow-ui calendar-api chat-api strava-sync-api workout-ingestor-api; do
  echo "=== $dir ==="
  git -C amakaflow-dev-workspace/$dir remote -v
done
```
If a remote is missing: `git -C amakaflow-dev-workspace/<name> remote add origin https://github.com/supergeri/<name>.git`

---

## Shared Workflow Content (Reference)

### claude-code.yml — identical for ALL repos

```yaml
name: Claude Code

on:
  issue_comment:
    types: [created]
  pull_request_review_comment:
    types: [created]

jobs:
  claude:
    runs-on: ubuntu-latest
    permissions:
      contents: write
      pull-requests: write
      issues: write
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: anthropics/claude-code-action@v1
        with:
          claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
```

### Dismiss stale reviews snippet — used in all claude-code-review.yml files

```yaml
      - name: Dismiss stale reviews
        uses: actions/github-script@v7
        with:
          script: |
            const reviews = await github.rest.pulls.listReviews({
              owner: context.repo.owner,
              repo: context.repo.repo,
              pull_number: context.issue.number
            });
            for (const review of reviews.data) {
              if (review.user.login === 'github-actions[bot]' && review.state === 'CHANGES_REQUESTED') {
                await github.rest.pulls.dismissReview({
                  owner: context.repo.owner,
                  repo: context.repo.repo,
                  pull_number: context.issue.number,
                  review_id: review.id,
                  message: 'Dismissed: new review in progress.'
                });
              }
            }
```

### claude-code-review.yml — common shell (swap in prompt per repo)

```yaml
name: Claude Code Review

on:
  pull_request:
    types: [opened, reopened, synchronize, ready_for_review]

jobs:
  code-review:
    if: "!github.event.pull_request.draft"
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
      id-token: write

    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Dismiss stale reviews
        uses: actions/github-script@v7
        with:
          script: |
            const reviews = await github.rest.pulls.listReviews({
              owner: context.repo.owner,
              repo: context.repo.repo,
              pull_number: context.issue.number
            });
            for (const review of reviews.data) {
              if (review.user.login === 'github-actions[bot]' && review.state === 'CHANGES_REQUESTED') {
                await github.rest.pulls.dismissReview({
                  owner: context.repo.owner,
                  repo: context.repo.repo,
                  pull_number: context.issue.number,
                  review_id: review.id,
                  message: 'Dismissed: new review in progress.'
                });
              }
            }

      - uses: anthropics/claude-code-action@v1
        with:
          claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
          github_token: ${{ secrets.GITHUB_TOKEN }}
          use_sticky_comment: true
          claude_args: '--allowedTools "mcp__github_inline_comment__create_inline_comment,Bash(gh pr comment:*),Bash(gh pr diff:*),Bash(gh pr view:*),Bash(gh api:*)"'
          prompt: |
            <REPO-SPECIFIC PROMPT — see each task below>
```

---

## Review Prompt Templates

### FastAPI prompt template (mapper-api, calendar-api, chat-api, strava-sync-api)

Replace `<SERVICE_NAME>` with the actual service name.

```
You are a senior code reviewer for a FastAPI Python backend (<SERVICE_NAME>).
Your audience is a junior developer — be specific and actionable.

First, use `gh pr diff` to review the changes. Then review this PR thoroughly for:

1. **Critical issues**: Runtime errors, crashes, incorrect function signatures, data loss
2. **Security**: Auth gaps, injection, input validation, secrets exposure
3. **Error handling**: Consistent use of HTTPException, specific exception types
4. **API design**: REST conventions, response models, OpenAPI docs
5. **FastAPI best practices**: async/sync correctness, Depends usage, Pydantic models
6. **Code quality**: DRY violations, unused code, type safety

## Output format

Structure your review EXACTLY like this:

### Verdict
State one of: **Approved**, **Approved with comments**, or **Changes required**

### Issues found
List each issue with:
- Severity (Critical / Important / Minor / Nitpick)
- File and line number
- What's wrong (1 sentence)
- How to fix it (specific code or steps)

### Action items
A numbered checklist of EXACTLY what the developer needs to do, in order.
Be specific — include file names, line numbers, and what to change.
For example:
1. In `api/routers/sync.py:42`, add `user_id: str = Depends(get_current_user)` parameter
2. In `api/routers/sync.py:100`, replace bare `except:` with `except ValueError as e:`
3. Push your changes — CI and code review will re-run automatically

If there are no issues, just say: "No action needed — this PR is ready to merge."

## Submitting the review

After writing your review, submit a formal PR review using the GitHub API:
- If there are ANY Critical issues: submit with event "REQUEST_CHANGES"
- If there are only Important/Minor/Nitpick issues: submit with event "COMMENT"
- If there are no issues: submit with event "APPROVE"

Use this command to submit the formal review:
```
gh api repos/$GITHUB_REPOSITORY/pulls/$PR_NUMBER/reviews \
  -f event="REQUEST_CHANGES" \
  -f body="Review verdict: **Request changes** — see action items in review comment."
```
Replace the event and body as appropriate for COMMENT or APPROVE verdicts.
Get the PR number from `gh pr view --json number --jq .number`.
```

### React/TypeScript prompt (amakaflow-ui)

```
You are a senior code reviewer for a React/TypeScript frontend (amakaflow-ui).
Your audience is a junior developer — be specific and actionable.

First, use `gh pr diff` to review the changes. Then review this PR thoroughly for:

1. **Critical issues**: Runtime errors, broken renders, incorrect prop types, data loss
2. **TypeScript**: Missing types, unsafe `any`, incorrect generics, type assertions
3. **React best practices**: Hook rules, missing deps in useEffect, stale closures, unnecessary re-renders
4. **Security**: XSS risks, unsafe innerHTML, exposed secrets in client code
5. **Performance**: Missing memo/useCallback where needed, large bundle imports, image optimization
6. **Accessibility**: Missing ARIA labels, keyboard navigation, color contrast

## Output format

Structure your review EXACTLY like this:

### Verdict
State one of: **Approved**, **Approved with comments**, or **Changes required**

### Issues found
List each issue with:
- Severity (Critical / Important / Minor / Nitpick)
- File and line number
- What's wrong (1 sentence)
- How to fix it (specific code or steps)

### Action items
A numbered checklist of EXACTLY what the developer needs to do, in order.
Be specific — include file names, line numbers, and what to change.

If there are no issues, just say: "No action needed — this PR is ready to merge."

## Submitting the review

After writing your review, submit a formal PR review using the GitHub API:
- If there are ANY Critical issues: submit with event "REQUEST_CHANGES"
- If there are only Important/Minor/Nitpick issues: submit with event "COMMENT"
- If there are no issues: submit with event "APPROVE"

Use this command to submit the formal review:
```
gh api repos/$GITHUB_REPOSITORY/pulls/$PR_NUMBER/reviews \
  -f event="REQUEST_CHANGES" \
  -f body="Review verdict: **Request changes** — see action items in review comment."
```
Replace the event and body as appropriate.
Get the PR number from `gh pr view --json number --jq .number`.
```

### SwiftUI/iOS prompt (amakaflow-ios-app)

```
You are a senior code reviewer for a SwiftUI iOS app (amakaflow-ios-app).
Your audience is a junior developer — be specific and actionable.

First, use `gh pr diff` to review the changes. Then review this PR thoroughly for:

1. **Critical issues**: Crashes, memory leaks, incorrect async patterns, data corruption
2. **SwiftUI best practices**: View composition, @State/@Binding/@ObservedObject correctness, view lifecycle
3. **Concurrency**: Correct use of async/await, MainActor, Task cancellation
4. **Memory management**: Retain cycles, weak/unowned references in closures
5. **Security**: Keychain usage, secure data handling, no secrets in code
6. **Performance**: Expensive body recomputation, missing lazy loading, image caching

## Output format

Structure your review EXACTLY like this:

### Verdict
State one of: **Approved**, **Approved with comments**, or **Changes required**

### Issues found
List each issue with:
- Severity (Critical / Important / Minor / Nitpick)
- File and line number
- What's wrong (1 sentence)
- How to fix it (specific code or steps)

### Action items
A numbered checklist of EXACTLY what the developer needs to do, in order.
Be specific — include file names, line numbers, and what to change.

If there are no issues, just say: "No action needed — this PR is ready to merge."

## Submitting the review

After writing your review, submit a formal PR review using the GitHub API:
- If there are ANY Critical issues: submit with event "REQUEST_CHANGES"
- If there are only Important/Minor/Nitpick issues: submit with event "COMMENT"
- If there are no issues: submit with event "APPROVE"

Use this command to submit the formal review:
```
gh api repos/$GITHUB_REPOSITORY/pulls/$PR_NUMBER/reviews \
  -f event="REQUEST_CHANGES" \
  -f body="Review verdict: **Request changes** — see action items in review comment."
```
Replace the event and body as appropriate.
Get the PR number from `gh pr view --json number --jq .number`.
```

### Kotlin/Android prompt (amakaflow-android-app)

```
You are a senior code reviewer for a Kotlin Android app (amakaflow-android-app).
Your audience is a junior developer — be specific and actionable.

First, use `gh pr diff` to review the changes. Then review this PR thoroughly for:

1. **Critical issues**: Crashes, ANR risks, incorrect lifecycle handling, data loss
2. **Kotlin best practices**: Null safety, coroutine scope correctness, sealed class usage
3. **Jetpack Compose**: State hoisting, remember/derivedStateOf usage, recomposition efficiency
4. **Architecture**: ViewModel lifecycle, Repository pattern, clean separation of concerns
5. **Security**: ProGuard rules, certificate pinning, no secrets in code or resources
6. **Performance**: Main thread blocking, excessive recomposition, bitmap memory management

## Output format

Structure your review EXACTLY like this:

### Verdict
State one of: **Approved**, **Approved with comments**, or **Changes required**

### Issues found
List each issue with:
- Severity (Critical / Important / Minor / Nitpick)
- File and line number
- What's wrong (1 sentence)
- How to fix it (specific code or steps)

### Action items
A numbered checklist of EXACTLY what the developer needs to do, in order.
Be specific — include file names, line numbers, and what to change.

If there are no issues, just say: "No action needed — this PR is ready to merge."

## Submitting the review

After writing your review, submit a formal PR review using the GitHub API:
- If there are ANY Critical issues: submit with event "REQUEST_CHANGES"
- If there are only Important/Minor/Nitpick issues: submit with event "COMMENT"
- If there are no issues: submit with event "APPROVE"

Use this command to submit the formal review:
```
gh api repos/$GITHUB_REPOSITORY/pulls/$PR_NUMBER/reviews \
  -f event="REQUEST_CHANGES" \
  -f body="Review verdict: **Request changes** — see action items in review comment."
```
Replace the event and body as appropriate.
Get the PR number from `gh pr view --json number --jq .number`.
```

---

## Task 1: mapper-api

**Repo path:** `amakaflow-dev-workspace/mapper-api/`
**Files:**
- Create: `.github/workflows/claude-code.yml`
- Create: `.github/workflows/claude-code-review.yml`

**Step 1: Create workflows directory**
```bash
mkdir -p amakaflow-dev-workspace/mapper-api/.github/workflows
```

**Step 2: Create claude-code.yml**

Create `amakaflow-dev-workspace/mapper-api/.github/workflows/claude-code.yml` with the shared `claude-code.yml` content from the reference above.

**Step 3: Create claude-code-review.yml**

Create `amakaflow-dev-workspace/mapper-api/.github/workflows/claude-code-review.yml` using the common shell + FastAPI prompt template with `<SERVICE_NAME>` = `mapper-api`.

**Step 4: Create branch and commit**
```bash
git -C amakaflow-dev-workspace/mapper-api checkout -b feat/add-claude-code-actions
git -C amakaflow-dev-workspace/mapper-api add .github/workflows/claude-code.yml .github/workflows/claude-code-review.yml
git -C amakaflow-dev-workspace/mapper-api commit -m "feat: add Claude Code GitHub Actions"
```

**Step 5: Push and open PR**
```bash
git -C amakaflow-dev-workspace/mapper-api push -u origin feat/add-claude-code-actions
gh pr create --repo supergeri/mapper-api --title "feat: add Claude Code GitHub Actions" --body "Adds @claude mention handling and automatic PR review using Claude Max OAuth token."
```

---

## Task 2: amakaflow-ui

**Repo path:** `amakaflow-dev-workspace/amakaflow-ui/`
**Files:**
- Create: `.github/workflows/claude-code.yml`
- Create: `.github/workflows/claude-code-review.yml`

**Step 1: Create workflows directory**
```bash
mkdir -p amakaflow-dev-workspace/amakaflow-ui/.github/workflows
```

**Step 2: Create claude-code.yml**

Create `amakaflow-dev-workspace/amakaflow-ui/.github/workflows/claude-code.yml` with the shared content.

**Step 3: Create claude-code-review.yml**

Create `amakaflow-dev-workspace/amakaflow-ui/.github/workflows/claude-code-review.yml` using the common shell + React/TypeScript prompt.

**Step 4: Create branch and commit**
```bash
git -C amakaflow-dev-workspace/amakaflow-ui checkout -b feat/add-claude-code-actions
git -C amakaflow-dev-workspace/amakaflow-ui add .github/workflows/claude-code.yml .github/workflows/claude-code-review.yml
git -C amakaflow-dev-workspace/amakaflow-ui commit -m "feat: add Claude Code GitHub Actions"
```

**Step 5: Push and open PR**
```bash
git -C amakaflow-dev-workspace/amakaflow-ui push -u origin feat/add-claude-code-actions
gh pr create --repo supergeri/amakaflow-ui --title "feat: add Claude Code GitHub Actions" --body "Adds @claude mention handling and automatic PR review using Claude Max OAuth token."
```

---

## Task 3: calendar-api

**Repo path:** `amakaflow-dev-workspace/calendar-api/`
**Files:**
- Create: `.github/workflows/claude-code.yml`
- Modify: `.github/workflows/` (add `claude-code-review.yml`)

Note: `calendar-api` already has `ci.yml` — do not touch it.

**Step 1: Create claude-code.yml**

Create `amakaflow-dev-workspace/calendar-api/.github/workflows/claude-code.yml` with the shared content.

**Step 2: Create claude-code-review.yml**

Create `amakaflow-dev-workspace/calendar-api/.github/workflows/claude-code-review.yml` using the common shell + FastAPI prompt with `<SERVICE_NAME>` = `calendar-api`.

**Step 3: Create branch and commit**
```bash
git -C amakaflow-dev-workspace/calendar-api checkout -b feat/add-claude-code-actions
git -C amakaflow-dev-workspace/calendar-api add .github/workflows/claude-code.yml .github/workflows/claude-code-review.yml
git -C amakaflow-dev-workspace/calendar-api commit -m "feat: add Claude Code GitHub Actions"
```

**Step 4: Push and open PR**
```bash
git -C amakaflow-dev-workspace/calendar-api push -u origin feat/add-claude-code-actions
gh pr create --repo supergeri/calendar-api --title "feat: add Claude Code GitHub Actions" --body "Adds @claude mention handling and automatic PR review using Claude Max OAuth token."
```

---

## Task 4: chat-api

**Repo path:** `amakaflow-dev-workspace/chat-api/`
**Files:**
- Create: `.github/workflows/claude-code.yml`
- Create: `.github/workflows/claude-code-review.yml`

**Step 1: Create workflows directory**
```bash
mkdir -p amakaflow-dev-workspace/chat-api/.github/workflows
```

**Step 2: Create claude-code.yml**

Create `amakaflow-dev-workspace/chat-api/.github/workflows/claude-code.yml` with the shared content.

**Step 3: Create claude-code-review.yml**

Create `amakaflow-dev-workspace/chat-api/.github/workflows/claude-code-review.yml` using the common shell + FastAPI prompt with `<SERVICE_NAME>` = `chat-api`.

**Step 4: Create branch and commit**
```bash
git -C amakaflow-dev-workspace/chat-api checkout -b feat/add-claude-code-actions
git -C amakaflow-dev-workspace/chat-api add .github/workflows/claude-code.yml .github/workflows/claude-code-review.yml
git -C amakaflow-dev-workspace/chat-api commit -m "feat: add Claude Code GitHub Actions"
```

**Step 5: Push and open PR**
```bash
git -C amakaflow-dev-workspace/chat-api push -u origin feat/add-claude-code-actions
gh pr create --repo supergeri/chat-api --title "feat: add Claude Code GitHub Actions" --body "Adds @claude mention handling and automatic PR review using Claude Max OAuth token."
```

---

## Task 5: strava-sync-api

**Repo path:** `amakaflow-dev-workspace/strava-sync-api/`
**Files:**
- Create: `.github/workflows/claude-code.yml`
- Create: `.github/workflows/claude-code-review.yml`

**Step 1: Create workflows directory**
```bash
mkdir -p amakaflow-dev-workspace/strava-sync-api/.github/workflows
```

**Step 2: Create claude-code.yml**

Create `amakaflow-dev-workspace/strava-sync-api/.github/workflows/claude-code.yml` with the shared content.

**Step 3: Create claude-code-review.yml**

Create `amakaflow-dev-workspace/strava-sync-api/.github/workflows/claude-code-review.yml` using the common shell + FastAPI prompt with `<SERVICE_NAME>` = `strava-sync-api`.

**Step 4: Create branch and commit**
```bash
git -C amakaflow-dev-workspace/strava-sync-api checkout -b feat/add-claude-code-actions
git -C amakaflow-dev-workspace/strava-sync-api add .github/workflows/claude-code.yml .github/workflows/claude-code-review.yml
git -C amakaflow-dev-workspace/strava-sync-api commit -m "feat: add Claude Code GitHub Actions"
```

**Step 5: Push and open PR**
```bash
git -C amakaflow-dev-workspace/strava-sync-api push -u origin feat/add-claude-code-actions
gh pr create --repo supergeri/strava-sync-api --title "feat: add Claude Code GitHub Actions" --body "Adds @claude mention handling and automatic PR review using Claude Max OAuth token."
```

---

## Task 6: workout-ingestor-api (UPDATE existing)

**Repo path:** `amakaflow-dev-workspace/workout-ingestor-api/`
**Files:**
- Modify: `.github/workflows/claude-code-review.yml` (update auth + remove user filter)
- Create: `.github/workflows/claude-code.yml`

**Step 1: Update claude-code-review.yml**

In `amakaflow-dev-workspace/workout-ingestor-api/.github/workflows/claude-code-review.yml`:

1. Remove the `if:` condition on the `code-review` job:
   ```yaml
   # DELETE THIS LINE:
   if: github.event.pull_request.user.login == 'openclawjoshua-eng' && !github.event.pull_request.draft
   # REPLACE WITH:
   if: "!github.event.pull_request.draft"
   ```

2. Replace the auth line:
   ```yaml
   # DELETE:
   anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
   # ADD:
   claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
   ```

**Step 2: Create claude-code.yml**

Create `amakaflow-dev-workspace/workout-ingestor-api/.github/workflows/claude-code.yml` with the shared content.

**Step 3: Create branch and commit**
```bash
git -C amakaflow-dev-workspace/workout-ingestor-api checkout -b feat/update-claude-code-actions
git -C amakaflow-dev-workspace/workout-ingestor-api add .github/workflows/claude-code.yml .github/workflows/claude-code-review.yml
git -C amakaflow-dev-workspace/workout-ingestor-api commit -m "feat: update Claude Code Actions to OAuth, enable for all users"
```

**Step 4: Push and open PR**
```bash
git -C amakaflow-dev-workspace/workout-ingestor-api push -u origin feat/update-claude-code-actions
gh pr create --repo supergeri/workout-ingestor-api --title "feat: update Claude Code Actions to OAuth, all users" --body "Switches from ANTHROPIC_API_KEY to CLAUDE_CODE_OAUTH_TOKEN. Removes Joshua-only filter so all PRs get reviewed. Adds @claude mention handling."
```

---

## Task 7: amakaflow-db (UPDATE existing)

**Repo path:** `amakaflow-dev-workspace/amakaflow-db/`
**Files:**
- Modify: `.github/workflows/claude-code-review.yml` (update auth + remove user filter)
- Create: `.github/workflows/claude-code.yml`

**Step 1: Update claude-code-review.yml**

In `amakaflow-dev-workspace/amakaflow-db/.github/workflows/claude-code-review.yml`:

1. Remove the `if:` condition on the `code-review` job:
   ```yaml
   # DELETE:
   if: github.event.pull_request.user.login == 'openclawjoshua-eng' && !github.event.pull_request.draft
   # REPLACE WITH:
   if: "!github.event.pull_request.draft"
   ```

2. Replace the auth line:
   ```yaml
   # DELETE:
   anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}
   # ADD:
   claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
   ```

**Step 2: Create claude-code.yml**

Create `amakaflow-dev-workspace/amakaflow-db/.github/workflows/claude-code.yml` with the shared content.

**Step 3: Create branch and commit**

Per the CRITICAL RULE in MEMORY.md, amakaflow-db has its own git repo:
```bash
git -C amakaflow-dev-workspace/amakaflow-db checkout -b feat/update-claude-code-actions
git -C amakaflow-dev-workspace/amakaflow-db add .github/workflows/claude-code.yml .github/workflows/claude-code-review.yml
git -C amakaflow-dev-workspace/amakaflow-db commit -m "feat: update Claude Code Actions to OAuth, enable for all users"
```

**Step 4: Push and open PR**
```bash
git -C amakaflow-dev-workspace/amakaflow-db push -u origin feat/update-claude-code-actions
gh pr create --repo supergeri/amakaflow-db --title "feat: update Claude Code Actions to OAuth, all users" --body "Switches from ANTHROPIC_API_KEY to CLAUDE_CODE_OAUTH_TOKEN. Removes Joshua-only filter. Adds @claude mention handling."
```

---

## Task 8: amakaflow-ios-app

**Repo path:** `amakaflow-ios-app/amakaflow-ios-app/`
**Files:**
- Create: `.github/workflows/claude-code.yml`
- Create: `.github/workflows/claude-code-review.yml`

**Step 1: Create workflows directory**
```bash
mkdir -p amakaflow-ios-app/amakaflow-ios-app/.github/workflows
```

**Step 2: Create claude-code.yml**

Create `amakaflow-ios-app/amakaflow-ios-app/.github/workflows/claude-code.yml` with the shared content.

**Step 3: Create claude-code-review.yml**

Create `amakaflow-ios-app/amakaflow-ios-app/.github/workflows/claude-code-review.yml` using the common shell + SwiftUI/iOS prompt.

**Step 4: Create branch and commit**
```bash
git -C amakaflow-ios-app/amakaflow-ios-app checkout -b feat/add-claude-code-actions
git -C amakaflow-ios-app/amakaflow-ios-app add .github/workflows/claude-code.yml .github/workflows/claude-code-review.yml
git -C amakaflow-ios-app/amakaflow-ios-app commit -m "feat: add Claude Code GitHub Actions"
```

**Step 5: Push and open PR**
```bash
git -C amakaflow-ios-app/amakaflow-ios-app push -u origin feat/add-claude-code-actions
gh pr create --repo supergeri/amakaflow-ios-app --title "feat: add Claude Code GitHub Actions" --body "Adds @claude mention handling and automatic PR review using Claude Max OAuth token."
```

---

## Task 9: amakaflow-android-app

**Repo path:** `amakaflow-android-app/`
**Files:**
- Create: `.github/workflows/claude-code.yml`
- Create: `.github/workflows/claude-code-review.yml`

Note: `amakaflow-android-app` already has `ci.yml`, `pr-ci.yml`, `nightly-ci.yml` — do not touch them.

**Step 1: Create claude-code.yml**

Create `amakaflow-android-app/.github/workflows/claude-code.yml` with the shared content.

**Step 2: Create claude-code-review.yml**

Create `amakaflow-android-app/.github/workflows/claude-code-review.yml` using the common shell + Kotlin/Android prompt.

**Step 3: Create branch and commit**
```bash
git -C amakaflow-android-app checkout -b feat/add-claude-code-actions
git -C amakaflow-android-app add .github/workflows/claude-code.yml .github/workflows/claude-code-review.yml
git -C amakaflow-android-app commit -m "feat: add Claude Code GitHub Actions"
```

**Step 4: Push and open PR**
```bash
git -C amakaflow-android-app push -u origin feat/add-claude-code-actions
gh pr create --repo supergeri/amakaflow-android-app --title "feat: add Claude Code GitHub Actions" --body "Adds @claude mention handling and automatic PR review using Claude Max OAuth token."
```

---

## Verification (after merging all PRs)

For each repo, verify both workflows are live:

1. **Auto-review**: Open a test PR → check Actions tab for `Claude Code Review` run
2. **@claude mention**: Comment `@claude what does this file do?` on any PR → check Actions tab for `Claude Code` run

If a workflow doesn't trigger:
- Check the secret exists: `https://github.com/supergeri/<repo>/settings/secrets/actions`
- Check the Claude GitHub App is installed on the repo
- Check the workflow file is on `main` (not just a branch)
