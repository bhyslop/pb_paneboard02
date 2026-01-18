---
argument-hint: [<coronet>...] | --move <coronet> --before|--after|--first|--last
description: Reorder paces within a heat
---

Reorder paces within a Job Jockey heat. Supports two modes:

**Order mode** — replace entire sequence:
```bash
/jjc-heat-rail ₢AAAAC ₢AAAAD ₢AAAAE
```

**Move mode** — relocate a single pace:
```bash
/jjc-heat-rail --move ₢AAAAE --first
/jjc-heat-rail --move ₢AAAAE --last
/jjc-heat-rail --move ₢AAAAE --before ₢AAAAC
/jjc-heat-rail --move ₢AAAAE --after ₢AAAAD
```

Arguments: $ARGUMENTS

## Mode Detection

**If $ARGUMENTS contains `--move`:** Use move mode
**Otherwise:** Use order mode

## Order Mode

### Step 1: Parse Coronets

Extract Coronets from $ARGUMENTS (space-separated list like `₢AAAAC ₢AAAAD ₢AAAAE`).

**If fewer than 2 Coronets:**
- Error: "Usage: /jjc-heat-rail <coronet> <coronet> [coronet...]"

### Step 2: Get heat context

Extract Firemark from first Coronet (e.g., `₢AAAAC` → `₣AA`).

### Step 3: Reorder

Run:
```bash
./tt/vvw-r.RunVVX.sh jjx_rail <FIREMARK> <CORONET1> <CORONET2> [CORONET3...]
```

**Validation:**
- Count must match current pace count
- No duplicates
- All Coronets must exist in the heat
- All Coronets must belong to the specified heat

## Move Mode

### Step 1: Parse arguments

Extract from $ARGUMENTS:
- `--move <CORONET>` — the pace to relocate
- One positioning flag: `--before <CORONET>`, `--after <CORONET>`, `--first`, or `--last`

**Validation:**
- `--move` requires exactly one positioning flag
- Cannot combine with positional Coronets

### Step 2: Get heat context

Extract Firemark from the move Coronet.

### Step 3: Relocate

Run:
```bash
./tt/vvw-r.RunVVX.sh jjx_rail <FIREMARK> --move <CORONET> --first
./tt/vvw-r.RunVVX.sh jjx_rail <FIREMARK> --move <CORONET> --last
./tt/vvw-r.RunVVX.sh jjx_rail <FIREMARK> --move <CORONET> --before <TARGET>
./tt/vvw-r.RunVVX.sh jjx_rail <FIREMARK> --move <CORONET> --after <TARGET>
```

**Validation:**
- Move Coronet must exist in heat
- Target Coronet (for --before/--after) must exist and differ from move Coronet

## Output

On success, the command outputs the new order (one Coronet per line).

Run parade to display the reordered pace list with silks and states:
```bash
./tt/vvw-r.RunVVX.sh jjx_parade <FIREMARK> --format order
```

## Auto-commit changes

Run guarded commit:
```bash
./tt/vvw-r.RunVVX.sh vvx_commit --message "Rail: reorder ₣<FIREMARK>"
```

On failure (e.g., lock held), report error but don't fail the operation — gallops changes are already saved.

## Error handling

On failure, report the error from vvx.

Common errors:
- "Heat not found" — invalid Firemark
- "Pace not found" — Coronet doesn't exist in heat
- "Cannot combine --move with positional coronets" — mode conflict
- "Move mode requires exactly one positioning flag" — missing position
- "Cannot position pace relative to itself" — self-reference
- "Order count mismatch" — order mode must include all paces
- "Order contains duplicate Coronets" — each pace listed once

## Available Operations

- `/jjc-pace-slate` — Add a new pace
- `/jjc-pace-reslate` — Refine pace specification
- `/jjc-pace-wrap` — Mark pace complete
- `/jjc-pace-bridle` — Arm pace for autonomous execution
- `/jjc-heat-mount` — Begin work on next pace
- `/jjc-heat-rail` — Reorder paces
- `/jjc-heat-chalk` — Add steeplechase marker
- `/jjc-parade-overview` — Heat summary
