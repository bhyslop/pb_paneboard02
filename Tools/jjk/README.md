# Job Jockey Kit

Job Jockey is how one person and Claude Code carry a long piece of work together
without either of them losing the thread.

The problem it solves is memory. A chat session forgets everything when it ends;
a person forgets more slowly but forgets too. So Job Jockey keeps the plan
outside both of them, in a record that survives every session, and gives each
session exactly the slice of that record its own work needs.

You do three things with it. You break work into **heats** — bounded initiatives
with an end you can name — and each heat into **paces**, the discrete actions
that get it done. You open a session by typing a door at your shell, which
stands up a working area for one pace and launches Claude Code inside it. And
you talk to that session in a small vocabulary of verbs — *mount*, *notch*,
*wrap* — that it turns into changes to the record.

Nothing about this is autonomous. Every session you get is one you asked for.

## The record

The plan does not live in your project. It lives in a repository of its own —
the **studbook** — which every project you work on shares.

That separation is deliberate and it buys three things. Your project's history
stays about your project, uncluttered by planning churn. Work that spans several
repositories is planned in one place instead of being split across them. And the
plan travels: a second machine clones the studbook and sees the same board.

What the studbook holds, per heat:

- The **paddock** — the heat's shape. What it is for, what has been decided and
  will not be reopened, and what done looks like. It grows as the heat teaches
  you things.
- A **docket** per pace — what that one pace must accomplish. Not how; a docket
  says what done looks like and points at what the session should read.
- The **steeplechase** — the running journal. Every commit, every wrap, every
  structural change, in order, with the reasoning the session wrote at the time.
- Two aggregates, `jji_itch.md` and `jjz_scar.md`, for work you are deliberately
  not doing now and work you have deliberately closed.

You never edit these files by hand. A session reads and writes them through
commands, and every command commits its own change.

## Opening a session

Sessions start at your shell, from a door in `tt/`. You name what you want to
work on; the door works out which repository that implies, stands up the
directories, and launches Claude Code in them.

If you are unsure which door you want, `tt/jjw-0.Help.sh` lists every door with
what it takes and what it does. It sorts to the top of `tt/`, which is what the
digit is for.

| Door | What it opens |
|------|---------------|
| `jjw-s.Saddle.sh` | **Saddle** — a working session on one pace. Name a pace and you get that pace; name a heat and you get its next actionable pace. |
| `jjw-l.Lunge.sh` | **Lunge** — a groom session on one heat or one pace: assessment with no working area, for reading and planning rather than doing. |
| `jjw-p.PlanHeats.sh` | **Ostler** — the planning seat over any number of heats, where dockets are cut and refined. Naming no heat opens it over everything at once. |
| `jjw-o.Oversee.sh` | **Drover** — the ruling seat above a wave of working sessions. It reads what those sessions reported and rules on whether anything further is warranted. |
| `jjw-i.InstantWork.sh` | **Vaquero** — a seat for work you want to do right now. Name a heat and then a repository; the session writes up the job itself, does the work, and closes before the chat ends. Both are required, and the repository must be one the heat already works in. |
| `jjw-c.CheckLock.sh` | Report every lock the studbook holds and who holds it. Read-only. |

Three more doors change something durably enough that they confirm before
acting, which is why their names end in a capital letter:

| Door | What it does |
|------|--------------|
| `jjw-M.Muck.sh` | Destroy a working area left standing. |
| `jjw-A.ApplyEstateRules.sh` | Install this machine's shared context texts, which the working doors refuse to run without. |
| `jjw-C.ClearLock.sh` | Dismiss a lock-holder that has gone derelict. |

Breaking a lock is a person's act and only a person's. Behind a held lock there
may be a live session on another machine, and a wrong break hands that session a
stale view with nothing to catch it. A session that meets a held lock stops and
reports it; you decide.

The doors read only what you type. Where your shell happens to be sitting says
nothing about what gets opened — the record decides that.

