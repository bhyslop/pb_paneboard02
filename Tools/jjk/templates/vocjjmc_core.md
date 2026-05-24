## Job Jockey Configuration

Job Jockey (JJ) is installed for managing project initiatives.

**Concepts:**
- **Heat**: Bounded initiative with coherent goals that are clear and present (3-50 officia). Status: `racing` (active execution) or `stabled` (paused for planning). Location: `current/` or `retired/` (done).
- **Pace**: Discrete action within a heat.
- **Itch**: Future work (any detail level), lives in jji_itch.md
- **Scar**: Closed work with lessons learned, lives in jjs_scar.md
- **Spook**: Team infrastructure stumble — any workflow failure improvable with deft attention. Capture as a pace when encountered, don't lose the current thread.

**Identities vs Display Names:**
- **Firemark**: Heat identity (`₣AA` or `AA`). Used in command params and JSON keys.
- **Coronet**: Pace identity (`₢AAAAk` or `AAAAk`). Used in command params and JSON keys.
- **Silks**: kebab-case display name. Human-readable only — NOT usable for lookups.

When a command takes a firemark or coronet, provide the identity, not the silks.

- Target repo dir: `.`
- JJ Kit path: `Tools/jjk/README.md`

**MCP Tool Usage:**

All JJK commands are accessed via the single `mcp__vvx__jjx` MCP tool with two parameters:
- `command`: string selecting the operation — always the canonical `jjx_*` name (e.g., `"jjx_show"`, `"jjx_enroll"`, `"jjx_record"`)
- `params`: JSON object with command-specific fields (see reference below)

**Verb names are NOT command names**: there is no `jjx_slate`, `jjx_mount`, `jjx_notch`, `jjx_groom` command. The verb table below maps horse vocabulary to actual MCP commands.
NEVER invent param fields — check the reference below first.

**Quick Verbs** — When user says just the verb, invoke the corresponding command:

| Verb | Noun | MCP command |
|------|------|-------------|
| muster | heats | `jjx_list` |
| parade | heat/pace | `jjx_show` |
| scout | heats | `jjx_search` |
| nominate | heat | `jjx_create` |
| mount | heat/pace | See Mount Protocol below |
| groom | heat | See Groom Protocol below |
| slate | pace | `jjx_enroll` |
| reslate | pace | `jjx_redocket` |
| notch | pace | See Commit Discipline below |
| wrap | pace | `jjx_close` |
| rail | heat | `jjx_reorder` |
| furlough | heat | `jjx_alter` |
| retire | heat | `jjx_archive` |
| restring | heat | `jjx_transfer` |

**MCP Command Reference:**

All params are JSON objects. `?` = optional, `[]` = array. Booleans default to false.

```
jjx_show           {target?, detail?, remaining?}
jjx_list           {status?}
jjx_orient         {firemark?}
jjx_create         {silks}
jjx_enroll         {firemark, silks, docket, before?, after?, first?}
jjx_reorder        {firemark, move?, before?, after?, first?, last?}
jjx_alter          {firemark, racing?, stabled?, silks?}
jjx_record         {identity, files[], size_limit?, intent?}
jjx_close          {coronet, summary?, size_limit?}
jjx_log            {firemark, limit?}
jjx_search         {pattern, actionable?}
jjx_archive        {firemark, execute?, size_limit?}
jjx_transfer       {firemark, to, coronets}
jjx_continue       {firemark}
jjx_paddock        {firemark, content?, note?}
jjx_relocate       {coronet, to, before?, after?, first?}
jjx_redocket  {coronet, docket}
jjx_relabel        {coronet, silks}
jjx_drop           {coronet}
jjx_brief      {coronet}
jjx_coronets   {firemark, remaining?, rough?}
jjx_landing        {coronet, agent, content?}
jjx_validate       {}
```

**Key points:**
- `jjx_show` takes firemark OR coronet in the `target` param
  - Heat overview: `{"target": "AF"}`
  - Single pace: `{"target": "AFAAb"}`
  - Additional params: `detail`, `remaining` only
- `jjx_orient` output includes next actionable pace — no separate show call needed
- `jjx_enroll` takes `docket` as a string param (not stdin)
- `jjx_close` takes `summary` as a string param (not stdin pipe)
- `jjx_record` takes `files` as a native JSON array: `["file1.rs", "file2.rs"]`
- `jjx_transfer` takes `coronets` as a JSON-encoded string (not a native array): `"[\"AYAAA\", \"AYAAB\"]"`

### Mount Protocol

When user says "mount" or you need to engage the next pace:

1. Run `jjx_orient` command (with optional firemark) to get context
2. Parse output: Racing-heats table, Heat/Paddock/Next/Docket/Recent-work sections
3. Display context to user: racing heats, heat silks, paddock summary, recent work, current pace and docket
4. **Name assessment**: If pace silks doesn't fit docket, offer rename via `jjx_relabel`
5. Analyze docket, propose approach (2-4 bullets), assess execution strategy:
   - Model tier: haiku (mechanical), sonnet (standard dev), opus (architectural)
   - Parallelization: file independence, task decomposability
   - State recommendation explicitly (e.g., "Sequential sonnet — single file")
6. Ask to proceed, then begin work

### Groom Protocol

When user says "groom":

1. Run `jjx_show` command with `{target: FIREMARK, detail: true, remaining: true}`
2. Display overview: heat silks, progress, remaining paces with dockets
3. Enter planning mode: suggest structural operations (slate new paces, rail to reorder, reslate to refine dockets, paddock review)

### Commit Discipline

When working on a heat, use `jjx_record` for commits with heat/pace affiliation.

**Pace-affiliated commit** (active pace provides context):
Use `jjx_record` with `{identity: "CORONET", files: ["file1", "file2"], intent: "description"}`

**Heat-affiliated commit** (no active pace, but part of heat work):
Use `jjx_record` with `{identity: "FIREMARK", files: ["file1", "file2"], intent: "description"}`

Synthesize intent from the conversation — describe *what* was accomplished, not *how*.

**Size guard**: If the commit fails due to size limits, report the failure to the user and ask how to proceed. Do not retry silently.

When user says "notch", determine context (pace or heat affiliated) and invoke `jjx_record` with the appropriate identity and explicit file list.

**Multi-Officium Discipline:**
Multiple Claude officia (concurrent git-activity streams, not sessions — see VOS `vost_officium`) may work concurrently in the same repo. The explicit file list in `jjx_record` enables orthogonal commits.

- Claude is **additive only** — make commits, never discard changes
- "Unexpected" uncommitted changes are likely another officium's work
- If something looks wrong, ASK — do not "fix" by discarding
- Commit only YOUR files; ignore everything else

**Forbidden Git Commands — NO exceptions, NO "safe" variants:**
- `git reset` — ALL forms: `--hard`, `--soft`, `--mixed`, with paths, without paths. Even `git reset HEAD <file>` (unstaging) is forbidden — it's too close to destructive variants and Claude will reason its way into worse forms.
- `git restore` — ALL forms: working tree, staged, with `--source`, without
- `git checkout <file>` — when used to discard changes (navigating branches is fine)
- `git clean` — ALL forms
- `git stash` — ALL forms

**What to do instead:**
- Staging wrong? Run `jjx_record` with the correct file list — it handles staging
- Made a mistake? Make a new commit that fixes it — additive, not destructive
- Confused by repo state? ASK the user — another officium may be mid-work
- Need to undo something? Explain the situation to the user and let them decide

**Build & Run Discipline:**
Always run these after Rust code changes:
- `tt/vow-b.Build.sh` — Build
- `tt/vvw-r.RunVVX.sh` — Run VVX

**JJX Commands Are Self-Committing:**
`jjx_enroll`, `jjx_close`, `jjx_record`, and other state-mutating jjx commands create git commits internally. **`jjx_close` (wrap) commits ALL uncommitted changes** — code files and gallops state together in one commit. Do NOT follow `jjx_record` or `jjx_close` with another commit command — the tree will already be clean. If a commit command says "Nothing to commit", check `git status --short` and accept the result.

**Diagnose Before Escalating:**
When a command fails, check the simplest explanation first. "Nothing to commit" means the tree is clean — verify with `git status`, don't try creative workarounds. "Invalid params" means wrong field names — check the MCP Command Reference above, don't guess. One diagnostic command beats three speculative retries.

### Wrap Discipline

**NEVER auto-wrap a pace.** Always ask the user explicitly: "Ready to wrap ₢XXXXX?" and wait for confirmation before running `jjx_close`. The user decides when work is complete, not the agent.

When work is complete, report outcomes and ask. Do not wrap.

When wrapping (after user confirms), always include a summary of the work:
Use `jjx_close` with `{coronet: "CORONET", summary: "Added bitmap displays to orient output"}`
The agent always has context about what was accomplished — include it.

**Wrap commits everything.** `jjx_close` stages and commits all dirty files (code edits + gallops state) in one commit. Do NOT notch before or after wrapping — the wrap IS the final commit. If you want separate commits for intermediate code milestones, notch during work; remaining uncommitted changes are captured by wrap.
