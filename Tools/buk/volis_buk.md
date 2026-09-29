## Bash Utility Kit (BUK) Concepts

BUK provides tabtarget/launcher infrastructure for bash-based tooling.

### TabTarget System

TabTargets are lightweight shell scripts in `tt/`, the CLI entry point for all operations. They delegate to workbenches via launchers — no business logic lives in tabtargets.

**Discoverability**: `ls tt/` shows all available commands. Tab completion narrows by prefix: `tt/rbw-<TAB>`.

**Naming pattern**: `{colophon}.{frontispiece}[.{imprint}].sh`

| Part | Purpose | Example |
|------|---------|---------|
| **Colophon** | Routing identifier (includes hyphen, workbench matches on this) | `rbw-cC`, `buw-tt-ll` |
| **Frontispiece** | Human-readable description (PascalCase) | `Charge` |
| **Imprint** | Optional target parameter (nameplate moniker, fixture name, etc.) | `tadmor` |

- The `.` is the delimiter between parts
- The hyphen is part of the colophon (not a separator)

Example: `tt/rbw-cC.Charge.tadmor.sh` — colophon `rbw-cC` routes to the crucible charge command, frontispiece tells you what it does, imprint `tadmor` selects the nameplate.

Multiple tabtargets can share the same colophon but differ by imprint:
```
tt/rbw-cC.Charge.tadmor.sh
tt/rbw-cC.Charge.srjcl.sh
tt/rbw-cC.Charge.pluml.sh
```

### BUK Vocabulary

| Term | Definition |
|------|------------|
| **Zipper** | Module kindling colophon→module→command array constants |
| **Workbench** | Routes commands: `{prefix}w_workbench.sh` |
| **Testbench** | Routes tests: `{prefix}t_testbench.sh` |
| **Folio** | Runtime target value (`BUZ_FOLIO`) passed to a command — nameplate moniker, role name, etc. How it arrives depends on the channel |
| **Channel** | Enrollment-time declaration of how a colophon receives its folio: `imprint` (from filename — one tabtarget per target), `param1` (command-line argument — single tabtarget), or empty (no folio needed) |

**Key files:**
- `Tools/buk/buc_command.sh` — command utilities
- `Tools/buk/bud_dispatch.sh` — dispatch utilities
- `Tools/buk/buw_workbench.sh` — workbench

Full spec: `Tools/buk/README.md`

## Forbidden Shell Operations

**Never use `cd` in Bash commands — NO exceptions.**

The working directory persists across Bash tool calls, so a `cd` is never scoped to the command that ran it: it is a durable edit to the seat, inherited by every command after it. That is a hazard here because relative paths are contract rather than convenience. A tabtarget is invoked as `./tt/...` from the project root, and what it resolves from there — its launcher, its regime config, the `../logs-buk` its station file names by default — silently follows the working directory wherever it has been moved. A cd'd session runs the same tabtarget against a different tree, or writes its logs where nobody will look, and nothing announces the shift, because each command still succeeds on its own terms.

- Reach the tree instead of moving to it, and reach it RELATIVE TO YOUR SEAT. A seat that never moves is a fixed origin, so `../sibling-repo/...` names one tree for the whole session and needs nothing discovered. A sibling repo, a peer worktree, a tree beside the one you stand in — all are reached that way; it is the idiom, not a workaround for the rule.
- A rooted spelling is not forbidden and is not the idiom either: what is banned is one verb, not a path shape. A rooted path obeys the rule but pins the text to one machine's layout, which is why the seat-relative form is what to reach for. That choice is about LIVE INVOCATION, which anchors on the seat; durable text a LATER reader runs names no root at all, its author not knowing the seat it will run from.

**There is no safe cd.** Do not reason that "I'll cd back" — the restoring command is one failure, interruption, or forgotten step away from never running, and everything in between has already been aimed at the wrong tree. Owning your working directory does not soften this: a session with a seat of its own still may not move it, because the hazard is the drift itself, not who else might be sharing.

## Tool Git Discipline

Rivet `BUr_k7d` governs, cited here rather than restated: tooling never stages or commits in a repository it does not own, whatever the tool is written in, and the caller seals the delta the tool leaves standing. BUK holds the bash arm. The uniform gate is `bug_require_clean_tree_creed "<creed>"` (BUG module) — a precision-band deliberate-rejection gate; BUG stays kit-agnostic and the caller supplies its rationale (a creed) for demanding a clean tree. A verb that installs into tracked config calls it first, so an install-then-forgot-to-commit cannot silently ride into a later build.

## TabTarget Invocation Discipline

**Never pipe a tabtarget invocation — into `tee`, `tail`, `head`, `grep`, or anything else — and never send one to `/dev/null`. NO exceptions.**

Tabtargets self-log to the directory the station file's `BURS_LOG_DIR` names, and there are two seats. **Station ground** is the default: `../logs-buk/`, relative to the project root, shared by every clone and worktree on that machine. **A dispatched session is the other seat** — the dispatch provisions `BURV_LOG_DIR`, which overrides the station value, so that session's logs land in its own per-billet scratch container. Three files are written either way, and the seat decides only how wide the race on the first two runs:
- `last.txt` — most recent invocation across **all** tabtargets writing into that directory. **Never read this** — any tabtarget run that shares the directory, between your dispatch and your read, overwrites it out from under you.
- `same-{cmd}.txt` — most recent invocation of this specific tabtarget. Same race, narrowed to one colophon: another run of the identical tabtarget still overwrites it.
- `hist-{cmd}-{timestamp}.txt` — one immutable file per invocation. The only race-free pointer, and the only one safe to read at either seat.

