# Workout Structure UI Redesign — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Replace the current flat workout block UI with type-first cards that show structure at a glance, with expandable inline config rows per block type — no dialogs for common configuration.

**Architecture:** Pure UI change in `amakaflow-ui`. No backend changes. Seven tasks, each independently committable. The data model is already correct — this is entirely a presentation and interaction layer change.

**Tech Stack:** React 18, TypeScript, Tailwind CSS, shadcn/ui, Vitest + Testing Library (existing)

**Design doc:** `docs/plans/2026-02-21-workout-structure-ui-redesign.md`

**Key files:**
- Types: `src/types/workout.ts`
- Utils: `src/lib/workout-utils.ts`
- Main component: `src/components/StructureWorkout.tsx`
- New components: `src/components/BlockConfigRow.tsx`, `src/components/AddBlockTypePicker.tsx`, `src/components/WorkoutSuggestionStrips.tsx`
- Tests: `src/components/__tests__/`

---

### Task 1: Extend WorkoutStructureType + add display/metric utilities

**Files:**
- Modify: `src/types/workout.ts`
- Modify: `src/lib/workout-utils.ts`
- Test: `src/components/__tests__/workout-utils.test.ts`

**Step 1: Write the failing tests**

Create `src/components/__tests__/workout-utils.test.ts`:

```ts
import { describe, it, expect } from 'vitest';
import {
  getStructureDisplayName,
  formatRestSecs,
  formatMMSS,
  getBlockKeyMetric,
} from '../../lib/workout-utils';
import type { Block } from '../../types/workout';

describe('getStructureDisplayName', () => {
  it('returns WARM-UP for warmup', () => {
    expect(getStructureDisplayName('warmup')).toBe('WARM-UP');
  });
  it('returns COOLDOWN for cooldown', () => {
    expect(getStructureDisplayName('cooldown')).toBe('COOLDOWN');
  });
  it('returns FOR TIME for for-time', () => {
    expect(getStructureDisplayName('for-time')).toBe('FOR TIME');
  });
  it('returns CIRCUIT for circuit', () => {
    expect(getStructureDisplayName('circuit')).toBe('CIRCUIT');
  });
});

describe('formatRestSecs', () => {
  it('formats seconds <= 90 as Xs', () => {
    expect(formatRestSecs(30)).toBe('30s');
    expect(formatRestSecs(90)).toBe('90s');
  });
  it('formats seconds > 90 with minutes', () => {
    expect(formatRestSecs(120)).toBe('2m');
    expect(formatRestSecs(150)).toBe('2m 30s');
  });
});

describe('formatMMSS', () => {
  it('formats seconds as MM:SS', () => {
    expect(formatMMSS(600)).toBe('10:00');
    expect(formatMMSS(75)).toBe('1:15');
    expect(formatMMSS(1200)).toBe('20:00');
  });
});

describe('getBlockKeyMetric', () => {
  it('returns rounds and rest for circuit', () => {
    const block: Partial<Block> = {
      structure: 'circuit',
      rounds: 4,
      rest_between_rounds_sec: 30,
    };
    expect(getBlockKeyMetric(block as Block)).toBe('4 rnds · 30s rest');
  });
  it('returns time cap for amrap', () => {
    const block: Partial<Block> = {
      structure: 'amrap',
      time_cap_sec: 1200,
    };
    expect(getBlockKeyMetric(block as Block)).toBe('Cap: 20:00');
  });
  it('returns work/rest for tabata', () => {
    const block: Partial<Block> = {
      structure: 'tabata',
      time_work_sec: 20,
      time_rest_sec: 10,
      rounds: 8,
    };
    expect(getBlockKeyMetric(block as Block)).toBe('20s on · 10s off · 8 rnds');
  });
  it('returns Configure → when fields missing', () => {
    const block: Partial<Block> = { structure: 'circuit' };
    expect(getBlockKeyMetric(block as Block)).toBe('Configure →');
  });
  it('returns duration and activity for warmup', () => {
    const block: Partial<Block> = {
      structure: 'warmup',
      warmup_duration_sec: 300,
      warmup_activity: 'jump_rope',
    };
    expect(getBlockKeyMetric(block as Block)).toBe('5 min · jump rope');
  });
});
```

**Step 2: Run tests to verify they fail**

```bash
cd /Users/davidandrews/dev/AmakaFlow/amakaflow-dev-workspace/amakaflow-ui
npx vitest run src/components/__tests__/workout-utils.test.ts
```
Expected: FAIL (formatRestSecs, formatMMSS, getBlockKeyMetric not defined)

**Step 3: Add `'warmup' | 'cooldown'` to WorkoutStructureType**

In `src/types/workout.ts`, update `WorkoutStructureType`:

```ts
export type WorkoutStructureType =
  | 'superset'
  | 'circuit'
  | 'tabata'
  | 'emom'
  | 'amrap'
  | 'for-time'
  | 'rounds'
  | 'sets'
  | 'regular'
  | 'warmup'    // new
  | 'cooldown'; // new
```

**Step 4: Add utility functions to `src/lib/workout-utils.ts`**

Add these functions after the existing `getStructureDisplayName`:

```ts
/** Format seconds into human-readable rest label. */
export function formatRestSecs(sec: number): string {
  if (sec <= 90) return `${sec}s`;
  const m = Math.floor(sec / 60);
  const s = sec % 60;
  return s > 0 ? `${m}m ${s}s` : `${m}m`;
}

/** Format seconds as MM:SS string. */
export function formatMMSS(sec: number): string {
  const m = Math.floor(sec / 60);
  const s = sec % 60;
  return `${m}:${String(s).padStart(2, '0')}`;
}

/** Return the key metric string shown in a block's header. */
export function getBlockKeyMetric(block: Block): string {
  switch (block.structure) {
    case 'circuit':
    case 'rounds': {
      const parts: string[] = [];
      if (block.rounds) parts.push(`${block.rounds} rnds`);
      if (block.rest_between_rounds_sec) parts.push(`${formatRestSecs(block.rest_between_rounds_sec)} rest`);
      return parts.length ? parts.join(' · ') : 'Configure →';
    }
    case 'emom': {
      const mins = block.time_cap_sec ? Math.floor(block.time_cap_sec / 60) : block.rounds ?? null;
      const workSec = block.time_work_sec;
      if (mins && workSec) return `${mins} min · ${workSec}s/station`;
      if (mins) return `${mins} min`;
      return 'Configure →';
    }
    case 'amrap':
      return block.time_cap_sec ? `Cap: ${formatMMSS(block.time_cap_sec)}` : 'Configure →';
    case 'for-time':
      return block.time_cap_sec ? `Cap: ${formatMMSS(block.time_cap_sec)}` : 'For Time';
    case 'tabata': {
      const parts: string[] = [];
      if (block.time_work_sec) parts.push(`${block.time_work_sec}s on`);
      if (block.time_rest_sec) parts.push(`${block.time_rest_sec}s off`);
      if (block.rounds) parts.push(`${block.rounds} rnds`);
      return parts.length ? parts.join(' · ') : 'Configure →';
    }
    case 'sets':
    case 'regular': {
      const parts: string[] = [];
      if (block.sets) parts.push(`${block.sets} sets`);
      if (block.rest_between_sets_sec) parts.push(`${formatRestSecs(block.rest_between_sets_sec)} rest`);
      return parts.length ? parts.join(' · ') : 'Configure →';
    }
    case 'superset': {
      const parts: string[] = [];
      if (block.rounds) parts.push(`${block.rounds} rnds`);
      if (block.rest_between_rounds_sec) parts.push(`${formatRestSecs(block.rest_between_rounds_sec)} rest`);
      return parts.length ? parts.join(' · ') : 'Configure →';
    }
    case 'warmup':
    case 'cooldown': {
      const parts: string[] = [];
      if (block.warmup_duration_sec) {
        const m = Math.floor(block.warmup_duration_sec / 60);
        const s = block.warmup_duration_sec % 60;
        parts.push(s > 0 ? `${m}m ${s}s` : `${m} min`);
      }
      if (block.warmup_activity) parts.push(block.warmup_activity.replace(/_/g, ' '));
      return parts.length ? parts.join(' · ') : 'Configure →';
    }
    default:
      return '';
  }
}
```

Also update `getStructureDisplayName` to handle special cases:

```ts
export function getStructureDisplayName(structure: string | null): string {
  if (!structure) return 'BLOCK';
  const MAP: Record<string, string> = {
    'warmup': 'WARM-UP',
    'cooldown': 'COOLDOWN',
    'for-time': 'FOR TIME',
    'emom': 'EMOM',
    'amrap': 'AMRAP',
    'hiit': 'HIIT',
  };
  return MAP[structure] ?? structure.toUpperCase();
}
```

Also add warmup/cooldown to `getStructureDefaults`:

```ts
case 'warmup':
case 'cooldown':
  return {
    warmup_duration_sec: 300, // 5 min default
    warmup_activity: 'stretching' as WarmupActivity,
    rounds: null, sets: null, time_work_sec: null, time_rest_sec: null,
    time_cap_sec: null, rest_between_rounds_sec: null, rest_between_sets_sec: null,
  };
```

Add `WarmupActivity` to the imports at top of `workout-utils.ts`:
```ts
import { Block, Exercise, WorkoutStructure, Superset, ValidationResponse, WorkoutStructureType, WarmupActivity } from '../types/workout';
```

**Step 5: Run tests to verify they pass**

```bash
npx vitest run src/components/__tests__/workout-utils.test.ts
```
Expected: 9 tests PASS

**Step 6: Commit**

```bash
git add src/types/workout.ts src/lib/workout-utils.ts src/components/__tests__/workout-utils.test.ts
git commit -m "feat(structure-ui): add warmup/cooldown types + format/metric utilities"
```

---

### Task 2: BlockConfigRow component (type-aware inline config)

**Files:**
- Create: `src/components/BlockConfigRow.tsx`
- Test: `src/components/__tests__/BlockConfigRow.test.tsx`

**Step 1: Write the failing tests**

Create `src/components/__tests__/BlockConfigRow.test.tsx`:

```tsx
import { describe, it, expect, vi } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import { BlockConfigRow } from '../BlockConfigRow';
import type { Block } from '../../types/workout';

const makeBlock = (overrides: Partial<Block>): Block => ({
  id: 'b1', label: 'Test', structure: null, exercises: [], ...overrides,
});

describe('BlockConfigRow', () => {
  it('renders rounds and rest steppers for circuit', () => {
    const onUpdate = vi.fn();
    render(
      <BlockConfigRow
        block={makeBlock({ structure: 'circuit', rounds: 4, rest_between_rounds_sec: 30 })}
        onUpdate={onUpdate}
      />
    );
    expect(screen.getByText('Rounds')).toBeInTheDocument();
    expect(screen.getByText('4')).toBeInTheDocument();
    expect(screen.getByText('Rest')).toBeInTheDocument();
    expect(screen.getByText('30s')).toBeInTheDocument();
  });

  it('renders time cap for amrap', () => {
    const onUpdate = vi.fn();
    render(
      <BlockConfigRow
        block={makeBlock({ structure: 'amrap', time_cap_sec: 1200 })}
        onUpdate={onUpdate}
      />
    );
    expect(screen.getByText('Time Cap')).toBeInTheDocument();
    expect(screen.getByText('20:00')).toBeInTheDocument();
  });

  it('renders work/rest/rounds for tabata', () => {
    const onUpdate = vi.fn();
    render(
      <BlockConfigRow
        block={makeBlock({ structure: 'tabata', time_work_sec: 20, time_rest_sec: 10, rounds: 8 })}
        onUpdate={onUpdate}
      />
    );
    expect(screen.getByText('Work')).toBeInTheDocument();
    expect(screen.getByText('Rest')).toBeInTheDocument();
    expect(screen.getByText('Rounds')).toBeInTheDocument();
  });

  it('increments rounds when + is clicked for circuit', () => {
    const onUpdate = vi.fn();
    render(
      <BlockConfigRow
        block={makeBlock({ structure: 'circuit', rounds: 4, rest_between_rounds_sec: 30 })}
        onUpdate={onUpdate}
      />
    );
    const plusButtons = screen.getAllByRole('button', { name: '+' });
    fireEvent.click(plusButtons[0]); // first + is rounds
    expect(onUpdate).toHaveBeenCalledWith(expect.objectContaining({ rounds: 5 }));
  });

  it('renders activity selector and duration for warmup', () => {
    const onUpdate = vi.fn();
    render(
      <BlockConfigRow
        block={makeBlock({ structure: 'warmup', warmup_duration_sec: 300, warmup_activity: 'jump_rope' })}
        onUpdate={onUpdate}
      />
    );
    expect(screen.getByText('Duration')).toBeInTheDocument();
    expect(screen.getByText('Activity')).toBeInTheDocument();
  });
});
```

**Step 2: Run tests to verify they fail**

```bash
npx vitest run src/components/__tests__/BlockConfigRow.test.tsx
```
Expected: FAIL (BlockConfigRow not defined)

**Step 3: Implement BlockConfigRow**

Create `src/components/BlockConfigRow.tsx`:

