---
argument-hint: <firemark>
description: Permanently retire a completed heat
---

Retire a heat: create trophy file, remove from gallops, delete paddock, commit.

Arguments: $ARGUMENTS (required firemark, e.g., "AB" or "₣AB")

## Step 1: Preview

Run dry run first:
```bash
./tt/vvw-r.RunVVX.sh jjx_retire $ARGUMENTS
```

Display the heat silks and pace count from JSON output.

## Step 2: Confirm

Ask user: "This will permanently retire heat ₣XX (silks). Trophy will be created in retired/. Are you sure?"

If user declines, stop.

## Step 3: Execute

```bash
./tt/vvw-r.RunVVX.sh jjx_retire $ARGUMENTS --execute
```

The Rust command handles everything:
- Creates trophy file in `.claude/jjm/retired/`
- Removes heat from `jjg_gallops.json`
- Deletes paddock file
- Commits with message "Retire: ₣{firemark} {silks}"

## Step 4: Report

Display:
- Trophy file path (from command output)
- "Heat ₣XX retired successfully"

## Available Operations

- `/jjc-heat-retire-dryrun` — Preview retirement without changes
- `/jjc-heat-muster` — List all heats
- `/jjc-parade-full` — View heat details before retiring
