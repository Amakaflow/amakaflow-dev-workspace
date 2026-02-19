---
name: create-joshua-ticket
description: Create a well-formed Linear ticket for Joshua (MiniMax/Antfarm). Ensures all required sections are present so the CI ticket validator passes and Joshua has everything needed to implement correctly. Use when creating any task to assign to Joshua.
---

# Create Joshua Ticket

You are creating a Linear issue for Joshua (MiniMax AI agent via Antfarm). Joshua needs very precise instructions — ambiguity causes wrong code.

## Required fields — ALL must be present

Every ticket MUST include ALL of these or the CI validator will block Joshua's PR:

1. `## Repo:` — exact GitHub repo (`supergeri/<name>`)
2. At least one `**File:**` entry with a real path
3. `## Acceptance Criteria` section
4. At least one `- [ ]` checkbox
5. A test command in the acceptance criteria (pytest / gradlew / npm test / etc.)

## Process

**Step 1: Gather information**

If David's message already contains the required info, skip to Step 2. Otherwise ask (one question at a time):
- What is the ticket title?
- Which repo? (`supergeri/mapper-api`, `supergeri/amakaflow-ui`, `supergeri/chat-api`, etc.)
- Which files need to be created or modified? (exact paths)
- What should each file do?
- What are the acceptance criteria?

**Step 2: Draft the ticket in canonical format**

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

Once approved, create it using:
- Tool: `mcp__claude_ai_Linear__create_issue`
- Team: `MyAmaka`
- Assignee: `openclawjoshua@gmail.com`
- Priority: as specified (default: 3 = Medium)
- Title and description as drafted

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
