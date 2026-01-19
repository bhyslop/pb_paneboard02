---
argument-hint: [firemark]
description: Review and refine heat plan
---

Groom a heat: review the full plan and prepare for refinement work.

Use this command when you want to work on the heat's overall structure - adding paces, reordering, refining specifications - rather than executing the next pace.

Arguments: $ARGUMENTS (optional Firemark or silks to select specific heat)

## Prerequisites

## Step 1: Identify target heat

**If $ARGUMENTS contains a Firemark (e.g., `AA` or `₣AA`):**
- Use that Firemark directly
- Skip to Step 2

**If $ARGUMENTS is empty or contains silks:**
- Run: `./tt/vvw-r.RunVVX.sh jjx_muster`
- Parse TSV output: `FIREMARK<TAB>SILKS<TAB>STATUS<TAB>PACE_COUNT`

**If 0 heats:** Report "No heats found. Create one with `./tt/vvw-r.RunVVX.sh jjx_nominate`." and stop.

**If 1 heat:** Use that heat's Firemark.

**If 2+ heats:**
- If $ARGUMENTS matches a silks value, use that heat
- Otherwise list heats and ask user to select

## Step 2: Get parade data

Run:
```bash
./tt/vvw-r.RunVVX.sh jjx_parade <FIREMARK>
```

Parse JSON output:
```json
{
  "heat_silks": "...",
  "heat_created": "YYMMDD",
  "heat_status": "current|retired",
  "paddock_file": ".claude/jjm/jjp_XX.md",
  "paddock_content": "...",
  "paces": [
    {
      "coronet": "₢AAAAC",
      "silks": "...",
      "state": "rough|bridled|complete|abandoned",
      "spec": "...",
      "direction": "..."
    }
  ]
}
```

## Step 3: Display heat overview

Present the full heat for planning review:

### Heat: {heat_silks} (₣{firemark})
**Created:** {heat_created} | **Status:** {heat_status}
{If heat_status is "stabled": "⚠ This heat is stabled (paused). Use `/jjc-heat-furlough <firemark> --racing` to resume execution."}

### Paddock
{Full paddock_content - this is the planning context}

### Paces ({N} total)

For each pace in order, show:
```
{index}. [{state}] {silks} (₢{coronet})
   {spec - full specification}
   {If bridled: "Direction: " + direction}
```

Show all paces with full detail regardless of state - this is a planning view.

### Progress
- Complete: X | Abandoned: Y | Remaining: Z (rough: A, bridled: B)

## Step 4: Enter planning mode

Identify the **next pace** — first incomplete pace by order (skip complete/abandoned). This is what `/jjc-heat-mount` will execute.

**Order determines execution priority; state determines execution mode:**
- rough → interactive (human collaboration)
- bridled → autonomous (agent execution)

A bridled pace later in the queue is NOT higher priority than a rough pace earlier in the queue.

Prompt the user:

"Heat **{silks}** has {N} paces. **Next up:** {next_pace_silks} (₢{coronet}) [{state}]"

"What would you like to work on?"

Suggest actions anchored to the next pace:
- If next pace is rough: "Execute interactively with `/jjc-heat-mount`" or "Bridle for autonomous execution with `/jjc-pace-bridle {coronet}`"
- If next pace is bridled: "Execute autonomously with `/jjc-heat-mount`"

Then offer structural operations:
- "Add new paces with `/jjc-pace-slate`"
- "Reorder paces with `/jjc-heat-rail`"
- "Refine a pace specification with `/jjc-pace-reslate`"
- "Review paddock context" (offer to edit paddock file)

If all paces complete:
- "All paces complete. `/jjc-heat-retire` to archive."

Remain in planning discussion mode - do not automatically proceed to execution.

## Context preservation

Store for use by other commands:
- Current FIREMARK
- Current heat SILKS

## Available Operations

- `/jjc-heat-mount` — Begin work on next pace
- `/jjc-heat-muster` — List all heats
- `/jjc-heat-groom` — Review and refine heat
- `/jjc-heat-nominate` — Create new heat
- `/jjc-pace-slate` — Add a new pace
- `/jjc-pace-notch` — JJ-aware git commit
- `/jjc-parade-overview` — Heat summary
