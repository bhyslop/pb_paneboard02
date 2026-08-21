# pb relight — moorings census, taken at mount

The per-file state of pb's bootstrap layer,
recorded before any modernization touched it,
so the re-light has a fixed baseline to be judged against.
Taken 260821 on branch `jjls_pace/203570_CAAKB` with a clean tree.

The pace warrant carried its own bridle-time description of this layer.
The census contradicts it in two places, recorded below rather than smoothed over:
the tabtarget population is mixed rather than uniformly legacy,
and two of the five moorings stubs already stand in a near-modern shape.

## Kit copy under the bootstrap

`Tools/buk` is brand **1017**, commit `401904f89d608a2ee75962c0a264fd20df8fa78d`, dated 260628-0815,
declared by `.vvk/vvbf_brand.json` as a three-kit install (`buk`, `jjk`, `vvk`).
43 files.

It is newer than the moorings that bootstrap it, and this is the whole shape of the darkness:

- `bul_launcher.sh` — present, and already the modern shared launcher.
  It requires `BURD_CONFIG_DIR` and refuses without it.
- `bubc_constants.sh` — present, and already carries `BUBC_launchers_subdir="rbml_launchers"`.
- `buut_tabtarget.sh` — present, and already emits the `BURD_LAUNCHER` tabtarget shape
  and the four-line stub into `${BURD_CONFIG_DIR}/rbml_launchers/`.
- `burc_regime.sh` — **no containment guard**.
  The stale-launcher refusal and band `119` postdate this brand,
  which is why pb's death is an incidental `buv_regime_enroll: command not found`
  rather than a named refusal.

So pb's installed kit already speaks the current bootstrap contract in every respect that matters here.
Nothing about the modernization has to wait on the freight;
the freight's contribution at this seam is the guard that makes a future relapse legible.

## Moorings — `.buk/`

The launchers sit flat in the moorings dir.
The kit expects them one level down, in `rbml_launchers/`,
which is where `buut_launcher` emits and where `buut_list_launchers` reads.
No stub here can be regenerated through the emitter while the directory it targets does not exist.

| file | shape |
|---|---|
| `burc.env` | consumer-authored config regime; `BURC_MANAGED_KITS=buk,jjk,vvk`, `BURC_TOOLS_DIR=Tools`, `BURC_TABTARGET_DIR=tt` |
| `launcher_common.sh` | **legacy shared launcher** — the darkness itself. Sources `buc_command.sh` and `burc_regime.sh` only; never `buv_validation.sh`, never `bubc_constants.sh`. Defines `bud_launch`. Superseded whole by `Tools/buk/bul_launcher.sh`. |
| `launcher.buut_tabtarget.sh` | legacy — sources `launcher_common.sh`, delegates via `bud_launch` to `buut_cli.sh` |
| `launcher.buw_workbench.sh` | legacy — sources `launcher_common.sh`, delegates via `bud_launch` to `buw_workbench.sh` |
| `launcher.pbw_workbench.sh` | near-modern — sources `bul_launcher.sh` and calls `bul_launch`, but by a stub-relative path (`${BASH_SOURCE[0]%/*}/../Tools/buk/…`) rather than the law's repo-root-relative `Tools/buk/bul_launcher.sh` |
| `launcher.vvw_workbench.sh` | near-modern — same divergence, delegating to `vvw_workbench.sh` |
| *(absent)* | `launcher.jjw_workbench.sh` — **referenced by three tabtargets and does not exist.** `Tools/jjk/jjw_workbench.sh` is present, so the stub is simply missing. |

## Tabtargets — `tt/`

Nine files, three shapes.

| file | shape |
|---|---|
| `z-launcher.sh` | **older trampoline contract.** Takes a workbench id as `$1` and composes the launcher path from it; exports `BURD_CONFIG_DIR` and `BURD_LAUNCHER`. The kit's contract instead has the tabtarget export `BURD_LAUNCHER` as a bare basename and resolves it under `${moorings}/rbml_launchers/`. |
| `buw-tt-cbn.CreateTabTargetBatchNolog.sh` | legacy — `export BUD_LAUNCHER=".buk/launcher.buw_workbench.sh"`, direct exec |
| `buw-tt-cl.CreateLauncher.sh` | legacy — same. This is the stub emitter's own tabtarget. |
| `jja-c.Check.sh` | legacy — direct exec of `.buk/launcher.jjw_workbench.sh`, **which does not exist** |
| `jja-i.Install.sh` | legacy — same, and the tabtarget the warrant names as pb's legacy install door |
| `jja-u.Uninstall.sh` | legacy — same |
| `pbw-b.BuildProof.sh` | z-launcher, old id-arg shape; `BURD_NO_LOG=1` |
| `pbw-t.ProofOfConceptTimed.10.sh` | z-launcher, old id-arg shape; `BURD_NO_LOG=1` |
| `vvw-r.RunVVX.sh` | z-launcher, old id-arg shape; logging |

`buw-pe.ParcelEmplace.sh` — the maintenance door — **is absent from pb** and must be generated.

Against the pace's first criterion, the baseline is:
`BUD_LAUNCHER` appears in 2 files, `BURD_LAUNCHER` in 1 (`z-launcher.sh`).

## Parcels standing in the tree

`vvk-parcels/` holds six committed parcels — `1010`, `1011`, `1013`, `1014`, `1015`, and `1055-buk-only`.
None is the freight this pace drives.
`1055` is the parcel of the first drive, and its bundled binary predates the containment relaxation,
so a fresh mint from the kit trunk is the freight.

## Registry, read through the cavvy

    manada 'buk' — taproot jj:Tools/buk, declared tree
      rb:Tools/buk      ponied  overlanded  outfooted
      pb:Tools/buk      brumby  overlanded  (never-sync — not reported)

The row this pace closes on is `pb:Tools/buk`, and it reads as the docket predicted.
