# Job Jockey Kit

## What is Job Jockey?

Job Jockey (JJ) is a lightweight system for managing project initiatives through conversation with Claude Code. It helps you track bounded heats, remember what's next, and keep a backlog of ideas without drowning in ceremony or context bloat.

Think of it as a project notebook specifically designed for human-AI collaboration:
- **Heats** are your current work (3-50 chat sessions worth)
- **Paces** track what's done and what's next within a heat
- **Itches** capture future ideas without losing focus
- **Scars** record closed ideas with lessons learned

The system is ephemeral by design: documents have clear lifecycles, completed work gets archived, and context stays lean. Everything is markdown, lives in git, and can move between computers with you.

## Naming Prefixes

All Job Jockey artifacts use the `jj` prefix with category-specific third letters:

| Prefix | Category | Purpose |
|--------|----------|---------|
| `jja_` | Action | Slash commands |
| `jjb_` | Brand | Current detected version |
| `jjc_` | Chase | Steeplechase performance logs |
| `jjg_` | aGent | (Future) Agent definitions |
| `jjh_` | Heat | Bounded initiative files |
| `jji_` | Itch | Future work aggregate |
| `jjk_` | sKill | (Future) Skill definitions |
| `jjl_` | Ledger | Version history registry |
| `jjm/` | Memory | State directory (`.claude/jjm/`) |
| `jjn_` | Notch | (Future) JJ-aware git commits |
| `jjs_` | Scar | Closed work aggregate |

## Core Concepts

### Heat
A bounded initiative with **coherent goals that are clear and present**. Spans 3-50 chat sessions. Has a goal, context section, and list of paces. Lives as a dated file like `jjh_b251108-buk-portability.md`.

Heat location indicates state:
- `current/` — actively working
- `retired/` — completed (retire date added to filename: `jjh_b251108-r251126-buk-portability.md`)

A heat must be timely. If work is well-specified but not timely, it remains an itch until the time is right.

### Pace
A discrete action within the current heat. Appears in heat documents as structured sections. Pending paces can have detailed descriptions. Completed paces get condensed to brief summaries to save context.

Paces can be worked on collaboratively (human drives, model assists) or **armed** for autonomous execution. To arm a pace, use `/jja-pace-arm` which validates the spec has clear objective, bounded scope, success criteria, and failure behavior. Armed paces can then be flown with `/jja-pace-fly`.

### Itch
Future work of any scope — heat-sized initiatives, individual paces, or smaller ideas — captured in the backlog because they're not timely for current work. The key attribute is **not now**: regardless of size or detail level, it's not ready to schedule. All itches live in a single aggregate backlog file (`jji_itch.md`).

### Scar
An itch that has been **closed with lessons learned**. Not deleted (we learned something), but won't be revisited. Different from "shelved" which implies "maybe later" — a scar is deliberately closed.

All scars live in a single aggregate file (`jjs_scar.md`).

### Silks
The kebab-case identifier that names heats, paces, itches, and scars. Examples: `cloud-first-light`, `fix-quota-bug`, `buc-info-default-visibility`. Target 3-5 words — short enough to say aloud and fit in commit messages. Good silks are memorable and evocative.

## How It Works

### Day-to-Day Usage

You work on a heat by talking with Claude Code. As you make progress:
- At session start, use `/jja-heat-saddle` to establish context and see proposed approach
- Work on the pace together
- Use `/jja-pace-wrap` to mark complete - Claude automatically analyzes next pace and proposes approach
- Use `/jja-notch` to commit/push - Claude then proposes approach for current pace
- New paces emerge and get added with `/jja-pace-new`

Note: After pace-wrap or notch, you do NOT need heat-saddle - those commands flow directly into the next pace.

When new ideas come up that don't belong in current heat, use `/jja-itch-add` to file them away.

When a heat completes, Claude uses `/jja-heat-retire` to move it to `retired/` with a datestamp.

### Interaction Pattern