```tsx
import { useState } from 'react';
import type { Block, WarmupActivity } from '../types/workout';
import { formatRestSecs, formatMMSS } from '../lib/workout-utils';
import { Label } from './ui/label';
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from './ui/select';

// ── Stepper ───────────────────────────────────────────────────────────────────

function Stepper({
  value,
  onChange,
  min = 0,
  max = 9999,
  format,
  step = 1,
}: {
  value: number | null;
  onChange: (v: number) => void;
  min?: number;
  max?: number;
  format?: (v: number) => string;
  step?: number;
}) {
  const [editing, setEditing] = useState(false);
  const [draft, setDraft] = useState('');
  const display = value != null ? (format ? format(value) : String(value)) : '—';

  return (
    <div className="flex items-center gap-1">
      <button
        type="button"
        aria-label="-"
        onClick={() => onChange(Math.max(min, (value ?? 0) - step))}
        className="w-7 h-7 rounded border bg-background hover:bg-muted flex items-center justify-center text-sm font-medium select-none"
      >
        −
      </button>
      {editing ? (
        <input
          autoFocus
          value={draft}
          onChange={e => setDraft(e.target.value)}
          onBlur={() => {
            const n = parseInt(draft, 10);
            if (!isNaN(n)) onChange(Math.max(min, Math.min(max, n)));
            setEditing(false);
          }}
          onKeyDown={e => {
            if (e.key === 'Enter') e.currentTarget.blur();
            if (e.key === 'Escape') setEditing(false);
          }}
          className="w-16 text-center text-sm border rounded px-1 py-0.5"
        />
      ) : (
        <span
          className="min-w-[3.5rem] text-center text-sm font-medium cursor-pointer hover:underline underline-offset-2"
          onClick={() => { setDraft(String(value ?? 0)); setEditing(true); }}
        >
          {display}
        </span>
      )}
      <button
        type="button"
        aria-label="+"
        onClick={() => onChange(Math.min(max, (value ?? 0) + step))}
        className="w-7 h-7 rounded border bg-background hover:bg-muted flex items-center justify-center text-sm font-medium select-none"
      >
        +
      </button>
    </div>
  );
}

// ── Field wrapper ─────────────────────────────────────────────────────────────

function Field({ label, children }: { label: string; children: React.ReactNode }) {
  return (
    <div className="flex flex-col gap-1">
      <Label className="text-xs text-muted-foreground">{label}</Label>
      {children}
    </div>
  );
}

// ── Warmup activity options ───────────────────────────────────────────────────

const ACTIVITY_OPTIONS: { value: WarmupActivity; label: string }[] = [
  { value: 'stretching', label: 'Stretching' },
  { value: 'jump_rope', label: 'Jump Rope' },
  { value: 'air_bike', label: 'Air Bike' },
  { value: 'treadmill', label: 'Treadmill' },
  { value: 'stairmaster', label: 'Stairmaster' },
  { value: 'rowing', label: 'Rowing' },
  { value: 'custom', label: 'Custom' },
];

// ── BlockConfigRow ────────────────────────────────────────────────────────────

export function BlockConfigRow({
  block,
  onUpdate,
}: {
  block: Block;
  onUpdate: (updates: Partial<Block>) => void;
}) {
  const { structure } = block;

  if (structure === 'circuit' || structure === 'rounds') {
    return (
      <div className="flex flex-wrap gap-6 p-3 bg-muted/30 rounded-lg border-t">
        <Field label="Rounds">
          <Stepper
            value={block.rounds ?? null}
            onChange={v => onUpdate({ rounds: v })}
            min={1}
            max={99}
          />
        </Field>
        <Field label="Rest">
          <Stepper
            value={block.rest_between_rounds_sec ?? null}
            onChange={v => onUpdate({ rest_between_rounds_sec: v })}
            min={0}
            step={5}
            format={formatRestSecs}
          />
        </Field>
      </div>
    );
  }

  if (structure === 'emom') {
    return (
      <div className="flex flex-wrap gap-6 p-3 bg-muted/30 rounded-lg border-t">
        <Field label="Duration (min)">
          <Stepper
            value={block.rounds ?? null}
            onChange={v => onUpdate({ rounds: v })}
            min={1}
            max={60}
          />
        </Field>
        <Field label="Work / station (s)">
          <Stepper
            value={block.time_work_sec ?? null}
            onChange={v => onUpdate({ time_work_sec: v })}
            min={5}
            step={5}
            format={v => `${v}s`}
          />
        </Field>
      </div>
    );
  }

  if (structure === 'amrap') {
    return (
      <div className="flex flex-wrap gap-6 p-3 bg-muted/30 rounded-lg border-t">
        <Field label="Time Cap">
          <Stepper
            value={block.time_cap_sec ?? null}
            onChange={v => onUpdate({ time_cap_sec: v })}
            min={60}
            step={60}
            format={formatMMSS}
          />
        </Field>
      </div>
    );
  }

  if (structure === 'tabata') {
    return (
      <div className="flex flex-wrap gap-6 p-3 bg-muted/30 rounded-lg border-t">
        <Field label="Work">
          <Stepper
            value={block.time_work_sec ?? null}
            onChange={v => onUpdate({ time_work_sec: v })}
            min={5}
            step={5}
            format={v => `${v}s`}
          />
        </Field>
        <Field label="Rest">
          <Stepper
            value={block.time_rest_sec ?? null}
            onChange={v => onUpdate({ time_rest_sec: v })}
            min={0}
            step={5}
            format={v => `${v}s`}
          />
        </Field>
        <Field label="Rounds">
          <Stepper
            value={block.rounds ?? null}
            onChange={v => onUpdate({ rounds: v })}
            min={1}
            max={40}
          />
        </Field>
      </div>
    );
  }

  if (structure === 'for-time') {
    return (
      <div className="flex flex-wrap gap-6 p-3 bg-muted/30 rounded-lg border-t">
        <Field label="Time Cap (optional)">
          <Stepper
            value={block.time_cap_sec ?? null}
            onChange={v => onUpdate({ time_cap_sec: v })}
            min={0}
            step={60}
            format={v => v > 0 ? formatMMSS(v) : 'No cap'}
          />
        </Field>
      </div>
    );
  }

  if (structure === 'sets' || structure === 'regular') {
    return (
      <div className="flex flex-wrap gap-6 p-3 bg-muted/30 rounded-lg border-t">
        <Field label="Sets">
          <Stepper
            value={block.sets ?? null}
            onChange={v => onUpdate({ sets: v })}
            min={1}
            max={20}
          />
        </Field>
        <Field label="Rest between sets">
          <Stepper
            value={block.rest_between_sets_sec ?? null}
            onChange={v => onUpdate({ rest_between_sets_sec: v })}
            min={0}
            step={5}
            format={formatRestSecs}
          />
        </Field>
      </div>
    );
  }

  if (structure === 'superset') {
    return (
      <div className="flex flex-wrap gap-6 p-3 bg-muted/30 rounded-lg border-t">
        <Field label="Rounds">
          <Stepper
            value={block.rounds ?? null}
            onChange={v => onUpdate({ rounds: v })}
            min={1}
            max={20}
          />
        </Field>
        <Field label="Rest after pair">
          <Stepper
            value={block.rest_between_rounds_sec ?? null}
            onChange={v => onUpdate({ rest_between_rounds_sec: v })}
            min={0}
            step={5}
            format={formatRestSecs}
          />
        </Field>
      </div>
    );
  }

  if (structure === 'warmup' || structure === 'cooldown') {
    return (
      <div className="flex flex-wrap gap-6 p-3 bg-muted/30 rounded-lg border-t">
        <Field label="Duration">
          <Stepper
            value={block.warmup_duration_sec ?? null}
            onChange={v => onUpdate({ warmup_duration_sec: v })}
            min={60}
            step={60}
            format={v => {
              const m = Math.floor(v / 60);
              const s = v % 60;
              return s > 0 ? `${m}m ${s}s` : `${m} min`;
            }}
          />
        </Field>
        <Field label="Activity">
          <Select
            value={block.warmup_activity ?? 'stretching'}
            onValueChange={v => onUpdate({ warmup_activity: v as WarmupActivity })}
          >
            <SelectTrigger className="h-8 text-sm w-36">
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              {ACTIVITY_OPTIONS.map(opt => (
                <SelectItem key={opt.value} value={opt.value}>{opt.label}</SelectItem>
              ))}
            </SelectContent>
          </Select>
        </Field>
      </div>
    );
  }

  // null / unknown structure — nothing to configure yet
  return null;
}
```

