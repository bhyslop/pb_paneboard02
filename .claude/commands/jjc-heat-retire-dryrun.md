---
argument-hint: <firemark>
description: Preview heat retirement (dry run)
---

Preview what retiring a heat would do, without making any changes.

Arguments: $ARGUMENTS (required firemark, e.g., "AB" or "₣AB")

## Execution

```bash
./tt/vvw-r.RunVVX.sh jjx_retire $ARGUMENTS
```

Display the JSON output showing:
- Heat firemark and silks
- Creation date
- Paddock content
- All paces with their tack history

No files are modified. No confirmation needed.

## Available Operations

- `/jjc-heat-retire-FINAL` — Actually retire the heat (with confirmation)
- `/jjc-heat-muster` — List all heats
- `/jjc-parade-full` — View heat details
