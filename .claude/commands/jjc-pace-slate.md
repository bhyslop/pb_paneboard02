---
argument-hint: <silks> [description] [--before ₢X | --after ₢X | --first]
description: Add a new pace to a heat
---

Add a new pace (discrete action) to a Job Jockey heat.

Arguments: $ARGUMENTS (format: `<silks> [description] [positioning]`)

## Step 1: Parse arguments

Extract from $ARGUMENTS:
- First word = silks (kebab-case pace name)
- Positioning flag (if present): `--before <CORONET>`, `--after <CORONET>`, or `--first`
- Remaining text = pace description (optional)

**If $ARGUMENTS is empty:**
- Error: "Usage: /jjc-pace-slate <silks> [description] [--before ₢X | --after ₢X | --first]"
- Examples:
  - `/jjc-pace-slate add-validation Add input validation to the form handler`
  - `/jjc-pace-slate fix-bug --first` (insert at beginning)
  - `/jjc-pace-slate new-feature --after ₢AAAAC` (insert after specific pace)
  - `/jjc-pace-slate cleanup --before ₢AAAAD` (insert before specific pace)

**Validate silks format:**
- Must be kebab-case: `[a-z0-9]+(-[a-z0-9]+)*`
- Error if invalid: "Silks must be kebab-case (e.g., 'add-tests', 'fix-bug')"

**Validate positioning (if provided):**
- `--before` and `--after` require a Coronet argument
- Only one positioning flag allowed
- Coronet must exist in the target heat

**If description is missing (only silks provided):**
- Synthesize a description from recent conversation context
- Draw on what was discussed about this pace concept
- Do NOT ask for confirmation - proceed directly

## Step 2: Get heat context

**If FIREMARK is available from current session context:**
- Use that Firemark

**Otherwise:**
- Run: `./tt/vvw-r.RunVVX.sh jjx_muster --status current`
- Parse TSV output

**If 0 heats:** Error: "No active heats. Create one with `/jjc-heat-nominate` first."

**If 1 heat:** Use that heat's Firemark.

**If 2+ heats:** List heats and ask user to select.

## Step 3: Create pace

Run:
```bash
echo "<PACE_TEXT>" | ./tt/vvw-r.RunVVX.sh jjx_slate <FIREMARK> --silks "<SILKS>" [POSITIONING]
```

Where `[POSITIONING]` is one of (if provided):
- `--first` — insert at beginning of pace order
- `--before <CORONET>` — insert before specified pace
- `--after <CORONET>` — insert after specified pace
- (omitted) — append at end (default)

The pace description text is passed via stdin.

Capture the new Coronet from stdout.

## Step 4: Report and assess

On success, report:
- "Created pace: **<SILKS>** (₢AAAAC)"
- "Heat: <HEAT_SILKS> (₣AA)"
- "Position: {first | after ₢X | before ₢X | end}" (if positioning was specified)
- "State: rough"

Then **assess the pace's health**:

1. **Clarity**: Is the description clear and actionable?
2. **Scope**: Is it well-bounded or too broad?
3. **Dependencies**: Does it depend on other paces completing first?

## Step 5: Assess bridleability

Apply **Primeability Assessment** criteria from CLAUDE.md.

If bridleable, suggest direction (agent type, parallelism, key files).
If not bridleable, state why: "Needs human judgment — [reason]"

**Next:** `/jjc-pace-slate` (add another) | `/jjc-pace-reslate` (refine) | `/jjc-pace-bridle` (arm)

## Step 6: Auto-commit changes

Run guarded commit:
```bash
./tt/vvw-r.RunVVX.sh vvx_commit --message "Slate: <SILKS> in ₣<FIREMARK>"
```

On failure (e.g., lock held), report error but don't fail the operation — gallops changes are already saved.

## Error handling

On failure, report the error from vvx.

Common errors:
- "Heat not found" — invalid Firemark
- "text must not be empty" — description synthesis failed

## Available Operations

- `/jjc-pace-slate` — Add a new pace
- `/jjc-pace-reslate` — Refine pace specification
- `/jjc-pace-wrap` — Mark pace complete
- `/jjc-pace-bridle` — Arm pace for autonomous execution
- `/jjc-heat-mount` — Begin work on next pace
- `/jjc-heat-rail` — Reorder paces
- `/jjc-heat-chalk` — Add steeplechase marker
- `/jjc-parade-overview` — Heat summary
