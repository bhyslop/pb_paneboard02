# Parcel emplace — first drive anywhere

Dated record of the first exercise of the VVK parcel machinery's *emplace* half.
The release half (collect, brand, tarball) was already well driven;
emplace was deferred to first use, and this is that first use.

Target consumer: this repository.
Parcel: `vvk-parcels/vvk-parcel-1055-buk-only.tar.gz`, brand `1055`, commit `4ba8bc9be47326d234745d9912de8420cd95fb93`, `vvbk_kits: ["buk"]`.
No fresh brand was cut; the parcel already standing committed here is the one driven.

## Verdict

**The emplace is blocked in this consumer and did not land.**
The machinery behind the blocking guard is sound — proven in an isolated replica — so the block is one guard, not a broken mechanism.
A second, independent blocker stands behind it and would keep this consumer dark even if the first were lifted.

## Interface, as discovered from the parcel

The installer ships at the parcel root and is aimed at the consumer's own BURC file:

```
./vvi_install.sh /path/to/target/<moorings-dir>/burc.env
```

It resolves the platform, then `exec`s the parcel's own bundled binary:

```
kits/vvk/bin/vvx-<platform> vvx_emplace --parcel <parcel-dir> --burc <burc-path>
```

`vvx_emplace --help` reports exactly two options, `--parcel` and `--burc`.
There is **no** kit-selection flag, no `--only`, and no `--force`.

Note the bundled `kits/vvk/bin/vvx-darwin-arm64` is the installer's *engine*, not installed payload —
a "buk-only" parcel legitimately carries the vvx binary, and emplace correctly declines to emplace it.

## Finding 1 — kit-set guard is equality where it should be containment (BLOCKING)

Invocation and exact signature:

```
$ ./vvi_install.sh /…/.buk/burc.env
Installing VVK parcel...
  Platform: darwin-arm64
  Target: /…/.buk/burc.env
emplace: installing kit assets...
  parcel: /…/parcel1055
  burc: /…/.buk/burc.env
emplace: error: Kit mismatch: parcel contains [buk] but target expects [buk,jjk,vvk]
EXIT=1
```

