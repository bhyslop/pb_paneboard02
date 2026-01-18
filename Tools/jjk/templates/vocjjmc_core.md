## Job Jockey Configuration

Job Jockey (JJ) is installed for managing project initiatives.

**Concepts:**
- **Heat**: Bounded initiative with coherent goals that are clear and present (3-50 sessions). Location: `current/` (active) or `retired/` (done).
- **Pace**: Discrete action within a heat; can be bridled for autonomous execution via `/jjc-pace-bridle`
- **Itch**: Future work (any detail level), lives in jji_itch.md
- **Scar**: Closed work with lessons learned, lives in jjs_scar.md

**Identities vs Display Names:**
- **Firemark**: Heat identity (`₣AA` or `AA`). Used in CLI args and JSON keys.
- **Coronet**: Pace identity (`₢AAAAk` or `AAAAk`). Used in CLI args and JSON keys.
- **Silks**: kebab-case display name. Human-readable only — NOT usable for lookups.

When a command takes `<firemark>` or `<coronet>`, provide the identity, not the silks.

- Target repo dir: `.`
- JJ Kit path: `Tools/jjk/README.md`

**JJ Slash Command Reference:**

ALWAYS read the corresponding slash command before attempting JJ operations.

**CRITICAL**: JJK CLI syntax is non-standard. Do NOT guess based on common CLI conventions.
- Specs go via stdin, not `--spec`
- Positioning uses `--move X --first`, not `--position first`
- Read the slash command to see the exact `./tt/vvw-r.RunVVX.sh jjx_*` invocation pattern.

| When you need to... | Read first |
|---------------------|------------|
| Add a new pace | /jjc-pace-slate |
| Refine pace spec | /jjc-pace-reslate |
| Bridle for autonomous execution | /jjc-pace-bridle |
| Mark pace complete | /jjc-pace-wrap |
| Commit with JJ context | /jjc-pace-notch |
| Execute next pace | /jjc-heat-mount |
| Review heat plan | /jjc-heat-groom |
| Evaluate bridleable paces | /jjc-heat-quarter |
| Reorder paces | /jjc-heat-rail |
| Add steeplechase marker | /jjc-heat-chalk |
| Create new heat | /jjc-heat-nominate |
| List all heats | /jjc-heat-muster |
| Draft paces between heats | /jjc-heat-restring |
| Retire completed heat | /jjc-heat-retire |
| View heat summary | /jjc-parade-overview |
| View pace order | /jjc-parade-order |
| View heat detail | /jjc-parade-detail |
| View full heat | /jjc-parade-full |

**Quick Verbs** — When user says just the verb, invoke the corresponding command:

| Verb | Command |
|------|---------|
| mount | /jjc-heat-mount |
| slate | /jjc-pace-slate |
| wrap | /jjc-pace-wrap |
| bridle | /jjc-pace-bridle |
| muster | /jjc-heat-muster |
| groom | /jjc-heat-groom |
| quarter | /jjc-heat-quarter |

**Build & Run Discipline:**
Always run these after Rust code changes:
- `tt/vow-b.Build.sh` — Build
- `tt/vvw-r.RunVVX.sh` — Run VVX

**Important**: New commands are not available in this installation session. You must restart Claude Code before the new commands become available.

### Bridleability Assessment

When evaluating whether a pace is ready for autonomous execution (bridled state), apply these criteria:

**Bridleable** (can bridle for autonomous execution) — ALL must be true:
- **Mechanical**: Clear transformation, not design work
- **Pattern exists**: Following established pattern, not creating new one
- **No forks**: Single obvious approach, not "we could do X or Y"
- **Bounded**: Touches known files, not "find where this should go"

**NOT bridleable** (needs human judgment):
- Language like "define", "design", "architect", "decide"
- Establishing new patterns others will follow
- Multiple valid approaches requiring human choice
- Scope unclear or requires judgment calls

**Examples:**
- ✓ Bridleable: "Rename function `getCwd` to `getCurrentWorkingDirectory` across codebase"
- ✓ Bridleable: "Add error handling to `fetchUser` following pattern in `fetchOrder`"
- ✗ Not bridleable: "Define KitAsset struct and registry pattern" (design decisions)
- ✗ Not bridleable: "Improve performance of dashboard" (unclear scope, many approaches)
