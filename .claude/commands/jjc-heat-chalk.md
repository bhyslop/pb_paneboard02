---
argument-hint: <marker> <description>
description: Add steeplechase marker
---

Create an empty commit marking a steeplechase event.

Arguments: $ARGUMENTS (format: `<MARKER> <description text>`)

Markers:
- `APPROACH` — Proposed approach for a pace (requires pace context)
- `WRAP` — Pace completion summary (requires pace context)
- `FLY` — Autonomous execution began (requires pace context)
- `DISCUSSION` — Significant decision or design discussion (pace optional)

## Prerequisites

- Must have active heat context (run `/jjc-heat-mount` first)
- For APPROACH/WRAP/FLY markers, must have pace context

## Step 1: Parse arguments

Extract from $ARGUMENTS:
- First word = MARKER (APPROACH, WRAP, FLY, or DISCUSSION)
- Remaining text = description

If no marker or invalid marker:
- Error: "Usage: /jjc-heat-chalk <APPROACH|WRAP|FLY|DISCUSSION> <description>"

## Step 2: Get context

Retrieve from current session:
- FIREMARK (current heat) — required
- PACE_SILKS (current pace) — required for APPROACH/WRAP/FLY

If no FIREMARK:
- Error: "No heat context. Run /jjc-heat-mount first."

If no PACE_SILKS and marker requires it:
- Error: "<MARKER> marker requires pace context."

## Step 3: Execute chalk

**For APPROACH/WRAP/FLY (pace required):**
```bash
./tt/vvw-r.RunVVX.sh jjx_chalk <PACE_CORONET> --marker <MARKER> --description "<description>"
```

**For DISCUSSION (heat-level, no pace):**
```bash
./tt/vvw-r.RunVVX.sh jjx_chalk <FIREMARK> --marker DISCUSSION --description "<description>"
```

The CLI accepts either a Coronet (for pace-level markers) or a Firemark (for heat-level markers) as the identity argument.

## Step 4: Report result

On success:
- "Chalk marker created: [jj:BRAND][₣AA/pace] <MARKER>: <description>"
- Report commit hash

On failure, report the error from vvx.

## Commit format

The empty commit message will be:
```
[jj:BRAND][₣AA/pace-silks] MARKER: description

Co-Authored-By: Claude <noreply@anthropic.com>
```

Or for DISCUSSION without pace:
```
[jj:BRAND][₣AA] DISCUSSION: description

Co-Authored-By: Claude <noreply@anthropic.com>
```

## Step 5: Auto-commit changes

Run guarded commit:
```bash
./tt/vvw-r.RunVVX.sh vvx_commit --message "Chalk: <MARKER> in ₣<FIREMARK>"
```

On failure (e.g., lock held), report error but don't fail the operation — gallops changes are already saved.

## Available Operations

- `/jjc-pace-slate` — Add a new pace
- `/jjc-pace-reslate` — Refine pace specification
- `/jjc-pace-wrap` — Mark pace complete
- `/jjc-pace-bridle` — Arm pace for autonomous execution
- `/jjc-heat-mount` — Begin work on next pace
- `/jjc-heat-rail` — Reorder paces
- `/jjc-heat-chalk` — Add steeplechase marker
- `/jjc-parade-overview` — Heat summary
