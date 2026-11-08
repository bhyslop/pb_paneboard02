# JJK Wrap — Closing a Pace

Read this before you wrap, once the operator has confirmed. It is an
**excursus** (`jjsuc_excursus`): held out of the standing session load and read
on demand, reached from the trigger line in `Tools/jjk/jjai0/jjais_jjk.md` "Wrap
Discipline" and from the dispatched-session conduct core, which names the read
before any session reaches this moment.

What stays in the standing load is deliberately short, and the split is not by topic. The
prohibition against reaching this moment on your own initiative binds *before*
the impulse: an agent that will read the wrap rules when it decides it is time
to wrap has already made the decision the rule exists to prevent. So the
never-auto-wrap rule is always loaded. So is the instruction to notice friction as
it happens — friction is observed across a whole session and only reported at
its end, and an agent that first meets the spook question here reconstructs
from memory and under-reports, which is the exact bias the channel exists to
resist. What follows is what is safe to arrive at the moment of use.

## Composing the close

Always include a summary of the work: `jjx_testimonium` with `{coronet: "CORONET",
summary: "Added bitmap displays to orient output"}`. The agent always has
context about what was accomplished — include it.

A designee closing under a warrant also passes `criteria` — a string, one criterion per line, or an array of strings, one per element — each line a criterion with the outcome observed; it rides the wrap's commit message as the `Warrant-criteria:` trailer.

## The spook (friction) trailer

Alongside `summary`, pass `spook` — a short, grep-friendly report of friction
*you* hit during this chat: re-reads forced by a missing pointer, a docket aimed
at a renamed file, a confusing paddock, a verb that fought you.

It rides the wrap's commit message as a single-line `Spook:` trailer; absent or empty
becomes `Spook: none`. Grep the corpus with
`git log --all --format='%b' | grep '^Spook:'`.

Open each item with one word naming the seat of its fault — docket, warrant, instruction, door, mine — then the item.
The set is closed at five, and a snag fitting none is reported under the
nearest word with its reason in the item itself. This is a convention in the
trailer's own text and nothing the equerry parses: the trailer stays one
free-text line, and the words are there so a pass can count by seat instead of
reading every item to learn whose fault it was.

- `docket` — what the slate said: the pace's own instructions, missing, stale or
  aimed wrong.
- `warrant` — what the bridle said: the tier, the effort, or a criterion that
  could not be driven as written.
- `instruction` — standing doctrine a session read: a context file, a guide, an
  excursus that misled, omitted, or could not be found at the moment of use.
- `door` — a tool or a gate: a verb that refused wrongly, a door that fought
  you, a refusal whose remedy was not the one it named.
- `mine` — the session's own slip: a misreading, a wrong turn, an act taken
  before the thing that governed it was read.

Some events are not snags, and the trailer leaves them out. Each is a guard
or a fence doing the work it was built for, and nothing in it wants repair:

- A breeching refusal of any strap — the seat, the pipe, the null sink. The
  guard refused before anything ran; the plain re-run is the whole remedy.
- A mid-pace binary-staleness refusal. The fence held while another landing
  moved the engine; the rebuild and reconnect are the operator's, and they are
  the cure.
- A lock-held refusal that cleared on its one re-run. That was contention,
  and the refusal named the re-run.

Two cases on those same guards stay reportable, because then the guard itself
is what wants repair:

- A guard that refused wrongly — a strap, a fence or a lock barring an act it
  should have let through — goes under `door`.
- A guard that let a held act through — a `cd`, a pipe or a null sink that ran
  unrefused — goes under `mine`, the act being yours and the gap the guard's.

Refits are not snags either, and they are counted rather than dropped: say how
many refits the pace took in the summary, where the fence's frequency is
evidence, and not in the trailer.

Report only first-person in-chat events you observed — those are the actionable
ones. "Nothing snagged" is a first-class answer: pass `spook: "none"` (or omit
it). You are required to answer, never required to invent.

The always-loaded layer has already told you to ask "what snagged?" assuming
something did, and to notice it as it happened rather than reconstruct it here.
Read back over the session before you answer.

## What the close commits

**Wrap commits the whole billet.** Like a listless `notch`/`jjx_record`,
`jjx_testimonium` stages and commits **every** dirty file in the tree — by design:
each chat works in its own dedicated billet, so everything dirty there is this
pace's estate, delivered together at wrap.

**And it lands your corpus work.** The same close converges the kraal's vulgate
billet onto the vulgate — one merge commit whose first parent is the vulgate's
tip and whose second is the billet's, pushed fast-forward-protected — and the
`Vulgate:` trailer on the commit message names the produced position, `none` when the
billet carried nothing new. What the converge delivers is what you COMMITTED:
notch corpus edits through the knowledge door (`jjx_record {vulgate: true}`)
before you wrap, because uncommitted corpus work is reported and never swept.

Two ways the corpus half stops the wrap, both leaving the pace open and the
billet standing in remote custody:

- **The landing gate refuses.** A corrector from the census tree's tracked
  roster judged the would-land corpus and said no — its verdict rides the
  refusal verbatim. Repair in the vulgate billet, notch, wrap again.
- **A lost race.** The vulgate moved under the converge. Run `jjx_refit`
  (the corpus axis is the ordinary enfold), then wrap again.

## Name evidence

A pace that minted or evicted a name, or whose warrant carries a lint
criterion, owes the evidence of it in its summary.