## What a session stands in

A door stands up a **kraal**: the set of directories one session works in, torn
down when that session ends.

- The **outspan** is the seat — where the session sits, where its scratch and
  its message files stand. It holds no repository and dies with the kraal.
- A **billet** is a working area on your project, checked out to a branch of that
  pace's own. Work happens here and nowhere else.
- Read-only peers stand beside them when the pace needs to read a repository it
  may not write.

When the pace is wrapped, the billet's branch lands on trunk as one commit,
carrying its own history as ancestry. The detailed commits stay reachable; the
trunk stays legible.

## Working a session

Inside a session you speak verbs. Say the word and the session runs the command
behind it.

The loop is three verbs long. You *mount* to begin — the session reads the
pace's docket and its heat's paddock, states the goal in a sentence, and
proposes an approach before touching anything. You work together. You *notch*
whenever there is progress worth committing, and *wrap* when the pace is done.
A session never wraps on its own; it asks you first.

Around that loop, the rest:

*Reading* — **muster** lists heats, **parade** shows one heat or pace whole,
**scout** searches, **fettle** says what could start right now and what is
holding the rest back, **riem** reports which repository a pace belongs to.

*Shaping a heat* — **groom** reviews a heat against its own definition of done,
**slate** adds a pace, **chivvy** adds one at the front, **cantle** adds one just
after the current pace, **reslate** rewrites a docket, **curry** revises the
paddock, **rail** reorders paces, **restring** moves paces to another heat,
**dight** renames one, **whorl** edits a pace's name, repository or kind,
**furlough** edits a heat's, **hopple** and **unhopple** set and lift the waits
between paces.

*Deciding how a pace runs* — **bridle** designates a pace for a model tier and
writes the brief its session will follow; **unbridle** lifts that.

*Heats* — **nominate** starts one, **retire** ends one. Both are yours alone: a
session may recommend either, and never performs one unasked.

*Elsewhere* — **foray** runs work on another machine, **unfurl** puts an image on
the viewer, **cavvy** reads the registry of files copied between repositories and
**rodear** writes it.

## Identities

Three names attach to the work, and they are not interchangeable.

A **firemark** identifies a heat: `₣` and two characters, as in `₣CJ`. A
**coronet** identifies a pace, and what you see printed is `₢`, the pace's
current heat, an interpunct, and the pace's own five characters — `₢CJ·CAAKR`.
The five characters are the identity and never change; the heat in front of them
says where the pace lives today, and would be re-read if it moved. Commands
accept either form.

**Silks** are the readable name — `fix-quota-check`, `audit-portability` — and
they are for people, not for lookups. They can be changed at any time, which is
exactly why nothing resolves by them.

## Naming prefixes

Every name Job Jockey mints begins with `jj` and a letter saying what kind of
thing it is.

| Prefix | Names |
|--------|-------|
| `jjw-` | The doors in `tt/` |
| `jjx_` | The commands a session calls |
| `jjezs_` | The headers on messages passed between a session and the record |
| `jjls_` | The branch a billet stands on |
| `jjqb_` | The directories of a kraal |
| `jji_` | The deferred-work aggregate, `jji_itch.md` |
| `jjz_` | The closed-work aggregate, `jjz_scar.md` |

## Installation

Job Jockey installs together with the rest of the kit family; there is no
separate step of its own. Its commands reach a session through a single tool, so
a session that can call that tool has the whole surface.

Restart Claude Code after installing, so the new tool is registered.

## Glossary

Every Job Jockey word you will meet in output, in a door name, or in a session's
own speech.

