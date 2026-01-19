---
argument-hint: [coronet]
description: Mark a pace complete
---

Mark a pace as complete and record the wrap in steeplechase history.

Arguments: $ARGUMENTS (optional Coronet; uses current pace if omitted)

## Prerequisites

- **User must explicitly invoke this command** — never auto-wrap
- Gallops JSON must exist
- Pace should be in "rough" or "bridled" state
- Work on the pace should be done

## Step 1: Identify target pace

**If $ARGUMENTS contains a Coronet (e.g., `AAAAC` or `₢AAAAC`):**
- Extract Firemark from first 2 characters
- Use that Coronet directly

**If $ARGUMENTS is empty:**
- Use PACE_CORONET from current context
- If no context, error: "No pace context. Run /jjc-heat-mount first."

## Step 2: Get current state

Run:
```bash
./tt/vvw-r.RunVVX.sh jjx_saddle <FIREMARK>
```

Verify pace state:
- If "complete": "Pace already complete."
- If "abandoned": "Pace was abandoned, cannot wrap."

## Step 3: Summarize outcome

Review the work completed:
- What was accomplished
- Key changes made
- Any notable decisions or deviations from plan

Construct a brief outcome summary (1-3 sentences).

## Step 3.5: Commit implementation changes

Run notch to commit any pending work with proper JJ context:

```bash
./tt/vvw-r.RunVVX.sh jjx_notch <CORONET>
```

**Interpret the result:**
- Success with commit hash → report the hash, proceed to Step 4
- "nothing to commit" or empty staging → proceed silently to Step 4
- Actual error (lock failure, guard rejection, etc.) → report error and stop wrap

This ensures implementation changes are attributed to the pace before wrap closes it out.

## Step 4: Transition to complete

Run:
```bash
echo "<outcome summary>" | ./tt/vvw-r.RunVVX.sh jjx_tally <CORONET> --state complete
```

## Step 5: Create wrap marker

Run:
```bash
./tt/vvw-r.RunVVX.sh jjx_chalk <PACE_CORONET> --marker W --description "<outcome summary>"
```

## Step 6: Advance to next pace

Run:
```bash
./tt/vvw-r.RunVVX.sh jjx_saddle <FIREMARK>
```

**If another actionable pace exists:**
- Display the next pace's silks and spec
- If rough: Propose approach (as in /jjc-heat-mount)
- If bridled: Parse direction for `Agent:` line and report: "Next pace is bridled for {agent} agent. Run `/jjc-heat-mount` to execute."

**If no more actionable paces:**
- Report "All paces complete for heat <SILKS>"
- Suggest `/jjc-pace-slate` to add more work, or `/jjc-heat-retire` if done

## Available Operations

- `/jjc-pace-slate` — Add a new pace
- `/jjc-pace-reslate` — Refine pace specification
- `/jjc-pace-wrap` — Mark pace complete
- `/jjc-pace-bridle` — Arm pace for autonomous execution
- `/jjc-heat-mount` — Begin work on next pace
- `/jjc-heat-rail` — Reorder paces
- `/jjc-heat-chalk` — Add steeplechase marker
- `/jjc-parade-overview` — Heat summary
