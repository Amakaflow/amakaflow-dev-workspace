# Exercise Multi-Metric Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Allow exercises to combine a primary metric (Sets/Reps, Distance, Calories, Duration) with optional modifiers (Duration per set, Time Cap) so workouts like "1000m Ski within 5 minutes" or "3 sets of 30s" can be expressed.

**Architecture:** Add `time_cap_sec` to the Exercise interface. In `EditExerciseDialog`, add two optional modifier toggles below each primary type's input. Update `updateExerciseImmediately` and tab-switch logic to write/clear both fields correctly. Update `DraggableExercise` badges to render combined metrics.

**Tech Stack:** React, TypeScript, Shadcn UI (Switch, Slider, Badge), Lucide icons

**Design doc:** `docs/plans/2026-02-22-exercise-multi-metric-design.md`

---

## Task 1: Add `time_cap_sec` to Exercise interface

**Files:**
- Modify: `amakaflow-ui/src/types/workout.ts:28-49`

**Step 1: Add the field**

In `workout.ts`, add `time_cap_sec` after `duration_sec`:

```typescript
export interface Exercise {
  id: string;
  name: string;
  sets: number | null;
  reps: number | null;
  reps_range: string | null;
  duration_sec: number | null;
  time_cap_sec: number | null;   // NEW: overall time limit for the exercise
  rest_sec: number | null;
  rest_type?: RestType;
  distance_m: number | null;
  distance_range: string | null;
  calories?: number | null;
  type: 'strength' | 'cardio' | 'HIIT' | 'interval' | string;
  followAlongUrl?: string | null;
  notes?: string | null;
  addedAt?: number;
  warmup_sets?: number | null;
  warmup_reps?: number | null;
}
```

**Step 2: Verify TypeScript compiles**

```bash
cd amakaflow-ui && npx tsc --noEmit
```

Expected: No errors (all existing usages of Exercise treat `time_cap_sec` as optional/nullable).

**Step 3: Commit**

```bash
git add amakaflow-ui/src/types/workout.ts
git commit -m "feat(types): add time_cap_sec to Exercise interface"
```

---

## Task 2: Add modifier state to EditExerciseDialog

**Files:**
- Modify: `amakaflow-ui/src/components/EditExerciseDialog.tsx:60-78` (state block)
- Modify: `amakaflow-ui/src/components/EditExerciseDialog.tsx:96-120` (initialization effect)

**Step 1: Add modifier state variables**

After the existing state declarations (around line 72), add:

```typescript
// Modifier state
const [timeCapEnabled, setTimeCapEnabled] = useState(false);
const [timeCapSec, setTimeCapSec] = useState(300); // default 5 min
const [durationPerSetEnabled, setDurationPerSetEnabled] = useState(false);
// durationSec (already exists, line 66) is reused for both standalone Duration and per-set modifier
```

**Step 2: Initialize modifier state from exercise**

In the `useEffect` that initializes state from exercise (around line 96), add after the existing initializations:

```typescript
// Time cap modifier
const hasTimeCap = exercise.time_cap_sec !== null && exercise.time_cap_sec !== undefined;
setTimeCapEnabled(hasTimeCap);
setTimeCapSec(exercise.time_cap_sec ?? 300);

// Duration per set modifier (sets-reps tab only)
// An exercise has per-set duration when it has sets AND duration_sec
const hasDurationPerSet = (
  (exercise.sets !== null && exercise.sets !== undefined) &&
  (exercise.duration_sec !== null && exercise.duration_sec !== undefined)
);
setDurationPerSetEnabled(hasDurationPerSet);
if (hasDurationPerSet) {
  setDurationSec(exercise.duration_sec ?? 60);
}
```

**Step 3: Fix `getInitialType` to handle sets + duration_sec**

Update `getInitialType` (line 49) so an exercise with both `sets` and `duration_sec` resolves to `'sets-reps'` not `'duration'`:

```typescript
const getInitialType = (): ExerciseType => {
  if (!exercise) return 'sets-reps';
  if (exercise.calories !== null && exercise.calories !== undefined) return 'calories';
  if (exercise.distance_m !== null && exercise.distance_m !== undefined) return 'distance';
  if (exercise.distance_range) return 'distance';
  // If sets is set, it's sets-reps even if duration_sec is also set (per-set modifier)
  if (exercise.sets !== null && exercise.sets !== undefined) return 'sets-reps';
  if (exercise.duration_sec !== null && exercise.duration_sec !== undefined) return 'duration';
  return 'sets-reps';
};
```