- **abuttal** — The written customs shared by everything on this machine, and the door that installs them: two files every session loads before it loads anything of your project's.
- **billet** — The working area a session does its work in: your project, checked out on a branch belonging to the pace being worked. It is torn down when the session's kraal is.
- **blotter** — The studbook's lock. One writer at a time; a session that finds it held stops and reports rather than waiting or breaking it.
- **bridle** — Designate a pace to run at a particular model tier, and write the brief its session will follow. A pace with no designation is waiting for someone to make this judgment.
- **cantle** — Add a pace immediately after the one being worked. Named for the saddle's raised back — the position just behind the rider.
- **cashier** — Dismiss a lock-holder that has gone derelict. A person's act only, confirmed at the terminal; no session performs it.
- **cavvy** — The registry of which files and directories stand copied across your repositories, at what expected degree of sameness. A cavvy is the herd of spare mounts a rider draws from.
- **chivvy** — Add a pace at the front of the heat, ahead of everything else.
- **cinch** — A decision recorded in a paddock or docket and not to be argued again. Both the noun and the act of recording one.
- **coronet** — A pace's identity. The five characters are the pace and never change; printed, they come prefixed by `₢` and the heat the pace currently sits in — `₢CJ·CAAKR`. A coronet is a marking just above a horse's hoof.
- **curry** — Revise a heat's paddock. Currying is grooming with a curry comb: working over the whole animal, not one spot.
- **dight** — Change a pace's readable name. An old word for arraying or adorning.
- **docket** — What one pace must accomplish. It states what done looks like and points at what to read; it does not prescribe how.
- **drover** — A ruling session standing above a wave of working sessions. It works no code and holds no pace: it reads what those sessions reported and rules on whether anything further is warranted. It opens no session of its own — you do that.
- **estancia** — The planning seat opened over no particular heat: the console for everything at once. An estancia is the great ranch house.
- **fettle** — What could start right now, and what is holding everything else back. Asks only about the waits between paces, so a pace with nothing before it is ready even if it needs your attention to run.
- **firemark** — A heat's permanent identity: `₣` and two characters, as in `₣CJ`. A firemark is a brand burned into the hide.
- **foray** — Run work on another machine.
- **furlough** — Edit a heat's own record: its name, whether it is running or paused, and which repositories its paces may touch.
- **gazette** — The two files a session and the record pass documents through. The session writes what it wants recorded into one and reads what it asked for out of the other.
- **groom** — Review a heat: its shape, its remaining paces, and whether anything its paddock calls for was never turned into a pace. Grooming is tending the horse, not riding it.
- **heat** — A bounded initiative with an end you can name, three to fifty paces long. It is either racing or stabled, and when its work is done it retires.
- **hopple** — Make paces wait on another pace. Hopples are the straps that keep a horse from wandering.
- **itch** — Work worth remembering and not worth doing now, whatever its size. It is a reminder to you and carries no authority: nothing acts on an itch until you say so.
- **kind** — What a pace *is*, as distinct from what tier it runs at: a lope, a poort, or neither. A pace carries one kind at most.
- **kraal** — Everything one session stands in: its seat, its working area, and any read-only companions. A kraal is a stock enclosure, and it is torn down when the session ends.
- **lope** — A pace whose work is a conversation with you rather than something to execute. It finishes when the thinking settles, when the answer turns out to be a few small changes, or when the question turns out to have been the wrong one.
- **lunge** — Open a session that reads and plans but does not work: no working area, deliberately. Lunging is working a horse from the ground on a long line.
- **mount** — Take up a pace: read its docket and its heat's paddock, state the goal, and propose an approach before anything is touched.
- **muck** — Destroy a working area left standing behind a session that did not clean up. Mucking out is exactly what it sounds like, and it is confirmed before it runs.
- **muster** — List the heats.
- **nominate** — Start a heat. Yours alone; a session may recommend one and never creates one unasked.
- **notch** — Commit progress mid-pace, with a message saying what was accomplished. A notch is a tally cut into a stick.
- **ostler** — The planning seat, over any number of heats: where dockets are cut, refined and designated. An ostler is the inn's horse-keeper, who tends every horse and rides none.
- **outfooted** — A copy that has fallen behind the original it tracks, with no changes of its own. Archaic racing usage: beaten on pure speed, nothing wrong with the horse.
- **outspan** — A session's seat: where it sits and keeps its scratch. It holds no repository and dies with its kraal. Outspanning is unyoking the team at the end of a stage.
- **overlanded** — A copy whose update has no simple recipe — an installer or a transform someone has to conduct. Overlanding is driving stock the long way, by a route that has to be known.
- **pace** — One discrete action inside a heat. It carries a docket and gets worked in one session.
- **paddock** — A heat's shape: what it is for, what has been decided and will not be reopened, and what done looks like. The paddock is where horses gather before a race.
- **parade** — Show one heat or one pace whole. The parade is the pre-race walk past the stands.
- **poort** — The kind carried by a pace that must run alone against something everything else shares. Before it starts, you confirm nothing else is running. A poort is a narrow mountain pass, taken single-file.
- **racing** — A heat that is actively being worked. The other state is stabled.
- **rail** — Reorder the paces within a heat.
- **reslate** — Rewrite a pace's docket. Doing so discards any tier the pace had been designated for, since that judgment was made about the old text.
- **restring** — Move paces from one heat to another. A string is the set of horses one rider is responsible for.
- **retire** — End a heat. Yours alone, and it is preceded by an audit: the paddock's definition of done, read clause by clause, each one met with its evidence or named unmet.
- **riem** — Report which repository a pace belongs to, or audit every pace that names none. A riem is the thong tying one ox into the team, so an ox with no riem is exactly what the audit hunts.
- **ringer** — A copy that tracks an original elsewhere. A ringer is a horse run under another's name.
- **rodear** — Write the registry of copied files. Yours alone; a session recommends and stops. A rodear is the roundup where cattle are sorted between owners.
- **saddle** — Open a working session on a pace.
- **scar** — Work deliberately closed, kept because something was learned. Not shelved, not pending: closed, in `jjz_scar.md`.
- **scout** — Search the record.
- **shied** — A copy holding content its original never had: diverged, not merely behind. Copying over it would destroy work, so it is always reported rather than fixed. The horse swerved off the line.
- **silks** — A readable name, for people rather than for lookups. Silks change freely, which is why nothing resolves by them; they are a rider's racing colours.
- **sire** — A repository a pace works in. Which one is a property of the pace, and it is what decides which project a door checks out for you.
- **slate** — Add a pace to a heat, with its docket.
- **spook** — Something in the workflow itself that snagged — a stale pointer, a confusing docket, a verb that fought you. Reported at wrap, so it can be fixed rather than re-suffered.
- **stabled** — A heat that is paused: still live, still planned against, but nobody is working it. The other state is racing.
- **steeplechase** — A heat's running journal: every commit and every closure in order, each carrying the reasoning written at the time.
- **studbook** — The repository the whole plan lives in, shared by every project you work on and separate from all of them.
- **taproot** — The authoritative copy of a file or tree that others track.
- **unbridle** — Lift a pace's tier designation, returning it to undesignated.
- **unfurl** — Put an image on the viewer, or replace one already there.
- **unhopple** — Lift a wait between paces.
- **unsound** — A copy whose original could not be read on this machine, so no comparison is possible and no guarantee about it is in force.
- **veduta** — An image put on the viewer, with its optional dark counterpart. Italian painters' term for a rendered view — a scene made to be looked at, which is all Job Jockey knows about it.
- **warrant** — The brief written when a pace is designated for a tier: what its session should do, and the criteria that would prove it done. Its session follows it, drives every criterion, and stops rather than closing on a failure.
- **whorl** — Edit a pace's readable name, its repository, or its kind. A whorl is the hair spiral recorded on a horse's passport — the mark that tells one animal from another.
- **wrap** — Close a pace: commit what is outstanding, write the journal entry, and land the branch. A session asks before wrapping; it never decides on its own that work is finished.
