Force-break a stuck VVC lock after a crash.

**WARNING**: Only use this if a previous operation crashed and left the lock held.
Normal operations release the lock automatically via RAII.

Arguments: $ARGUMENTS (ignored)

## When to use

Use this command when you see errors like:
- "Another commit in progress - lock held"
- "error: Another operation in progress - lock held"

And you are certain no other operation is actually running.

## Step 1: Check lock status

```bash
git show-ref --verify refs/vvg/locks/vvx 2>&1 || echo "No lock held"
```

If no lock exists, report "No lock held - nothing to do" and stop.

## Step 2: Confirm with user

If lock exists, warn the user:

"Lock is held at `refs/vvg/locks/vvx`. This typically means a previous operation crashed.

**Before breaking**: Ensure no other Claude Code session or terminal is running a vvx/jjx operation.

Break the lock?"

Wait for user confirmation before proceeding.

## Step 3: Break the lock

```bash
./tt/vvw-r.RunVVX.sh vvx_unlock
```

## Step 4: Report result

On success: "Lock broken. You can now retry your operation."

On failure: Report the error.

## Lock mechanism

The VVC lock (`refs/vvg/locks/vvx`) prevents concurrent:
- `vvx_commit` operations
- `vvx_push` operations
- `jjx_slate`, `jjx_rail`, `jjx_tally`, `jjx_draft`, `jjx_nominate` operations

The lock is a git ref that gets deleted when the operation completes.
If the process crashes, the ref remains and must be manually cleared.
