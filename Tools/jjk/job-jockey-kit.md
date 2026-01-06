# Job Jockey Kit

## What is Job Jockey?

Job Jockey (JJ) is a lightweight system for managing project initiatives through conversation with Claude Code. It helps you track bounded heats, remember what's next, and keep a backlog of ideas without drowning in ceremony or context bloat.

Think of it as a project notebook specifically designed for human-AI collaboration:
- **Heats** are your current work (3-50 chat sessions worth)
- **Paces** track what's done and what's next within a heat
- **Itches** capture future ideas without losing focus

The system is ephemeral by design: documents have clear lifecycles, completed work gets archived, and context stays lean. Everything is markdown, lives in git, and can move between computers with you.

This document (the Job Jockey Kit) is the complete reference and installer for the system.

## Installation Variables

During installation, Claude replaces these markers in the generated command files:

- `«JJC_TARGET_REPO_DIR»` → Where actual work happens (relative to CLAUDE.md launch directory)
  - `.` = direct mode (JJ and work in same repo)
  - `../path` = relative path (portable across machines with matching layout)
  - `/absolute/path` = absolute path (machine-specific)
- `«JJC_KIT_PATH»` → Path to this Kit file, supports relative paths for portability
  - Example: `Tools/jjk/job-jockey-kit.md` (in same repo)
  - Example: `../shared-tools/jjk/job-jockey-kit.md` (sibling directory)

JJ files always live at `.claude/jji/` relative to CLAUDE.md - this is not configurable.

These markers appear throughout this document in templates and will be hardcoded with actual values during installation. You never need to type the guillemets (« ») yourself.

## Core Concepts

### Heat
A bounded initiative spanning 3-50 chat sessions. Has a clear goal, context section, and list of paces. Lives as a dated file like `jjh-b251108-buk-portability.md`.

Heat location indicates state:
- `current/` — actively working
- `pending/` — detailed but parked (blocked or deferred)
- `retired/` — completed (retire date added to filename: `jjh-b251108-r251126-buk-portability.md`)

Move to `current/` via prose when ready to work. Park in `pending/` via prose when blocked or deferring.

### Pace
A discrete action within the current heat. Appears as checklist items in heat documents. Pending paces can have detailed descriptions. Completed paces get condensed to brief summaries to save context.

Each pace has a **mode**:
- **Manual**: Human drives, model assists. Minimal spec needed.
- **Delegated**: Model drives from spec, human monitors. Requires clear objective, bounded scope, success criteria, and failure behavior.

Paces default to `manual` when created. Use `/jja-pace-refine` to prepare a pace for delegation or to clarify a manual pace.

### Itch
A potential future heat or consideration. The spark/urge that might become a heat someday. Lives in either Future (worthy of doing) or Shelved (respectfully set aside for now).

## How It Works

### Day-to-Day Usage

You work on a heat by talking with Claude Code. As you make progress:
- Claude uses `/jja-heat-next` to show current heat and next pace(s), asking for clarification if needed
- You work on the pace together
- Claude uses `/jja-pace-wrap` to summarize and mark it complete
- New paces emerge and get added with `/jja-pace-add`

When new ideas come up that don't belong in current heat, Claude uses `/jja-itch-find` and `/jja-itch-move` to file them away in Future or Shelved.

When a heat completes, Claude uses `/jja-heat-retire` to move it to `retired/` with a datestamp and start a new one.

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
- Future/Shelved itches stay out of context unless needed
- Full history preserved in git, not in active documents

### Announcing JJ Availability

When appropriate (session start, heat selection, user mentions next paces), Claude announces:
- The current heat being worked on
- "See /jja- commands for Job Jockey services"

This reminds the user of available tooling without being intrusive.

## File Structure

All Job Jockey documents use the `jj` prefix with category-specific third letters:

### `jjh-bYYMMDD-description.md` and `jjh-bYYMMDD-rYYMMDD-description.md` (Job Jockey Heat)
Main context document for a heat.
- **Active**: Named with begin date and description (e.g., `jjh-b251108-buk-portability.md`)
- **Retired**: Begin date preserved, retire date added (e.g., `jjh-b251108-r251126-buk-portability.md`)
- Located in: `.claude/jji/current/` (active), `.claude/jji/pending/` (parked), or `.claude/jji/retired/` (completed)
- Contains context section and paces

### `jjf-future.md` (Job Jockey Future)
Itches for worthy future heats.
- Items graduate from here to new `jjh-` files
- Located in: `.claude/jji/`