Both stdout and stderr are captured already, so adding your own `tee` or `2>&1` duplicates work the tool did — redundant rather than forbidden, and a bare `2>&1` is a redirection that passes. The real hazard is piping a tabtarget into `tail`/`head`/`grep`: zsh defaults `pipefail` OFF, so the pipeline returns the last command's exit status — usually 0. **A failing test reports as success.** The null sink costs the same verdict by the other road: a silenced door reports the same unread result a piped one does, and both are refused under one rule.

**The line is between discard and capture, not between pipe and redirect.** A redirect to a real file stays lawful on every door and every spelling — `tt/buw-rcv.ValidateConfigRegime.sh > regime.log` as much as `>> regime.log` — because a door captured to a file keeps its verdict whole and readable. What is refused is the two shapes that throw the verdict away: a pipe into a reader, and `/dev/null` standing anywhere in the door's own segment.

- Run the tabtarget directly, then read the announced `hist-` path in a separate command. Non-interactive dispatch prints all three paths on a `log files:` line; interactive dispatch prints the `hist-` path alone on a `log (interactive:)` line — either way the path is handed to you, so use it verbatim.
- **Never locate the hist file by `ls -t` or any other newest-match search** — that reinstates the race the announced path exists to avoid, another invocation sharing the log directory being free to drop a newer `hist-` file between your dispatch and your search. If the announced path wasn't captured, re-run the tabtarget and read its freshly printed line.
- Environment variables before the command are fine: `BURE_CONFIRM=skip ./tt/rbw-cQ.Quench.tadmor.sh`

```
# Wrong — exit code is from `tail`, not the tabtarget; failures masked
./tt/rbw-ts.TestSuite.gauntlet.sh 2>&1 | tee /tmp/log | tail -80

# Wrong — even a bare `| head` discards the real signal
./tt/rbw-ts.TestSuite.reveille.sh | head -50

# Wrong — the verdict is silenced rather than truncated; the same loss, the other road
./tt/rbw-ts.TestSuite.reveille.sh > /dev/null

# Right — separate commands; exit code preserved; read the hist path the dispatch announced
./tt/rbw-ts.TestSuite.gauntlet.sh
# (dispatch's "log files:" line named ../logs-buk/hist-ts-gauntlet-20260723-103812-51023-4.txt — use that verbatim)
tail -80 ../logs-buk/hist-ts-gauntlet-20260723-103812-51023-4.txt

# Right — capture to a real file is lawful; only discard is refused
./tt/rbw-ts.TestSuite.gauntlet.sh > ../logs-buk/capture.txt
```

**There is no safe `tee | tail`, and no safe `> /dev/null`.** Do not reason "I'll just truncate the output for readability" — the truncation and the exit-code-eating are inseparable. Do not reason "I don't need this door's output" either: the verdict *is* the output, and a run you silenced is a run you cannot report. Truncate by reading the log file afterward.

**In a dispatched session, run a kennel test door through the engine's tabtarget door — never by bash.** That door hands the child the session's own output roots and reads what the run measured the moment it returns; a door run by bash is a run the engine never sees, so what it measured is discarded rather than recorded. **Never batch such a run beside a bash-run tabtarget either** — the two then share one output slot, and the record the engine reads may be the one it did not launch.

## Test Execution Discipline

Run test fixture tabtargets **sequentially, never in parallel**. Test fixtures share regime state and container/network namespaces — parallel execution causes resource conflicts and false failures.

```
# Correct: run one at a time
tt/rbw-tf.FixtureRun.sh regime-validation
tt/rbw-tf.FixtureRun.sh tadmor

# Wrong: never run fixtures concurrently
tt/rbw-tf.FixtureRun.sh regime-validation & tt/rbw-tf.FixtureRun.sh tadmor &
```

## Acronym Notes

Annotations for the acronym homes indexed in `Tools/buk/volip_buk.md` — the per-row descriptions and family topology the index does not carry.

- **BUC**  → `Tools/buk/buc_command.sh` (command utilities, buc_* functions)
- **BUD**  → `Tools/buk/bud_dispatch.sh` (dispatch utilities, zbud_* functions)
- **BUE**  → `Tools/buk/bue_exergue.sh` (exergue module, bue_* functions — stamps a build with the source position it was struck from: the newest first-parent landing on the trunk counterpart that touched an elected root, written into a gitignored generated Rust module, write-if-changed, dying rather than shipping unstamped)
- **BUG**  → `Tools/buk/bug_git.sh` (bash git utilities, bug_* functions — home of the "tools never commit, gate on a clean tree" gate `bug_require_clean_tree_creed`)
- **BUH**  → `Tools/buk/buh_handbook.sh` (handbook utilities, buh_* functions - always-visible user interaction)
- **BUPE** → `Tools/buk/bupe_cli.sh` (parcel emplacement — the maintenance door for a lit station, colophon `buw-pe`: it takes the extracted parcel directory as an explicit argument, runs the install procedure through that parcel's own bundled engine rather than any binary in the consumer tree, and past the emplace only reads, its own file having stood in the directory just replaced. The parcel's `vvi_install.sh` remains the rescue door for a station too dark to dispatch)
- **BUYM** → `Tools/buk/buym_yelp.sh` (yelp module — diastema wire format, yawp functions, format resolver, legacy captures)
- **BUV**  → `Tools/buk/buv_validation.sh` (validation utilities, buv_* functions)
- **BUW**  → `Tools/buk/buw_workbench.sh` (workbench utilities, buw_* functions)
- **BURC** → `Tools/buk/burc_cli.sh`, `Tools/buk/burc_regime.sh` (regime configuration)
- **BURS** → `Tools/buk/burs_cli.sh`, `Tools/buk/burs_regime.sh` (regime station)
