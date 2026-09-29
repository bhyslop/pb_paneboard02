# The halmote — the estate's own readings, at three moments

This file is an **excursus** (`jjsuc_excursus`): held out of the standing
session load and read on demand, from the Commit Discipline stub in
`Tools/jjk/volis_jjk.md`. Read it the first time a notch prints a note you did
not write, a write door refuses a document with words that are not Job
Jockey's, or a wrap's corpus landing is refused by a named reading.

It explains the mechanism and never a finding. A note or a refusal carries its
own words, and those words stand on their own; nothing here interprets them.

## What a roster is

An estate may run a census tool beside Job Jockey. Where it does, it elects a
**census tree** — one repository on the station — and the session's register,
written when the session was launched, names that tree. Job Jockey knows no
tool by name. It knows three directories inside the census tree, one per
moment, and whatever executable files stand in a directory are that moment's
**roster**. Each file is one **entry**. Entries run in name order; a name
opening with a dot is not an entry.

Job Jockey hands each entry one argument and reads its exit:

- **exit 0** — the entry is content, and says nothing.
- **exit 33** — the entry has something to say, and what it printed on stdout is
  carried to you verbatim.
- **anything else**, a timeout (120 seconds), or a file that will not start —
  the entry **faulted**. What a fault costs depends on the moment, below.

**An estate that declares no census tree meets none of this.** No register row
names one, so no roster is reached at any moment: no notes after a notch, no
refusals at a write, and a wrap reports its landing gate as undeclared and lands
the corpus ungated.

## The three moments

### After every notch — the scrutators

When `jjx_record` has committed, each scrutator runs with the session's working
directory as its argument. A scrutator **reports and never refuses**: the commit
has already landed, whatever it says.

An entry that has something to say appears as a warning line naming it — the
`'<name>' reading over this work` — with the time it took, and its words
beneath. Every other outcome is silent: an entry content with the work, an
entry that faulted, a roster directory that is absent or unreadable, a register
that cannot be read. A notch that prints no note has told you nothing about
whether a reading ran.

**What to do with a note.** Read it. It speaks about the work you just
committed. Where it names something you did, repair it and notch again; where
you judge it wrong or out of this pace's scope, say so to the operator and carry
it into the wrap summary. Never treat a note as a refusal — nothing was refused.

### Before every docket, paddock or warrant write — the quaesitors

At `jjx_enroll`, `jjx_redocket`, `jjx_curry` and `jjx_apostille`, after the
gazette is read and before anything is written, each staged body — a docket, a
paddock, a warrant, an abeyance brief — is copied to a scratch file beside the
gazette, and each quaesitor runs with that file's path as its argument. A
quaesitor **can refuse the write.**

Job Jockey's own heading and identity rules are judged in the same pass, so a
document meets one refusal listing every finding, whoever raised it. The
refusal says nothing was written, shows the first findings inline, and writes
the whole list to `gazette_out.md` under a `jjezs_quaesitorium` header. A
finding raised by a roster entry is labelled with the entry's name.

A quaesitor that **faults** is a finding too, labelled a station defect rather
than a defect in the document: a write door never reads a fault as a pass, so an
entry whose tool is missing refuses every write until it is repaired. A roster
directory that is absent or unreadable is silent, and the write proceeds under
Job Jockey's own rules alone.

**What to do with a refusal.** Answer the findings in the body, re-write
`gazette_in.md` from scratch — the gazette was consumed on entry — and call
again. Where a finding says the entry could not run, the document is not at
fault and no edit reaches it: report the refusal verbatim to the operator and
stop.

### At every wrap that lands corpus changes — the correctors

At `jjx_testimonium`, only when the vulgate billet would move the corpus trunk,
the would-land corpus is laid out whole in a scratch directory and each
corrector runs with that directory as its argument. A corrector **can refuse
the landing.** A wrap whose vulgate billet carries nothing new runs none.

- **A corrector refuses** (exit 33): the wrap stops, its words ride the refusal
  verbatim, nothing lands on either trunk, and the pace stays open. Repair the
  corpus in the vulgate billet, notch it through `jjx_record {vulgate: true}`,
  and wrap again.
- **A corrector faults**, the roster directory is absent, or it cannot be read:
  the refusal leads with `INTERDICTUM` and names a station defect. The corpus is
  not at fault and re-wrapping unchanged meets the same refusal. Report it
  verbatim and stop; the repair is the operator's.
- **The roster directory stands empty**: the landing passes. Empty is the
  estate's honest statement that nothing gates its corpus.

## Where an entry's words come from

Every word a note or a refusal carries beyond the entry's name, its timing and
Job Jockey's own framing is the entry's, printed by a program the estate chose
to run. Job Jockey never summarizes an entry, never rewords one, and carries no
knowledge of what any entry checks. Where a note's meaning is unclear, the
estate that installed the tool is the one to ask — not this door, and not the
conduct.