**Step 4: Verify TypeScript compiles**

```bash
npx tsc --noEmit
```

Expected: No errors.

**Step 5: Commit**

```bash
git add amakaflow-ui/src/components/EditExerciseDialog.tsx
git commit -m "feat(edit-exercise): add modifier state for time cap and duration per set"
```

---

## Task 3: Update `updateExerciseImmediately` to write modifiers

**Files:**
- Modify: `amakaflow-ui/src/components/EditExerciseDialog.tsx:122-220`

**Step 1: Add modifier values to the overrides type and resolver**

The `updateExerciseImmediately` callback signature (line 123) needs two new override fields. Add to the `overrides` parameter type:

```typescript
timeCapEnabled?: boolean;
timeCapSec?: number;
durationPerSetEnabled?: boolean;
```

Add to the resolver block (after line 156):

```typescript
const currentTimeCapEnabled = overrides?.timeCapEnabled ?? timeCapEnabled;
const currentTimeCapSec = overrides?.timeCapSec ?? timeCapSec;
const currentDurationPerSetEnabled = overrides?.durationPerSetEnabled ?? durationPerSetEnabled;
```

**Step 2: Update the per-type field logic**

Replace the four `if/else if` blocks (lines 169-210) with:

```typescript
if (currentExerciseType === 'sets-reps') {
  updates.sets = currentSets;
  updates.reps = currentRepsRange ? null : currentReps;
  updates.reps_range = currentRepsRange || null;
  // Duration per set: write duration_sec only if modifier is enabled
  updates.duration_sec = currentDurationPerSetEnabled ? currentDurationSec : null;
  updates.distance_m = null;
  updates.distance_range = null;
  updates.calories = null;
  updates.time_cap_sec = currentTimeCapEnabled ? currentTimeCapSec : null;
} else if (currentExerciseType === 'duration') {
  updates.duration_sec = currentDurationSec;
  updates.sets = null;
  updates.reps = null;
  updates.reps_range = null;
  updates.distance_m = null;
  updates.distance_range = null;
  updates.calories = null;
  updates.time_cap_sec = null; // Duration standalone has no time cap modifier
  updates.warmup_sets = null;
  updates.warmup_reps = null;
} else if (currentExerciseType === 'distance') {
  updates.distance_m = currentDistanceRange ? null : (currentDistanceM !== null && currentDistanceM !== undefined ? currentDistanceM : null);
  updates.distance_range = currentDistanceRange || null;
  updates.sets = null;
  updates.reps = null;
  updates.reps_range = null;
  updates.duration_sec = null;
  updates.calories = null;
  updates.time_cap_sec = currentTimeCapEnabled ? currentTimeCapSec : null;
  updates.warmup_sets = null;
  updates.warmup_reps = null;
} else if (currentExerciseType === 'calories') {
  updates.calories = currentCaloriesVal;
  updates.distance_m = null;
  updates.distance_range = null;
  updates.duration_sec = null;
  updates.sets = null;
  updates.reps = null;
  updates.reps_range = null;
  updates.time_cap_sec = currentTimeCapEnabled ? currentTimeCapSec : null;
  updates.warmup_sets = null;
  updates.warmup_reps = null;
}
```

**Step 3: Add new state to the `useCallback` dependency array**

On line 220, add `timeCapEnabled`, `timeCapSec`, `durationPerSetEnabled` to the dependency array:

```typescript
}, [exercise, exerciseType, name, sets, reps, repsRange, durationSec, distanceM,
    distanceRange, caloriesVal, restSec, restType, notes, warmupEnabled, warmupSets,
    warmupReps, timeCapEnabled, timeCapSec, durationPerSetEnabled, onSave]);
```

**Step 4: Update `handleTabChange` to clear modifiers correctly**

Replace `handleTabChange` (line 223):

```typescript
const handleTabChange = (newType: ExerciseType) => {
  // Clear duration-per-set when leaving sets-reps
  const newDurationPerSetEnabled = newType === 'sets-reps' ? durationPerSetEnabled : false;
  // Clear time cap when switching to duration (duration standalone has no time cap)
  const newTimeCapEnabled = newType === 'duration' ? false : timeCapEnabled;

  setExerciseType(newType);
  if (!newDurationPerSetEnabled) setDurationPerSetEnabled(false);
  if (!newTimeCapEnabled) setTimeCapEnabled(false);

  updateExerciseImmediately({
    exerciseType: newType,
    durationPerSetEnabled: newDurationPerSetEnabled,
    timeCapEnabled: newTimeCapEnabled,
  });
};
```