This consumer declares `BURC_MANAGED_KITS=buk,jjk,vvk` and genuinely carries all three
(`Tools/buk`, `Tools/jjk`, `Tools/vvk`, plus the project's own `Tools/pbk`).
The parcel's brand declares `["buk"]`.
Emplace compares the two sets for **equality** and refuses on any difference.

Why this reads as a defect rather than a policy:
a single-kit parcel exists precisely to update one kit in a consumer that manages several.
Under an equality guard a buk-only parcel can only ever be emplaced into a buk-only consumer,
which makes the shape close to unusable and contradicts why this parcel was cut and committed here.
The guard should almost certainly test **containment** — parcel kits ⊆ target managed kits — not equality.

Supporting evidence that the guard has simply never been contradicted before:
every prior parcel standing in `vvk-parcels/` is a full three-kit parcel exactly matching this consumer's declared set.

| parcel | vvbk_kits |
|---|---|
| vvk-parcel-1010 … 1015 | `["buk","jjk","vvk"]` |
| vvk-parcel-1055-buk-only | `["buk"]` |

The buk-only parcel is the new shape, and it is the first artifact this guard rejects.

**Not worked around.** Editing `BURC_MANAGED_KITS` to satisfy the guard would falsify a true
statement about this consumer, and the repair belongs in the emplace guard.

## Behind the guard, the machinery is sound

Driven in a throwaway replica of this consumer whose *sole* difference was `BURC_MANAGED_KITS=buk`:

```
emplace: success - 43 files, 0 commands, 0 hooks
emplace: no vvk in this parcel - no binary emplaced
emplace: nothing was committed - review the working tree and commit any install delta
EXIT=0
```

- `diff -rq <replica>/Tools/buk <parcel>/kits/buk` → **no output, exit 0**: the installed tree is byte-exact to the payload.
- Emplace is a *replacement*, not a merge: it deleted kit files absent from the parcel
  (`buhj_*`, `bujb_*`, `bujp_preflight.sh`, `burn_*`, `burp_*`) and added `burs_template.sh`,
  `buts/butcdc_color.sh`, `claude-buk-acronyms.md`, plus a `.vvk/` brand record.
- Tools-never-commit holds, and the closing line says so explicitly.
- Two ordering guards fire ahead of the payload work and are correctly ordered:
  the kit-set check, then `emplace: error: Target is not a git repository: <root>`.

## Finding 2 — the parcel cannot re-light this consumer on its own (BLOCKING, independent)

Driven in the same replica **after a fully successful emplace**, an existing tabtarget still dies identically to the pre-install state:

```
Tools/buk/burc_regime.sh: line 40: buv_regime_enroll: command not found
EXIT=127
```

Cause: this consumer's moorings launcher `.buk/launcher_common.sh` is a legacy hand-rolled launcher.
It sources only `buc_command.sh` and `burc_regime.sh`, and never sources `buv_validation.sh` or `bubc_constants.sh`.
The kit's own modern launcher `Tools/buk/bul_launcher.sh` does source them, in order, and additionally handles `BURS_TACKROOM`.
The parcel ships **no** moorings launcher and emplace **does not** regenerate the stubs, so the stale launcher survives the install.

Confirmed by repair-in-replica. Rewriting a launcher stub to the canonical modern shape that
`buut_launcher` itself now generates:

```bash
#!/bin/bash
# Launcher stub - delegates to pbw workbench
source "Tools/buk/bul_launcher.sh"
bul_launch "${BURC_TOOLS_DIR}/pbk/pbw_workbench.sh" "$@"
```

moves the failure past the launcher and into the workbench:

```
Tools/pbk/pbw_workbench.sh: line 85: bug_require_clean_tree: command not found
EXIT=127
```

That is dispatch reaching the workbench — the launcher was passed.
The remaining error is the consumer's own `pbk` kit, which no parcel ships, and is a separate question.

## Finding 3 — tabtarget shapes are mixed (adjacent, non-blocking)

Two tabtarget shapes coexist here. The modern shape routes through the `z-launcher.sh` trampoline,
which is the sole file that knows this project keeps moorings in `.buk` and which exports `BURD_CONFIG_DIR`
— a value `bul_launcher.sh` requires and refuses without:

```
bul_launcher: BURD_CONFIG_DIR unset — dispatch must run through z-launcher
```

| tabtarget | shape | logging |
|---|---|---|
| `pbw-b.BuildProof.sh`, `pbw-t.ProofOfConceptTimed.10.sh` | modern (z-launcher) | no — `BURD_NO_LOG=1` |
| `vvw-r.RunVVX.sh` | modern (z-launcher) | yes |
| `buw-tt-cbn.*`, `buw-tt-cl.*` | legacy (direct exec of the stub) | yes |
| `jja-c/i/u.*` | legacy, and reference a `launcher.jjw_workbench.sh` that does not exist in `.buk` | yes |

Consequence for anyone re-driving this: the legacy-shaped tabtargets cannot pass a modernized stub,
and the only *logging* tabtarget already in the modern shape is `vvw-r.RunVVX.sh`, which starts the MCP stdio server.
So there is currently no cheap logging tabtarget that both routes through z-launcher and terminates on its own.

## Finding 4 — the launcher refusal is invisible to the log corpus (observation)

Logging is performed by `bud_dispatch.sh`, downstream of the launcher.
Every failure described above dies *in* the launcher, so **nothing is written** to `../logs-buk/` —
no `hist-`, no `same-`, no update to `last.txt`.
Confirmed: no `hist-buw-tt-cl-*` file has ever existed.

This cuts usefully as an acceptance test — the mere existence of a `hist-` file for a tabtarget proves the launcher was passed —
but it also means a consumer dark at the launcher leaves no trace in the log corpus at all,
which is worth knowing before diagnosing a silent station from logs.

## Superseded docket premise

The docket predicted the block would be the station regime refusing the unenrolled `BURS_TACKROOM` key
(present in the shared `../station-files/burs.env` since 260818).
That refusal is real in principle — the installed `burs_regime.sh` does not enroll the key while the parcel's does,
as an optional `buv_string_enroll BURS_TACKROOM 0 512` — but it is **third in line**.
Two nearer failures fire first, and the key is never reached.
Once the launcher is modernized, the same parcel resolves the key question too,
since `bul_launcher.sh` handles `BURS_TACKROOM` explicitly.

## What a repair would need

1. Emplace's kit guard tests containment rather than equality (engine-side; blocks everything else).
2. A decision on whether moorings launcher stubs are consumer-owned or parcel-refreshed —
   today they are consumer-owned and silently outlive the kit they bootstrap, which is what made this consumer dark.
3. This consumer's stubs and legacy tabtargets brought to the current shape.

Items 2 and 3 are the same class of hazard: the moorings layer is the one part of the
bootstrap that no parcel governs, so it drifts against the kit without any check noticing.
