# Workout Structure UI Redesign

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Replace the current flat block list with type-first cards that show structure at a glance, with expandable inline config rows per block type — no dialogs for common configuration.

**Architecture:** Pure UI change in `amakaflow-ui`. No backend or data model breaking changes. Two small data model additions (`'warmup'` and `'cooldown'` as valid `structure` values; auto-migrate legacy `workoutWarmup` setting to a warmup block on load).

**Tech Stack:** React, TypeScript, Tailwind CSS, shadcn/ui, react-dnd (existing)

---

## Design Decisions

### Block Type Visual System

Each block type gets a left-border colour accent, a type badge, and a key metric displayed inline in the header.

| Structure | Colour token | Key metric in header |
|-----------|-------------|----------------------|
| `circuit` | `border-green-500` | `N rnds · Xs rest` |
| `emom` | `border-blue-500` | `N min · 1:00/station` |
| `amrap` | `border-orange-500` | `Cap: MM:SS` |
| `tabata` | `border-red-500` | `Xs on · Xs off · N rnds` |
| `for-time` | `border-purple-500` | `For Time` or `Cap: MM:SS` |
| `sets` / `regular` | `border-neutral-400` | `N sets · Xs rest` |
| `superset` | `border-amber-500` | `N rnds · Xs rest` |
| `warmup` | `border-muted` | `N min · [activity]` |
| `cooldown` | `border-muted` | `N min · [activity]` |
| `rounds` | `border-green-400` | `N rnds · Xs rest` |

### Block Card Anatomy

Three layers per card:
1. **Header** (always visible): drag handle · colour accent · type badge · block name · key metric · ⚙ config toggle · ∨ expand exercises
2. **Config row** (expandable inline, type-aware): steppers and toggles relevant to the block type only
3. **Exercise list** (visible when card expanded): existing DraggableExercise components, unchanged

### Config Row Fields Per Type

| Type | Fields shown |
|------|-------------|
| `circuit` | Rounds stepper · Rest between rounds stepper · Warm-up toggle + activity + duration |
| `emom` | Total minutes stepper · Work time per station (auto-calculates from total ÷ exercise count) |
| `amrap` | Time cap picker (MM:SS) · Warm-up toggle |
| `tabata` | Work time stepper · Rest time stepper · Rounds stepper |
| `for-time` | Time cap toggle + MM:SS picker (optional) |
| `sets` / `regular` | Sets stepper · Rest between sets stepper |
| `superset` | Rounds stepper · Rest after pair stepper |
| `rounds` | Rounds stepper · Rest between rounds stepper |
| `warmup` / `cooldown` | Activity selector (stretching, jump rope, air bike, treadmill, stairmaster, rowing, custom) · Duration stepper |

Steppers: `−` / `+` for quick tap. Tapping the value itself opens a number input for precise entry. Rest displays in seconds up to 90s, then `Xm Ys` format.

Block type badge is tappable → inline dropdown to switch type. Switching type resets structure fields only, not exercises.

### Warm-up / Cooldown / Default Rest — Suggestion Prompts

**Never auto-add.** Instead, show dismissible suggestion strips:

- **Warm-up strip**: appears at top of block list when no `warmup` block exists
- **Cooldown strip**: appears at bottom of block list when no `cooldown` block exists
- **Default rest strip**: appears below the workout title when `settings.defaultRestSec` is not set

Trigger conditions:
- On import completion (workout loaded into StructureWorkout)
- On first block added when creating from scratch

Dismissal: clicking "Skip" sets a flag in component state (`skippedWarmup`, `skippedCooldown`, `skippedRest`). Suggestions don't re-appear within the same session. They re-appear on next load if still missing.

Actions:
- `+ Add Warm-up` → prepend warmup block, open its config row
- `+ Add Cooldown` → append cooldown block, open its config row
- `+ Set Rest` → expand default rest inline banner to a stepper

### Add Block Flow

`+ Add Block` shows an inline type picker chip strip (no dialog):

```
[🟢 Circuit] [🔵 EMOM] [🟠 AMRAP] [🔴 Tabata] [⬜ Warm-up] [⬜ Cooldown] [⚫ Sets] [More ▼]
```

Selecting a type inserts the block and pre-opens the config row.

### Default Rest Banner

Replaces the workout-level rest badge. A muted single-line banner between the workout header card and the block list:

```
Default rest: 30s (applied to all blocks unless overridden)  [Edit]
```

If not set, the suggestion strip appears instead (see above).

### Data Model Changes

**`workout.ts` — two additions to `WorkoutStructureType`:**
```ts
export type WorkoutStructureType =
  | 'superset' | 'circuit' | 'tabata' | 'emom' | 'amrap'
  | 'for-time' | 'rounds' | 'sets' | 'regular'
  | 'warmup'    // NEW
  | 'cooldown'; // NEW
```

**Auto-migration in `StructureWorkout`:**
On mount, if `workout.settings.workoutWarmup?.enabled === true`, convert to a warmup block prepended to `blocks[]` and clear `settings.workoutWarmup`. This is a one-time in-memory migration (no API call needed — saved on next user action).

### What Stays Unchanged

- `DraggableExercise`, `ExerciseDropZone` — no changes
- `EditExerciseDialog` — no changes
- All drag-and-drop logic — no changes
- `WorkoutSettingsDialog` — kept for title editing only (rest + warmup now inline)
- Export flow, device selector
- All API contracts and backend

---

## Component Map

```
StructureWorkout (refactored)
├── WorkoutHeaderCard (existing, minor update: remove rest/warmup badges)
├── DefaultRestBanner (NEW: inline banner or suggestion strip)
├── WarmupSuggestionStrip (NEW: dismissible, top of list)
├── DraggableBlock (refactored: new header + BlockConfigRow)
│   ├── BlockHeader (NEW: colour accent, type badge, key metric, toggle buttons)
│   ├── BlockConfigRow (NEW: type-aware stepper fields)
│   └── ExerciseDropZone (unchanged)
├── CooldownSuggestionStrip (NEW: dismissible, bottom of list)
└── AddBlockTypePicker (NEW: inline chip strip, replaces bare "+ Add Block")
```

---

## Out of Scope

- No backend changes
- No changes to exercise editing (EditExerciseDialog)
- No changes to Validate & Map or Export steps
- No multi-source composition (AMA-32)
- No Figma mockups — implementation follows this spec directly
