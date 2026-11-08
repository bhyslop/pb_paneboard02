# JJK Foray — Dispatching Work to a Remote Machine

Read this when the user says "foray" or asks to run something on a remote
machine. It is an **excursus** (`jjsuc_excursus`): held out of the standing
session load and read on demand, reached from the trigger line in
`Tools/jjk/jjai0/jjais_jjk.md` "Foray Protocol" and from the `foray` row of that
file's Quick Verbs table.

The six remote commands are catalogued here and nowhere else. That is
deliberate, and it is the one place this door departs from the usual counsel
against deferring a command reference: the always-loaded reference exists to suppress
confident guessing, and a session that is not foraying never reaches for
`jjx_bind` at all — it has no occasion to guess. A session that *is* foraying
arrived through the verb, which routes here before the first call.

## Concepts

- **Legatio**: A standing SSH session to a remote project (fundus). Created by `jjx_bind`, identified by a token (L0, L1, ...). Its state is an exchange tenant at the kraal's seat, so it persists for the session and dies with the kraal.
- **Pensum**: An async dispatched job within a legatio. Created by `jjx_relay`, identified by a `₱`-prefixed token. Each pensum maps to a remote temp directory on the fundus.
- **Curia**: The invoking side (where Claude runs). **Fundus**: The executing side (where the tabtarget runs).

**Fundus constants** (use these for `jjx_bind`): the default reldir and BURN alias are project-specific — get them from your project's veiled `claude-jjk-*.md` (if present) or the target's BUK Regime Node profile.

## Command reference

All params are JSON objects. `?` = optional. Booleans default to false.

```
jjx_bind           {alias, reldir}                                  # remote: create legatio session (alias resolves BURN profile)
jjx_send           {legatio, command}                               # remote: synchronous exec on fundus
jjx_plant          {legatio, commit}                                # remote: reset fundus to exact commit
jjx_relay          {legatio, tabtarget, timeout, firemark}          # remote: async dispatch via nohup
jjx_certiorari     {pensum, timeout}                                # remote: probe/poll pensum status
jjx_fetch          {legatio, path}                                  # remote: read single file from fundus
```

## Workflow

1. **Bind** (once per session per host): `jjx_bind` with `{alias: "<BURN_ALIAS>", reldir: "<your-project-reldir>"}`. Resolves the BURN profile on the curia to extract host/user/command, then probes via SSH. Returns legatio token.
2. **Ensure curia is clean and pushed**: notch if needed, `git push` if needed. `jjx_relay` will refuse dispatch if working tree is dirty or HEAD is unpushed.
3. **Plant**: `jjx_plant` with `{legatio: "L0", commit: "<HEAD SHA>"}`. Resets fundus to exact commit.
4. **Relay**: `jjx_relay` with `{legatio: "L0", tabtarget: "<filename>.sh", timeout: <seconds>, firemark: "<heat>"}`. Returns pensum token.
5. **Certiorari**: `jjx_certiorari` with `{pensum: "<token>", timeout: 0}` for instant probe, or `timeout: <seconds>` to poll until terminal. Reads the run's own temp dir on the fundus, which no later dispatch rotates, and returns a liveness report with the run's lifecycle from its exchange file (`BURX_PID`, `BURX_BEGAN_AT`, then `BURX_EXIT_STATUS` and `BURX_ENDED_AT` once it ends) and its facts from its dispatch file (`BURD_TARGET`, `BURD_TEMP_DIR`, `BURD_TRANSCRIPT`, `BURD_LOG_HIST`, `BURD_LABEL`). On terminal status, also returns the temp dir's file list.
6. **Fetch** (selective): `jjx_fetch` with `{legatio: "L0", path: "<absolute-path>"}` to retrieve specific result files. Use paths from the certiorari file list.

**Liveness states** (from `jjx_certiorari`):
- **afoot**: the exchange file carries no `BURX_EXIT_STATUS`, PID alive
- **orphaned**: the exchange file carries no `BURX_EXIT_STATUS`, PID dead (crashed without writing status)
- **stopped**: the exchange file carries `BURX_EXIT_STATUS` (check exit code)
- **lost**: no exchange file (`burx.env`) stands in the run's temp dir

**`jjx_send`** is for synchronous one-off commands (no pensum, no polling). Use when the command is short and you need inline results.

**Windows fundus body discipline:** When the fundus is a Windows host, both `jjx_send` and `jjx_relay`-dispatched tabtargets traverse the cmd.exe → wsl.exe / cygwin / PowerShell transport stack. Body authoring rules (escape `\$name` for w-letter wsl.exe transit, no heredocs, single-line `;`-joined for cmd.exe transit, lazy-flush avoidance for PowerShell cmdlets, etc.) live in your project's Windows scripting guide, if present. Empirical record under `memo-YYYYMMDD-windows-transport-{topic}.md`.
