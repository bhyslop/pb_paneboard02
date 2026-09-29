# JJK Groom — planning on a heat

Read this when the operator says "groom", or whenever you are about to plan on a
heat rather than execute a pace. It is an **excursus** (`jjsuc_excursus`): held
out of the standing session load and read on demand, reached from the trigger
line in `Tools/jjk/volis_jjk.md` "Groom Protocol" and from the `groom` row
of the Quick Verbs table.

One duty binds whether or not this door is opened, so it stays resident with the
trigger: a groom reads the paddock's done-when against the remaining paces and
reports the gap, slating nothing on its own initiative.

### Groom Protocol

When user says "groom":

1. Write one or more `# jjezs_halter <firemark>` notices to `gazette_in.md`, then run `jjx_show {remaining: true}` (paddock + remaining dockets land in `gazette_out.md`).
2. Read `gazette_out.md` directly for full paddock and pace docket content — never the persisted tool-result blob or the studbook-journaled gallops JSON.
3. Display overview: heat silks, progress, remaining paces with dockets — and the **sire roster**, which that same call rendered inline: every declared sire marked elected, writable, readable or unmarked for this heat. It belongs in the first act because it bounds every pace you are about to cut: a pace may be slated to write only a sire the heat's write half admits, and to read only one its read half does, so a roster read after the slating is a roster read too late.
4. **Read the paddock's done-when against the remaining paces, and report the gap.** A standing step, run at every groom rather than only when the board looks finished — the whole failure this catches is that the board *does* look finished. Take each done-when clause and ask which remaining pace carries it; a clause no pace answers is work never cut, and naming it here is cheap where naming it at the archive door is late. Report the gaps and stop: slating them is the operator's call, as `jjx_archive`'s own quittance gate makes it (see Heat Birth and Death). Not every gap is work never cut — sometimes the clause is what drifted, the heat having delivered something its done-when no longer describes, and where that is what you find, propose the rewording beside the gap (JJS0 `jjsp_paddock` and "The Done-When") so the operator's disposal is one word either way. Proposing is the whole of it: the curry that lands a rewording is theirs to direct, exactly as the slating is.
5. Enter planning mode: suggest structural operations (slate, rail to reorder, reslate to refine dockets, paddock review).

