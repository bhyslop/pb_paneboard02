# JJK Mass Reslate — The Show → Reslate Bridge

Read this when one mechanical edit has to reach many dockets at once. It is an
**excursus** (`jjsuc_excursus`): held out of the standing session load and read
on demand, reached from the trigger line in `Tools/jjk/volis_jjk.md`, in
the gazette workflow bullets beside the paddock read-modify-write.

Nothing here is load-bearing for correctness. An agent that never opens this
door authors each `# jjezs_reslate <coronet>` notice by hand and lands exactly
the same result, more slowly — which is why the door is safe. The resident layer
keeps what a wrong turn would cost: the one-heat constraint and the sibling-door
refusal both live with `jjx_redocket` in the command reference.

## The bridge

Mass docket editing — the show output *is* the reslate input, bridged.

`jjx_show` populates `gazette_out.md` with the resolved set (paddock[s] + every
pace docket); `jjx_redocket` consumes `gazette_in.md` as `jjezs_reslate`
notices, **and takes no other kind of notice** — the docket door carries
documents of one kind, so a `jjezs_paddock` notice left in the bridged file
refuses the whole call, naming `jjx_curry`. Dropping the paddocks in step 2 is
therefore the bridge working, not tidiness; to revise a paddock in the same
sitting, do it as its own `jjx_curry` call.

1. **Pull**: write the target selection to `gazette_in.md` — one `# jjezs_halter ₣XX` notice (or several, a heterogeneous set) — then call `jjx_show {"remaining": true}` and read the emitted `gazette_out.md`.
2. **Bridge**: drop the `# jjezs_paddock …` notices (and their bodies) — required, not cosmetic; one left standing refuses the call — and rewrite each output-typed `# jjezs_pace <coronet>` header to the input-typed `# jjezs_reslate <coronet>`. The pace *bodies* are already valid reslate dockets — only the slug changes:
   ```
   # keep the pace notices, drop the paddocks, rename the slug
   awk '/^# jjezs_paddock /{skip=1;next} /^# jjezs_/{skip=0} !skip' gazette_out.md \
     | sed 's/^# jjezs_pace /# jjezs_reslate /' > gazette_in.md
   ```
3. **Edit**: apply the actual docket change to `gazette_in.md`. For a uniform mechanical rewrite across many dockets, this is one more pass (portable in-place form, no GNU/BSD `-i` divergence):
   ```
   sed -e 's/^## Locked$/## Cinched/' -e 's/^## Done$/## Done when/' \
     gazette_in.md > gazette_in.tmp && mv gazette_in.tmp gazette_in.md
   ```
4. **Replumb**: `jjx_redocket {}` — mass reslate consumes every `jjezs_reslate` notice in one call, echoing a per-coronet diff.

## When to reach for it

Reach for the bridge when the edit is the same mechanical shape across N dockets
(rename a heading, retag a term); when each docket needs its own novel prose,
author each `# jjezs_reslate <coronet>` notice by hand instead.

There is no reslate dry-run; trust the per-coronet diff `jjx_redocket` echoes.