The system is **conversational and collaborative**:
- Claude proposes actions ("I'll mark this pace done and summarize it as...")
- You approve or amend ("yes" / "change it to..." / "no, actually...")
- Changes commit to git automatically after approval
- You maintain control, Claude does the bookkeeping

### Context Management

The system is designed to minimize context usage:
- Completed paces become one-line summaries
- Only current heat is in regular context
- Itches and scars stay out of context unless needed
- Full history preserved in git, not in active documents

## File Structure

### `jjh_bYYMMDD-description.md` (Job Jockey Heat)
Main context document for a heat.
- **Active**: Named with begin date and description (e.g., `jjh_b251108-buk-portability.md`)
- **Retired**: Begin date preserved, retire date added (e.g., `jjh_b251108-r251126-buk-portability.md`)
- Located in: `.claude/jjm/current/` (active) or `.claude/jjm/retired/` (completed)

### `jji_itch.md` (Job Jockey Itches)
**All** itches live here — the single source of future work.
- Brief sparks or detailed specifications
- Items graduate from here to new heat files
- Located in: `.claude/jjm/`

### `jjs_scar.md` (Job Jockey Scars)
Closed itches with lessons learned.
- Not rejected, but deliberately closed
- Includes context on why closed and what was learned
- Located in: `.claude/jjm/`

### `jjc_bYYMMDD-description.md` (Job Jockey Steeplechase)
Performance log capturing how each heat actually ran.
- Created lazily when first entry is logged
- Naming matches the heat file (same begin date and silks)
- Located in: `.claude/jjm/current/` during active work
- On retirement: contents merged into heat file under `## Steeplechase` section

## Directory Structure

JJ memory lives at `.claude/jjm/` relative to CLAUDE.md. Commands live at `.claude/commands/`.

```
my-project/                 # Launch Claude Code here
  CLAUDE.md
  .claude/
    commands/
      jja-heat-saddle.md
      jja-heat-retire.md
      jja-pace-new.md
      jja-pace-arm.md
      jja-pace-fly.md
      jja-pace-wrap.md
      jja-itch-add.md
      jja-notch.md
    jjm/
      jji_itch.md
      jjs_scar.md
      current/
        jjh_b251108-feature-x.md
        jjc_b251108-feature-x.md
      retired/
        jjh_b251001-r251015-feature-y.md
  src/
  ...
```

## Itch Format

All itches live in `jji_itch.md`. Each itch is a section with a descriptive header (no "Itch:" prefix — keeps entries clean for moving to scar file):

```markdown
# Itches

## governor-implementation
Create rbgp_create_governor for depot setup flow. Depends on understanding
the full depot lifecycle. Could be armed for haiku once spec is clear.

## image-retrieve-design
Design rbtgo_image_retrieve operation from scratch. No existing implementation
to extract from. Needs architectural decision on caching strategy.

## quick-idea
Brief spark about improving error messages.
```

When moving to scars, the section moves as-is with added closure context:

```markdown
# Scars

## governor-implementation
Create rbgp_create_governor for depot setup flow...

**Closed**: Implemented as rbgp_create_governor in Payor module.
Learned: Governor creation is a Payor operation since Payor owns depot lifecycle.
```

## Steeplechase Format

The steeplechase file (`jjc_bYYMMDD-description.md`) captures three types of entries:

### APPROACH Entry
Logged when analyzing a pace and proposing how to approach it:
```markdown
---
### 2025-12-25 14:30 - specify-image-delete - APPROACH
**Proposed approach**:
- Read rbf_delete implementation to extract step sequence
- Apply completeness criteria from RBAGS pattern
- Document in same format as rbtgo_director_create
---
```

### WRAP Entry
Logged when marking a pace complete:
```markdown
---
### 2025-12-25 16:45 - specify-image-delete - WRAP
**Outcome**: Documented rbtgo_image_delete with 5-step sequence extracted from rbf_delete
---
```

