---
argument-hint: <pace> [new text]
description: Refine a pace's plan
---

Refine a pace's plan by adding a new Tack with updated text.

Arguments: $ARGUMENTS (format: `<pace> [optional new text]`)

The pace can be identified by:
- Coronet (e.g., `₢AAAAA` or `AAAAA`)
- Silks (e.g., `kit-asset-registry`) - resolved within current heat

## Step 1: Parse arguments

Extract from $ARGUMENTS:
- First word = pace identifier (coronet or silks)
- Remaining text = new tack text (optional)

**If $ARGUMENTS is empty:**
- Error: "Usage: /jjc-pace-reslate <pace> [new text]"
- Example: `/jjc-pace-reslate kit-asset-registry Refined approach: use macro for asset declaration`

**If new text is missing (only pace identifier provided):**
- Synthesize refined text from recent conversation context
- Draw on what was discussed about refining this pace
- Do NOT ask for confirmation - proceed directly

## Step 2: Resolve pace

**If identifier looks like a Coronet (5 base64 chars, optionally with ₢ prefix, e.g., `₢AAAAC`):**
- Use directly

**If identifier looks like silks (kebab-case):**
- Need heat context to resolve
- If FIREMARK available from session: use it
- Otherwise run `./tt/vvw-r.RunVVX.sh jjx_muster`:
  - If 1 heat: use it
  - If 0 heats: Error "No heats found"
  - If 2+ heats: ask user to select
- Run `./tt/vvw-r.RunVVX.sh jjx_parade <FIREMARK>` and find pace by silks match
- Error if silks not found in heat

## Step 3: Name assessment

Before applying the reslate, assess whether the pace silks still fits the refined spec.

**Fetch current pace data:**
```bash
./tt/vvw-r.RunVVX.sh jjx_parade <FIREMARK> --pace <CORONET>
```

Extract:
- Current silks (display name)
- Current spec text (from most recent tack)

**Compare gestalts:**
- Old focus: What the current spec emphasized
- New focus: What the refined spec emphasizes
- Assess: Does the current name still capture the refined essence?

**If name still fits:**
- Proceed silently to Step 4 (apply reslate)

**If gestalt has shifted:**
- Suggest new silks based on refined focus
- Present 3-option prompt:

```
⚠ Name check: "old-silks" may not fit refined spec.
  Was: [old focus summary]
  Now: [new focus summary]
  Suggested: "better-name"

  [R] Rename to "better-name" (default)
  [C] Continue with current name
  [S] Stop (abort reslate)

  Choice [R]:
```

**On user response:**
- **R** (or Enter): Proceed with rename (set `RENAME_TO="better-name"`)
- **C**: Proceed with current silks (set `RENAME_TO=""`)
- **S**: Abort reslate entirely, report "Reslate aborted by user" and exit

## Step 4: Apply reslate

**If renaming (RENAME_TO is set):**
```bash
echo "<NEW_TEXT>" | ./tt/vvw-r.RunVVX.sh jjx_tally <CORONET> --silks "<RENAME_TO>"
```

**Otherwise:**
```bash
echo "<NEW_TEXT>" | ./tt/vvw-r.RunVVX.sh jjx_tally <CORONET>
```

The new tack text is passed via stdin. State is inherited (stays rough, stays bridled, etc.).

To change state, use:
- `/jjc-pace-bridle` → bridled (arm for autonomous execution)
- `/jjc-pace-wrap` → complete

## Step 5: Report and assess

On success, report:
- "Refined pace: **<SILKS>** (₢AAAAC)"
- If renamed: "Renamed from: **<OLD_SILKS>**"
- "State: <current state> (unchanged)"
- "New tack text: <first 100 chars>..."

Then **assess the pace's health**:

1. **Clarity**: Is the refined description clearer and more actionable?
2. **Scope**: Has scope crept or tightened appropriately?
3. **Readiness**: Is it now ready for priming?

## Step 6: Assess bridleability

Apply **Primeability Assessment** criteria from CLAUDE.md.

If bridleable, suggest direction (agent type, parallelism, key files).
If not bridleable, state why: "Needs human judgment — [reason]"

**Next:** `/jjc-pace-reslate` (refine more) | `/jjc-pace-bridle` (arm) | `/jjc-parade-overview` (view all)

## Step 7: Auto-commit changes

Run guarded commit:
```bash
./tt/vvw-r.RunVVX.sh vvx_commit --message "Reslate: <SILKS>"
```

On failure (e.g., lock held), report error but don't fail the operation — gallops changes are already saved.

## Error handling

On failure, report the error from vvx.

Common errors:
- "Pace not found" — invalid coronet or silks not in heat
- "Heat not found" — invalid Firemark context
- "text must not be empty" — synthesis failed

## Available Operations

- `/jjc-pace-slate` — Add a new pace
- `/jjc-pace-reslate` — Refine pace specification
- `/jjc-pace-wrap` — Mark pace complete
- `/jjc-pace-bridle` — Arm pace for autonomous execution
- `/jjc-heat-mount` — Begin work on next pace
- `/jjc-heat-rail` — Reorder paces
- `/jjc-heat-chalk` — Add steeplechase marker
- `/jjc-parade-overview` — Heat summary