**Step 5: Verify TypeScript compiles**

```bash
npx tsc --noEmit
```

Expected: No errors.

**Step 6: Commit**

```bash
git add amakaflow-ui/src/components/EditExerciseDialog.tsx
git commit -m "feat(edit-exercise): wire modifier state into updateExerciseImmediately"
```

---

## Task 4: Add Optional modifier UI — Sets/Reps tab

**Files:**
- Modify: `amakaflow-ui/src/components/EditExerciseDialog.tsx` (Sets/Reps TabsContent, around line 287)

**Step 1: Add Clock import**

At line 11, add `Clock` to the lucide-react import:

```typescript
import { ChevronDown, ChevronUp, Clock } from 'lucide-react';
```

**Step 2: Add the Optional section inside the Sets/Reps TabsContent**

After the warm-up section (end of the `sets-reps` TabsContent, before the closing `</TabsContent>`), add:

```tsx
{/* Optional modifiers */}
<div className="space-y-3 pt-2">
  <div className="flex items-center gap-2">
    <div className="h-px flex-1 bg-border" />
    <span className="text-xs text-muted-foreground">Optional</span>
    <div className="h-px flex-1 bg-border" />
  </div>

  {/* Duration per set toggle */}
  <div className="space-y-2">
    <div className="flex items-center justify-between">
      <Label className="text-sm font-normal">Duration per set</Label>
      <Switch
        checked={durationPerSetEnabled}
        onCheckedChange={(checked) => {
          setDurationPerSetEnabled(checked);
          updateExerciseImmediately({ durationPerSetEnabled: checked });
        }}
      />
    </div>
    {durationPerSetEnabled && (
      <div className="space-y-2">
        <div className="flex items-center justify-between">
          <span className="text-sm text-muted-foreground">Duration</span>
          <span className="text-sm font-medium">{formatDuration(durationSec)}</span>
        </div>
        <div className="flex items-center gap-4">
          <span className="text-xs text-muted-foreground w-8">0s</span>
          <Slider
            value={[durationSec]}
            onValueChange={(values) => {
              const newValue = values[0];
              setDurationSec(newValue);
              updateExerciseImmediately({ durationSec: newValue });
            }}
            min={0}
            max={600}
            step={5}
            className="flex-1"
          />
          <span className="text-xs text-muted-foreground w-8 text-right">10m</span>
          <Input
            type="number"
            value={durationSec}
            onChange={(e) => {
              const val = parseInt(e.target.value) || 0;
              setDurationSec(val);
              updateExerciseImmediately({ durationSec: val });
            }}
            className="w-16 h-9 text-center"
          />
        </div>
        <p className="text-xs text-muted-foreground">e.g., 30 for 30 seconds per set</p>
      </div>
    )}
  </div>

  {/* Time cap toggle */}
  <div className="space-y-2">
    <div className="flex items-center justify-between">
      <Label className="text-sm font-normal">Time Cap</Label>
      <Switch
        checked={timeCapEnabled}
        onCheckedChange={(checked) => {
          setTimeCapEnabled(checked);
          updateExerciseImmediately({ timeCapEnabled: checked });
        }}
      />
    </div>
    {timeCapEnabled && (
      <div className="space-y-2">
        <div className="flex items-center justify-between">
          <span className="text-sm text-muted-foreground">Cap</span>
          <span className="text-sm font-medium">{formatDuration(timeCapSec)}</span>
        </div>
        <div className="flex items-center gap-4">
          <span className="text-xs text-muted-foreground w-8">0s</span>
          <Slider
            value={[timeCapSec]}
            onValueChange={(values) => {
              const newValue = values[0];
              setTimeCapSec(newValue);
              updateExerciseImmediately({ timeCapSec: newValue });
            }}
            min={0}
            max={1800}
            step={30}
            className="flex-1"
          />
          <span className="text-xs text-muted-foreground w-8 text-right">30m</span>
          <Input
            type="number"
            value={timeCapSec}
            onChange={(e) => {
              const val = parseInt(e.target.value) || 0;
              setTimeCapSec(val);
              updateExerciseImmediately({ timeCapSec: val });
            }}
            className="w-16 h-9 text-center"
          />
        </div>
        <p className="text-xs text-muted-foreground">e.g., 300 for 5 minutes</p>
      </div>
    )}
  </div>
</div>
```