### `jjs-shelved.md` (Job Jockey Shelved)
Itches respectfully set aside.
- Not rejected, but deferred for foreseeable future
- May include brief context on why shelved
- Located in: `.claude/jji/`

### `job-jockey-kit.md` (this document)
The complete reference and installer. Defines structure, naming, and conventions.
- Used during installation
- Referenced by `/jja-doctor` for validation
- Location tracked in CLAUDE.md configuration

## Directory Structure

JJ files always live at `.claude/jji/` relative to CLAUDE.md. Commands live at `.claude/commands/`.

### Direct Mode (target = `.`)

JJ state and work in the same repo:

```
my-project/                 # Launch Claude Code here
  CLAUDE.md
  .claude/
    commands/
      jja-heat-next.md
      jja-heat-retire.md
      jja-pace-find.md
      jja-pace-left.md
      jja-pace-add.md
      jja-pace-refine.md
      jja-pace-delegate.md
      jja-pace-wrap.md
      jja-sync.md
      jja-itch-list.md
      jja-itch-find.md
      jja-itch-move.md
      jja-doctor.md
    jji/
      jjf-future.md
      jjs-shelved.md
      current/
        jjh-b251108-feature-x.md
      pending/
        jjh-b251101-blocked-work.md
      retired/
        jjh-b251001-r251015-feature-y.md
  src/                      # Work happens here too
  ...
```

### Separate Mode (target ≠ `.`)

JJ state in one repo, work in another (portable with relative paths):

```
project-admin/              # Launch Claude Code here
  CLAUDE.md
  .claude/
    commands/jja-*.md
    jji/
      jjf-future.md
      jjs-shelved.md
      current/
        jjh-b251108-feature-x.md
      pending/
        jjh-b251101-blocked-work.md
      retired/
  Tools/jjk/
    job-jockey-kit.md

../my-project/              # Target repo (work happens here)
  src/
  tests/
  ...
```

Config in CLAUDE.md: `Target repo dir: ../my-project`

## Workflows

