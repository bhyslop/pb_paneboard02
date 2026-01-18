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
- Otherwise run `./tt/vvw-r.RunVVX.sh jjx_muster --status current`:
  - If 1 heat: use it
  - If 0 heats: Error "No active heats"
  - If 2+ heats: ask user to select
- Run `./tt/vvw-r.RunVVX.sh jjx_parade <FIREMARK>` and find pace by silks match
- Error if silks not found in heat

## Step 3: Apply reslate

Run:
```bash
echo "<NEW_TEXT>" | ./tt/vvw-r.RunVVX.sh jjx_tally <CORONET>
```

The new tack text is passed via stdin. State is inherited (stays rough, stays bridled, etc.).

To change state, use:
- `/jjc-pace-bridle` → bridled (arm for autonomous execution)
- `/jjc-pace-wrap` → complete

## Step 4: Report and assess

On success, report:
- "Refined pace: **<SILKS>** (₢AAAAC)"
- "State: <current state> (unchanged)"
- "New tack text: <first 100 chars>..."

Then **assess the pace's health**:

1. **Clarity**: Is the refined description clearer and more actionable?
2. **Scope**: Has scope crept or tightened appropriately?
3. **Readiness**: Is it now ready for priming?

## Step 5: Assess bridleability

Apply **Primeability Assessment** criteria from CLAUDE.md.

If bridleable, suggest direction (agent type, parallelism, key files).
If not bridleable, state why: "Needs human judgment — [reason]"

**Next:** `/jjc-pace-reslate` (refine more) | `/jjc-pace-bridle` (arm) | `/jjc-parade-overview` (view all)

## Step 6: Auto-commit changes

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
