# The cavvy — cross-sire replication maintenance

This file is an **excursus** (`jjsuc_excursus`): held out of the standing
session load and read on demand, from the "Rodear Protocol" stub in
`Tools/jjk/volis_jjk.md`. Sessions that maintain the replication registry
are rare; the ones that do not should not carry this vocabulary.

It is a **mirror** of the design home, never the home itself. Canon is
`JJSAV-cavvy.adoc` (design) and `JJSCCV-cavvy.adoc` / `JJSCRD-rodear.adoc` (the
two operation contracts). Where this file and those disagree, they win.

It deliberately does **not** carry the mount directive's wording. That line
fires in sessions standing in a ringer-hosting sire that never open this door,
so its text is settled where every session can see it, not here.

## What the cavvy registers

One fact: **this tree is a byte copy of that tree, in another sire.** The
registry is one JSON document, `cavvy.json`, at the studbook store root beside
`pedigrees.json` — store-level because a replication fact is cross-sire by
nature, and sharding it per sire would forfeit the census.

Three nouns, and they nest:

- **manada** — one registered family, keyed by a plain spoken *name* (`buk`).
  A name, never an identity: nothing durable references it, and renaming it is
  an ordinary edit. A kit registering as several byte-copied subtrees is
  several manadas under prefixed names.
- **taproot** — the manada's origin: a `(sire, path)` pair, its fields sitting
  directly on the manada.
- **ringer** — a copy: its own `(sire, path)` pair, so a *routed* copy living
  at a different path is as expressible as a mirrored one.

**Ringers are variants, not descendants.** A fix sometimes lands in a ringer
first. Any reading that treats every difference as "the ringer is wrong" erases
the distinction the grade roster exists to draw.

## The three rosters

Each is closed by the schema — an out-of-roster token dies at the parse, and
the refusal enumerates what was accepted, so none of these need memorizing to
be used correctly.

**Grade** — what synchrony is owed. Every ringer declares exactly one, and the
declaration is the point.

| Grade | Wire | Means |
|---|---|---|
| bitted | `jjocge_bitted` | Must equal the taproot. Ringer-side edits refuse at wrap; taproot changes mint debt. |
| ponied | `jjocge_ponied` | Drift permitted and **reported**. Upgrades are deliberate consumer-sired paces. |
| brumby | `jjocge_brumby` | Declared never-sync. No debt, no reporting — the freeze is on the record. |

The three-way split exists to close the unexamined middle: before it, "not yet
upgraded" and "never will be" were indistinguishable, and the second hid inside
the first.

**Transport** — how a sync is conducted. The registry never records *how* an
overlanded ringer syncs, and that is deliberate.

| Transport | Wire | Means |
|---|---|---|
| trailered | `jjocte_trailered` | The act is fully implied by the registration: byte-copy the registered paths from the pinned taproot. |
| overlanded | `jjocte_overlanded` | Bespoke — an installer or a scripted transform. The cavvy detects staleness only; a session *proposes*, the operator commands. |

**Shape** — `jjocse_tree` or `jjocse_file`, declared on the manada for the
whole entry. A shape change reports as a violation rather than a confusing
diff.

## The verdict words

What `jjx_cavvy` speaks per ringer. The order below is the order it decides in,
and the order is load-bearing.

1. **brumby → silence.** Not walked at all; the declaration already happened.
2. **taproot unsound → no verdict** for its ringers. Blaming a ringer for its
   taproot's fault would be a lie.
3. **shape mismatch → violation**, spoken *before* any byte verdict.
4. **current** — byte-equal to the taproot. Plain and unminted.
5. **outfooted** — differs, but the ringer's bytes stood at the taproot path at
   some committed position. Purely behind.
6. **shied** — differs and matches no prior taproot state. Diverged.

Plus **unreadable**, which is not a verdict: a station that has not cloned a
sire reports no verdict there and it is counted apart from drift. A station's
own ignorance is never a ringer's divergence.

The read **never fetches.** Every sire is read at its trunk's remote
counterpart as that clone last gleaned it, and the report says so — a census is
only as current as the images the station holds.

## The workflow

`jjx_cavvy` reads, `jjx_rodear` writes. Mode is named by the command, never
inferred.

1. `jjx_cavvy {}` — the census and drift report land inline; the registry's
   canonical body lands in `gazette_out.md` under a lede-less `# jjezs_cavvy`
   header.
2. Edit that body. **The editable form IS the canonical JSON** — there is no
   projection dialect, so the round trip is the whole parse contract.
3. Move it to `gazette_in.md`, header unchanged, and call `jjx_rodear
   {note?: "..."}`.

**The notice is lede-less** — `# jjezs_cavvy` alone. A lede is refused, not
ignored: the cavvy is one store-level document with no identity to aim at.

**Create, update and delete are not modes.** All three are just "the staged
body differs from what stands". A body equal to what stands lands no commit and
succeeds.

**Each landing is one commit of its own**, carrying no other mutation, so the
store's journal is the registry's own edit record.

**The body carries a `jjocrn_revision` stamp — leave it where it stands.** It
names the equerry that last wrote the store, so a write overwrites it with the
writing equerry's own number and a hand-typed value never survives. Editing or
deleting it does nothing; there is simply no reason to touch it.

**An elder-schema refusal is not a damaged store, and the write verb is not its
cure.** If a read reports the store was written at a revision this equerry does
not know, the store is *sound* and this equerry is behind it — the write door
bars the replacement outright with an INTERDICTUM, because an equerry that cannot
represent the store would drop every key its schema does not name. Report it and
stop; the remedy is rebuilding the equerry and re-dispatching, which is an act
outside the call. Do not reach for `jjx_rodear` to tidy it.

**A mistyped key is dropped, not refused.** An unknown key is ignored so an
equerry can read its predecessor's store — but in a hand-edited body it is
usually a misspelling, and a misspelled ringers key drops that manada's ringers
entirely. The verb names the shed keys and reports the census that landed.
**Read both before moving on.**

## The fence

**Registry edits are operator-only. Propose, then stop.**

The fence stands on *initiative*, not on the verb. There is no confirm gate, and
its absence is deliberate rather than pending: do not add one, do not simulate
one, do not read it as permission. It is a different fence in the same doorway
rather than a missing one, and that argument is `JJSCRD-rodear.adoc`
"No confirm gate".

A good recommendation, so the stop has a path:

- which manada, and the exact `(sire, path)` anchors;
- the grade and transport you would declare, and why;
- for a grade *change*, the sentence you would put in `note` — because that
  commit message is the fork's whole record;
- what you observed that prompted it (a census line, an unregistered tree).

**bitted → ponied is the dangerous one.** It is how a fork gets legitimized.
Git is the journal and the census reports present state only, so nothing but
that commit message will ever say why.

## Registering a host

A ringer's host is named by its **sire handle**, and a handle exists only in a
pedigree. Hosting a ringer therefore requires enrollment — a repo with no
pedigree cannot appear in the cavvy at all, and the write door refuses it by
name, enumerating the declared handles.

Pedigree edits stand behind the same initiative fence.

## Path form

Registered paths are **literal anchors, never rules.** No globs, no leading or
trailing slash, no `.` or `..` segments — a claim would be intensional, while a
registered path is a byte-copy scope whose extent must be deterministic.

Within one sire, no two registered paths may be identical or nested, across
every manada's taproot and ringers alike. The door reports every finding at
once rather than one per retry.

Shape against reality is deliberately **not** a door check: a registration may
precede the tree, and reality is the census's to report.