### Starting a New Heat
1. Create `jjh-bYYMMDD-description.md` in `.claude/jji/current/` (use today's date)
2. Include Context section with stable background information
3. Include Paces section with initial checklist items
4. Archive previous heat to `retired/` (if applicable)

### Selecting Current Heat
When starting a session or the user calls `/jja-heat-next`, Claude checks `.claude/jji/current/`:
- **0 heats**: No active work. If pending heats exist, mention them ("You have N pending heats"). Ask if user wants to start a new heat, activate a pending heat, or promote an itch.
- **1 heat**: Show heat and next pace(s), ask for clarification if next pace is unclear
- **2+ heats**: Ask user which heat to work on, then show that heat with next pace(s)

### Working on a Heat
1. Use `/jja-heat-next` to see current heat and next pace(s)
2. Work on it conversationally with Claude
3. Use `/jja-pace-wrap` when complete (Claude summarizes)
4. Use `/jja-heat-next` again to see what's next
5. Repeat until heat is complete

### Completing a Heat
1. Verify all paces are complete or explicitly discarded
2. Use `/jja-heat-retire` to move and rename heat file:
   - Adds retire date (`rYYMMDD`) to filename, preserving begin date
   - Moves from `current/jjh-bYYMMDD-description.md` → `retired/jjh-bYYMMDD-rYYMMDD-description.md`
   - Commits the archival

### Itch Triage
When a new itch emerges:
1. **Does it block current heat completion?** → Add as pace to current heat
2. **Is it worthy but not now?** → Add to `jjf-future.md`
3. **Interesting but setting aside?** → Add to `jjs-shelved.md`

Use `/jja-itch-find` to search for similar itches before adding.
Use `/jja-itch-move` to promote, demote, or shelve itches.

## Format Conventions

- **All documents**: Markdown (`.md`)
- **Paces**: Checklist format with `- [ ]` and `- [x]`
- **Dates**: YYMMDD format (e.g., 251108 for 2025-11-08)
  - `b` prefix = begin date (when heat started)
  - `r` prefix = retire date (when heat completed)
- **Descriptions**: Lowercase with hyphens (e.g., `buk-portability`)
- **Pace titles**: Bold (e.g., `**Audit BUK portability**`)
- **Completed summaries**: Brief, factual (e.g., `Found 12 issues, documented in notes.md`)

## Design Principles

1. **Ephemeral by design**: Documents have clear lifecycles, completed work gets archived
2. **Conversational**: Claude proposes, you approve or amend, Claude executes
3. **Context-conscious**: Minimize active context, maximize git history
4. **Model-primary**: Claude reads/writes frequently, human adjusts occasionally
5. **Clear naming**: Prefixes make purpose immediately obvious
6. **Git-friendly**: Preserve history, commit after approval (one commit per action)
7. **Minimal ceremony**: Easy to use, hard to misuse
8. **Respectful**: Itches are "shelved" not "rejected"
9. **Portable**: Works across computers via relative paths
10. **Do No Harm**: If paths are misconfigured or files missing, announce issue and stop - don't guess or auto-fix

## Actions

Job Jockey Actions (JJA) are Claude Code commands for managing the system.

### Heat Actions

#### `/jja-heat-next`
Show the current heat and its next pace(s), with optional clarification prompts.

**Behavior**:
- Checks `.claude/jji/current/` for active heats
- **0 heats**: Announces no active work, asks if user wants to start a heat or promote an itch
- **1 heat**: Displays:
  - Heat name and brief gesture/summary
  - Next incomplete pace with description
  - If multiple next paces or unclear priority: asks for clarification ("Which pace should we focus on next?")
- **2+ heats**: Asks user which heat to work on, then displays that heat with next pace(s)

**Example output**:
```
Current heat: **BUK Utility Rename**
Next pace: Update buc_command.sh internal functions
  Rename zbcu_* functions to zbuc_*
  (11 internal functions total)

Ready to start?
```

#### `/jja-heat-retire`
Move completed heat to retired directory with retire date added to filename.

**Behavior**:
- Verifies current heat exists in `.claude/jji/current/`
- Checks that all paces are marked complete (or explicitly discarded)
- Adds retire date to filename: `jjh-bYYMMDD-description.md` → `jjh-bYYMMDD-rYYMMDD-description.md`
- Moves file to `.claude/jji/retired/`
- Commits the move (JJ state repo only, no push)

**Example**:
- Before: `.claude/jji/current/jjh-b251108-buk-rename.md`
- After: `.claude/jji/retired/jjh-b251108-r251126-buk-rename.md`

#### `/jja-sync`
Commit and push JJ state and target repo work. The only command that pushes.

**Behavior**:
- Commits any uncommitted JJ state changes in this repo
- Pushes this repo
- If target ≠ `.`:
  - Changes to target repo directory
  - Commits any uncommitted work
  - Pushes target repo
- Reports status of both operations
- Warns if JJ files cannot be synced (e.g., gitignored)

**Note**: User is responsible for being on the correct branch in target repo. JJ does not manage branches.

**Example output**:
```
JJ state: committed and pushed (3 files)
Target repo: committed and pushed (12 files)
```

Or if issues:
```
JJ state: committed and pushed
Target repo: WARNING - .claude/jji/ appears to be gitignored, JJ state not tracked
```

### Itch Actions

#### `/jja-itch-list`
Show all itches from both `jjf-future.md` and `jjs-shelved.md`.

**Output format**:
```
Future itches (3):
1. Add dark mode support
2. Refactor authentication module
3. Performance optimization for large datasets

Shelved itches (2):
1. Legacy API migration (blocked on vendor)
2. Mobile app prototype (deferred to Q2)
```

#### `/jja-itch-find`
Find an itch by keyword or fuzzy match across both `jjf-future.md` and `jjs-shelved.md`.

**Usage**: User provides search term, Claude searches both files and reports matches with context.

#### `/jja-itch-move`
Move an itch between future, shelved, or promote to a new heat.

**Usage**: After locating an itch, move it to:
- `jjf-future.md` (worthy of doing)
- `jjs-shelved.md` (setting aside)
- New `jjh-*.md` file (promoting to heat, initial pace from itch)

### Pace Actions

#### `/jja-pace-find`
Show the next incomplete pace from the current heat.

**Behavior**: Displays the title, mode, and description of the first unchecked pace.

#### `/jja-pace-left`
Show terse list of all remaining paces in the current heat, with mode.

**Output format**:
```
Remaining paces (3):
1. [manual] Audit BUK portability
2. [manual] Create test harness
3. [delegated] Document migration guide
```

#### `/jja-pace-add`
Add a new pace to the current heat with intelligent positioning.

**Behavior**:
- Claude analyzes the heat context and existing paces
- Proposes a new pace with title, optional description, and position
- New paces default to `mode: manual`
- Explains reasoning for the placement
- Waits for user approval or amendment before updating file
- Does NOT commit (preparatory work, accumulates until /jja-pace-wrap or /jja-sync)

**Example**:
```
I propose adding pace '**Test BCU fixes**' after 'Audit BUK portability'
because we'll need to validate each fix before moving to BDU.
Should I add it there?
```

#### `/jja-pace-wrap`
Mark a pace as complete with automatic summarization.

**Behavior**:
- Claude summarizes the pace based on current chat context
- Updates the heat file, moving pace to Completed section with summary
- Commits the change (JJ state repo only, no push)
- Reports what was written
- User can approve or request amendments

**Example output**:
```
Updated pace 'Audit BUK portability' →
'Found 12 issues: 8 in BCU, 3 in BDU, 1 in BTU. Documented in portability-notes.md'
Committed to JJ state.
```

#### `/jja-pace-refine`
Refine a pace's specification through adaptive interview. Can set or change pace mode.

**Behavior**:
- Reads current pace spec (may be sparse or already detailed)
- Conducts adaptive interview based on current state:
  - If sparse: builds spec from scratch
  - If exists: asks "what needs to change?" and focuses on delta
- Interview determines mode (`manual` or `delegated`)
- For `delegated` mode, ensures spec includes:
  - Clear objective
  - Bounded scope
  - Success criteria
  - Failure behavior
  - Model hint (haiku-ok / needs-sonnet / needs-opus)
- Final check for `delegated`: reads spec as fresh model would, verifies clarity
- Updates pace in heat file with refined spec
- Can be run multiple times (iterative refinement)

**Final clarity check** (for delegated paces):
```
Reading this spec as a model with no prior context:
- Objective: ✓ clear / ✗ ambiguous because...
- Scope: ✓ bounded / ✗ unclear because...
- Success: ✓ measurable / ✗ vague because...
- Stuck: ✓ know when to stop / ✗ might spin because...
```

If any check fails, interview continues until spec passes.

#### `/jja-pace-delegate`
Execute a delegated pace. Validates health before proceeding.

**Behavior**:
- Verifies pace mode is `delegated`
- Verifies spec passes health checks (objective, scope, success, failure defined)
- If unhealthy: refuses with specific guidance ("Run /jja-pace-refine first")
- If healthy: presents pace spec to model for execution
- Model executes from spec alone (no refinement context)
- On completion or failure: reports outcome

**Refusal cases**:
- Pace is `manual`: "This pace is manual - work on it conversationally"
- Pace is `delegated` but unhealthy: "This pace needs refinement - [specific gap]"

### Heat Document Structure

Heat files (`jjh-bYYMMDD-description.md` when active, `jjh-bYYMMDD-rYYMMDD-description.md` when retired) contain two main sections:

#### Context Section
Stable information about the heat that only changes when explicitly updated by the user. Contains:
- Goals and objectives
- Key constraints
- Important decisions
- Background information
- Links to related resources

This section provides Claude with consistent context across sessions without needing to reread the entire chat history.

**Note**: Concrete examples of heat files will be added as the system is used and patterns emerge.

#### Paces Section
Divided into Pending and Completed subsections.

**Pending paces format**:
```markdown
### Pending
- [ ] **Pace title in bold**
  Optional description with as much detail as needed.
  Can span multiple lines for complex paces.
  May include links, code snippets, or detailed requirements.
```

**Completed paces format**:
```markdown
### Completed
- [x] **Pace title** - Concise summary of what was accomplished
- [x] **Another pace** - Brief factual outcome
```

Completed paces are kept brief to minimize context usage. Full history is preserved in git.

## Installation

### Prerequisites
- A git repository with a `CLAUDE.md` file
- Claude Code access to the repository

### Bootstrap Process

1. **Place this file** in a location accessible to your CLAUDE.md
   - Can be in the same repo as CLAUDE.md (e.g., `Tools/jjk/job-jockey-kit.md`)
   - Can be in a separate admin/documentation repo

2. **Run the installation conversation** with Claude Code:
   - Open the repository containing CLAUDE.md
   - Say: "Read job-jockey-kit.md and let's install Job Jockey"
   - Claude will ask configuration questions

3. **Configuration questions**:
   - **Target repo dir**: Where does actual work happen, relative to this directory?
     - `.` = direct mode (work happens here, JJ lives with the code)
     - `../path` = relative path (portable across machines with matching layout)
     - `/absolute/path` = absolute path (machine-specific)
   - **Kit path**: Claude will use the path where it found this file (supports relative paths for portability)

4. **Claude will then** (idempotent - safe to run multiple times):
   - Delete any existing `jja-*.md` command files from `.claude/commands/`
   - Generate all command files in `.claude/commands/jja-*.md` with hardcoded paths
     - All `«JJC_TARGET_REPO_DIR»`, `«JJC_KIT_PATH»` variables are replaced with actual values
     - JJ files path is always `.claude/jji/` (hardcoded, not configurable)
     - Git commands include target repo navigation when target ≠ `.`
     - Commit messages are fully specified per action
     - No runtime variable parsing required
   - Replace (not append) the `## Job Jockey Configuration` section in CLAUDE.md
   - Initialize JJ file structure at `.claude/jji/`:
     - Create `jjf-future.md` (if not exists, preserve if exists)
     - Create `jjs-shelved.md` (if not exists, preserve if exists)
     - Create `current/` directory (if not exists)
     - Create `pending/` directory (if not exists)
     - Create `retired/` directory (if not exists)
   - Note any existing heat files found
   - Commit the changes

5. **Installation completes**. CLAUDE.md will contain:
```markdown
## Job Jockey Configuration

Job Jockey (JJ) is installed for managing project initiatives.

**Concepts:**
- **Heat**: Bounded initiative (3-50 sessions), has paces. Location indicates state: `current/` (active), `pending/` (parked), `retired/` (done). Move to `current/` via prose when ready to work. Park in `pending/` via prose when blocked or deferring.
- **Pace**: Discrete action within a heat; mode is `manual` (human drives) or `delegated` (model drives from spec)
- **Itch**: Future idea, lives in Future or Shelved

- Target repo dir: `../my-project`
- JJ Kit path: `Tools/jjk/job-jockey-kit.md`

**Available commands:**
- `/jja-heat-next` - Show current heat and next pace(s)
- `/jja-heat-retire` - Move completed heat to retired with datestamp
- `/jja-pace-find` - Show next incomplete pace (with mode)
- `/jja-pace-left` - List all remaining paces (with mode)
- `/jja-pace-add` - Add a new pace (defaults to manual)
- `/jja-pace-refine` - Refine pace spec, set mode (manual or delegated)
- `/jja-pace-delegate` - Execute a delegated pace
- `/jja-pace-wrap` - Mark pace complete
- `/jja-sync` - Commit and push JJ state and target repo
- `/jja-itch-list` - List all itches (future and shelved)
- `/jja-itch-find` - Find an itch by keyword
- `/jja-itch-move` - Move or promote an itch
- `/jja-doctor` - Validate Job Jockey setup

**Important**: New commands are not available in this installation session. You must restart Claude Code before the new commands become available.
```

### Validation

After installation completes and you restart your Claude Code session, you can use `/jja-doctor` to verify:
- Kit file exists at configured path
- JJ files directory exists at `.claude/jji/`
- Expected files are present (jjf-future.md, jjs-shelved.md, current/, pending/, retired/)
- Target repo exists and is accessible
- If target ≠ `.`, target repo is a valid git repository
- JJ files are not gitignored (warns if sync would fail)
- All heat and pace commands exist and reference correct paths

**Important**: Do not attempt to run `/jja-doctor` in the same chat session where installation occurred. The commands are not available until you restart Claude Code, as they are only loaded when the session initializes.

## CLAUDE.md Integration

After installation, update CLAUDE.md to reference JJ for session context:

```markdown
## Session Context
- Check active heats in .claude/jji/current/ when starting relevant work
- Announce heat selection and mention /jja- commands
- Use /jja-pace-find to see next pace
- Use /jja-pace-left for overview of remaining work
- Use /jja-sync to commit and push both JJ state and target repo work

**Note**: Restart Claude Code session after installation for new commands to become available.
```

## Technical Implementation Notes

### Command Files
All JJA commands are markdown files in `.claude/commands/` that instruct Claude what to do.

**During installation**, the kit is used as a template to generate commands with:
- All `«JJC_TARGET_REPO_DIR»` markers replaced with the configured target repo path
- All `«JJC_KIT_PATH»` references replaced with actual path to this kit
- JJ files path hardcoded to `.claude/jji/` (not configurable)
- Commit message patterns hardcoded per action (prefix: "JJA:")
- Git-aware commands: `/jja-pace-wrap`, `/jja-heat-retire`, `/jja-sync`
- Non-git commands: all others (changes accumulate until next git-aware command)

**Result**: Commands are fully baked and ready to execute without any runtime interpretation. This keeps chat context focused on work, not system management.

### Git Behavior

**Git-aware commands:**
| Command | This repo (JJ state) | Target repo (work) |
|---------|---------------------|-------------------|
| `/jja-pace-wrap` | commit | — |
| `/jja-heat-retire` | commit | — |
| `/jja-sync` | commit + push | commit + push |

**Git behavior by target repo setting:**

When target = `.` (direct mode, JJ and work in same repo):
```bash
# /jja-pace-wrap
git add .claude/jji/current/jjh-b251108-buk-portability.md
git commit -m "JJA: pace-wrap - Completed audit of BUK portability"

# /jja-sync
git add -A
git commit -m "JJA: sync" --allow-empty
git push
```

When target ≠ `.` (separate mode, JJ here, work elsewhere):
```bash
# /jja-pace-wrap (commits JJ state only)
git add .claude/jji/current/jjh-b251108-buk-portability.md
git commit -m "JJA: pace-wrap - Completed audit of BUK portability"

# /jja-sync (commits and pushes both repos)
# First, this repo (JJ state)
git add -A
git commit -m "JJA: sync" --allow-empty
git push

# Then, target repo (work)
cd «JJC_TARGET_REPO_DIR»
git add -A
git commit -m "JJA: sync" --allow-empty
git push
cd - > /dev/null
```

Each action specifies its own commit message pattern.

### Command Templates

The following templates are used during installation. Variables (`«JJC_*»`) are replaced with configured values.

#### `/jja-heat-next` Template

```markdown
You are showing the current Job Jockey heat and its next pace(s).

Configuration:
- Target repo dir: «JJC_TARGET_REPO_DIR»
- Kit path: «JJC_KIT_PATH»

Steps:

1. Check for heat files in .claude/jji/current/
   - Look for files matching pattern `jjh-b*.md`

2. Branch based on heat count:

   **If 0 heats:**
   - Check .claude/jji/pending/ for pending heats
   - Announce: "No active heat found in .claude/jji/current/"
   - If pending heats exist: "You have N pending heat(s): [list names]"
   - Ask: "Would you like to start a new heat, activate a pending heat, or promote an itch from jjf-future.md?"
   - Stop and wait for user direction

   **If 1 heat:**
   - Read the heat file
   - Display:
     - Heat name (from filename, e.g., "buk-portability" from jjh-b251108-buk-portability.md)
     - Brief summary from Context section (first sentence or goal)
     - Next incomplete pace (first `- [ ]` item) with its description
   - If multiple unchecked paces exist and priority is unclear:
     - Ask: "Which pace should we focus on next?"
   - Otherwise: Ask "Ready to start?" or similar

   **If 2+ heats:**
   - List all heats by name with brief summary
   - Ask: "Which heat would you like to work on?"
   - Wait for selection, then display that heat as in "1 heat" case

3. Example output format:
   ```
   Current heat: **BUK Utility Rename**
   Goal: Rename BCU/BDU/BTU/BVU utilities to use consistent buc/bdu/btu/bvu prefixes

   Next pace: **Update bcu_command.sh internal functions**
     Rename zbcu_* functions to zbuc_*
     (11 internal functions total)

   Ready to start?
   ```

Error handling: If .claude/jji/current/ doesn't exist, announce issue and stop.
```

#### `/jja-heat-retire` Template

```markdown
You are retiring a completed Job Jockey heat.

Configuration:
- Target repo dir: «JJC_TARGET_REPO_DIR»
- Kit path: «JJC_KIT_PATH»

Steps:

1. Check for heat files in .claude/jji/current/
   - If 0 heats: announce "No active heat to retire" and stop
   - If 2+ heats: ask which one to retire

2. Read the heat file and verify completion:
   - Check for any incomplete paces (`- [ ]` items)
   - If incomplete paces exist:
     - List them
     - Ask: "These paces are incomplete. Mark them as discarded, or continue working?"
     - If user wants to discard: mark them with `- [~]` prefix and note "(discarded)"
     - If user wants to continue: stop retirement process

3. Determine filenames:
   - Current filename pattern: `jjh-bYYMMDD-description.md`
   - Extract the begin date (bYYMMDD) and description
   - Generate retire date: today's date as rYYMMDD
   - New filename: `jjh-bYYMMDD-rYYMMDD-description.md`

   Example:
   - Before: `jjh-b251108-buk-rename.md`
   - After: `jjh-b251108-r251127-buk-rename.md`

4. Move the file:
   ```bash
   git mv .claude/jji/current/jjh-b251108-buk-rename.md .claude/jji/retired/jjh-b251108-r251127-buk-rename.md
   ```

5. Commit the retirement (JJ state repo only, no push):
   ```bash
   git commit -m "JJA: heat-retire - [heat description]"
   ```

6. Report completion:
   ```
   Retired heat: **BUK Rename**
   - Began: 2025-11-08
   - Retired: 2025-11-27
   - File: .claude/jji/retired/jjh-b251108-r251127-buk-rename.md
   ```

7. Offer next steps:
   - "Would you like to start a new heat or check jjf-future.md for itches to promote?"

Error handling: If paths wrong or files missing, announce issue and stop.
```

#### `/jja-doctor` Template

```markdown
You are validating the Job Jockey installation.

Configuration:
- Target repo dir: «JJC_TARGET_REPO_DIR»
- Kit path: «JJC_KIT_PATH»

Steps:

1. Check kit file:
   - Verify «JJC_KIT_PATH» exists and is readable
   - Report: ✓ Kit file exists / ✗ Kit file not found at [path]

2. Check JJ directory structure:
   - Verify .claude/jji/ exists
   - Verify .claude/jji/current/ exists
   - Verify .claude/jji/pending/ exists
   - Verify .claude/jji/retired/ exists
   - Report status of each

3. Check JJ content files:
   - Verify .claude/jji/jjf-future.md exists
   - Verify .claude/jji/jjs-shelved.md exists
   - Report: ✓ exists / ✗ missing for each

4. Check target repo (if target ≠ `.`):
   - Verify «JJC_TARGET_REPO_DIR» exists
   - Verify it's a git repository (has .git/)
   - Report: ✓ Target repo accessible / ✗ Target repo issue: [details]

5. Check git tracking:
   - Run: git check-ignore .claude/jji/
   - If ignored: ⚠ WARNING: JJ state is gitignored - /jja-sync will not track changes
   - If not ignored: ✓ JJ state is tracked by git

6. Check command files:
   - Verify these files exist in .claude/commands/:
     - jja-heat-next.md
     - jja-heat-retire.md
     - jja-pace-find.md
     - jja-pace-left.md
     - jja-pace-add.md
     - jja-pace-refine.md
     - jja-pace-delegate.md
     - jja-pace-wrap.md
     - jja-sync.md
     - jja-itch-list.md
     - jja-itch-find.md
     - jja-itch-move.md
     - jja-doctor.md
   - Report: ✓ All 13 commands present / ✗ Missing: [list]

7. Check heats:
   - List any files in .claude/jji/current/
   - List any files in .claude/jji/pending/
   - Report counts and names

8. Summary:
   ```
   Job Jockey Health Check
   =======================
   Kit:        ✓ Found at Tools/jjk/job-jockey-kit.md
   Structure:  ✓ All directories present
   Files:      ✓ jjf-future.md, jjs-shelved.md present
   Target:     ✓ ../my-project accessible (separate mode)
   Git:        ✓ JJ state tracked
   Commands:   ✓ All 13 commands installed

   Active heats: 1
   - jjh-b251108-buk-portability.md

   Pending heats: 1
   - jjh-b251101-blocked-work.md

   Status: HEALTHY
   ```

   Or if issues:
   ```
   Status: NEEDS ATTENTION
   - Missing command: jja-pace-wrap.md
   - Target repo not accessible
   ```

Error handling: Report all issues found, don't stop at first error.
```

#### `/jja-pace-refine` Template

```markdown
You are helping refine a pace's specification in the current Job Jockey heat.

Configuration:
- Target repo dir: «JJC_TARGET_REPO_DIR»
- Kit path: «JJC_KIT_PATH»

Steps:

1. Check for current heat in .claude/jji/current/
   - If no heat: announce "No active heat" and stop
   - If multiple: ask which one

2. Ask which pace to refine (or infer from context)

3. Read the current pace spec and assess its state:
   - Is mode defined? (manual/delegated/unset)
   - Is spec sparse or detailed?

4. Conduct adaptive interview:

   If spec is sparse/new:
   - "Is this a manual pace (you drive) or should we prepare it for delegation (model drives)?"
   - If manual: confirm and done
   - If delegated: continue to step 5

   If spec exists:
   - Show current spec summary
   - "What needs to change?"
   - Focus on the delta

5. For delegated mode, ensure spec covers:
   - Objective: What specifically to achieve?
   - Scope: What files/systems to touch or avoid?
   - Success: How do we know it's done?
   - Failure: What to do if stuck? (stop/report/retry)
   - Model hint: haiku-ok / needs-sonnet / needs-opus

   Ask only for missing elements.

6. Final clarity check (delegated only):
   Read the spec as if you have no prior context. Assess:
   - Objective: clear or ambiguous?
   - Scope: bounded or unclear?
   - Success: measurable or vague?
   - Stuck: know when to stop or might spin?

   If any check fails, explain why and ask clarifying question.
   Loop until all checks pass.

7. Update the pace in the heat file with refined spec

8. Do NOT commit (preparatory work, accumulates until /jja-pace-wrap or /jja-sync)

9. Report what was updated

Error handling: If paths wrong or files missing, announce issue and stop.
```

#### `/jja-pace-delegate` Template

```markdown
You are executing a delegated pace from the current Job Jockey heat.

Configuration:
- Target repo dir: «JJC_TARGET_REPO_DIR»
- Kit path: «JJC_KIT_PATH»

Steps:

1. Check for current heat in .claude/jji/current/
   - If no heat: announce "No active heat" and stop

2. Identify the pace to delegate (from context or ask)

3. Validate the pace:
   - Is mode `delegated`?
     - If `manual`: refuse with "This pace is manual - work on it conversationally"
     - If unset: refuse with "Run /jja-pace-refine first to set mode"
   - Is spec healthy? Check for:
     - Objective defined
     - Scope bounded
     - Success criteria clear
     - Failure behavior specified
   - If unhealthy: refuse with "This pace needs refinement - [specific gap]"

4. If valid, present the pace spec clearly:
   ```
   Executing delegated pace: **[title]**

   Objective: [objective]
   Scope: [scope]
   Success: [criteria]
   On failure: [behavior]
   ```

5. Execute the pace based solely on the spec
   - If target repo ≠ `.`, work in target repo directory: «JJC_TARGET_REPO_DIR»
   - Work from the spec, not from refinement conversation context
   - Stay within defined scope
   - Stop when success criteria met OR failure condition hit

6. Report outcome:
   - Success: what was accomplished, evidence of success criteria
   - Failure: what was attempted, why stopped, what's needed

7. Do NOT auto-complete the pace. User decides via /jja-pace-wrap
   Work in target repo is NOT auto-committed. User can review and use /jja-sync.

Error handling: If paths wrong or files missing, announce issue and stop.
```

### Example Command Structure (Before Installation)

Template in this kit with variables:

```markdown
You are helping mark a pace complete in the current Job Jockey heat.

Configuration:
- Target repo dir: «JJC_TARGET_REPO_DIR»
- Kit path: «JJC_KIT_PATH»

Steps:
1. Ask which pace to mark done (or infer from context)
2. Summarize the pace completion based on chat context
3. Show proposed summary and ask for approval
4. Update the heat file in .claude/jji/current/
   - Move pace from Pending to Completed
   - Replace description with brief summary
5. Commit JJ state: "JJA: pace-wrap - [brief description]"
6. Report what was done
```

### Example Command Structure (After Installation)

Generated `.claude/commands/jja-pace-wrap.md` with hardcoded values:

```markdown
You are helping mark a pace complete in the current Job Jockey heat.

Configuration:
- Target repo dir: ../my-project
- Kit path: Tools/jjk/job-jockey-kit.md

Steps:
1. Ask which pace to mark done (or infer from context)
2. Summarize the pace completion based on chat context
3. Show proposed summary and ask for approval
4. Update the heat file in .claude/jji/current/
   - Move pace from Pending to Completed
   - Replace description with brief summary
5. Commit JJ state (this repo only, no push):
   git add .claude/jji/current/jjh-*.md
   git commit -m "JJA: pace-wrap - [brief description]"
6. Report what was done

Error handling: If files missing or paths wrong, announce issue and stop.
```

#### `/jja-sync` Template

```markdown
You are synchronizing JJ state and target repo work.

Configuration:
- Target repo dir: «JJC_TARGET_REPO_DIR»
- Kit path: «JJC_KIT_PATH»

Steps:

1. Check if .claude/jji/ is gitignored
   - If yes: warn "JJ state is gitignored - cannot sync" and stop

2. Commit and push JJ state (this repo):
   git add -A .claude/jji/
   git commit -m "JJA: sync" --allow-empty
   git push
   Report: "JJ state: committed and pushed"

3. If target repo = `.`:
   - JJ state and work are same repo, already handled
   - Report: "Target repo: same as JJ state (direct mode)"

4. If target repo ≠ `.`:
   cd «JJC_TARGET_REPO_DIR»
   git add -A
   git commit -m "JJA: sync" --allow-empty
   git push
   cd - > /dev/null
   Report: "Target repo: committed and pushed"

5. If any git operation fails, report the specific failure

Error handling: If paths wrong or repos inaccessible, announce issue and stop.
```

**Important**: After installation completes, restart your Claude Code session for the new commands to become available.

## Future Enhancements

- Automated prompts for itch triage
- Cross-heat learning/pattern extraction
- Template generation for new heats
- Integration with project-specific workflows
- Enhanced heat metadata (estimated duration, tags, dependencies)

---

*This is a living document. Refine as the system evolves.*