**Step 4: Run tests to verify they pass**

```bash
npx vitest run src/components/__tests__/BlockConfigRow.test.tsx
```
Expected: 5 tests PASS

**Step 5: Commit**

```bash
git add src/components/BlockConfigRow.tsx src/components/__tests__/BlockConfigRow.test.tsx
git commit -m "feat(structure-ui): add BlockConfigRow with type-aware stepper fields"
```

---

### Task 3: Refactor DraggableBlock header to type-first design

**Files:**
- Modify: `src/components/StructureWorkout.tsx` (DraggableBlock component only, lines ~283–775)
- Test: `src/components/__tests__/DraggableBlock.test.tsx`

**Context:** `DraggableBlock` is a large function component inside `StructureWorkout.tsx`. This task replaces its `CardHeader` with the new type-first layout. The exercise list and D&D logic are untouched.

**Step 1: Write the failing tests**

Create `src/components/__tests__/DraggableBlock.test.tsx`:

```tsx
import { describe, it, expect, vi } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import { DndProvider } from 'react-dnd';
import { HTML5Backend } from 'react-dnd-html5-backend';
import { StructureWorkout } from '../StructureWorkout';
import type { WorkoutStructure } from '../../types/workout';

// Minimal workout for rendering StructureWorkout
function makeWorkout(blockOverrides: object = {}): WorkoutStructure {
  return {
    title: 'Test Workout',
    source: 'test',
    blocks: [{
      id: 'b1',
      label: 'Main Block',
      structure: 'circuit',
      rounds: 4,
      rest_between_rounds_sec: 30,
      exercises: [{ id: 'e1', name: 'Burpees', sets: null, reps: 10, reps_range: null, duration_sec: null, rest_sec: null, distance_m: null, distance_range: null, type: 'cardio' }],
      ...blockOverrides,
    }],
  };
}

const defaultProps = {
  onWorkoutChange: vi.fn(),
  onAutoMap: vi.fn(),
  onValidate: vi.fn(),
  loading: false,
  selectedDevice: 'ios_companion' as const,
  onDeviceChange: vi.fn(),
  userSelectedDevices: ['ios_companion'],
};

function renderWorkout(workout: WorkoutStructure) {
  return render(
    <DndProvider backend={HTML5Backend}>
      <StructureWorkout workout={workout} {...defaultProps} />
    </DndProvider>
  );
}

describe('DraggableBlock type-first header', () => {
  it('shows CIRCUIT type badge', () => {
    renderWorkout(makeWorkout({ structure: 'circuit', rounds: 4 }));
    expect(screen.getByText('CIRCUIT')).toBeInTheDocument();
  });

  it('shows key metric in header for circuit', () => {
    renderWorkout(makeWorkout({ structure: 'circuit', rounds: 4, rest_between_rounds_sec: 30 }));
    expect(screen.getByText('4 rnds · 30s rest')).toBeInTheDocument();
  });

  it('config row is hidden initially', () => {
    renderWorkout(makeWorkout({ structure: 'circuit', rounds: 4 }));
    expect(screen.queryByText('Rounds')).not.toBeInTheDocument();
  });

  it('config row shows when configure button is clicked', () => {
    renderWorkout(makeWorkout({ structure: 'circuit', rounds: 4, rest_between_rounds_sec: 30 }));
    const configBtn = screen.getByRole('button', { name: /configure/i });
    fireEvent.click(configBtn);
    expect(screen.getByText('Rounds')).toBeInTheDocument();
  });

  it('shows EMOM badge and cap metric', () => {
    renderWorkout(makeWorkout({ structure: 'emom', rounds: 12, time_work_sec: 40 }));
    expect(screen.getByText('EMOM')).toBeInTheDocument();
    expect(screen.getByText('12 min · 40s/station')).toBeInTheDocument();
  });
});
```

**Step 2: Run tests to verify they fail**

```bash
npx vitest run src/components/__tests__/DraggableBlock.test.tsx
```
Expected: FAIL (type badge and key metric not in DOM)

**Step 3: Define colour map constant at top of StructureWorkout.tsx**

Add after the imports (before the `cloneExercise` helpers):