**Step 3: Verify TypeScript compiles and dev server starts**

```bash
npx tsc --noEmit
npm run dev
```

Open `localhost:3000`, edit a Sets/Reps exercise, verify the Optional section appears with two toggles.

**Step 4: Commit**

```bash
git add amakaflow-ui/src/components/EditExerciseDialog.tsx
git commit -m "feat(edit-exercise): add Duration per set and Time Cap modifiers to Sets/Reps tab"
```

---

## Task 5: Add Time Cap modifier UI — Distance and Calories tabs

**Files:**
- Modify: `amakaflow-ui/src/components/EditExerciseDialog.tsx` (Distance and Calories TabsContent)

**Step 1: Extract a reusable TimeCapModifier block**

To avoid duplicating the time cap UI, define a helper just above the `return` statement (around line 242):

```tsx
const TimeCapModifierUI = (
  <div className="space-y-2 pt-2">
    <div className="flex items-center gap-2">
      <div className="h-px flex-1 bg-border" />
      <span className="text-xs text-muted-foreground">Optional</span>
      <div className="h-px flex-1 bg-border" />
    </div>
    <div className="space-y-2">
      <div className="flex items-center justify-between">
        <Label className="text-sm font-normal">Time Cap</Label>
        <Switch
          checked={timeCapEnabled}
          onCheckedChange={(checked) => {
            setTimeCapEnabled(checked);
            updateExerciseImmediately({ timeCapEnabled: checked });
          }}
        />
      </div>
      {timeCapEnabled && (
        <div className="space-y-2">
          <div className="flex items-center justify-between">
            <span className="text-sm text-muted-foreground">Cap</span>
            <span className="text-sm font-medium">{formatDuration(timeCapSec)}</span>
          </div>
          <div className="flex items-center gap-4">
            <span className="text-xs text-muted-foreground w-8">0s</span>
            <Slider
              value={[timeCapSec]}
              onValueChange={(values) => {
                const newValue = values[0];
                setTimeCapSec(newValue);
                updateExerciseImmediately({ timeCapSec: newValue });
              }}
              min={0}
              max={1800}
              step={30}
              className="flex-1"
            />
            <span className="text-xs text-muted-foreground w-8 text-right">30m</span>
            <Input
              type="number"
              value={timeCapSec}
              onChange={(e) => {
                const val = parseInt(e.target.value) || 0;
                setTimeCapSec(val);
                updateExerciseImmediately({ timeCapSec: val });
              }}
              className="w-16 h-9 text-center"
            />
          </div>
          <p className="text-xs text-muted-foreground">e.g., 300 for 5 minutes</p>
        </div>
      )}
    </div>
  </div>
);
```

**Step 2: Add `{TimeCapModifierUI}` at the end of Distance and Calories TabsContent**

Inside the `distance` TabsContent, before its closing `</TabsContent>` tag, add:
```tsx
{TimeCapModifierUI}
```

Inside the `calories` TabsContent, before its closing `</TabsContent>` tag, add:
```tsx
{TimeCapModifierUI}
```

**Step 3: Verify in browser**

Open `localhost:3000`, edit a Distance exercise, verify the Time Cap toggle appears. Toggle it on, set 300s. Save. Re-open the exercise — it should load with Time Cap toggled on and showing 5m.

Repeat for a Calories exercise.

**Step 4: Commit**

```bash
git add amakaflow-ui/src/components/EditExerciseDialog.tsx
git commit -m "feat(edit-exercise): add Time Cap modifier to Distance and Calories tabs"
```

---

## Task 6: Update DraggableExercise badge display

**Files:**
- Modify: `amakaflow-ui/src/components/DraggableExercise.tsx:193-206`

**Step 1: Add Clock import**

Find the lucide-react import at the top of `DraggableExercise.tsx` and add `Clock`:

```typescript
import { ..., Clock } from 'lucide-react';
```

**Step 2: Replace the metrics badge block (lines 195-206)**

Replace:

```tsx
<div className="flex gap-2 text-sm">
  {exercise.reps && <Badge variant="secondary">{exercise.reps} reps</Badge>}
  {exercise.distance_m && <Badge variant="secondary">{exercise.distance_m}m</Badge>}
  {exercise.duration_sec && <Badge variant="secondary">{exercise.duration_sec}s</Badge>}
  {exercise.weight_kg && <Badge variant="secondary">{exercise.weight_kg}kg</Badge>}
  {exercise.sets && exercise.sets > 1 && (
    <Badge variant="default" className="bg-primary/20 text-primary">
      <Repeat className="w-3 h-3 mr-1" />
      {exercise.sets} sets
    </Badge>
  )}
</div>
```

With:

```tsx
<div className="flex gap-2 text-sm flex-wrap">
  {/* Sets: combine with duration_sec if both present (e.g. "3 × 30s") */}
  {exercise.sets && exercise.sets > 1 && (
    <Badge variant="default" className="bg-primary/20 text-primary">
      <Repeat className="w-3 h-3 mr-1" />
      {exercise.duration_sec
        ? `${exercise.sets} × ${formatDuration(exercise.duration_sec)}`
        : `${exercise.sets} sets`}
    </Badge>
  )}
  {/* Reps (only show if sets didn't already combine with duration) */}
  {exercise.reps && <Badge variant="secondary">{exercise.reps} reps</Badge>}
  {/* Distance */}
  {exercise.distance_m && <Badge variant="secondary">{formatDistance(exercise.distance_m)}</Badge>}
  {/* Duration standalone (only when no sets — sets+duration shown above) */}
  {exercise.duration_sec && !exercise.sets && (
    <Badge variant="secondary">{formatDuration(exercise.duration_sec)}</Badge>
  )}
  {/* Calories */}
  {exercise.calories && <Badge variant="secondary">{exercise.calories} cal</Badge>}
  {/* Time cap — clock icon, muted style */}
  {exercise.time_cap_sec && (
    <Badge variant="outline" className="text-muted-foreground">
      <Clock className="w-3 h-3 mr-1" />
      {formatDuration(exercise.time_cap_sec)} cap
    </Badge>
  )}
</div>
```

**Step 3: Import `formatDuration` and `formatDistance`**

These helpers currently live inside `EditExerciseDialog.tsx`. Move them to a shared utility file and import from there in both components.

Create `amakaflow-ui/src/lib/formatExercise.ts`:

```typescript
export const formatDuration = (seconds: number): string => {
  if (seconds >= 60) {
    const minutes = Math.floor(seconds / 60);
    const remainingSec = seconds % 60;
    return remainingSec > 0 ? `${minutes}m ${remainingSec}s` : `${minutes}m`;
  }
  return `${seconds}s`;
};

export const formatDistance = (meters: number): string => {
  if (meters >= 1000) {
    const km = meters / 1000;
    return km % 1 === 0 ? `${km}km` : `${km.toFixed(1)}km`;
  }
  return `${meters}m`;
};
```

In `EditExerciseDialog.tsx`, replace the two local function definitions (lines 24-40) with:

```typescript
import { formatDuration, formatDistance } from '../lib/formatExercise';
```

In `DraggableExercise.tsx`, add:

```typescript
import { formatDuration, formatDistance } from '../lib/formatExercise';
```

**Step 4: Verify TypeScript compiles**

```bash
npx tsc --noEmit
```

Expected: No errors.

**Step 5: Smoke test in browser**

1. Edit a Sets/Reps exercise — toggle Duration per set to 30s and Time Cap to 5m. Save. Card should show `3 × 30s` and `🕐 5m cap`.
2. Edit a Distance exercise — toggle Time Cap to 300s. Card should show `1000m` and `🕐 5m cap`.
3. Edit a Duration standalone exercise — card should show `60s`, no time cap badge.

**Step 6: Commit**

```bash
git add amakaflow-ui/src/components/DraggableExercise.tsx amakaflow-ui/src/lib/formatExercise.ts amakaflow-ui/src/components/EditExerciseDialog.tsx
git commit -m "feat(exercise-card): display combined metrics and time cap badge"
```

---

## Task 7: Run full test suite and fix any failures

**Step 1: Run tests**

```bash
cd amakaflow-ui && npm test
```

**Step 2: If tests fail**

Read the failure output, find the affected test file, and fix the test or the implementation as appropriate.

**Step 3: Final TypeScript check**

```bash
npx tsc --noEmit
```

**Step 4: Commit any test fixes**

```bash
git add -p
git commit -m "fix(exercise-multi-metric): fix test failures after modifier additions"
```
