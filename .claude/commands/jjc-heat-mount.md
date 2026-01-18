---
argument-hint: [firemark]
description: Mount up and execute next pace
---

Mount a heat: identify the next actionable pace and begin execution.

Use this command when you're ready to work - it finds the next rough or bridled pace and drives toward completing it.

Arguments: $ARGUMENTS (optional Firemark or silks to select specific heat)

## Prerequisites

## Step 1: Identify target heat

**If $ARGUMENTS contains a Firemark (e.g., `AA` or `₣AA`):**
- Use that Firemark directly
- Skip to Step 2

**If $ARGUMENTS is empty or contains silks:**
- Run: `./tt/vvw-r.RunVVX.sh jjx_muster --status current`
- Parse TSV output: `FIREMARK<TAB>SILKS<TAB>STATUS<TAB>PACE_COUNT`

**If 0 heats:** Report "No active heats. Create one with `./tt/vvw-r.RunVVX.sh jjx_nominate`." and stop.

**If 1 heat:** Use that heat's Firemark.

**If 2+ heats:**
- If $ARGUMENTS matches a silks value, use that heat
- Otherwise list heats and ask user to select

## Step 2: Get current pace context

Run:
```bash
./tt/vvw-r.RunVVX.sh jjx_saddle <FIREMARK>
```

Parse JSON output:
```json
{
  "heat_silks": "...",
  "paddock_file": ".claude/jjm/jjp_XX.md",
  "paddock_content": "...",
  "pace_coronet": "₢AAAAC",
  "pace_silks": "...",
  "pace_state": "rough|bridled",
  "spec": "...",
  "direction": "...",
  "recent_work": [{"timestamp": "...", "commit": "...", "coronet": "...", "action": "...", "subject": "..."}]
}
```

Fields `pace_coronet` through `direction` are absent if no actionable pace.

## Step 3: Display context

Show:
- Heat silks and Firemark
- Brief paddock summary (from paddock_content)
- **Recent work** (from `recent_work` array, last 5-10 entries):
  ```
  Recent work on this heat:
  YYYY-MM-DD HH:MM  abc123ef  [W] ₢XXXXX  Wrap description
  YYYY-MM-DD HH:MM  def456ab  [n] ₢XXXXX  Commit message
  ...
  ```
- Current pace silks and state (if present)
- Spec (the pace specification)

## Step 4: Branch on state

**If no actionable pace:**
- Report "All paces complete or abandoned"
- Suggest `/jjc-pace-slate` to add a new pace
- Suggest `/jjc-heat-groom` to review the heat
- Stop

**If pace_state is "rough":**
- Analyze the spec to understand the work
- If spec mentions dependencies, blockers, or sequencing concerns:
  - Surface these to the user as questions before proceeding
  - Do NOT investigate gallops data to validate the system's pace selection
  - If sequencing appears wrong, suggest `/jjc-heat-groom` to reorder or refine
- Read any files referenced in the pace spec
- Propose a concrete approach (2-4 bullets)
- Assess execution strategy:
  - **Bridleability**: Apply CLAUDE.md criteria (mechanical, pattern exists, no forks, bounded). If all four hold, note "This pace is bridleable" and mention `/jjc-pace-bridle` as an option.
  - **Parallelization**: Would multiple agents help? Consider:
    - File independence (same-file edits conflict)
    - Task decomposability (can work be split into independent units?)
    - Overhead vs benefit (parallel setup cost vs sequential simplicity)
  - **Model tier**: Recommend haiku (mechanical), sonnet (standard dev), or opus (architectural) based on complexity.
  - State recommendation explicitly: e.g., "Sequential haiku — single file, mechanical pattern" or "Parallel sonnet×2 — independent modules"
- Create chalk APPROACH marker: `./tt/vvw-r.RunVVX.sh jjx_chalk <PACE_CORONET> --marker A --description "<approach summary>"`
- Ask: "Ready to proceed, or would you prefer to `/jjc-pace-bridle` for autonomous execution later?"
- On approval: Begin work directly

**If pace_state is "bridled":**
- The pace has explicit direction in the direction field
- Parse direction to extract `Agent:` line (haiku/sonnet/opus)
- Create chalk FLY marker: `./tt/vvw-r.RunVVX.sh jjx_chalk <PACE_CORONET> --marker F --description "Executing bridled pace via {agent} agent"`
- **Spawn a Task agent** to execute the pace:
  - `model`: the extracted agent tier (haiku/sonnet/opus)
  - `subagent_type`: "general-purpose"
  - `prompt`: Combine spec + direction. Agent should report completion status when done.
- The spec contains the "what" (requirements, acceptance criteria); direction contains the "how" (steps, verification)
- Wait for agent completion and report outcome to user
- **Do NOT auto-wrap.** Ask user: "Ready to wrap ₢<CORONET>?" and wait for confirmation before running `/jjc-pace-wrap`

## Context preservation

Store for use by other commands:
- Current FIREMARK (for heat-level operations)
- Current PACE_CORONET (primary identifier for pace-level operations)
- Current PACE_SILKS (for display)

## Available Operations

- `/jjc-heat-mount` — Begin work on next pace
- `/jjc-heat-muster` — List all heats
- `/jjc-heat-groom` — Review and refine heat
- `/jjc-heat-nominate` — Create new heat
- `/jjc-pace-slate` — Add a new pace
- `/jjc-pace-notch` — JJ-aware git commit
- `/jjc-parade-overview` — Heat summary