```tsx
// ── Block type visual system ──────────────────────────────────────────────────
const STRUCTURE_STYLES: Record<string, { border: string; badge: string }> = {
  circuit:   { border: 'border-l-4 border-l-green-500',   badge: 'bg-green-100 text-green-800 dark:bg-green-900 dark:text-green-200' },
  rounds:    { border: 'border-l-4 border-l-green-400',   badge: 'bg-green-50 text-green-700 dark:bg-green-900 dark:text-green-300' },
  emom:      { border: 'border-l-4 border-l-blue-500',    badge: 'bg-blue-100 text-blue-800 dark:bg-blue-900 dark:text-blue-200' },
  amrap:     { border: 'border-l-4 border-l-orange-500',  badge: 'bg-orange-100 text-orange-800 dark:bg-orange-900 dark:text-orange-200' },
  tabata:    { border: 'border-l-4 border-l-red-500',     badge: 'bg-red-100 text-red-800 dark:bg-red-900 dark:text-red-200' },
  'for-time':{ border: 'border-l-4 border-l-purple-500',  badge: 'bg-purple-100 text-purple-800 dark:bg-purple-900 dark:text-purple-200' },
  sets:      { border: 'border-l-4 border-l-neutral-400', badge: 'bg-neutral-100 text-neutral-700 dark:bg-neutral-800 dark:text-neutral-300' },
  regular:   { border: 'border-l-4 border-l-neutral-400', badge: 'bg-neutral-100 text-neutral-700 dark:bg-neutral-800 dark:text-neutral-300' },
  superset:  { border: 'border-l-4 border-l-amber-500',   badge: 'bg-amber-100 text-amber-800 dark:bg-amber-900 dark:text-amber-200' },
  warmup:    { border: 'border-l-4 border-l-slate-300',   badge: 'bg-slate-100 text-slate-600 dark:bg-slate-800 dark:text-slate-300' },
  cooldown:  { border: 'border-l-4 border-l-slate-300',   badge: 'bg-slate-100 text-slate-600 dark:bg-slate-800 dark:text-slate-300' },
  default:   { border: 'border-l-4 border-l-neutral-300', badge: 'bg-neutral-100 text-neutral-600' },
};
```

**Step 4: Update DraggableBlock to use type-first header + BlockConfigRow**

In `src/components/StructureWorkout.tsx`, add to imports:
```tsx
import { BlockConfigRow } from './BlockConfigRow';
import { getStructureDisplayName, getBlockKeyMetric } from '../lib/workout-utils';
```

In the `DraggableBlock` component:

1. Add state for config row visibility after the existing `isCollapsed` state:
```tsx
const [showConfig, setShowConfig] = useState(false);
```

2. Replace the entire `<CardHeader>` section with:
```tsx
<CardHeader className={`${styles.border} pl-4 bg-muted/20`}>
  <div className="flex items-center gap-2 min-w-0">
    {/* Drag handle */}
    <div
      ref={drag}
      className="cursor-grab active:cursor-grabbing text-muted-foreground hover:text-foreground shrink-0"
    >
      <GripVertical className="w-5 h-5" />
    </div>

    {/* Collapse exercises toggle */}
    <Button
      size="sm"
      variant="ghost"
      onClick={() => setIsCollapsed(!isCollapsed)}
      className="p-0 h-auto hover:bg-transparent shrink-0"
      title={isCollapsed ? 'Expand exercises' : 'Collapse exercises'}
    >
      {isCollapsed ? <ChevronDown className="w-4 h-4 text-muted-foreground" /> : <ChevronUp className="w-4 h-4 text-muted-foreground" />}
    </Button>

    {/* Type badge */}
    <span className={`shrink-0 text-xs font-bold px-2 py-0.5 rounded ${styles.badge}`}>
      {getStructureDisplayName(block.structure)}
    </span>

    {/* Block name */}
    <span className="font-medium text-sm truncate flex-1">{block.label}</span>

    {/* Key metric */}
    {block.structure && (
      <span className="text-xs text-muted-foreground shrink-0 hidden sm:block">
        {getBlockKeyMetric(block)}
      </span>
    )}

    {/* Configure button */}
    {block.structure && (
      <Button
        size="sm"
        variant={showConfig ? 'secondary' : 'ghost'}
        onClick={() => setShowConfig(!showConfig)}
        className="shrink-0 gap-1 text-xs h-7"
        aria-label="configure"
      >
        <Settings2 className="w-3 h-3" />
        Configure
      </Button>
    )}

    {/* Edit block name button */}
    <Button size="sm" variant="ghost" onClick={onEditBlock} title="Edit block name" className="shrink-0 p-1 h-7">
      <Edit2 className="w-3.5 h-3.5" />
    </Button>
  </div>
</CardHeader>

{/* Config row — inline, no dialog */}
{showConfig && (
  <BlockConfigRow
    block={block}
    onUpdate={(updates) => onUpdateBlock(updates)}
  />
)}
```

3. Add `Settings2` to the lucide-react import line.

4. Remove the old `getStructureInfo()` helper and the `{getStructureInfo()}` render call inside CardHeader — it's replaced by the key metric in the header.

**Step 5: Run tests to verify they pass**

```bash
npx vitest run src/components/__tests__/DraggableBlock.test.tsx
```
Expected: 5 tests PASS

**Step 6: Run full test suite and fix any regressions**

```bash
npm test -- --reporter=verbose 2>&1 | grep -E "(PASS|FAIL|Error)"
```

**Step 7: Commit**

```bash
git add src/components/StructureWorkout.tsx
git commit -m "feat(structure-ui): type-first block headers with colour accents and inline config"
```

---

### Task 4: AddBlockTypePicker — inline chip strip

**Files:**
- Create: `src/components/AddBlockTypePicker.tsx`
- Test: `src/components/__tests__/AddBlockTypePicker.test.tsx`

**Step 1: Write the failing tests**

Create `src/components/__tests__/AddBlockTypePicker.test.tsx`:

```tsx
import { describe, it, expect, vi } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import { AddBlockTypePicker } from '../AddBlockTypePicker';

describe('AddBlockTypePicker', () => {
  it('shows type chips when open', () => {
    render(<AddBlockTypePicker onSelect={vi.fn()} onCancel={vi.fn()} />);
    expect(screen.getByText('Circuit')).toBeInTheDocument();
    expect(screen.getByText('EMOM')).toBeInTheDocument();
    expect(screen.getByText('AMRAP')).toBeInTheDocument();
    expect(screen.getByText('Warm-up')).toBeInTheDocument();
  });

  it('calls onSelect with structure type when chip clicked', () => {
    const onSelect = vi.fn();
    render(<AddBlockTypePicker onSelect={onSelect} onCancel={vi.fn()} />);
    fireEvent.click(screen.getByText('Circuit'));
    expect(onSelect).toHaveBeenCalledWith('circuit');
  });

  it('calls onCancel when cancel is clicked', () => {
    const onCancel = vi.fn();
    render(<AddBlockTypePicker onSelect={vi.fn()} onCancel={onCancel} />);
    fireEvent.click(screen.getByRole('button', { name: /cancel/i }));
    expect(onCancel).toHaveBeenCalled();
  });
});
```

**Step 2: Run tests to verify they fail**

```bash
npx vitest run src/components/__tests__/AddBlockTypePicker.test.tsx
```
Expected: FAIL

