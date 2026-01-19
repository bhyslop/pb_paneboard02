---
argument-hint: <firemark> [--racing | --stabled] [--silks <new-name>]
description: Pause or resume a heat
---

Change a heat's racing status (pause/resume execution) or rename it.

Use this to:
- Pause active work on a heat: `--stabled`
- Resume work on a paused heat: `--racing`
- Rename a heat: `--silks <new-name>`
- Combine status change and rename

Arguments: $ARGUMENTS (format: `<firemark> [--racing | --stabled] [--silks <new-name>]`)

## Prerequisites

## Step 1: Parse arguments

Extract from $ARGUMENTS:
- First positional: Firemark (e.g., `AA` or `₣AA`)
- Optional flags:
  - `--racing` — Resume execution (make heat current)
  - `--stabled` — Pause execution (stable the heat)
  - `--silks <name>` — Rename to new kebab-case name

**If $ARGUMENTS is empty:**
- Error: "Usage: /jjc-heat-furlough <firemark> [--racing | --stabled] [--silks <new-name>]"
- Examples:
  - `/jjc-heat-furlough AA --stabled` (pause heat AA)
  - `/jjc-heat-furlough AB --racing` (resume heat AB)
  - `/jjc-heat-furlough AC --silks better-name` (rename)
  - `/jjc-heat-furlough AD --racing --silks active-work` (resume and rename)

**Validation:**
- At least one flag (--racing, --stabled, or --silks) must be provided
- `--racing` and `--stabled` are mutually exclusive
- If `--silks` provided, validate kebab-case format: `[a-z0-9]+(-[a-z0-9]+)*`

## Step 2: Verify heat exists

Run:
```bash
./tt/vvw-r.RunVVX.sh jjx_muster
```

Parse TSV output and verify the Firemark exists. Capture current status and silks for reporting.

**If heat not found:** Error and stop.

## Step 3: Apply furlough

Run:
```bash
./tt/vvw-r.RunVVX.sh jjx_furlough <FIREMARK> [--racing | --stabled] [--silks "<NEW_NAME>"]
```

Pass through the flags exactly as provided by the user.

## Step 4: Report result

On success, report changes:

**If status changed:**
- "Heat **<SILKS>** (₣<FIREMARK>) is now **racing**" (if --racing)
- "Heat **<SILKS>** (₣<FIREMARK>) is now **stabled**" (if --stabled)

**If renamed:**
- "Renamed: **<OLD_SILKS>** → **<NEW_SILKS>**"

**If both:**
- "Heat **<NEW_SILKS>** (₣<FIREMARK>) is now **racing**"
- "Renamed from: **<OLD_SILKS>**"

**Context about status:**
- Racing heats appear in `/jjc-heat-mount` selection
- Stabled heats are for planning only (visible in `/jjc-heat-groom`, `/jjc-pace-slate`, etc.)
- Use furlough to pause work on one heat while focusing on another

## Step 5: Auto-commit changes

Run guarded commit:
```bash
./tt/vvw-r.RunVVX.sh vvx_commit --message "Furlough: ₣<FIREMARK> {status change and/or rename summary}"
```

On failure (e.g., lock held), report error but don't fail the operation — gallops changes are already saved.

## Error handling

On failure, report the error from vvx.

Common errors:
- "Heat not found" — invalid Firemark
- "Invalid silks format" — not kebab-case
- "Must specify at least one operation" — no flags provided

## Available Operations

- `/jjc-heat-furlough` — Pause/resume heat (this command)
- `/jjc-heat-mount` — Begin work on next pace (racing heats only)
- `/jjc-heat-muster` — List all heats
- `/jjc-heat-groom` — Review and refine heat (all heats)
- `/jjc-heat-nominate` — Create new heat
- `/jjc-parade-overview` — Heat summary
