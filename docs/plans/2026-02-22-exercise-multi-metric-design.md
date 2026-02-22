# Exercise Multi-Metric Design

**Date:** 2026-02-22
**Status:** Approved
**Repo:** `supergeri/amakaflow-ui`

## Problem

The Edit Exercise dialog uses mutually exclusive tabs (Sets/Reps | Duration | Distance | Calories). Switching tabs nulls all other fields, making it impossible to express real-world combinations like:

- 1000m Ski with a 5-minute time cap (Hyrox station format)
- 3 sets of 30-second holds (Sets + Duration per set)
- 50 calories on the rower with a 5-minute cap

## Approach: Primary Metric + Optional Modifiers

Keep the four primary type tabs unchanged. Add an "Optional" section below each type's main input that surfaces relevant modifiers via toggles. Off by default; enabling a toggle reveals its input.

## Data Model

Add `time_cap_sec` to the `Exercise` interface in `src/types/workout.ts`:

```typescript
export interface Exercise {
  // ... existing fields unchanged ...
  duration_sec: number | null;   // per-set work duration (existing meaning preserved)
  time_cap_sec: number | null;   // NEW: overall time limit for the exercise
}
```

No changes to `ExerciseType` enum. No existing fields renamed or removed.

## Modifier Matrix

| Primary type | Duration per set (`duration_sec`) | Time Cap (`time_cap_sec`) |
|---|---|---|
| Sets/Reps | ✅ | ✅ |
| Distance | — | ✅ |
| Calories | — | ✅ |
| Duration | — (it IS the duration) | — |

Both modifiers can be active simultaneously on Sets/Reps (e.g. "3 × 30s with a 5-minute cap").

## Edit Exercise Dialog UI

Below the primary metric input for each type, show an "Optional" divider followed by toggle rows. Toggling one on reveals its slider/input inline.

```
Sets/Reps tab:
┌─────────────────────────────────────────┐
│ Sets          Reps                      │
│ − 3 +         − 10 +                   │
│                                         │
│ ── Optional ──────────────────────────  │
│ Duration per set          ○ (off)       │
│ Time Cap                  ○ (off)       │
└─────────────────────────────────────────┘

Duration per set toggled on:
│ Duration per set          ● (on)        │
│ 0s ●────────────── 10m  [ 30 ]s        │

Time Cap toggled on:
│ Time Cap                  ● (on)        │
│ 0s ●────────────── 30m  [ 300 ]s       │
```

**Tab switching behaviour:**
- Switching primary tab clears `duration_sec` (per-set, only valid for Sets/Reps)
- `time_cap_sec` is preserved when switching between Distance, Calories, and Sets/Reps (all support it)
- Switching to Duration clears both modifiers

## Exercise Card Display (DraggableExercise)

| State | Badge display |
|---|---|
| Sets/Reps only | `[ 3 sets ]  [ 10 reps ]` |
| Sets + Duration/set | `[ 3 × 30s ]` |
| Sets + Time Cap | `[ 3 sets ]  [🕐 5m cap]` |
| Sets + Both | `[ 3 × 30s ] [🕐 5m cap]` |
| Distance only | `[ 1000m ]` |
| Distance + Time Cap | `[ 1000m ]   [🕐 5m cap]` |
| Calories only | `[ 50 cal ]` |
| Calories + Time Cap | `[ 50 cal ]  [🕐 5m cap]` |
| Duration standalone | `[ 30s ]` |

Time cap badge uses a clock icon and muted style to visually distinguish it as a constraint rather than a target metric.

## Key Files

| File | Change |
|---|---|
| `src/types/workout.ts` | Add `time_cap_sec: number \| null` to `Exercise` interface |
| `src/components/EditExerciseDialog.tsx` | Add Optional modifier toggles + inputs per type; update tab-switch clearing logic |
| `src/components/DraggableExercise.tsx` | Update badge display logic for combined metrics |

## Out of Scope

- Backend/mapper changes (covered by AMA-728)
- Block-level `time_cap_sec` (already exists at block level; this adds it at exercise level)
- Weight field inconsistency (`weight_kg` referenced in DraggableExercise but missing from interface) — separate issue