**Step 3: Implement AddBlockTypePicker**

Create `src/components/AddBlockTypePicker.tsx`:

```tsx
import type { WorkoutStructureType } from '../types/workout';
import { Button } from './ui/button';

const BLOCK_TYPES: { structure: WorkoutStructureType; label: string; emoji: string }[] = [
  { structure: 'circuit',  label: 'Circuit',  emoji: '🟢' },
  { structure: 'emom',     label: 'EMOM',     emoji: '🔵' },
  { structure: 'amrap',    label: 'AMRAP',    emoji: '🟠' },
  { structure: 'tabata',   label: 'Tabata',   emoji: '🔴' },
  { structure: 'for-time', label: 'For Time', emoji: '🟣' },
  { structure: 'sets',     label: 'Sets',     emoji: '⚫' },
  { structure: 'superset', label: 'Superset', emoji: '🟡' },
  { structure: 'rounds',   label: 'Rounds',   emoji: '🟢' },
  { structure: 'warmup',   label: 'Warm-up',  emoji: '⬜' },
  { structure: 'cooldown', label: 'Cooldown', emoji: '⬜' },
];

export function AddBlockTypePicker({
  onSelect,
  onCancel,
}: {
  onSelect: (structure: WorkoutStructureType) => void;
  onCancel: () => void;
}) {
  return (
    <div className="rounded-lg border bg-muted/30 p-4 space-y-3">
      <p className="text-sm font-medium text-muted-foreground">What type of block?</p>
      <div className="flex flex-wrap gap-2">
        {BLOCK_TYPES.map(({ structure, label, emoji }) => (
          <button
            key={structure}
            type="button"
            onClick={() => onSelect(structure)}
            className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full border bg-background text-sm hover:bg-muted transition-colors"
          >
            <span aria-hidden>{emoji}</span>
            {label}
          </button>
        ))}
      </div>
      <Button variant="ghost" size="sm" onClick={onCancel} aria-label="cancel">
        Cancel
      </Button>
    </div>
  );
}
```

**Step 4: Run tests to verify they pass**

```bash
npx vitest run src/components/__tests__/AddBlockTypePicker.test.tsx
```
Expected: 3 tests PASS

**Step 5: Commit**

```bash
git add src/components/AddBlockTypePicker.tsx src/components/__tests__/AddBlockTypePicker.test.tsx
git commit -m "feat(structure-ui): add AddBlockTypePicker inline chip strip"
```

---

### Task 5: Suggestion strips (warm-up, cooldown, default rest)

**Files:**
- Create: `src/components/WorkoutSuggestionStrips.tsx`
- Test: `src/components/__tests__/WorkoutSuggestionStrips.test.tsx`

**Step 1: Write the failing tests**

Create `src/components/__tests__/WorkoutSuggestionStrips.test.tsx`:

```tsx
import { describe, it, expect, vi } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import { WarmupSuggestionStrip, CooldownSuggestionStrip, DefaultRestStrip } from '../WorkoutSuggestionStrips';

describe('WarmupSuggestionStrip', () => {
  it('renders warm-up suggestion', () => {
    render(<WarmupSuggestionStrip onAdd={vi.fn()} onSkip={vi.fn()} />);
    expect(screen.getByText(/no warm-up found/i)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /add warm-up/i })).toBeInTheDocument();
  });

  it('calls onAdd when Add Warm-up clicked', () => {
    const onAdd = vi.fn();
    render(<WarmupSuggestionStrip onAdd={onAdd} onSkip={vi.fn()} />);
    fireEvent.click(screen.getByRole('button', { name: /add warm-up/i }));
    expect(onAdd).toHaveBeenCalled();
  });

  it('calls onSkip when Skip clicked', () => {
    const onSkip = vi.fn();
    render(<WarmupSuggestionStrip onAdd={vi.fn()} onSkip={onSkip} />);
    fireEvent.click(screen.getByRole('button', { name: /skip/i }));
    expect(onSkip).toHaveBeenCalled();
  });
});

describe('DefaultRestStrip', () => {
  it('renders default rest suggestion when no rest set', () => {
    render(<DefaultRestStrip onSet={vi.fn()} onSkip={vi.fn()} />);
    expect(screen.getByText(/no default rest/i)).toBeInTheDocument();
  });
});
```

**Step 2: Run tests to verify they fail**

```bash
npx vitest run src/components/__tests__/WorkoutSuggestionStrips.test.tsx
```
Expected: FAIL

**Step 3: Implement WorkoutSuggestionStrips**

Create `src/components/WorkoutSuggestionStrips.tsx`:

```tsx
import { Lightbulb } from 'lucide-react';
import { Button } from './ui/button';

function SuggestionStrip({
  message,
  actionLabel,
  onAction,
  onSkip,
}: {
  message: string;
  actionLabel: string;
  onAction: () => void;
  onSkip: () => void;
}) {
  return (
    <div className="flex items-center gap-3 px-4 py-2.5 rounded-lg border border-dashed bg-muted/20 text-sm">
      <Lightbulb className="w-4 h-4 text-muted-foreground shrink-0" />
      <span className="text-muted-foreground flex-1">{message}</span>
      <Button size="sm" variant="outline" className="h-7 text-xs" onClick={onAction} aria-label={actionLabel}>
        + {actionLabel}
      </Button>
      <Button size="sm" variant="ghost" className="h-7 text-xs text-muted-foreground" onClick={onSkip} aria-label="skip">
        Skip
      </Button>
    </div>
  );
}

export function WarmupSuggestionStrip({
  onAdd,
  onSkip,
}: {
  onAdd: () => void;
  onSkip: () => void;
}) {
  return (
    <SuggestionStrip
      message="No warm-up found. Want to add one?"
      actionLabel="Add Warm-up"
      onAction={onAdd}
      onSkip={onSkip}
    />
  );
}

export function CooldownSuggestionStrip({
  onAdd,
  onSkip,
}: {
  onAdd: () => void;
  onSkip: () => void;
}) {
  return (
    <SuggestionStrip
      message="No cooldown found. Want to add one?"
      actionLabel="Add Cooldown"
      onAction={onAdd}
      onSkip={onSkip}
    />
  );
}

export function DefaultRestStrip({
  onSet,
  onSkip,
}: {
  onSet: () => void;
  onSkip: () => void;
}) {
  return (
    <SuggestionStrip
      message="No default rest set. Add a rest period that applies to all blocks?"
      actionLabel="Set Rest"
      onAction={onSet}
      onSkip={onSkip}
    />
  );
}
```

**Step 4: Run tests to verify they pass**

```bash
npx vitest run src/components/__tests__/WorkoutSuggestionStrips.test.tsx
```
Expected: 5 tests PASS

