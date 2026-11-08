# JJK Slating — authoring a docket and a paddock

Read this before you author a docket or a paddock body — at `jjx_enroll`, at
`jjx_redocket`, or at `jjx_curry`. It is an **excursus** (`jjsuc_excursus`):
held out of the standing session load and read on demand, reached from the
trigger line in `Tools/jjk/jjai0/jjais_jjk.md`.

What stays in the standing load is deliberately the armor rather than the craft: the graph
question, the stale-by-saddle filter, the docket anti-patterns, the semantic
linefeed rule and the mid-execution posture all bind at a moment of temptation
or across scattered moments, and none of them defers. So does the rule that a
coronet never appears in paddock prose and silks never appear in either — a
prohibition whose failure is silent.


**Docket posture:** A docket is a specification of needed change, not architectural commentary. It articulates what done looks like — the completion criterion goes under a `## Done when` heading (never a bare `## Done`, which misreads as a record of work already finished) — and any cinched constraints, which go under a `## Cinched` heading (never `## Locked`: *lock* is reserved for the concurrency-sense git-ref commit lock); it points at sources rather than restating them. A short `## Character` line naming the cognitive posture earns its keep; the rest of the docket should resist filling in.

**The delegate test — ask it at every slate.** Before you write the docket, ask whether a fresh session could carry this to done with the operator absent. If it could not — if the work needs the operator's word *mid-execution* to proceed at all — the pace is a **lope**, and you slate it one: `jjx_enroll {kind: "hackamore"}`. Never write a rough pace with stop-clauses ("surface X and wait", "ask before deciding Y") as a substitute. A stop-clause is a lope in disguise, and it fails in both directions: a session either executes straight past it at exit zero or is handed full-ceremony orders for work that is a conversation. The kind is the honest form of that instruction, and it is the only form anything mechanical can see.

**A lope's docket names the section of law that decides its question.** Name the spec section, the guide clause, or the paddock cinch the question turns on, and name it as the thing to be read rather than as the thing you have summarized — a session opens on the law, not on your framing of it. A docket that frames the question without naming its law hands the session a fork the corpus has already closed, and the session reads past the answer it is holding. This is the slate-side half of what the orders' lope protocol line asks of the session: the line demands the premise a position rests on and the sentence that would falsify it, and neither demand can be met against standing material the docket never pointed at.

**A lope's done-when is authored under a wider licence.** Three exits close a lope and all three are honest completions: the thinking settles and banks, the work finishes cheap inline on the operator's word, or **the premise proves faulty** — the reframing recorded where it becomes authority, and successor work slated against it. Write the done-when so the third exit is a completion rather than a failure; a done-when that forecloses it was written for an ordinary pace, and is evidence the work was never conversational to begin with.

**A spec edit can owe a render.** When a docket's spec edits reach the sources a render reads — a codex's include walk for an `offprint`, a handbook sheaf and its codex's mapping section for an `itinerarium` — write the render in that codex's sire into the docket as work the pace owes. Where that sire's tree will not stand in the pace's kraal, write instead that the close names the debt and slates a render pace.

**Slate-time vs saddle-time.** The saddled session reorients against the project as it stands, with CLAUDE.md and specs already loaded. Hand off goal and boundary, not the analysis; depth belongs in the slate's precis and commit message, not the docket body.

**Scratch is named, never located.** A docket needing a scratch clone, a throwaway build or an intermediate file names the kraal's scratch directory, which the saddled session's orders declare, and never describes or locates one.

**The precis names its seat and quotes the word it answers.** Where the slate is made at a pace's seat, name that pace by its coronet in the precis; and quote verbatim the seat's own sentence the operator was answering when they gave the slate its word. A pace's roster names the chats that worked it and never the chat that slated it, which was a tenure of the slating seat, so the precis is how a later reader reaches that chat: `jjx_hansard` over the coronet it names, then a summon of the chat that roster lists.

**Scope and prescription are two dials.** Prescription is the docket's own words, and the conduct home's threshold reads it: a docket that outgrows it moves depth into the precis rather than cutting a cinch the work needs. Scope is how much the pace changes, and the sitting bounds it: one invariant a fresh session can hold, land and verify in one sitting, leaving the tree lawful when it lands. Where a pace must split, split at a landing boundary, where each half leaves the tree lawful, never at a prose boundary. A docket's length is evidence about prescription alone; a pace's refit count is evidence about the environment it ran in, not about its size.

**Reference discipline.** Single-operator workflow runs paces in heat order, so explicit dependency markers in docket prose are usually overspecified; coronet cross-refs earn their keep only when the dependency crosses heats or skips order — rare, not never.

**Paddock posture.** A paddock articulates shape, cinched decisions, and what done looks like — not a progress journal. Git log and `jjx_steeplechase` are the journal; the paddock is the shape. The sections it carries, and the two laws its done-when is written under, are homed in JJS0 (`jjsp_paddock` and "The Done-When"), and both laws bind at the curry: an open question bearing on the done-when is slated as a lope rather than banked as paddock prose — prose blocks no retirement where a slated pace does — and a done-when the work has outgrown is reworded in the same curry that records the learning, the two moving together or the done-when quietly ceasing to describe the heat. Paddock and docket own-voice prose is durable-document register (MCM `mcm_skidmark`): no revision markers, no dated change narration — the curry/notch commit carries the when; dated frozen records carried verbatim inside them keep the dated-artifact exemption. A coronet is an enrollment-ledger key, not shape data, and silks are display names that drift via the editor's `silks` field — neither belongs in paddock or docket prose. `jjx_show` is the authoritative source for what paces exist; refer to a heat or pace by its purpose, not its identifier or display name. The three identity types fare differently against the lifecycle:
- **Firemarks** — lifecycle-bound (a heat keeps its firemark for life) → fine in both paddock and docket prose.
- **Coronets** — stable but invalidated by pace-state ops (drop, dight, reorder, transfer) → barred from paddock prose; in docket prose only for genuine cross-order or cross-heat dependencies (see **Reference discipline**).
- **Silks** — evolve freely via dight → barred from *both* paddock and docket prose.

When editing a paddock or docket for other reasons, prune any coronet refs or silks-shaped kebab strings you find.

