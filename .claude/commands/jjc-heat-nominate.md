---
argument-hint: <silks>
description: Create a new heat
---

Create a new Job Jockey heat (bounded initiative).

Arguments: $ARGUMENTS (required: kebab-case silks name for the heat)

## Step 1: Parse arguments

Extract silks from $ARGUMENTS.

**If $ARGUMENTS is empty:**
- Error: "Usage: /jjc-heat-nominate <silks>"
- Example: `/jjc-heat-nominate my-new-feature`

**Validate silks format:**
- Must be kebab-case: `[a-z0-9]+(-[a-z0-9]+)*`
- Error if invalid: "Silks must be kebab-case (e.g., 'my-feature', 'fix-auth-bug')"

## Step 2: Get current date

Get today's date in YYMMDD format (e.g., `260114` for 2026-01-14).

```bash
date +%y%m%d
```

## Step 3: Create heat

Run:
```bash
./tt/vvw-r.RunVVX.sh jjx_nominate --silks "<SILKS>" --created "<YYMMDD>"
```

Capture the new Firemark from stdout.

## Step 4: Report result

On success:
- "Created heat: **<SILKS>** (₣AA)"
- "Paddock file: `.claude/jjm/jjp_XX.md`"
- "Next: Edit the paddock to add context, then `/jjc-pace-slate` to add paces"

On failure, report the error from vvx.

## Step 5: Offer next steps

Ask: "Would you like to:"
1. Edit the paddock file to add context
2. Add a pace with `/jjc-pace-slate`
3. Continue without further setup

## Available Operations

- `/jjc-heat-mount` — Begin work on next pace
- `/jjc-heat-muster` — List all heats
- `/jjc-heat-groom` — Review and refine heat
- `/jjc-heat-nominate` — Create new heat
- `/jjc-pace-slate` — Add a new pace
- `/jjc-pace-notch` — JJ-aware git commit
- `/jjc-parade-overview` — Heat summary
