## Job Jockey Configuration

Job Jockey (JJ) is installed for managing project initiatives.

**A fact stated twice here is stated twice on purpose.** Homes are placed by *moment* — what the reader is doing when they reach one — so the vocabulary list, the slating guidance, the protocol verdict and the bridle dispositions each carry the part of a doctrine their own reader acts on, and each names the moment it serves. Before collapsing an apparent duplicate, name the moment each home fires: only where two fire at the same moment for the same reader is one of them spare. Parameter facts are the exception with a single home — the command reference — and prose that restates a row rather than pointing at it is spare by that test.

**Concepts** — what the words mean; what to *do* about them is in the protocol sections below:
- **Heat**: Bounded initiative with coherent goals that are clear and present (3-50 paces). Status: `racing` (active execution) or `stabled` (paused for planning). Location: `current/` or `retired/` (done).
- **Pace**: Discrete action within a heat.
- **Kind**: The durable axis beside the voidable bridle designation — what the work *is*, as the slater stated it. Three values — `hackamore`, `poort` and `entrepas` — in **one field**, so they are mutually exclusive by construction and a pace carries one or none. Two doors write it: `jjx_enroll` at birth, `jjx_whorl` thereafter. A reslate cannot void it, the plan write a redocket funnels through taking no kind. `entrepas` is the one exception to that two-doors law: it is declared at birth or never, the flip refusing it in both directions.
- **Lope**: A pace carrying the *hackamore* kind — work that completes in conversation with the operator rather than by execution. A lope stands *rough* and carries the kind: it holds no tier, effort, or warrant, and `jjx_apostille` refuses one. *Lope* is the only word for it in prose; `hackamore` is the token, and every param, field and serialized value keeps that spelling. Graduation is transmute-in-place: settle the thinking, redocket into executable form, flip the kind away, and the pace stands awaiting designation. Full doctrine: JJS0 "The Lope" and `jjdpk_hackamore`.
- **Poort**: The other kind — work that runs solo against shared durable state: the pace holds the pass, and nothing else may work against the store while it runs. Unlike a lope it **composes with the designation** rather than foreclosing it: kind and tier are independent axes, so exclusive-and-indult-at-opus is the ordinary shape for schema work. There is no second noun — a pace carrying it is a *poort pace*, and the word is the token. Its whole enforcement is the **operator's word at the session's opening**: the session's orders carry the confirmation as this kind's protocol line, no lock is taken and no other session is detected. Full doctrine: JJS0 `jjdpk_poort`.
- **Entrepas**: The third kind — a pace born, worked and closed inside a single dispatch. Its claim is narrow and stated narrowly: **no frontier bridling ruling stood between slate and execution, and no designee warrant governed it** — one authority carried both ends. It never says the work was unreviewed; what it collapses is the ceremony's *ordering*, not its volume. There is no second noun: a pace carrying it is an *entrepas pace*, and the word is the token. Tier is not a parameter of the kind, and the close's commit message records the tier the session actually ran at. `jjx_apostille` refuses all three forms, `jjx_whorl` refuses the flip in **both** directions, and `jjx_girth` **admits every tier without a warrant** — so the overflow exit is a **new pace, never a mutation**. Its trees stand before you do: the operator opens the **vaquero** door naming a heat and a sire, the stile provisions the whole kraal at dispatch — outspan, work billet, vulgate billet — and lands its mandamus in the outspan for you to read. What is inverted is the ORDER, never the geometry: the pace those trees are for does not exist until you enroll it, so your first act is that enroll. The trees carry no coronet, none having existed when they were minted; the enroll banks the kraal's serial onto the pace, which is how the saddle's resume finds the branch again after this kraal is gone. Full doctrine: JJS0 `jjdpk_entrepas`.
- **Spook**: Team infrastructure stumble — any workflow failure improvable with deft attention. Capture as a pace when encountered, don't lose the current thread.
- **Cinch**: A decision settled in a paddock or docket and not to be re-litigated — both noun and verb. Distinct from a *lock* in the concurrency sense (JJK's git-ref commit lock), which keeps that word.
- **Phase ladder**: A long arc shaped as a succession of heats, one rung apiece — the ladder recorded in the standing heat's paddock, rungs named but detailed only once their predecessor lands. Three hard laws: a phase boundary is a **slated pace, never paddock prose** (a pace blocks a clean retirement; prose does not); findings travel **verbatim**, proven by byte diff against the source, never re-glossed or condensed; **only live findings travel** — a carry is a liveness filter, and a retired paddock is provenance, never authority. When you groom a heat whose paddock shows a ladder, or cut a heat that will hand work forward, four further rules bind: each rung's done-line is a state predicate to sight in the world, never an adjective and never an ordinal (a rail silently redefines one); the boundary pace nominates the successor heat, carries the live findings into its paddock and expands the next rung into paces; verbatim carriage imports the source's deixis, so the carrying pace frames a carried block — naming its source, the cut, and whose voice its "this heat" speaks in — rather than repairing it, and marks any note it adds as added; and a ladder ends by record, its terminal rung's paddock saying so and slating no boundary pace. Home: JJS0 "The Phase Ladder", cited as depth.
- **Mulling heat**: A stabled heat paired with an aspirant sheaf — aspirancy is declared by the sheaf's `//axvd_sheaf axd_aspirant` voicing, never inferred from prose, and an aspirant may stand *unpaired*, its acronym entry saying which and a heat nominated later when a need calls for one. Design leans bank in the sheaf; work-shape and cinches bank in the paddock — read the paddock before cutting any pace, or the sheaf's settling register where no heat stands. Sheaf-authoring paces may race; implementation paces wait for *settling*, never for infusion. Full doctrine: JJS0 "The Mulling Heat" (Aspirant Nucleations).
**Sincerity over efficiency:** When you notice something — a pattern, a concern, an insight about the work or the collaboration — say it. Discovery through conversation is part of the work, not a detour from it.

**Docket and paddock craft is a pull door.** `Tools/jjk/jjai0/jjaie_slating.md`
holds it — docket posture, the delegate test and a lope's wider done-when,
slate-time versus saddle-time, reference discipline, and paddock posture. Read it
before you author a docket or a paddock body.

**The graph question — ask it at every slate, in both directions.** A slate authors edges as well as a docket. Ask first what the born pace must wait on, and name those paces in the birth call's `predecessor_coronets` — plain addressing, since the pace being born is the pace that waits. Then ask the inverse, the direction that gets forgotten: what *standing* pace must now wait on the pace you just slated. Author that edge in the same breath through `jjx_hopple`, whose addressing inverts — its `identity` names the thing waited *on*, its list the dependents that will wait — so one call fans the new work across everything it holds up. **The edge BITES:** a wait is a condition on starting work and on landing it, never on continuing it, and the rows below carry which door does what. Author an edge on suspicion: a missing one dispatches a session onto work whose inputs have not landed, and a wrong one costs one `jjx_unhopple` on the operator's word, which is the whole of the override.

**Stale-by-saddle filter.** Each line must still be true at saddle-time. Fail (drift): line numbers, byte/match counts, version strings, exhaustive site enumerations. Pass (durable): file paths as entry points, commit hashes, spec/concept names.

**Docket anti-patterns:**
- Restating commits/specs the saddled session already loads. Point, don't paraphrase.
- Pre-baking implementation (function names, signatures, locations for new code). Saddle-time decisions.
- Site enumerations. Write a discovery recipe instead of listing six file:line entries.
- **Every-X dockets without a census.** A docket that quantifies over a set of code sites ("repoint every mutating command") must carry the set's heterogeneity census or mandate it as the session's first checkpointed artifact — never open with a binary "confirm whether" first act. The mandate form (discovery recipe + census-first requirement) is the usual fit under the stale-by-saddle filter. The census is the plan: a representative-specimen survey excludes by construction the outliers where the risk lives.
- Body over ~25 lines or ~500 words warrants suspicion of overprescription; the remedy is moving depth into the slate's precis, never cutting a cinch the work needs.
- **Plan-step structure stays in the plan.** Docket phase/step labels (A/B/C, "Phase 1", "first/then/finally") must not appear as code comments; line order already conveys execution.
- **Absolute paths to working trees.** Don't pin a docket to a specific repo clone (`/Users/foo/projects/your-project`, `~/proj/`). A session may legitimately run against a different clone — if work needs to happen in *the* working directory, say so without naming it. Absolute paths *are* acceptable for external data roots (log dirs, machine-pinned data), flagged as operator-mutable rather than identity; a docket needing scratch names the kraal's scratch directory.

**Semantic linefeeds in artifact prose.** Author paddock and docket prose — the bodies you write into `gazette_in.md` — with *semantic line breaks*: one sentence per line, a long sentence broken at its major internal boundaries (em-dash, semicolon, colon, comma-before-conjunction). Markdown soft-wraps these into one rendered paragraph, so the breaks are invisible in output. Never break at the word level — for word-grain diffs use `git diff --word-diff`, not physically split prose. (Instantiates JJS0's *Diff-Friendly Prose* principle, which governs gazette markdown only — not the `.adoc` specs, whose source answers to MCM line-break discipline.)

**Citation spans in corpus prose.** Corpus prose citing a governed word wears a citation span around it — a backtick literal, an attribute reference in braces, or a cross reference in double angles — since a word standing bare outside one is an ordinary use rather than a citation, however plainly the sentence around it means the name. This binds the specs and guides you edit in the vulgate billet, not the gazette bodies the passage above governs.

**Mid-execution posture.** When a failure or surprise surfaces while a pace is saddled, the default response is mechanism + one specific repair you'd attempt. Do not proliferate options or weigh consequences across alternatives — pace scope and segmentation are operator territory. If the repair is obvious, proceed; else surface the question and stop.

**Identities vs Display Names:**
- **Firemark**: Heat identity, `₣` + two characters from a nonstandard b64 alphabet (e.g., `₣AA`, `₣A-`, `₣A_`, `₣A7`). Used in command params and JSON keys; input may omit the `₣` glyph, output always includes it.
- **Coronet**: Pace identity, `₢` + **five** characters from the same alphabet — one flat global index carrying **no** firemark and encoding **no** heat affiliation (seed-minted coronets begin at `C`, e.g. `₢CAAAG`; the leading characters are never a heat reference, save a grandfathered id whose leading two happen to equal a firemark by frozen coincidence). The **bare five-character body** (`CAAAG`) is the machine identity — command params, JSON keys, git refs. On emission it is qualified by *live* heat affiliation: `₢` + the current heat firemark + the interpunct `·` + the body (`₢B4·CAAAG`, the form seen in prose; a grandfathered pace renders its heat twice, `₢B4·B4AAB`); tables show the bare `₢`+body (`₢CAAAG`). **Any of these forms is accepted as input** — the `₢` glyph and any `·` qualifier are stripped and the bare body is looked up — so you never guess the wire form.
- **Silks**: kebab-case display name. Human-readable only — NOT usable for lookups.

When a command takes a firemark or coronet, provide the identity, not the silks.

**Display discipline (agent text output to user):**
- **Always show the full emitted form; never abbreviate.** Write a coronet
  live-qualified — `₢B4·CAAAG` (`₢` + heat firemark + `·` + body) — and a
  firemark as `₣A-`, never `A-`. A bare body dropped into running prose leaves
  the reader with no heat context. That prefix records *live* affiliation and is
  not part of the immutable identity — a relocate re-qualifies tomorrow's
  rendering — but it is what you display. This holds in prose, tables, bullets,
  headers and casual back-references.
- **Prefer coronets over silks in references.** Coronets are precise and
  immutable; silks change via `jjx_whorl`. Lead with the coronet, silks
  following parenthetically for readability (`₢B4·CAAAG
  (coronet-doc-gestalt-drift)`). The coronet alone is always sufficient; the
  silks alone never are.
- **Say *lope* for the pace, `hackamore` for the token.** In prose to the
  operator a pace carrying that kind is a lope — never "a hackamore pace". Use
  the token only where it is literally spelled: a param value (`{kind:
  "hackamore"}`), a word the equerry printed, a JSON value. Use both words in one
  breath the first time they meet in a session, so a reader told they hold a
  lope can still reach a value spelled `hackamore`.
- **Poort has no second noun, so say *poort pace*.** *Lope* and `hackamore` are
  two words for one thing; poort is one word for one thing, and inventing a noun
  for it would be minting in prose. It is the pace's kind, never its state — so
  never write it where a state word belongs.

- Target repo dir: `.`
- JJ Kit path: `Tools/jjk/README.md`

**MCP Tool Usage:**

All JJK commands are accessed via the single `mcp__vvx__jjx` MCP tool with three parameters — the whole per-call surface, with nothing else accepted:
- `command`: string selecting the operation — always the canonical `jjx_*` name (e.g., `"jjx_show"`, `"jjx_record"`)
- `params`: JSON object with command-specific fields (see reference below)
- `model`: agent's verbatim model ID string from its system prompt (e.g., `"claude-opus-4-8"`). Required on ALL commands.

**There is no session-identity parameter, and no verb that mints one.** The door seated this server in the kraal it serves, so its own working directory already tells it whose tenure this is. Pass `command`, `params` and `model`; nothing more is read. Why the parameter is declined rather than merely unused: JJS0 "Session Exchange".

**`params` must be a JSON object, never a string.** If params is accidentally stringified (e.g., `"{\"key\": \"val\"}"` instead of `{"key": "val"}`), deserialization will fail. The server has a defensive fallback for this, but always pass a native object.

**Interdictum — the gating refusal.** A jjx result whose first word is `INTERDICTUM` bars the act; it is not a *vitium* — the correctable verdict, which you fix and retry. The genre and its severity rule are spec-homed at JJS0 `jjdz_interdictum` — the three verdicts (monitum, interdictum, vitium), the differentia that sorts them (a vitium is correctable by fixing the call; an interdictum's condition lies outside it), and the emission's own obligations. A vitium carries no wire token of its own and none is coming, so the recognition rule stays exactly one: the leading `INTERDICTUM`, or its absence. Cited, not summarized: what binds *you* is the four bullets below, and an agent never needs the spec to obey a token. It is named because the author of the next refusal does need it.

- **Stop the act and its objective by any route** — no altered-params retry, no other command to the same end, and no gathering of context to hand the operator a recommendation the interdictum did not invite. What is barred is not only the literal act but everything downstream that served it, a substitute recommendation included; a *read-only* read pursued to that end is the workaround, not an exempt route. The rationalization "reads aren't to the same end" is exactly the loophole this shuts. Unrelated work continues.
- **Report it verbatim, and stop there.** The message is self-sufficient: what refused, why, the remedies. The verbatim report is your whole response — do nothing further unless the operator directs it, and pursue a named remedy only on their word — save the refit a refused wrap demands, which Commit Discipline's staleness law has you take unasked.
- **When the operator reports the cure done, resume the act that refused.** The cure, and any refit or resume that follows it, licenses nothing beyond resuming that act. Every question open before the refusal stays open and takes its own word.
- **Do not model the guard.** This context says nothing about what generates an interdictum — carried mechanism becomes a self-check, and second implementations drift. Attempt the act; obey the token.

**Verb names are NOT command names**: there is no `jjx_slate`, `jjx_notch`, `jjx_groom` command. The verb table below maps horse vocabulary to actual MCP commands.
NEVER invent param fields — check the reference below first.

**Quick Verbs** — When user says just the verb, invoke the corresponding command:

| Verb | Noun | MCP command |
|------|------|-------------|
| muster | heats | `jjx_muster` |
| parade | heat/pace | `jjx_show` |
| scout | heats | `jjx_search` |
| fettle | store | `jjx_runnable` — what can start now, and what holds the rest |
| nominate | heat | See Heat Birth and Death below |
| groom | heat | See Groom Protocol below |
| slate | pace | `jjx_enroll` |
| chivvy | pace | `jjx_enroll {first: true}` |
| cantle | pace | `jjx_enroll {after: <current_coronet>}` |
| reslate | pace | `jjx_redocket` |
| curry | paddock | `jjx_curry` (write; the read is `jjx_paddock`) |
| gesta | wraps | `jjx_gesta` (read; the store-wide wrap harvest with each close's trailers) |
| cavvy | replication registry | `jjx_cavvy` (read; census + drift report) |
| rodear | cavvy | `jjx_rodear` (write; the read is `jjx_cavvy`) — see Rodear Protocol below |
| vademecum | drover doctrine | `jjx_vademecum` (read; the drover's standing document, with the cocket that arms the write) |
| enface | drover doctrine | `jjx_enface` (write; the read is `jjx_vademecum`) — operator-directed only, the Rodear Protocol's fence exactly |
| waybill | tropa record | `jjx_waybill {tropa}` (read; one tropa's working record — a tropa being the share of the estate one drover rules, keyed from a fixed roster — with the cocket that arms the write) |
| indite | tropa record | `jjx_indite` (write; the read is `jjx_waybill`) — the drover's own, without the operator's word; never a working session's |
| strigil | chat line | `jjx_strigil` (read open to all; `{write: true}` only from a poort pace's session) |
| hansard | chat line | `jjx_hansard` (read; a pace's chats, or one chat into the outspan) |
| bridle | pace | `jjx_apostille {coronet, tier, effort?}` — see Bridle Protocol below |
| unbridle | pace | `jjx_apostille {coronet, release: true}` |
| notch | pace | See Commit Discipline below |
| wrap | pace | `jjx_testimonium` — see Wrap Discipline below |
| rail | heat | `jjx_rail` |
| furlough | heat status/silks/atajo | `jjx_alter` — heat records only, all params, no gazette |
| whorl | pace silks/sire/kind | `jjx_whorl` — the scalar pace editor; the lope flip is its `kind` field |
| hopple | pace wait | `jjx_hopple {identity, add_coronets}` — make paces wait on this one; the identity is the thing WAITED ON, a coronet for one pace or a firemark for a whole heat |
| unhopple | pace wait | `jjx_unhopple {identity, remove_coronets}` — lift that wait, at either grain |
| dight | pace silks | `jjx_whorl {coronet, silks}` |
| riem | pace sire | `jjx_riem` — read-only report, or the blank audit with no coronet |
| retire | heat | See Heat Birth and Death below |
| restring | heat | `jjx_transfer` |
| foray | remote dispatch | See Foray Protocol below |
| unfurl | image | See Unfurl Protocol below |
| wrangle | marked stack | drover only — read `jjaie_wrangle.md` before the first step |

**MCP Command Reference:**

All params are JSON objects. `?` = optional, `[]` = array. Booleans default to false.

**This table is the contract, not a hint.** Every command refuses a param it does
not carry, naming the fields it expected, so a name that is absent here is a name
the equerry will not take. Read the row before you guess.

```
jjx_show           {remaining, hark?}
jjx_muster         {status?}
jjx_girth          {}
jjx_create         {silks}                                          # operator-directed only — see Heat Birth and Death
jjx_enroll         {firemark, before?, after?, first?, sire?, kind?, crupper?, predecessor_coronets?[], readable_sires?[], size_limit?}
jjx_rail           {firemark, move?, before?, after?, first?, last?}
jjx_alter          {firemark, racing?, stabled?, silks?, writable_sires?[], readable_sires?[], size_limit?}
jjx_record         {identity, files?[], size_limit?, intent?, vulgate?} # files omitted = whole dirty tree; [] = the empty notch; [...] = exactly those paths. A SETTLED pace's coronet demotes to its heat rather than refusing, and the monitum names the pace you then owe.
jjx_testimonium    {coronet, summary?, spook?, criteria?, size_limit?}    # criteria: a string (one criterion per line) or an array of strings (one per element)
jjx_steeplechase   {firemark, limit?}
jjx_gesta          {since?, limit?, heats?[], trailers?}
jjx_search         {pattern, actionable?}
jjx_archive        {firemark, size_limit?}                          # operator-directed only — see Heat Birth and Death.
jjx_transfer       {firemark, to, coronets[], size_limit?}
jjx_paddock        {firemark}                                       # EMITS A jjezs_cocket NOTICE BESIDE THE PADDOCK — same firemark lede, its body the mark of the reading — and that mark is what arms jjx_curry's stale-base guard. This door, jjx_vademecum and jjx_waybill are the ONLY doors that mint one: a paddock `jjx_girth` or a parade emits is context, not edit material
jjx_cavvy          {}
jjx_curry          {note?, size_limit?}                             # GATED ON A STALE BASE: a curry is a WHOLE-BODY REPLACE, so one composed against a superseded reading discards whatever landed in between, silently and with every door reporting success. A curry carrying NO cocket LANDS, with a monitum saying the guard was not armed.
jjx_vademecum      {}
jjx_enface         {note?, size_limit?}                              # A write carrying NO cocket LANDS with a monitum saying the guard was unarmed.
jjx_waybill        {tropa}
jjx_indite         {note?, size_limit?}                              # A WHOLE-BODY REPLACE of one tropa's record, its key riding the notice's lede. A write carrying NO cocket lands only as a tropa's FIRST edition, and REFUSES where a record stands.
jjx_strigil        {write?, legacy_root?, archive?, retention?}      # READ FORM CHANGES NOTHING; WRITE FORM ONLY DURING A POORT. Rulings ride jjezs_placitum, never a param.
jjx_hansard        {coronet?, chat?}                                 # EXACTLY ONE: coronet = the pace's chats and their lines; chat = that chat lands in the outspan
jjx_rodear         {note?, size_limit?}                             # A WHOLE-BODY REPLACE of the cavvy: create/update/delete are all just "the staged body differs from what stands". OPERATOR-DIRECTED ONLY — see Rodear Protocol below
jjx_relocate       {coronet, to, before?, after?, first?}
jjx_redocket       {size_limit?}                                    # ONE HEAT PER RUN: reslates spanning two heats refuse the whole run
jjx_whorl          {coronet, silks?, sire?, readable_sires?[], kind?, size_limit?}
jjx_hopple         {identity, add_coronets[]}
jjx_unhopple       {identity, remove_coronets[]}
jjx_drop           {coronet}
jjx_brief      {coronet}
jjx_coronets   {firemark, remaining?, rough?}
jjx_runnable       {heats?[]}
jjx_apostille      {coronet, tier?, effort?, release?, trigger?}
jjx_rasp           {size_limit?}                                     # NORMALIZE REMOVES DATA ON ONE AXIS, the rest being byte-shuffling: a predecessor edge touching a RESOLVED pace is cleared, in either direction, since the graph holds live paces only. NORMALIZED IS A STRUCTURAL VERDICT, NEVER A SEMANTIC BLESSING: a 2 says the bytes are canonical, not that the heat/pace inventory is right, so after a merge convergence eyeball the inventory against both branches yourself
jjx_refit          {}                                                # Voids criteria you have already driven — re-drive them on the merged tree
jjx_riem           {coronet?}
```

**What each door DOES is a pull door.** The table above is the param contract
and stops there; `Tools/jjk/jjai0/jjaie_portolan.md` carries every
command's behavior. Read it before you drive a verb for the first time this
session, and whenever one of these plain questions comes up:

- *what does this print, and what rides the gazette* — which half of a result is
  inline, what a count counts;
- *what does this param do, and what if I leave it out* — whether a list is a
  filter or an election, what absent means beside `[]`, what a field replaces;
- *what does this notice need* — which slug, whether it takes a lede, what the
  body must carry;
- *what does this refuse, and why did it just refuse me* — the refusal roster
  per door, which the signature line does not carry;
- *what does this void, announce, or leave alone* — designations, waits,
  deferrals, criteria already driven.

A refusal you have already met names its own remedy. The portolan is for the
call you have not made yet.

The six remote commands (`jjx_bind`, `jjx_send`, `jjx_plant`, `jjx_relay`, `jjx_certiorari`, `jjx_fetch`) are deliberately absent above — they are catalogued in `Tools/jjk/jjai0/jjaie_foray.md`, which the Foray Protocol routes you to before the first call.

### Session Protocol

**There is no opening ceremony — begin with your orders.** The door that opened this session composed them at the top of your CLAUDE.md: what it was opened for, and for a pace its protocol, warrant and docket, naming `heat.md` beside it for the heat's paddock and recent work. A session performs no startup act, mints nothing, and holds no session token: your first jjx call is whatever the work needs. Nothing has to be threaded through later calls.

A chat the door did not dispatch holds no jjx tools at all, the MCP config being written per-dispatch, and is refused outright with an INTERDICTUM naming both doors if one is reached anyway. The law and its ground: JJS0 "Session Exchange".

**The exchange is the kraal's seat: `gazette_in.md` and `gazette_out.md` stand in this session's own working directory.** They are not in a per-session directory somewhere else, and there is nothing to derive from an id.

**Take the paths from the equerry, never from memory.** A getter prints the absolute pair beneath its result; a setter that finds nothing staged names the exact path it checked. Use what you are given verbatim. Do not rebuild a path from a remembered layout or search for one — a notice written to the wrong directory does not fail as a wrong gazette, it fails as an absent one, and the refusal will name a path you did not write to.

Every jjx MCP call the dispatcher admits deletes both gazette files on entry (read+delete `gazette_in.md`, delete `gazette_out.md`) — gazette content has single-MCP-call lifetime, a parameter or return value, not persistent state. A handful of refusals stand *ahead* of that entry read and leave a staged notice untouched; see **On failure** below.

**⚠️ `gazette_in.md` is the argument to the *next* jjx call — whichever fires next consumes it on entry, not a particular command.** So write the gazette as the immediate last step before *that* call; if you reconsider which command to run, rewrite or clear it first. **Deleted-on-entry means read-on-entry** — a stale notice is consumed as this call's input *before* it is deleted, and a gazette *setter* writes and **auto-commits with no confirm gate**. Keep every gazette write welded to the single call it was written for.

- **`gazette_in.md`** (agent → server): write before a setter (`jjx_enroll`, `jjx_redocket`, `jjx_curry`, `jjx_rodear`), before `jjx_apostille` (its **required** `jjezs_warrant` on the tier form, `jjezs_abeyance` on the deferral form), before `jjx_archive` (its **required** `jjezs_quittance`), before `jjx_strigil`'s write form (its optional `jjezs_placitum`), or before `jjx_show` (its `jjezs_halter` target selection). For every one of them the gazette is the sole input path — there is no JSON param fallback.
- **`gazette_out.md`** (server → agent): written by getter commands, read after they return. Notices are `# jjezs_paddock <firemark>` / `# jjezs_pace <coronet>` / `# jjezs_steeplechase <firemark>`, content beneath each: `jjx_girth` → paddock, the seated pace whole (original-intent, then docket, then pace digest), and the recent-work entries — the re-read of what your orders and `heat.md` carry; `jjx_show` → the paddock of each heat haltered by firemark (a coronet halter carries its pace notice alone) + a docket per resolved pace, each carrying its warrant beneath where the pace has one; `jjx_paddock` → paddock only; `jjx_brief` → the one pace's docket and warrant whole under its `# jjezs_pace <coronet>` notice, at every size, the inline result carrying the state word alone; `jjx_cavvy` → the cavvy's canonical body under a LEDE-LESS `# jjezs_cavvy` header. Every other read — `jjx_steeplechase`, `jjx_gesta`, `jjx_search` among them — prints its whole answer as its result, and `jjx_record` and `jjx_redocket` print their scrutators' readings and their diffs the same way: the seat's `# jjezs_tenor` notice below carries any result whole.

**Never reach past the JJK interface to raw storage — NO exceptions.** Do not parse the harness's persisted tool-result files or the studbook-journaled gallops JSON directly. `gazette_out.md` is what a getter wrote for you: read it with the file reader, by line range when it runs long, and never rebuild it from a clipped shell print, since the transport bounds what a tool result carries (JJS0 `jjdx_mcp`, *Bounded-inline*); `jjx_girth` names each notice's line range inline, so range straight to the one you want. To read one pace's docket, call `jjx_brief {coronet}`, which writes the docket to `gazette_out.md` and is the single-pace read; `jjx_show` with several halters is the many-pace read, and a session reading several paces reads the gazette between calls, since each call clears it.

**A result whose closing line says it was cut is its leading lines alone: read the whole, last in `gazette_out.md` under `# jjezs_tenor`, before acting on it.**

**Gazette wire format (setter commands):**
Each notice is a `#`-header line with slug and lede, followed by a content body. The lede is **exactly one whitespace-free token** (silks / coronet / firemark, per the table below) — nothing follows it on the `#` line; the body goes beneath, and appending extra text to the lede folds it into the identity and fails validation. `jjezs_halter` is body-less (the lede is the whole notice); the content-bearing slugs (`jjezs_slate`, `jjezs_reslate`, `jjezs_paddock`, `jjezs_dictation`, `jjezs_precis`, and the four lede-less ones, `jjezs_warrant`, `jjezs_cavvy`, `jjezs_quittance` and `jjezs_placitum`) require a **non-empty** body — an empty or whitespace-only body rejects loud, a setter never executes a clear.

**Critical: `#` (H1) in gazette_in.md is a wire format delimiter, NOT a markdown heading.** For single-notice commands (enroll, curry), use exactly ONE `#` line. For mass reslate and multi-target show, each `# jjezs_reslate` / `# jjezs_halter` line starts a new notice. All markdown headings within body content must use `##` or deeper — a bare `#` line inside content is parsed as a notice boundary, and rejects naming the offending line and slug (`Line 5: unknown slug 'Paddock:'`).

**On failure: re-write `gazette_in.md` from scratch before retrying, whatever refused you.** Most refusals reach you from *past* the entry read — every parse, param and validation refusal among them — so the notice is already consumed and a blind retry sends an empty gazette. A few stand *ahead* of it and leave the notice standing, but nothing in a refusal tells you which side of the read it fell on, so the re-write law is unconditional and errs safe under either. Never retry on the strength of a notice you believe survived.

**A call that dies with no verdict at all is a different thing from a refusal, and for `jjx_refit` and `jjx_testimonium` the remedy is simply to re-run it.**
A dropped transport — `Connection closed` or any dead call returning neither success nor refusal — leaves you unable to tell from the call whether the act landed, and neither door asks you to find out: a refit whose axis already advanced reports that axis already current, and a wrap whose converge landed before its journal was refused says so and resumes on the re-run, converging nothing a second time.
Re-run the door and read what it reports; do not go reading the trees by hand to reconstruct what happened.

| Command | Write to `gazette_in.md` | Then call with params |
|---------|--------------------------|----------------------|
| `jjx_show` | `# jjezs_halter <firemark\|coronet>` per target (one or more, body-less) | `{"remaining": true\|false}` |
| `jjx_enroll` | `# jjezs_slate <silks>` + docket body; `# jjezs_dictation <silks>` + verbatim body; `# jjezs_precis <silks>` + distillation body (one shared lede) | `{"firemark": "XX", "before?": ..., "after?": ..., "first?": ..., "sire?": "jj", "kind?": "hackamore", "predecessor_coronets?": ["CAAAG"]}` |
| `jjx_redocket` (single/mass) | One or more `# jjezs_reslate <coronet>` notices, each with docket body — and nothing else; a paddock or slate notice here refuses, naming its own door | `{}` |
| `jjx_curry` | `# jjezs_paddock <firemark>` + content body (non-empty), and beside it the `# jjezs_cocket <firemark>` notice the read emitted, body copied whole (omit it and the write lands with a monitum; carry a stale one and it refuses) | `{"note?": "commit annotation"}` |
| `jjx_rodear` | `# jjezs_cavvy` — **NO lede** — + the whole cavvy JSON (non-empty) | `{"note?": "why the grade moved"}` |
| `jjx_enface` | `# jjezs_vademecum` — **NO lede** — + the whole document (non-empty), and beside it the `# jjezs_cocket` notice the read emitted — **also NO lede** — body copied whole (omit it and the write lands with a monitum; carry a stale one and it refuses) | `{"note?": "why the ruling moved"}` |
| `jjx_indite` | `# jjezs_waybill <tropa>` + the tropa's whole record (non-empty), and beside it the `# jjezs_cocket <tropa>` notice the read emitted, body copied whole (omit it only for a tropa's first edition; carry a stale one and it refuses) | `{"note?": "what moved"}` |
| `jjx_strigil` (write form, optional) | `# jjezs_placitum` — **NO lede** — + one ruling per line: `acquittal <shape> <digest>`, `acceptance <uuid> <offset>`, `decline <uuid>` | `{"write": true}` |
| `jjx_apostille` (every bridle) | `# jjezs_warrant` — **NO lede** — + briefing body (non-empty) | `{"coronet": "...", "tier": "sonnet", "effort?": "..."}` |
| `jjx_apostille` (every deferral) | `# jjezs_abeyance` — **NO lede** — + brief body (non-empty) | `{"coronet": "...", "trigger": "CAAAB"}` |
| `jjx_archive` (every retirement) | `# jjezs_quittance` — **NO lede** — + done-when audit body (non-empty) | `{"firemark": "XX", "size_limit?": ...}` |

**Original intent at slate.** Every slate stages the dictation and precis
companions beside its slate notice — wire form in the table above. Both freeze
at slate and no verb rewrites them, so an omission can never be repaired.
Optional at the tool, required at every slate. There is no exception: every
pace is born at `jjx_enroll`, so an intent-less pace is one whose slater omitted
the capture, never one whose door could not hold it.

**Read-modify-write workflow** (paddock editing):
1. Call `jjx_paddock {firemark}` → writes `gazette_out.md`, carrying the paddock notice and a `jjezs_cocket` notice beside it
2. Rename `gazette_out.md` → `gazette_in.md`, edit the paddock body — **leave the cocket notice alone and in place**
3. Call `jjx_curry`

**Compose the body in scratch before you stage it.** Any refusal consumes the staged notice, so a revision authored straight into `gazette_in.md` is gone the moment the write is turned away.

The cavvy takes the same shape — `jjx_cavvy` → edit → `jjx_rodear` — the emitted notice being byte-identical to the one the writer expects. **But never begin it unbidden: see Rodear Protocol below.**

**Mass reslate is a pull door.** When one mechanical edit has to reach many dockets at once, read `Tools/jjk/jjai0/jjaie_reslate.md` for the show → reslate bridge before improvising a run.

**Scratch goes to the kraal's scratch directory.** When a session writes a scratch file — a capture, a draft body, a recipe — it writes it into the kraal's scratch directory its orders name, never into the outspan, the infield root or a temp path, the harness's scratchpad being no exception; a data root a docket names stays the docket's to cite.

### Parallel Tool Batch Discipline

When tool calls share one parallel block and one exits non-zero, the harness **cancels the still-queued siblings** ("Cancelled: parallel tool call … errored"), so a screenful of cancellations usually traces to *one* real error upstream — diagnose that, don't react to the cascade. Three rules:

- **Never co-batch a producer with its consumer.** A command and another that needs its output, or a path built from it, must be sequenced across tool blocks. `jjx_record` alongside the edits/checks that must *precede* it is the standing case: verify the tree first, commit second. A gazette write and the single call that consumes it are the same shape — write, then call, never both in one block. Two jjx calls never share a block either: the gazette is one pair of files cleared on every call's entry, so the second call clears what the first wrote or staged.
- **Keep fragile or dependent commands out of wide read-only batches** — an empty/failed sibling can silently cancel unrelated reads. In a zsh batch, a separator echo is quoted (`echo '===='`), since zsh reads a bare run of equals signs as a command to look up, and its failure cancels the sibling reads.
- **Await the handle the launch printed.** `vvx_tt_await` takes the handle a detached `vvx_tt` report printed, in a tool block after the launch's own, never one guessed or co-batched with its launch; its report closes on the call to copy. Handed no handle, the await takes the server's one live detached run, and refuses naming each live one where several stand.

### Opening Protocol

Your orders stand at the top of your CLAUDE.md, composed by the door that opened this session. A session opened on a pace opens this way:

1. Read the orders whole: the `Designation:`/`Protocol:` lines lead them, then the warrant where the pace holds one, the pace (original-intent, docket, digest) and its sires. Its heat's paddock and recent work stand in `heat.md`, which the orders name: read it with the file reader, by line range where it runs long. A staleness line beneath the protocol names `jjx_refit`: remedy it yourself before you propose an approach, exactly as Commit Discipline below directs, then call `jjx_girth` for a re-read describing the merged tree.
2. **Read the paddock before the docket.** The paddock tells you the shape of the work; the docket tells you what to do next. An `Original-intent` block above the docket is the slate-frozen understanding; the docket below is the living authority.
3. **Lead with the pace goal in one sentence**, distilled from the docket — what this pace is trying to accomplish, stated precisely (paces can sit weeks between slating and their session; goal recall comes first). Then display brief heat context (silks + paddock one-liner + recent work) and finally the full docket.
4. **Run the readiness half of the bridling procedure**, which a rough pace
   opened at full ceremony has never passed:
   `Tools/jjk/jjai0/jjaie_bridling.md` — the trees, the three gap
   classes, the lope test, and the done-proof litmus — skipping tier, effort
   and warrant and recording nothing.
   A session whose orders open it on a lope skips this step whole, the lope
   test with it, since the readiness half readies a pace for execution and a
   lope's orders replace this protocol.
5. **Name assessment**: If pace silks doesn't fit docket, offer a dight via `jjx_whorl {coronet, silks}`
6. Propose the approach compactly — a one-line recommended execution strategy (model tier + sequential/parallel). Offer the reasoning (tier rationale, parallelization analysis) on request, not unprompted. Tiers: haiku (mechanical), sonnet (standard dev), opus (architectural).
7. Ask to proceed, then begin work — a designee skips the ask, the launch that seated it being the proceed

### Standing and Protocols

**Your standing is decided by the server, never by you.** Your orders carry the
`Protocol:` line your pace asks of a session; your first jjx call judges the
`model` param you pass against the pace's designation, and `jjx_girth` prints
`Standing:` and `Protocol:` at the very *head* of its re-read. Obey them. Do not
weigh your own model against the pace's tier, and do not reason about which
protocol you fall under: a session that reaches its work has already been judged,
and one that may not proceed is refused outright rather than returned for you to
interpret. The operator closes every pace, at every tier.

This law binds from the opening through close, in every working session. The two
protocols your orders name:

- **Full ceremony** — work and wrap the pace yourself (the Wrap
  Discipline below still governs: ask the operator before wrapping).
- **Lope** — a pace carrying the hackamore kind (JJS0 `jjdpk_hackamore`): it
  completes in conversation with the operator rather than by execution. Your
  orders carry the protocol whole; obey what they say. Two things it
  does not carry: the Wrap Discipline below still governs the exit that finishes
  cheap and wraps, and a premise that breaks is a lope **completing**, not failing.

**The entrepas kind displaces those two, as a lope does.** You hold full
ceremony at whatever tier you are — no warrant governs the pace and none can, so
the tier moves your Standing line and nothing else. Your orders carry the
rest, the obligation to resolve the pace before this chat ends among it.

**The poort kind is a gate over those two, never a third.** Where a lope
*replaces* your protocol, a poort pace *gates* it: the verdict names the kind and
then hands you whichever of the two your designation earns, and your orders
carry the confirmation the gate requires. Once the operator confirms, proceed
under the protocol the verdict gave you, unchanged.

### Groom Protocol

**Excursus** (`jjsuc_excursus`): `Tools/jjk/jjai0/jjaie_groom.md` carries the
groom procedure — the halter notices, reading the gazette, the overview, the
done-when gap report and the move into planning. Read it when the operator says
"groom".

### Bridle Protocol

**Excursus — read `Tools/jjk/jjai0/jjaie_bridling.md` before you bridle, whenever
bridling or warrants are under discussion.** Never bridle from memory of it.

Bridling designates a pace for execution at a specific model tier. A `rough`
pace is one no frontier agent has ruled on yet; an `indult` pace carries its
tier (and optionally an effort word) until it is released, reverted, or closed.

- **Rough is the absence of a ruling, never a signal.** A pace whose execution
  needs opus judgment is bridled *at opus* — never left rough to say so, since
  rough reads identically to a pace nobody has examined. Bridling at a frontier
  tier is a first-class act: the only durable record that a frontier agent read
  this docket and ruled it frontier-grade, the only thing that surfaces the tier
  in `jjx_coronets` (`[indult opus]`), and the only way to record an effort
  word. Its mirror binds equally: "this pace needs judgment to execute" is not a
  gap and is never a reason to withhold designation. Both temptations are toward
  *not* designating — an inaction that announces no occasion, so no trigger
  fires and neither can wait behind the door.
- **A designation is void when its judgment inputs change, and the voiding
  table is the whole rule.** Four authored fields void: the **docket** (the
  text the judgment read), the **sire** (which tree a saddle provisions), the
  **read list** (which further trees it provisions), and the **kind** (what the
  work IS). Two never do: **silks** and **the waits** — so reach for
  `jjx_hopple` and `jjx_unhopple` without weighing a designation. Transfer and
  relocate void as well; reorder does not. A void reverts the pace to rough and
  wipes the tier, effort and warrant together.
  Where the void is announced differs by door: `jjx_whorl` names the tier it discarded, so a
  sire, read-list or kind edit says what it cost — but a **redocket announces
  nothing**, so refining a docket still discards its designation silently. That
  binds at *reslate*, not at bridling.

### Rodear Protocol

**Cavvy edits are the operator's. Never call `jjx_rodear` on your own
initiative** — recommend, and stop.

`Tools/jjk/jjai0/jjaie_cavvy.md` holds the maintenance protocol whole — the
cavvy's shape, the grade and transport rosters, the verdict words, and the
propose-then-stop workflow. Read it before recommending or performing a
cavvy edit.

### Foray Protocol

`Tools/jjk/jjai0/jjaie_foray.md` holds the remote-dispatch protocol whole — its
vocabulary, its six `jjx_` commands with their params, and its workflow. When
the user says "foray" or asks to run something on a remote machine, read that
file before the first call.

### Unfurl Protocol

`Tools/jjk/jjai0/jjaie_images.md` holds the tools for VIEWING and UPDATING SVG/PNG
files (diagrams / rendered images) on the diagram viewer. When the user says
"unfurl" or asks to view or update an image, read that file for the precise
directions.

### Commit Discipline

When working on a heat, use `jjx_record` for commits with heat/pace affiliation.

`files` has three readings, and **omitted is not the same as `[]`**:

**Whole dirty tree** (the default — omit `files`):
Use `jjx_record` with `{identity: "CORONET", intent: "description"}`. Everything dirty in the billet rides, as at wrap. Prefer this: work left out of a list stays dirty and later rides the wrap under a machine-written message instead of your intent.

**Exactly these paths** (pass a list):
Use `jjx_record` with `{identity: "CORONET", files: ["file1", "file2"], intent: "description"}`. Use it to bank a coherent slice deliberately — a mechanical sweep apart from a design change. Anything dirty and unlisted is named back to you in a warning.

**Heat-affiliated commit** (no active pace, but part of heat work):
Use `jjx_record` with `{identity: "FIREMARK", ...}` — the same three readings apply.

**Empty commit** (work that changed nothing on disk — a verification run, a platform proof):
Use `jjx_record` with `files: []` explicitly. The commit lands, affiliated, carrying `intent` as its whole content; a warning names it afterward. `intent` is required here — there is no diff to describe.

Synthesize intent from the conversation — describe *what* was accomplished, not *how*.

**A notch after this kraal's own wrap is demoted, not refused.** A settled pace owns no further work, so naming its coronet lands the commit affiliated to its **heat** instead, and says so. Nothing is lost: the commit stands on the billet branch and reaches remote custody with it. What it has is no pace to carry it — so **slate one and name that commit in its docket**. The monitum you read in the moment is the only place the debt is recorded; nothing greps for it later.

**Two staleness lines, and both name `jjx_refit`.** Your orders carry a billet behind trunk's remote counterpart where the dispatch found one, and `jjx_record` reports it again on every commit. Both are monita: they report, you remedy. Act on the first one you see: a refit is cheapest before your work piles onto a stale base, and a re-saddled pace inherits its first saddle's fork point, so a session's opening is not a first sighting. After the merge has landed, call `jjx_girth` for a re-read describing the tree you now hold; where you met the line on a `jjx_girth` re-read, read that payload first — `gazette_out.md` is cleared on the refit's entry like any other call's.

**What you owe either line is the same at every tier: attempt the refit, and obey the verdict.** The verb is open to you whatever your standing. Don't weigh your own tier before calling it, and don't retry or route around a refusal. **A refit voids criteria you have already driven**, so re-drive them on the merged tree before you close.

**A second staleness line in the same pace surfaces to the operator before you refit, naming which criteria you have already driven.** **The third line and every later one surface the same way**, each naming the criteria standing driven at that moment. Two exceptions carry no threshold and refit unasked regardless: a pace the staleness itself blocks outright, and a refit a refused wrap demands.

When user says "notch", determine context (pace or heat affiliated) and invoke `jjx_record` with the appropriate identity.

**Where a spec edit goes.** Specs and guides are edited in the kraal's **vulgate billet** — the corpus work tree standing beside your work billet, on this pace's own branch — and recorded with `jjx_record {vulgate: true}`, which commits and consigns to remote custody in one act; the wrap converges what is committed onto the vulgate, and a corpus-billet-behind line on a `jjx_girth` re-read or a notch means run `jjx_refit` now, while your pace context is live. Full law: JJSVS-studbook.adoc "Knowledge homing"; the converge, the landing gate and the `Vulgate:` trailer are JJSRWP-wrap.adoc; the billet choreography, refit's corpus axis and the stile's clearing are JJSVD-dispatch.adoc; the design home is JJSAE-embillet.adoc.

**Where your estate runs a name census, its readings speak at three moments, and what they are is a pull door.** Where a notch prints a note you did not write, a write door refuses with words that are not Job Jockey's, or a wrap's corpus landing is refused by a named reading, the outspan you stand in carries `jjaie_halmote.md`, and that door says what ran, which of the three moments can refuse, and what each outcome asks of you — read it the first time one reaches you. Before you notch a file that ships beyond its own tree, keep from it every guide or spec acronym and every veiled path, since the census's closed-document reading reads each shipping Bash and Rust file for those acronyms as whole words in their struck case.

**A notch precedes every door drive, build doors included.** A kennel door refuses outright while the repository a collar stands in carries an uncommitted or untracked file, and the refusal names the notch, so a dirty-tree refusal met at a build door is that law biting rather than a build failure to diagnose. Notch first whatever the drive is for. Ground: BKSCL-Collar.adoc "Door Law".

**Where your outspan carries census doors and your work billet carries `tt/vow-b.Build.sh`, those doors owe that billet's whistle and engine build before their first drive** — `../<billet>/tt/bkw-w.Whistle.sh`, then `../<billet>/tt/vow-b.Build.sh`, driven by relative path from the outspan — since the doors probe the artifact the billet's engine build lays and die for want of it, and the outspan's own build door refuses there.

**Additive-Only Discipline:**

- Claude is **additive only** — make commits, never discard changes
- If something looks wrong, ASK — do not "fix" by discarding

**Forbidden Git Commands — NO exceptions, NO "safe" variants:**
- `git reset` — ALL forms: `--hard`, `--soft`, `--mixed`, with paths, without paths. Even `git reset HEAD <file>` (unstaging) is forbidden — it's too close to destructive variants and Claude will reason its way into worse forms.
- `git restore` — ALL forms: working tree, staged, with `--source`, without
- `git checkout <file>` — when used to discard changes (navigating branches is fine)
- `git clean` — ALL forms
- `git stash` — ALL forms

**What to do instead:**
- Staging wrong? Run `jjx_record` with the correct file list — it handles staging
- Made a mistake? Make a new commit that fixes it — additive, not destructive
- Landed a wrong write through a census act or a render? Notch it, then `git revert` that notch — additive, and exactly the write, since every act demands a clean tree before it writes
- Confused by repo state? ASK the user
- Need to undo something? Explain the situation to the user and let them decide

**JJX Commands Are Self-Committing:**
`jjx_enroll`, `jjx_testimonium`, `jjx_record`, and other state-mutating jjx commands create git commits internally. **`jjx_testimonium` (wrap) commits ALL uncommitted changes** — code files and gallops state together in one commit. Do NOT follow `jjx_record` or `jjx_testimonium` with another commit command, and do NOT notch immediately before or after a wrap — the tree will already be clean. If a commit command says "Nothing to commit", check `git status --short` and accept the result.

**Diagnose Before Escalating:**
When a command fails, check the simplest explanation first. "Invalid params" means wrong field names — check the MCP Command Reference above, don't guess.

### Blotter-Lock Recovery is Human-Only — NO Exceptions

A JJ blotter lock guards a SHARED store (the studbook): behind a held lock
there may be a live session on another machine, and a wrong break can hand a
live reader a stale image with nothing to catch it. **Cashiering (breaking) a
blotter lock is a HUMAN-ONLY ceremony. Claude never performs it, never begins
it, never prepares it — no exceptions, no matter how obvious the recovery
looks.**

A lock-held refusal names its case, and the case it names governs:
- **Contention** — "The holder still runs, so this is contention: re-run once, and if it refuses again, report it verbatim and stop." It is not this ceremony: re-run once as it directs, which is not acting toward the lock. "a parallel call of this very session holds the commit lock" names a call of your own, with the same remedy; where it adds "Its process is this very server, so a call of this session whose client went away may still hold it: if no other call of yours is in flight, reconnecting the door ends that call and frees the lock.", report it to the operator, whose reconnect is the remedy. Call nothing crashed that the refusal did not.
- **The cashier case** — "The holder's process is gone: it crashed, and the lock is stranded." It names the operator's doors, and every word below binds.
- **A holder the refusal cannot read** — "The holder is on another station, so whether it runs cannot be read here." or "The lock names no station and process, so whether its holder runs cannot be read." It names both remedies: re-run once; met again, report it verbatim and stop.

A lock whose holder's process is gone from this station is cleared by the next call that takes it, which says so in its result — "The holder's process was gone, so this call cleared its stranded lock and took it"; the line asks nothing of you.

On a refusal saying the holder is gone, on any lock-held refusal met again on its re-run, and on ANY lock-held refusal whose case you are unsure of (dispatch, notch, wrap, curry — any jjx command):

1. STOP the refused operation.
2. Report the refusal to the operator VERBATIM.
3. Do nothing further toward the lock. The operator recovers it themselves,
   in their own terminal — sight with `tt/jjw-c.CheckLock.sh`, break with
   `tt/jjw-C.ClearLock.sh`, never an agent action.

Forbidden — all of it the on-ramp:
- Invoking `tt/jjw-C.ClearLock.sh` as an agent action. These are operator
  terminal doors; an agent that reaches them names them and stops.
- `./tt/jjw-C.ClearLock.sh` — with or without `BURE_CONFIRM`; presetting or
  skipping its typed gate is routing around the ceremony's heart.
- `./tt/jjw-c.CheckLock.sh` or the vvx cashier verb in service of lock
  recovery — "it's only the read-only sight" is how a cashier begins.
- Raw git against the lock ref or the studbook to clear, delete, or
  force-update a lock — the same break by a worse road.

The rationalizations ARE the hazard — each has already nearly caused the
failure this rule exists to prevent, and each is barred: "it's only the
read-only sight step"; "the wrap/recovery flow told me to resume and the lock
blocks it"; "the lock is obviously mine / obviously stale / obviously dead";
"the refusal message names the remedy, so running it is sanctioned" (the
remedy is named for the OPERATOR); "the operator authorized it in chat" (the
gate reads the operator's terminal, which an agent does not have — hand them
the card). A held lock never strands you: the correct next action is always
available — stop, surface, wait.

### Heat Birth and Death Are the Operator's

A heat is the operator's unit of planning. **Never call `jjx_create` or
`jjx_archive` on your own initiative** — recommend, and stop.

**Read `Tools/jjk/jjai0/jjaie_consuetudinary.md` before you call
either verb.** Not after, and not only when the act feels doubtful.
Nominating a heat, retiring one, a board that reads finished, an operator
asking whether to cut a heat or end one: open the door first.

**Fence width: `jjx_create` and `jjx_archive`, and nothing else** — every other
verb, the heat-level ones included, stays yours under its ordinary discipline.

### Wrap Discipline

**NEVER auto-wrap a pace.** When work is complete, report outcomes and ask the user explicitly: "Ready to wrap ₢XXXXX?" — then wait for confirmation before running `jjx_testimonium`. Your orders print this for every session, at every tier.

**An unmet wait refuses the wrap, and it is not yours to lift.** The refusal is about the record, never about your work: report it verbatim and stop. The remedy is the blocking work landing, or an express `jjx_unhopple` on the operator's word — neither is a move you make to get your own pace closed.

**Notice friction as it happens.** At wrap you will be asked what snagged — re-reads forced by a missing pointer, a docket aimed at a renamed file, a confusing paddock, a verb that fought you — and an honest answer is assembled across the whole session, never recalled at its end. Ask yourself "what snagged?" assuming something did, not "did anything snag?"; at wrap the pull is to tidy up and under-report. Carry the answer forward as you work.

**How to wrap is a pull door.** `Tools/jjk/jjai0/jjaie_wrap.md` holds the procedure — composing the summary, the spook trailer with its five seats, and what the close commits. Read it once the operator has confirmed, before calling `jjx_testimonium`.
