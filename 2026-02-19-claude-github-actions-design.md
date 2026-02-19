# Claude Code GitHub Actions — Design Doc

**Date:** 2026-02-19
**Status:** Approved

## Goal

Add Claude Code GitHub Actions to all AmakaFlow repos so that:
1. `@claude` mentions in PR/issue comments trigger Claude to respond and optionally push code
2. Every PR automatically receives a Claude code review tailored to the repo's tech stack

## Auth Strategy

Use `CLAUDE_CODE_OAUTH_TOKEN` (Claude Max subscription via OAuth) in place of a paid Anthropic API key.

**One-time manual setup (per person, not per repo):**
1. Run `claude setup-token` locally → generates OAuth token
2. Install the Claude GitHub App on the `supergeri` org

**Per-repo setup:**
- Add `CLAUDE_CODE_OAUTH_TOKEN` as a GitHub Actions secret to each repo

## Repos in Scope

| Repo | GitHub | Tech Stack | Action Required |
|------|--------|-----------|----------------|
| `mapper-api` | supergeri/mapper-api | Python/FastAPI | Add both workflow files |
| `amakaflow-ui` | supergeri/amakaflow-ui | React/TypeScript (Vite) | Add both workflow files |
| `calendar-api` | supergeri/calendar-api | Python/FastAPI | Add both workflow files |
| `chat-api` | supergeri/chat-api | Python/FastAPI | Add both workflow files |
| `strava-sync-api` | supergeri/strava-sync-api | Python/FastAPI | Add both workflow files |
| `workout-ingestor-api` | supergeri/workout-ingestor-api | Python/FastAPI | Update existing + add claude-code.yml |
| `amakaflow-db` | supergeri/amakaflow-db | Supabase/PostgreSQL | Update existing + add claude-code.yml |
| `amakaflow-ios-app` | supergeri/amakaflow-ios-app | SwiftUI/iOS | Add both workflow files |
| `amakaflow-android-app` | supergeri/amakaflow-android-app | Kotlin/Jetpack Compose | Add both workflow files |

## Two Workflow Files Per Repo

### 1. `claude-code.yml` — @claude mention handler (identical across all repos)

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

### 2. `claude-code-review.yml` — automatic PR review (repo-specific prompt)

Structure is the same across repos; only the `prompt:` field differs per tech stack.

**Common structure:**
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
            # ... dismiss previous github-actions[bot] reviews

      - uses: anthropics/claude-code-action@v1
        with:
          claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
          github_token: ${{ secrets.GITHUB_TOKEN }}
          use_sticky_comment: true
          claude_args: '--allowedTools "mcp__github_inline_comment__create_inline_comment,Bash(gh pr comment:*),Bash(gh pr diff:*),Bash(gh pr view:*),Bash(gh api:*)"'
          prompt: |
            <repo-specific review prompt>
```

**Prompt focus areas by tech stack:**

| Stack | Key review areas |
|-------|-----------------|
| Python/FastAPI | async/sync correctness, Pydantic models, HTTPException usage, auth, OpenAPI docs |
| React/TypeScript | type safety, hook rules, component composition, bundle size, accessibility |
| SwiftUI/iOS | memory management, async/await, view lifecycle, SwiftUI best practices |
| Kotlin/Android | coroutines, Jetpack Compose state, ViewModel lifecycle, null safety |
| Supabase/SQL | RLS policies, migration safety, index coverage, zero-downtime changes |

**Changes to existing files (`workout-ingestor-api`, `amakaflow-db`):**
- Replace `anthropic_api_key: ${{ secrets.ANTHROPIC_API_KEY }}` → `claude_code_oauth_token: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}`
- Remove `if: github.event.pull_request.user.login == 'openclawjoshua-eng'` condition
- Keep existing repo-specific prompts unchanged

## Output Format (all review prompts)

All prompts follow the same structured output:
```
### Verdict
Approved | Approved with comments | Changes required

### Issues found
- Severity | File:line | What's wrong | How to fix

### Action items
1. Specific numbered steps with file names and line numbers
```

## Non-goals

- No changes to existing CI test workflows
- No org-level GitHub App configuration (per-repo secrets only)
- No reusable workflow abstraction (each repo is self-contained)