### FLY Entry
Logged when executing an armed pace autonomously:
```markdown
---
### 2025-12-25 15:00 - update-config-refs - FLY
**Spec**: Update all config references from old to new format
**Execution trace**: Read 12 config files, modified 8 with reference updates
**Result**: success
**Modified files**: auth.ts, api.ts (8 files total)
---
```

On heat retirement, the entire steeplechase is appended to the heat file under a `## Steeplechase` section, creating a complete archive of how the heat ran.

## Workflows

### Starting a New Heat
1. Create `jjh_bYYMMDD-description.md` in `.claude/jjm/current/` (use today's date)
2. Include Paddock section with stable background information
3. Include Paces section with initial checklist items
4. Archive previous heat to `retired/` (if applicable)

### Selecting Current Heat
When starting a session or the user calls `/jja-heat-saddle`, Claude checks `.claude/jjm/current/`:
- **0 heats**: No active work. Ask if user wants to start a new heat or promote an itch.
- **1 heat**: Show heat and current pace
- **2+ heats**: Ask user which heat to work on

### Working on a Heat
1. Use `/jja-heat-saddle` at session start - Claude shows context and proposes approach
2. Approve approach or adjust, then work on the pace
3. Use `/jja-pace-wrap` when complete - Claude analyzes next pace and proposes approach
4. Approve and continue (no need for heat-saddle between paces)
5. Use `/jja-notch` periodically - commits, pushes, and proposes approach for current pace
6. Repeat until heat is complete

### Completing a Heat
1. Verify all paces are complete or explicitly discarded
2. Use `/jja-heat-retire` to move and rename heat file:
   - Adds retire date (`rYYMMDD`) to filename, preserving begin date
   - Moves from `current/` → `retired/`
   - Commits the archival

### Itch Triage
When a new idea emerges:
1. **Does it block current heat completion?** → Add as pace to current heat
2. **Is it future work worth capturing?** → Add to `jji_itch.md`
3. **Is it something we're deliberately closing?** → Add to `jjs_scar.md` with reason

## Format Conventions

- **All documents**: Markdown (`.md`)
- **Dates**: YYMMDD format (e.g., 251108 for 2025-11-08)
  - `b` prefix = begin date (when heat started)
  - `r` prefix = retire date (when heat completed)
- **Descriptions**: Lowercase with hyphens (e.g., `buk-portability`)
- **Pace titles**: Bold (e.g., `**Audit BUK portability**`)
- **Completed summaries**: Brief, factual, no line numbers (they go stale)

## Heat Document Structure

Heat files contain these sections:

```markdown
# Heat: [Name]

## Paddock
[Stable background info. Can grow as insights emerge during heat work.]

## Done
- First completed pace title
- Second completed pace title
...

## Remaining
- **Current pace title** ← First item is implicitly current (bold to highlight)
  [Working notes for this pace only, if needed]
- Next pace title
- Another future pace
...
```

### Section Details

**Paddock**: Stable information that grows as architectural insights emerge. Goals, constraints, decisions, background.

**Done**: Completed pace titles only. No verbose summaries - git commits carry that detail.

**Remaining**: Unnumbered queue of paces. **First item is implicitly current** (bold it to highlight, may include working notes). Rest are future paces in priority order. Order can change freely. When current pace completes, move it to Done and first remaining item becomes current.

**Design rationale**: Eliminates dedicated Current section to reduce document thrash. As paces move from Remaining → Done, fewer section movements mean cleaner diffs and less context distraction.

## Design Principles

1. **Ephemeral by design**: Documents have clear lifecycles, completed work gets archived
2. **Conversational**: Claude proposes, you approve or amend, Claude executes
3. **Context-conscious**: Minimize active context, maximize git history
4. **Model-primary**: Claude reads/writes frequently, human adjusts occasionally
5. **Clear naming**: Prefixes make purpose immediately obvious
6. **Git-friendly**: Preserve history, commit after approval (one commit per action)
7. **Minimal ceremony**: Easy to use, hard to misuse
8. **Aggregate itches**: All itches in one file, all scars in one file — no sprawl
9. **Portable**: Works across computers via relative paths
10. **Do No Harm**: If paths are misconfigured or files missing, announce issue and stop — don't guess or auto-fix
11. **Branch workflow**: Work happens on branches that get squashed on merge. Notch commits form the steeplechase — execution history lives in branch history until squash.

## Installation

Job Jockey is installed via the workbench script:

```bash
# Install
./Tools/jjk/jjw_workbench.sh jjk-i

# Uninstall (preserves .claude/jjm/ state)
./Tools/jjk/jjw_workbench.sh jjk-u
```

The workbench:
- Creates `.claude/commands/jja-*.md` command files
- Creates `.claude/jjm/` directory structure
- Patches CLAUDE.md with configuration section
- Adds `Edit(.claude/jjm/**)` permission to `.claude/settings.local.json` for frictionless JJ state updates

Configuration is via environment variables:
- `ZJJW_TARGET_DIR` - Target repo directory (default: `.`)
- `ZJJW_KIT_PATH` - Path to this kit file (default: `Tools/jjk/README.md`)

**Important**: Restart Claude Code after installation for new commands to become available.

## Available Commands

- `/jja-heat-saddle` - Saddle up on heat at session start, analyze pace, propose approach
- `/jja-heat-retire` - Move completed heat to retired with datestamp
- `/jja-pace-new` - Add a new pace
- `/jja-pace-arm` - Validate pace spec and arm for autonomous execution
- `/jja-pace-fly` - Execute an armed pace autonomously
- `/jja-pace-wrap` - Mark pace complete, analyze next pace, propose approach
- `/jja-itch-add` - Add a new itch to the backlog
- `/jja-notch` - JJ-aware git commit, push, and re-engage with current pace

## Terminology

### Paddock
The heat-wide context section in a heat document. Named after the prep area where horses gather before a race.

The Paddock holds stable information that spans multiple paces:
- Approach and guidelines for working the heat
- Reference files and domain knowledge
- Facts and insights that emerge during heat execution
- Constraints, decisions, and architectural background

Usage: "Add that insight to the Paddock" / "Check the Paddock for guidelines"

In heat documents, the Paddock is the `## Paddock` section and its subsections.

### Notch
A JJ-aware git commit. Use `/jja-notch` to commit with heat/pace/brand context.

Fire-and-forget design:
1. Dispatcher validates heat context from conversation (no filesystem fallback)
2. Checks for untracked files (fails if any - stage manually first)
3. Spawns background haiku agent that does: git add -u, commit, push
4. Returns immediately - user continues working

Commit format:
- With pace: `[jj:BRAND][HEAT/PACE] Message`
- Without pace: `[jj:BRAND][HEAT] Message` (for general heat work)

Example: `[jj:600][cloud-first-light/fix-quota-bug] Fix project quota check`

Usage: "Notch these changes" / "Let me notch that"

### Silks
The kebab-case identifier that uniquely names JJ artifacts:
- **Silks** are the kebab-case identifiers for heats, paces, itches, and scars (e.g., `cloud-first-light`, `fix-quota-bug`)
- Every itch has silks; silks carry to scars when closed
- Heats have silks (the description part of filename)
- Steeplechases inherit the heat's silks
- Usage: "What's the silks on that itch?" / "The heat silks are `rbags-specification`"

### Brand and Ledger
Version tracking for JJ kit installations:
- **Brand**: The current detected version number (e.g., 600, 601). Computed during install from content hash of kit files.
- **Ledger entry**: A single version record containing version number, content hash, git commit, and date.
- **Ledger file**: `Tools/jjk/jjl_ledger.json` - registry of all known versions, tracked in git.

During install:
1. Compute SHA-256 hash of `jjw_workbench.sh` + `README.md`
2. Look up hash in ledger
3. If found, use existing version number
4. If not found, increment from max version (starting at 600), register new entry
5. Bake brand into all emitted command files

Benefits:
- Deterministic: same kit content always produces same brand
- Traceable: correlate heat outcomes to specific JJ versions
- Self-documenting: each command file declares its brand

## Future Directions

### Specialized Agents
Create purpose-built agents for delegation, not just model hints:
- **Model-tier agents**: haiku-worker, sonnet-worker, opus-worker with appropriate context budgets
- **Pace-type agents**: mechanical-edit, codebase-explore, test-runner, doc-writer
- **Delegation router**: analyzes pace spec, selects optimal agent, handles handoff
- Success criteria: right agent for right task, minimal token waste, clear failure escalation

### Skill Articulation
Before delegation can succeed, skills must be identified and well-described:
- **Skill inventory**: catalog of capabilities available for delegation (edit, search, test, generate, validate, etc.)
- **Skill cards**: each skill has preconditions, inputs, outputs, failure modes, model requirements
- **Heat planning**: match heat goals to available skills, identify gaps early
- **Pace analysis**: when proposing approach, suggest "this pace needs skills X, Y" and verify they exist
- **Skill gaps**: surface when a pace requires a skill not yet articulated → triggers skill development

### Heat Creation Skill
Create a dedicated skill for forming well-structured heats:
- **Purpose**: Ensure new heats follow silks guidance, correct structure, and validated context from creation
- **Invocation**: User describes heat intent; skill guides through:
  - Silks workshop: generate 3-5 candidates, validate against guidance (2-4 words, catchy, <30 chars)
  - Paddock gathering: stable background info, goals, constraints
  - Initial paces: sketch first 3-5 paces as unnumbered Remaining list (no Current section)
  - Validation: verify `.claude/jjm/current/` exists, file naming, structure
- **Output**: Properly formed heat file in `.claude/jjm/current/jjh_bYYMMDD-silks.md`
- **Benefit**: Prevents malformed heats from manual creation; ensures consistency across team/sessions
- **Related**: Complements "Heat Scrub" (future direction) which fixes existing/legacy heats
- **Invocation example**: `/jja-heat-create "cloud build follow-up"`

### Delegation Intelligence
Improve the analyze→delegate flow:
- Learn from action logs which pace patterns succeed/fail per agent type
- Auto-suggest agent selection based on pace characteristics
- Detect scope creep or unbounded work before it spins
- Graceful escalation: haiku fails → sonnet retry → opus rescue → human
- Match pace requirements to skill inventory before attempting delegation

### Heat Document Efficiency
Reduce thrash in heat files during active work:
- Current structure causes frequent moves between Done/Current/Remaining sections
- Consider: more stable pace representation that reduces edits
- Investigate: what's the minimum mutable surface for tracking progress?
- Goal: cleaner diffs, less context churn, easier retrospectives

### Formal Pace Numbering
Remove pace numbers from human-visible artifacts:
- Numbers appearing in heat files/code are brittle and go stale
- Pace ordering is implicit in document position (first unnumbered item = current/next)
- Recommendation: assign stable pace IDs on creation (e.g., `p001`, `p002`) for internal tracking only
- **Heat template revision**: Remove all `1.`, `2.`, etc. prefixes from Remaining section; keep paces as unnumbered list
- **Steeplechase entries**: Reference pace by ID+silks (e.g., `p001 - setup-config`) instead of numbers
- Keep numbers internal to JJ machinery, never in prose or human-facing docs

### Silk Design Guidance
Make silks short and memorable for human cognition:
- **Silks**: Kebab-case identifiers for heats, paces, itches, scars (e.g., `cloud-foundation-stabilize`, `fix-unbound-variable`)
- **Target**: 3-5 words, short enough to say aloud and fit in commit messages
- **Rationale**: Silks appear frequently in speech, commit messages, and steeplechase entries. Short + catchy reduces cognitive load and typos.
- **Anti-patterns**: Avoid long descriptive names, avoid acronyms unless widely recognized in project, avoid generic names (e.g., `misc-fixes`, `stuff`)
- **Mnemonic quality**: Good silks create mental hooks (e.g., `image-registry-listing` immediately evokes the feature; `gad-perf-analysis` links to GAD tool)
- **Workshop**: When creating a new heat/itch/pace, generate 3-5 candidate silks and pick the one that "sticks" best

### Configurable Autocommit
Project-level control over automatic git commits:
- Some projects want commits per pace wrap
- Some want manual commit control
- Some want no JJ-initiated commits at all
- Configuration in CLAUDE.md JJ section: `autocommit: per-pace | per-notch | never`
- Default behavior should match current (commits on wrap/notch)

### Steeplechase as Git Commit Discipline
Experiment with moving steeplechase entries from heat files to git commits:
- **Observation**: Steeplechase entries are valuable for retrospective analysis (models actually read them). Question: does the heat file need to carry them, or should git be the source of truth?
- **Current model**: Steeplechase entries live in heat file, merge to heat on retirement. Accumulates in-memory context during heat work.
- **Alternative model**: Store steeplechase-like metadata in "degenerate" commits (commits that contain only metadata/logs, no code changes)
  - Approach: Each pace wrap, delegate, or approach logs a commit with structured metadata in message/trailers
  - Format: `[jj:APPROACH|WRAP|DELEGATE] [heat:silks][pace:silks] <execution details in body>`
  - Git becomes the execution log; heat files stay lean (no Steeplechase section needed)
- **Benefits**:
  - Execution history lives where it naturally belongs (git history)
  - Heat files lighter, fewer section movements during work
  - Full git tooling available for filtering/searching execution patterns
  - Correlates execution patterns directly to code commit timeline
  - Can use `git log --grep="jj:WRAP"` to reconstruct heat retrospective
- **Challenges**:
  - Requires discipline to remember to search git during retrospectives
  - Need reliable patterns for identifying steeplechase commits
  - Must explicitly gather git metadata when retiring heat (vs. auto-merge in file)
  - Adds "degenerate commits" to repo (worth the tradeoff?)
- **Experiment**: Try for one heat; evaluate whether git-based steeplechase is more useful than file-based

### Git Control Exfiltration
Delegate git operations to a dedicated Claude-aware git kit invoked via bash:
- **Problem**: Git control from Claude Code has been unreliable. The Task tool's subagent dispatch doesn't inherit system context predictably, and LLM interpretation of git operations can be "sloppy" (wrong commit formats, unexpected attribution, etc.).
- **Solution**: Create a separate open-source git kit (e.g., `cgk` - Claude Git Kit) with:
  - Workbench that invokes `claude` CLI directly from bash (not via Task tool)
  - Haiku model for mechanical commit formatting
  - Claude Code treats it as a background process to monitor
  - Deterministic prompts baked into bash, not interpreted at runtime
- **JJ integration**: `/jja-notch` remains the JJ command; it delegates to the git kit via bash:
  ```bash
  # notch command tells Claude Code to run:
  ./Tools/cgk/cgw_workbench.sh cgk-commit --heat "$heat" --pace "$pace" --brand "$brand"
  ```
  JJ owns the concept (notch = JJ-aware commit); git kit owns the execution.
- **Absorbs from other kits**:
  - CMK's prep-pr command (branch preparation for upstream PRs)
  - Any other git-centric operations that benefit from controlled LLM formatting
- **Benefits**:
  - Bash-level control over exactly what prompt haiku receives
  - No system prompt inheritance confusion
  - Claude Code monitors completion without executing git itself
  - Reusable across projects independent of JJ or CMK
- **Architecture sketch**:
  ```bash
  # cgk_workbench.sh command implementation:
  claude --model haiku -p "Format commit: $context" | xargs git commit -m
  ```
- **Prerequisite**: Validate that `claude` CLI can be invoked from bash with controlled prompts and predictable output parsing

---

*Command implementations live in the workbench. This document is the conceptual reference.*
