---
argument-hint: [firemark]
description: Display heat detail
---

Show full pace details with tack text for a heat.

Arguments: $ARGUMENTS (optional Firemark; uses current context if omitted)

## Prerequisites

## Step 1: Identify target heat

**If $ARGUMENTS contains a Firemark (e.g., `AB` or `₣AB`):**
- Use that Firemark directly

**If $ARGUMENTS is empty:**
- Use FIREMARK from current context
- If no context: Error "No heat context. Use `/jjc-heat-mount` first."

## Step 2: Get parade data

Run:
```bash
./tt/vvw-r.RunVVX.sh jjx_parade <FIREMARK> --format detail
```

## Step 3: Display output

Display the formatted output from vvx.

## Available Operations

- `/jjc-parade-overview` — Heat summary with pace counts
- `/jjc-parade-order` — Ordered pace list with states
- `/jjc-parade-detail` — Full pace details with tack text
- `/jjc-parade-full` — Complete heat dump including paddock