**Step 5: Commit**

```bash
git add src/components/WorkoutSuggestionStrips.tsx src/components/__tests__/WorkoutSuggestionStrips.test.tsx
git commit -m "feat(structure-ui): add warm-up/cooldown/rest suggestion strips"
```

---

### Task 6: Wire everything into StructureWorkout + auto-migration

**Files:**
- Modify: `src/components/StructureWorkout.tsx` (StructureWorkout function, lines ~777–1619)
- Test: `src/components/__tests__/StructureWorkout.integration.test.tsx`

**Step 1: Write the failing tests**

Create `src/components/__tests__/StructureWorkout.integration.test.tsx`:

```tsx
import { describe, it, expect, vi } from 'vitest';
import { render, screen, fireEvent } from '@testing-library/react';
import { DndProvider } from 'react-dnd';
import { HTML5Backend } from 'react-dnd-html5-backend';
import { StructureWorkout } from '../StructureWorkout';
import type { WorkoutStructure } from '../../types/workout';

const defaultProps = {
  onWorkoutChange: vi.fn(),
  onAutoMap: vi.fn(),
  onValidate: vi.fn(),
  loading: false,
  selectedDevice: 'ios_companion' as const,
  onDeviceChange: vi.fn(),
  userSelectedDevices: ['ios_companion'],
};

function renderSW(workout: WorkoutStructure) {
  return render(
    <DndProvider backend={HTML5Backend}>
      <StructureWorkout workout={workout} {...defaultProps} />
    </DndProvider>
  );
}

describe('StructureWorkout integration', () => {
  it('shows warmup suggestion strip when no warmup block', () => {
    renderSW({ title: 'Test', source: 'test', blocks: [
      { id: 'b1', label: 'Main', structure: 'circuit', rounds: 3, exercises: [] }
    ]});
    expect(screen.getByText(/no warm-up found/i)).toBeInTheDocument();
  });

  it('does not show warmup strip when warmup block exists', () => {
    renderSW({ title: 'Test', source: 'test', blocks: [
      { id: 'b0', label: 'Warm-up', structure: 'warmup', warmup_duration_sec: 300, warmup_activity: 'jump_rope', exercises: [] },
      { id: 'b1', label: 'Main', structure: 'circuit', rounds: 3, exercises: [] }
    ]});
    expect(screen.queryByText(/no warm-up found/i)).not.toBeInTheDocument();
  });

  it('hides warmup strip after skip clicked', () => {
    renderSW({ title: 'Test', source: 'test', blocks: [
      { id: 'b1', label: 'Main', structure: 'circuit', rounds: 3, exercises: [] }
    ]});
    fireEvent.click(screen.getAllByRole('button', { name: /skip/i })[0]);
    expect(screen.queryByText(/no warm-up found/i)).not.toBeInTheDocument();
  });

  it('auto-migrates legacy workoutWarmup setting to warmup block', () => {
    const onWorkoutChange = vi.fn();
    render(
      <DndProvider backend={HTML5Backend}>
        <StructureWorkout
          workout={{
            title: 'Test', source: 'test',
            settings: { defaultRestType: 'timed', defaultRestSec: 30, workoutWarmup: { enabled: true, activity: 'jump_rope', durationSec: 300 } },
            blocks: [{ id: 'b1', label: 'Main', structure: 'circuit', rounds: 3, exercises: [] }],
          }}
          {...defaultProps}
          onWorkoutChange={onWorkoutChange}
        />
      </DndProvider>
    );
    // Auto-migration fires onWorkoutChange with warmup block prepended
    expect(onWorkoutChange).toHaveBeenCalledWith(
      expect.objectContaining({
        blocks: expect.arrayContaining([
          expect.objectContaining({ structure: 'warmup', warmup_activity: 'jump_rope' })
        ])
      })
    );
  });

  it('shows AddBlockTypePicker when + Add Block clicked', () => {
    renderSW({ title: 'Test', source: 'test', blocks: [] });
    fireEvent.click(screen.getByRole('button', { name: /add block/i }));
    expect(screen.getByText('Circuit')).toBeInTheDocument();
    expect(screen.getByText('EMOM')).toBeInTheDocument();
  });

  it('shows default rest banner when rest is configured', () => {
    renderSW({
      title: 'Test', source: 'test',
      settings: { defaultRestType: 'timed', defaultRestSec: 60 },
      blocks: [{ id: 'b1', label: 'Main', structure: 'circuit', rounds: 3, exercises: [] }],
    });
    expect(screen.getByText(/default rest/i)).toBeInTheDocument();
    expect(screen.getByText(/60s/)).toBeInTheDocument();
  });
});
```

**Step 2: Run tests to verify they fail**

```bash
npx vitest run src/components/__tests__/StructureWorkout.integration.test.tsx
```
Expected: FAIL

**Step 3: Update StructureWorkout to wire new components**

In `src/components/StructureWorkout.tsx`, update the `StructureWorkout` function:

**a) Add new imports:**
```tsx
import { AddBlockTypePicker } from './AddBlockTypePicker';
import { WarmupSuggestionStrip, CooldownSuggestionStrip, DefaultRestStrip } from './WorkoutSuggestionStrips';
import { getStructureDefaults, generateId } from '../lib/workout-utils';
import { useEffect } from 'react';
```

**b) Add new state variables** (after existing state declarations):
```tsx
const [showAddBlockPicker, setShowAddBlockPicker] = useState(false);
const [skippedWarmup, setSkippedWarmup] = useState(false);
const [skippedCooldown, setSkippedCooldown] = useState(false);
const [skippedRest, setSkippedRest] = useState(false);
```

**c) Add auto-migration effect** (after state declarations):
```tsx
// Auto-migrate legacy workoutWarmup setting to a real warmup block (one-time)
useEffect(() => {
  const warmup = workout?.settings?.workoutWarmup;
  if (warmup?.enabled) {
    const hasWarmupBlock = workout.blocks?.some(b => b.structure === 'warmup');
    if (!hasWarmupBlock) {
      const newWorkout = cloneWorkout(workout);
      const warmupBlock = {
        id: generateId(),
        label: 'Warm-up',
        structure: 'warmup' as const,
        exercises: [],
        warmup_activity: warmup.activity,
        warmup_duration_sec: warmup.durationSec ?? null,
        warmup_enabled: true,
      };
      newWorkout.blocks = [warmupBlock, ...(newWorkout.blocks || [])];
      if (newWorkout.settings) {
        newWorkout.settings = { ...newWorkout.settings, workoutWarmup: undefined };
      }
      onWorkoutChange(newWorkout);
    }
  }
}, []); // eslint-disable-line react-hooks/exhaustive-deps — intentionally once on mount
```

