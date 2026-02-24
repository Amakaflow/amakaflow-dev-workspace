---
name: create-joshua-ticket
description: Create a well-formed Linear ticket for Joshua (MiniMax/Antfarm). Ensures all required sections are present so the CI ticket validator passes and Joshua has everything needed to implement correctly. Use when creating any task to assign to Joshua.
---

# Create Joshua Ticket

You are creating a Linear issue for Joshua (MiniMax AI agent via Antfarm). Joshua needs very precise instructions — ambiguity causes wrong code.

**Joshua's known failure modes (MiniMax limitations):**
- Implements the first/easiest criterion and marks done without verifying the rest
- Guesses file paths when given "or equivalent" — always wrong
- Loses track of requirements across multi-step tasks
- Marks PRs done before running the full acceptance criteria checklist

Every rule below exists to close one of these failure modes.

## Before creating — routing check

Only create this ticket for Joshua if ALL of these are true:
- ✅ Single-repo implementation task
- ✅ Has a clear spec (you're about to write it below)
- ❌ NOT a Knowledge Base (KB) task — David owns KB
- ❌ NOT a SPIKE or research task
- ❌ NOT a planning, architecture, or PRD-writing task
- ❌ NOT an iOS task — David owns `amakaflow-ios-app`

If any ❌ applies, stop and tell David this task should not go to Joshua.

## Hard rules — enforce every time

### 1. One acceptance criterion = one ticket

If the work has 3 distinct things to fix, create 3 tickets. Do NOT bundle them.

**Why:** Joshua completes item 1 and stops. Items 2 and 3 never get done.

### 2. Exact file paths — no guessing, no "or equivalent"

Before writing the ticket, use Glob or Grep to find the real file path. Never write:
- ❌ `mapper_api/extraction/workout_extractor.py` *(or equivalent)*
- ❌ `The file that handles X`
- ✅ `/app/services/instagram_reel_service.py` (verified with Glob)

**Why:** "Or equivalent" is an escape hatch. Joshua picks the wrong file.

### 3. Include the exact lines to change when possible

After finding the file, read it. Include the function name, line range, or the exact existing code block to modify.

### 4. Pre-write the failing test

If the repo has a test suite, write the pytest/Jest test that must pass. Give Joshua the test — he just needs to make it green.

**Why:** Vague acceptance criteria let Joshua write a test that doesn't actually verify the requirement.

### 5. Never use "or equivalent", "similar", "appropriate", or "relevant"

Every qualifier is a loophole. Be explicit or ask David for clarification before creating the ticket.

### 6. Add a "DO NOT mark done" warning for multi-criteria tickets

Even with one main task, if there are 3+ checkboxes, add this line at the top of Acceptance Criteria:

> ⚠️ Do NOT mark this ticket done until every checkbox below is manually verified.

## Required fields — ALL must be present

Every ticket MUST include ALL of these or the CI validator will block Joshua's PR:

1. `## Repo:` — exact GitHub repo (`Amakaflow/<name>`)
2. At least one `**File:**` entry with a real, verified path
3. `## Acceptance Criteria` section
4. At least one `- [ ]` checkbox
5. A test command in the acceptance criteria (pytest / gradlew / npm test / etc.)

## Process

**Step 1: Find the real file paths**

Before drafting the ticket, search the codebase:
```
Use Glob/Grep to locate the exact files involved.
Read the relevant functions/lines.
Only then write the ticket.
```

If you can't find the file, tell David — do not guess.

**Step 2: Split into atomic tickets**

Count the distinct things that need to change. If > 1, create separate tickets. Each ticket = one clear, verifiable outcome.

**Step 3: Draft each ticket in canonical format**

For backend tasks the repo is always `Amakaflow/amakaflow-backend`. File paths must include the `services/<name>/` prefix. The working directory for tests is `services/<name>/`.

```
## Repo: `Amakaflow/amakaflow-backend`

<1-2 sentence context explaining the why>

## Task

**Service:** `services/<service-name>/`
**File:** `services/<service-name>/<exact/verified/path/to/file.ext>`
**Function/Location:** `<function name or line range>`

<Specific instructions — exact logic to add or change. Include the before/after if helpful.>

## Acceptance Criteria

⚠️ Do NOT mark done until every checkbox is manually verified.

- [ ] <Single, specific, verifiable outcome>
- [ ] All tests pass: `cd services/<service-name> && pytest`

## Manual Test (if applicable)

<Step-by-step instructions for David to verify after deploy>
```

For non-backend repos (amakaflow-ui, amakaflow-android-app, etc.) use the standard format:

```
## Repo: `Amakaflow/<repo-name>`
```

**Step 4: Confirm with David**

Show the drafted ticket(s) and ask: "Does this look right, or anything to add/change?"

**Step 5: Create the ticket(s) in Linear**

Once approved, create using:
- Tool: `mcp__claude_ai_Linear__create_issue`
- Team: `MyAmaka`
- Assignee: `openclawjoshua@gmail.com`
- Priority: as specified (default: 3 = Medium)
- Title and description as drafted

**Step 6: Confirm**

Report back the ticket identifier (e.g. `AMA-701`) and URL.

## Test commands by service/repo

All backend services live in `Amakaflow/amakaflow-backend`. Always `cd` into the service directory before running tests.

| Service / Repo | Test command |
|----------------|-------------|
| `amakaflow-backend` → `services/chat-api` | `cd services/chat-api && pytest` |
| `amakaflow-backend` → `services/mapper-api` | `cd services/mapper-api && pytest` |
| `amakaflow-backend` → `services/calendar-api` | `cd services/calendar-api && pytest` |
| `amakaflow-backend` → `services/workout-ingestor-api` | `cd services/workout-ingestor-api && pytest` |
| `amakaflow-backend` → `services/strava-sync-api` | `cd services/strava-sync-api && pytest` |
| `amakaflow-backend` → `services/garmin-sync-api` | `cd services/garmin-sync-api && pytest` |
| `amakaflow-backend` → `db/` | `supabase db lint` |
| `amakaflow-ui` | `npm test` |
| `amakaflow-android-app` | `./gradlew testDebugUnitTest` |
| `amakaflow-ios-app` | `xcodebuild test -scheme AmakaFlowCompanion -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` |

> **Note:** `amakaflow-ios-app` is David's domain — Joshua should not be assigned iOS tickets. If you're about to create an iOS ticket for Joshua, stop and reassign to David.
> **Note:** The old standalone repos (`chat-api`, `mapper-api`, etc.) are archived. Do NOT reference them in tickets.

## Red flags — stop and fix before creating

| You're about to write... | Do this instead |
|---|---|
| "or equivalent" | Find the real file with Glob/Grep |
| 3+ acceptance criteria | Split into 3 tickets |
| "The file that handles X" | Read the codebase, find the exact path |
| A task with vague instructions like "add support for X" | Specify exactly what function/line to change and what the output must be |
| A ticket without a manual test | Add a step-by-step test David can run |
