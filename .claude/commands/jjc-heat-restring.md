---
argument-hint: <source-firemark> <dest-firemark> <coronet> [coronet...]
description: Draft paces between heats with paddock ceremony
---

Move one or more paces from a source heat to a destination heat. This is the ceremony that wraps the `jjx_draft` primitive with paddock guidance and steeplechase markers.

**Example:**
```bash
/jjc-heat-restring AA AB ₢AAAAJ ₢AAAAM
```

Arguments: $ARGUMENTS

## Prerequisites

- Gallops JSON must exist
- Source and destination heats must exist
- All specified Coronets must exist in source heat

## Step 1: Parse arguments

Extract from $ARGUMENTS:
- First positional: source Firemark (e.g., `AA` or `₣AA`)
- Second positional: destination Firemark (e.g., `AB` or `₣AB`)
- Remaining positionals: one or more Coronets to draft

**Validation:**
- At least 3 arguments required (source, dest, and at least one coronet)
- Source and destination must be different

## Step 2: Validate heats exist

Run:
```bash
./tt/vvw-r.RunVVX.sh jjx_muster
```

Verify both source and destination Firemarks appear in the output.

## Step 3: Draft each pace

For each Coronet, run:
```bash
./tt/vvw-r.RunVVX.sh jjx_draft <CORONET> --to <DEST_FIREMARK>
```

Collect the mapping: old coronet -> new coronet for each pace.

**On any failure:** Report error and stop. No partial drafts - if one fails, abort before any more.

## Step 4: Display draft summary

Show:
- Number of paces drafted
- Source heat Firemark and silks
- Destination heat Firemark and silks
- Mapping table: old coronet -> new coronet with pace silks

## Step 5: Check source heat status

Run:
```bash
./tt/vvw-r.RunVVX.sh jjx_parade <SOURCE_FIREMARK> --format overview
```

**If source heat is now empty (no paces):**
- Warn: "Source heat ₣{source} is now empty. Consider retiring with `/jjc-heat-retire`."

## Step 6: Guide paddock updates

Inform the user:
```
Paddock updates may be needed:

Source (.claude/jjm/jjp_{source}.md):
- Remove references to drafted paces
- Add steeplechase note about the restring

Destination (.claude/jjm/jjp_{dest}.md):
- Add context for the incoming paces
- Reference source heat if relevant

Would you like me to open these files for review?
```

If user confirms, read and display relevant sections of both paddock files.

## Step 7: Create steeplechase marker

Run:
```bash
./tt/vvw-r.RunVVX.sh jjx_chalk <DEST_FIREMARK> --marker DISCUSSION --description "Restring: {N} paces from ₣{source}"
```

## Step 8: Auto-commit changes

Run guarded commit:
```bash
./tt/vvw-r.RunVVX.sh vvx_commit --message "Restring: {N} paces ₣{source} -> ₣{dest}"
```

On failure (e.g., lock held), report error but don't fail - gallops changes are already saved.

## Error handling

Common errors:
- "Source heat not found" — invalid source Firemark
- "Heat not found" — invalid destination Firemark
- "Cannot draft pace to same heat" — source equals destination
- "Pace not found in heat" — Coronet doesn't exist in source

## Notes

- Draft preserves pace state (rough stays rough, complete stays complete)
- Draft preserves all tack history with a note recording the transfer
- New Coronets are assigned using destination heat's seed
- Old Coronets become invalid after draft

## Available Operations

- `/jjc-heat-restring` — Draft paces between heats (this command)
- `/jjc-heat-mount` — Begin work on next pace
- `/jjc-heat-groom` — Review and refine heat plan
- `/jjc-heat-nominate` — Create new heat
- `/jjc-parade-overview` — Heat summary