**d) Update `addBlock` to accept a structure type:**
```tsx
const addBlock = (structure?: WorkoutStructureType) => {
  const newWorkout = cloneWorkout(workoutWithIds);
  const defaults = structure ? getStructureDefaults(structure) : {};
  const label = structure
    ? getStructureDisplayName(structure).charAt(0).toUpperCase() + getStructureDisplayName(structure).slice(1).toLowerCase()
    : `Block ${(workoutWithIds.blocks || []).length + 1}`;
  const newBlock: Block = {
    id: generateId(),
    label,
    structure: structure ?? null,
    exercises: [],
    ...defaults,
  };
  newWorkout.blocks.push(newBlock);
  onWorkoutChange(newWorkout);
  setShowAddBlockPicker(false);
};
```

**e) Derive suggestion visibility flags** (before the return):
```tsx
const hasWarmupBlock = (workoutWithIds.blocks || []).some(b => b.structure === 'warmup');
const hasCooldownBlock = (workoutWithIds.blocks || []).some(b => b.structure === 'cooldown');
const hasDefaultRest = !!workoutWithIds.settings?.defaultRestSec;
const hasAnyBlock = (workoutWithIds.blocks || []).length > 0;

const showWarmupStrip = hasAnyBlock && !hasWarmupBlock && !skippedWarmup;
const showCooldownStrip = hasAnyBlock && !hasCooldownBlock && !skippedCooldown;
const showRestStrip = hasAnyBlock && !hasDefaultRest && !skippedRest;
```

**f) Replace the workout title card's rest/warmup badges** with a DefaultRestBanner. In the title card section, replace the `<div className="flex items-center gap-2 mt-2">` badges block with:
```tsx
{hasDefaultRest && (
  <p className="text-xs text-muted-foreground mt-1">
    Default rest: {formatRestSecs(workoutWithIds.settings!.defaultRestSec!)} · applied to all blocks unless overridden
    <button className="ml-2 underline" onClick={() => setShowWorkoutSettings(true)}>Edit</button>
  </p>
)}
```

Add `formatRestSecs` to the workout-utils import.

**g) Replace the block list + Add Block button** in the return JSX:

```tsx
{/* Suggestion strips */}
{showWarmupStrip && (
  <WarmupSuggestionStrip
    onAdd={() => {
      const newWorkout = cloneWorkout(workoutWithIds);
      newWorkout.blocks.unshift({
        id: generateId(), label: 'Warm-up', structure: 'warmup',
        exercises: [], warmup_duration_sec: 300, warmup_activity: 'stretching', warmup_enabled: true,
        ...getStructureDefaults('warmup'),
      });
      onWorkoutChange(newWorkout);
    }}
    onSkip={() => setSkippedWarmup(true)}
  />
)}
{showRestStrip && (
  <DefaultRestStrip
    onSet={() => setShowWorkoutSettings(true)}
    onSkip={() => setSkippedRest(true)}
  />
)}

{/* Block list (existing ScrollArea) */}
<ScrollArea className="h-[calc(100vh-400px)] min-h-[400px]">
  <div className="space-y-4 pr-4 pb-8">
    {/* ... existing blocks map ... */}
  </div>
</ScrollArea>

{/* Cooldown strip at bottom */}
{showCooldownStrip && (
  <CooldownSuggestionStrip
    onAdd={() => {
      const newWorkout = cloneWorkout(workoutWithIds);
      newWorkout.blocks.push({
        id: generateId(), label: 'Cool-down', structure: 'cooldown',
        exercises: [], warmup_duration_sec: 300, warmup_activity: 'stretching', warmup_enabled: true,
        ...getStructureDefaults('cooldown'),
      });
      onWorkoutChange(newWorkout);
    }}
    onSkip={() => setSkippedCooldown(true)}
  />
)}

{/* Add Block — type picker */}
{showAddBlockPicker ? (
  <AddBlockTypePicker
    onSelect={(structure) => addBlock(structure)}
    onCancel={() => setShowAddBlockPicker(false)}
  />
) : (
  <Button onClick={() => setShowAddBlockPicker(true)} variant="outline" className="gap-2">
    <Plus className="w-4 h-4" />
    Add Block
  </Button>
)}
```

Also add `WorkoutStructureType` to the types import in StructureWorkout.tsx, and `getStructureDisplayName` to the workout-utils import.

**Step 4: Run integration tests**

```bash
npx vitest run src/components/__tests__/StructureWorkout.integration.test.tsx
```
Expected: 6 tests PASS

**Step 5: Run full test suite**

```bash
npm test
```
Fix any remaining failures before committing.

**Step 6: Commit**

```bash
git add src/components/StructureWorkout.tsx
git commit -m "feat(structure-ui): wire suggestion strips, type picker, auto-migration into StructureWorkout"
```

---

### Task 7: Visual polish + final test run

**Files:**
- Modify: `src/components/StructureWorkout.tsx` (remove dead code from old system)
- Modify: `src/components/EditBlockDialog.tsx` (keep, but remove warmup config — now inline)

**Step 1: Remove dead code from StructureWorkout**

In `StructureWorkout.tsx`, remove:
- The old `getRestSettingsLabel()` helper function
- The old workout-level rest/warmup badges (`<div className="flex items-center gap-2 mt-2">`)
- The old `Collapse All` / `Expand All` / `Add Block` button row (replaced by new inline controls)

**Step 2: Remove warmup config from EditBlockDialog**

In `src/components/EditBlockDialog.tsx`, remove the warm-up section (warmupEnabled, warmupActivity, warmupDurationSec fields). These are now handled inline in BlockConfigRow. Keep all other block editing (label, rest override, sets, reps).

**Step 3: Run full test suite**

```bash
npm test
```
Expected: same or fewer failures than pre-task baseline (67 backend-dependent E2E failures are pre-existing — ignore them, focus on new unit test failures only).

**Step 4: Manual visual check**

Start dev server and import a workout to verify:
```bash
npm run dev
```
- Open http://localhost:3000
- Import a YouTube/Instagram URL
- Verify: colour-coded block, key metric in header, config row expands, suggestion strips appear, Add Block shows type picker

**Step 5: Final commit**

```bash
git add -A
git commit -m "feat(structure-ui): remove dead code, clean up EditBlockDialog warmup section"
```

---

## Test command

```bash
cd /Users/davidandrews/dev/AmakaFlow/amakaflow-dev-workspace/amakaflow-ui
npm test
```

## Pre-existing failures to ignore

~67 E2E/contract tests that require a live backend. These were failing before this work. Only fail if new unit tests you added are failing.
