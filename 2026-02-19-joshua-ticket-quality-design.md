# Joshua Ticket Quality — Design Doc

**Date:** 2026-02-19
**Status:** Approved

## Problem

Joshua (MiniMax via Antfarm) produces misaligned code when tickets are missing key information — wrong files, no tests, incomplete implementation. The missing field varies: sometimes it's the repo, sometimes file paths, sometimes the test command. Any gap causes rework.

## Solution

Two-layer enforcement:

1. **Ticket creation skill** — Claude Code skill that guarantees all required fields are present when the ticket is created.
2. **CI validator** — GitHub Actions workflow on every Joshua PR that hard-blocks merge if the linked ticket is missing any required section.

---

## Part 1: `create-joshua-ticket` Skill

A Claude Code skill in `amakaflow-dev-workspace/.claude/skills/create-joshua-ticket/` that David invokes with `/create-joshua-ticket`.

**Behaviour:**
- Claude gathers the required information (one question at a time if needed)
- Generates a ticket description in the canonical format (see below)
- Creates the Linear issue via MCP (`mcp__claude_ai_Linear__create_issue`)
- Assigns to Joshua (`openclawjoshua@gmail.com`), sets team to `MyAmaka`

**Canonical ticket format:**

```markdown
## Repo: `supergeri/<repo-name>`

<Context paragraph explaining the why>

## Tasks

### 1. <Task name>

**File:** `path/to/file.ext`

<What to do>

### 2. <Task name>

**File:** `path/to/file.ext`

<What to do>

## Acceptance Criteria

- [ ] <Verifiable outcome>
- [ ] <Verifiable outcome>
- [ ] All tests pass: `<test command>`
```

**Required fields the skill must always include:**
- `## Repo:` with explicit `supergeri/<repo>` name
- At least one `**File:**` entry with a real path
- `## Acceptance Criteria` with at least one `- [ ]` checkbox
- A test command inside the acceptance criteria (e.g. `pytest`, `./gradlew testDebugUnitTest`)

---

## Part 2: `validate-ticket.yml` CI Workflow

Added to all 8 Joshua repos:
- `supergeri/mapper-api`
- `supergeri/amakaflow-ui`
- `supergeri/calendar-api`
- `supergeri/chat-api`
- `supergeri/strava-sync-api`
- `supergeri/workout-ingestor-api`
- `supergeri/amakaflow-db`
- `supergeri/amakaflow-android-app`

**Trigger:** `pull_request` opened/synchronize/reopened by `openclawjoshua-eng`

**Steps:**
1. Extract `AMA-NNN` from branch name via regex
2. Fetch ticket description from Linear REST API using `LINEAR_API_KEY`
3. Run 5 validation checks against the description
4. If any fail: post a PR comment listing what's missing + fail the CI check
5. If all pass: post a sticky "✅ Ticket validated" comment + pass

**5 Validation Checks:**

| Check | Pattern | Failure message |
|-------|---------|-----------------|
| Repo specified | `## Repo:` header present | "Missing `## Repo:` — specify which repository" |
| File paths | At least one `src/`, `app/`, `api/`, `lib/`, `test` path | "Missing explicit file paths — add `**File:**` entries" |
| Acceptance criteria | `## Acceptance Criteria` header present | "Missing `## Acceptance Criteria` section" |
| Checkboxes | At least one `- [ ]` | "Acceptance criteria has no checkboxes" |
| Test command | `pytest`, `gradlew`, `npm test`, `cargo test`, `go test`, or `yarn test` | "Missing test command in acceptance criteria" |

**Secret:** `LINEAR_API_KEY` — set as an organisation-level secret so it applies to all repos automatically.

**PR comment format (on failure):**
```
## ❌ Ticket Validation Failed

The linked Linear ticket **AMA-NNN** is missing required sections.
Joshua cannot reliably implement this without complete specs.

**Missing:**
- [ ] Explicit file paths (add `**File:**` entries)
- [ ] Test command in acceptance criteria

**Fix:** Update the ticket description in Linear, then re-push to re-run this check.
```

---

## Infrastructure

**Org-level secret:** `LINEAR_API_KEY`
- Linear personal API key (Settings → API → Personal API keys)
- Set once at org level: `gh secret set LINEAR_API_KEY --org supergeri`

**Sticky comment:** Uses `actions/github-script` to find and update an existing comment rather than posting a new one on each push.

**Re-run on fix:** Workflow triggers on `synchronize` so re-pushing re-runs the check automatically.

---

## What This Does Not Do

- Does not validate that the file paths actually exist in the repo (too strict — new files are legitimate)
- Does not check ticket priority or project assignment
- Does not run on David's PRs (only `openclawjoshua-eng`)
