# Bash Utility Kit (BUK)

A portable bash infrastructure for building maintainable command-line tools, with configuration management, dispatch routing and validation.

## Overview

BUK provides a three-layer architecture for bash-based CLI tools:

1. **BUK Core** (`Tools/buk/*.sh`): portable utilities with no project-specific knowledge.
2. **BURC** (`mymm_moorings/burc.env`): project-level configuration defining repository structure.
3. **BURS** (`../station-files/burs.env`): developer and machine-level configuration, never committed.

This separation lets one BUK serve any repository, configured through the assignment files of its [Config Regimes](#Config-Regime) rather than code modification.

## Core Concepts

### [Moorings Launchers](#Moorings-Launcher)

<a id="Moorings-Launcher"></a>**Moorings-Launcher**

The moorings launcher stub a tabtarget reaches through the trampoline: a script in the moorings' `buml_launchers/` directory, named `launcher.{workbench}.sh`, that execs the shared script `bul_launcher.sh`, which delegates to dispatch with the [workbench](#Workbench) the stub names as coordinator.
Its two-line shape is kit law, and the kit's [Moorings-Launcher](#Moorings-Launcher) door, buut\_launcher, writes it, so a stub is regenerated rather than edited by hand.

A [Moorings-Launcher](#Moorings-Launcher) is the environment gate of every tabtarget invocation.
The shared script it execs validates [BURC](#BURC) and [BURS](#BURS) before dispatch runs, so a configuration error is caught before any [formulary](#Formulary) starts.
A tabtarget a [testbench](#Testbench) invokes passes through its own [Moorings-Launcher](#Moorings-Launcher) too, which revalidates the [Config Regimes](#Config-Regime) and establishes a fresh dispatch environment, so the testbench's state never bleeds into the code under test.

**Naming Pattern**: `launcher.{workbench_name}.sh`

**Location**: the `buml_launchers/` subdirectory of the moorings directory.
The subdirectory name is fixed by the kit; the moorings directory itself is yours to name.

**Examples**:

- `mymm_moorings/buml_launchers/launcher.buw_workbench.sh`: the [Moorings-Launcher](#Moorings-Launcher) of the BUK workbench.
- `mymm_moorings/buml_launchers/launcher.myw_workbench.sh`: the [Moorings-Launcher](#Moorings-Launcher) of a consumer's workbench (`myw` is a naming specimen throughout this file, standing for your own prefix).

**Creation**: use `tt/buw-tt-cl.CreateLauncher.sh` to create a new [Moorings-Launcher](#Moorings-Launcher).

### Workbenches

<a id="Formulary"></a>**Formulary**

The coordinator script dispatch runs for a tabtarget, routing its [colophon](#Colophon) to the implementation.
A [formulary](#Formulary) holds no command logic of its own: it kindles a zipper, a sourced module whose kindle enrolls each [colophon](#Colophon) with the executable CLI module and command implementing it, the channel by which that command receives its folio, and a one-line description, and it hands the [colophon](#Colophon) to the zipper's lookup, `buz_exec_lookup`, which execs the enrolled module.

Two types exist: the [workbench](#Workbench) routes commands for a kit, and the [testbench](#Testbench) routes tests.

The [Moorings-Launcher](#Moorings-Launcher) names the [formulary](#Formulary) that dispatch runs as its coordinator, the [colophon](#Colophon) its command and the tabtarget's further arguments after it.

<a id="Workbench"></a>**Workbench**

A [formulary](#Formulary) that routes commands for a kit.
Named `{prefix}w_workbench.sh`.
It kindles BUK's dispatch and zipper modules and then its own zipper, and every command it routes runs in an executable CLI module that zipper enrolls.

**Examples**:

- `Tools/buk/buw_workbench.sh`: the BUK workbench, which manages BUK itself.
- `Tools/myk/myw_workbench.sh`: a consumer's workbench (naming specimen).

`Tools/buk/buw_workbench.sh` is the whole pattern in under eighty lines, and the rules it follows are stated in Module Contract below.

**Key Characteristics**:

- Routes by zipper lookup, never by a hand-written `case`.
- Kindles BUK's dispatch and zipper modules, then its own zipper.
- Delegates every command to an executable CLI module.
- Crash-fast error handling (`set -euo pipefail`).

### Testbenches

<a id="Testbench"></a>**Testbench**

A [formulary](#Formulary) that routes tests for a kit.
Named `{prefix}t_testbench.sh`.
Its scenarios invoke the tabtargets under test and assess what each did, and BUK itself ships none.

**Two-Layer Dispatch**:

```
tt/myt-s.Scenario.sh → Moorings Launcher → BUD → myt_testbench.sh
                                                       │
                                                       ▼ invokes
                                             tt/myw-p.Provision.sh → Moorings Launcher → BUD → myw_workbench.sh
                                                       │                                    ▲
                                                       ▼ assesses                           │
                                                  [pass/fail]                          environment
                                                                                          gate
```

The names in the diagram are naming specimens.

### Zipper

A zipper is a module obeying the Module Contract below whose kindle enrolls each colophon with its implementing module and command, and sets a symbolic constant holding the colophon string.
Testbenches use those constants instead of hardcoded colophon strings.

**Naming Pattern**: `{prefix}z_zipper.sh`, in the `Tools/{toolkit}/` subdirectory.

**Examples**:

- `Tools/buk/buz_zipper.sh`: the base registry every zipper enrolls into.
- `Tools/buk/buwz_zipper.sh`: the BUK workbench zipper, a complete zipper to copy.

**Key Functions**:

- `buz_enroll VARNAME colophon module command channel description` enrolls one colophon; all six arguments are required, and `VARNAME` is set to the colophon string.
- `buz_exec_lookup colophon base_dir [args...]` is the workbench's dispatch: it execs `base_dir/module command`, with the folio in `BUZ_FOLIO`.

**Design Rationale**:

- Symbolic constants eliminate hardcoded colophon strings in tests.
- Parallel arrays keep one row per enrolled colophon.
- Each toolkit's zipper owns its colophon registry.

### TabTargets

#### The TabTarget Pattern

A TabTarget is a design pattern for CLI discoverability that trades argument flexibility for command visibility.
The key insight: `ls tt/` shows all available commands, and `tt/prefix-<TAB>` narrows to a category.

**Essential characteristics**, independent of any implementation:

- Shell scripts in a dedicated directory, conventionally `tt/`.
- The filename encodes the command's identity and its embedded parameters.
- Tokens are parsed by a configurable delimiter, typically `.`.
- The script delegates immediately to a dispatch mechanism.
- It contains no business logic, being purely a routing layer.

BUK implements the pattern as bash dispatch, and the rest of this section describes that implementation.

#### BUK TabTarget Implementation

In BUK, TabTargets are lightweight shell scripts in the `tt/` directory that delegate to workbenches through [Moorings Launchers](#Moorings-Launcher).

**Naming Pattern**: `{colophon}.{frontispiece}[.{imprint}...].sh`

**Location**: the `tt/` directory at the project root, configurable through [BURC\_TABTARGET\_DIR](#burc_tabtarget_dir).

**Token Delimiter**: configurable through [BURC\_TABTARGET\_DELIMITER](#burc_tabtarget_delimiter), typically `.`.

#### TabTarget Anatomy

TabTarget filenames encode structured information in publishing terminology:

<a id="Colophon"></a>**Colophon**

The routing identifier in a tabtarget Inscription.
A [colophon](#Colophon) determines which [formulary](#Formulary) handles the dispatch.
Includes the hyphen and the case-significant suffix that follows it — the whole of the signet\_case that Tabtarget Vesture declares — as its identity (e.g., `rbw-cr`).

<a id="Frontispiece"></a>**Frontispiece**

The human-readable description in a tabtarget Inscription.
A [frontispiece](#Frontispiece) uses PascalCase and describes the operation.

Appears after the [colophon](#Colophon) and dot separator.

Examples: `Build`, `Rack`, `RunVVX`, `Saddle`.

<a id="Imprint"></a>**Imprint**

An optional embedded parameter in a tabtarget Inscription.
An [imprint](#Imprint) specifies a target, instance, or configuration variant.

Appears after a second dot separator following the [frontispiece](#Frontispiece).

Examples:

- `tadmor` in `rbw-cr.Rack.tadmor.sh`
- `srjcl` in `rbw-cr.Rack.srjcl.sh`

**Simple example** (no imprint):

```
buw-tt-ll.ListLaunchers.sh
├── Colophon: buw-tt-ll      (workbench routes on this)
├── Frontispiece: ListLaunchers (human reads this)
└── Extension: sh
```

**Parameterized example** (with imprint):

```
rbw-cr.Rack.tadmor.sh
├── Colophon: rbw-cr         (workbench routes on this)
├── Frontispiece: Rack        (human reads this)
├── Imprint: tadmor          (passed to implementation)
└── Extension: sh
```

Multiple tabtargets can share the same colophon and frontispiece but differ by imprint:

```
rbw-cC.Charge.tadmor.sh    → same command, different targets
rbw-cC.Charge.srjcl.sh
rbw-cC.Charge.pluml.sh
```

**Examples**:

- `tt/buw-tt-ll.ListLaunchers.sh`: list the [Moorings Launchers](#Moorings-Launcher) (no imprint).
- `tt/buw-rcv.ValidateConfigRegime.sh`: validate BURC, the project's [Config-Regime](#Config-Regime) (no imprint).
- `tt/rbw-cr.Rack.tadmor.sh`: rack a bottle on tadmor (with imprint).

**Creation**: the `buw-tt-c*` doors create tabtargets:

- `buw-tt-cbl`: batch, keeping a Station Log, the default.
- `buw-tt-cbn`: batch, keeping no Station Log, for secret-handling operations and for a door that runs before a station file stands.
- `buw-tt-cbo`: batch, for a door whose command writes its own record.
- `buw-tt-cil`: interactive, keeping a Station Log, for shells.
- `buw-tt-cin`: interactive, keeping no Station Log, for secret entry.

These doors write every tabtarget a repository stands, a kit's and your own alike.
A kit's door carries nothing of the repository it stands in, so the door they write is the door the kit ships, flags and all.

**Which form a door takes is a fact of the door, never of the roster.** A zipper enrolls how a door is routed, its module, its command and its channel, and not how its dispatch keeps a record, so neither the roll call nor any listing drawn from the zipper can say it.
The kit that ships a door names each of its doors that takes a form other than the default, in its own README.
BUK's own are the six doors validating and rendering its [Config Regimes](#Config-Regime), `buw-rcv`, `buw-rcr`, `buw-rsv`, `buw-rsr`, `buw-rev` and `buw-rer`, which keep no Station Log because they run before a station file stands.
A door minted in the default form where its kit names another form still runs; it is only recorded where its kit asked otherwise.

**Token Parsing**: dispatch splits the filename into tokens on [BURC\_TABTARGET\_DELIMITER](#burc_tabtarget_delimiter):

| Filename | Colophon | Frontispiece | Imprint(s) |
| --- | --- | --- | --- |
| `buw-tt-ll.ListLaunchers.sh` | `buw-tt-ll` | `ListLaunchers` | none |
| `rbw-cr.Rack.tadmor.sh` | `rbw-cr` | `Rack` | `tadmor` |

The first token, the colophon, is what the workbench routes on.

**Key Benefits**:

1. **Tab completion**: type `tt/buw-` then press TAB to see all BUK commands.
2. **Self-documenting**: the frontispiece describes what the command does.
3. **Discoverability**: `ls tt/` shows all available commands.
4. **Parameterization**: imprints encode target-specific variants.
5. **Lightweight**: no logic in tabtargets, just delegation.

**Design Rationale**:

- Colophons route through the workbench to implementations.
- Frontispieces serve as inline documentation for humans.
- Imprints allow the same command to target different instances.
- Delegating to [Moorings Launchers](#Moorings-Launcher) ensures validation happens on every invocation.

### Config Regimes

A Config Regime is a structured configuration system consisting of:

- An **assignment**: a shell-sourceable file (`.env`) holding the actual values.
- A **config regime module**: a script whose kindle enrolls every variable's type, constraints and one-line purpose, the delivered home of the config regime's own documentation, and which validates and renders them.

Each [Config-Regime](#Config-Regime) has a unique uppercase prefix (`BURC_`, `BURS_`, `RBRN_`, `RBRR_`) that keeps its variables from colliding with another's.

A config regime module performs three operations:

<a id="Kindle"></a>**Kindle**

Silent initialization of Bash Utility Kit config regime state from [assignments](#Assignment).
Sets defaults, detects unexpected variables, builds derived structures.

<a id="Validate"></a>**Validate**

Strict field validation for Bash Utility Kit [Config Regimes](#Config-Regime).
Checks every variable a config regime's kindle enrolled, through `buv_regime_enroll` and the typed enrollments beside it, against its type and constraints, rejecting on the first that fails.

<a id="Render"></a>**Render**

Diagnostic display of Bash Utility Kit [Config-Regime](#Config-Regime) state, including the source-file path from which it was sourced.

**File Naming Pattern**:

- **Assignment**: `{regime}.env`, concise because it is frequently sourced.
- **Support files**: `{regime}_{full_word}.{ext}`, readable and self-documenting.

| Config Regime | Assignment | Config Regime Module |
| --- | --- | --- |
| BURC | `mymm_moorings/burc.env` | `Tools/buk/burc_regime.sh` |
| BURS | `../station-files/burs.env` | `Tools/buk/burs_regime.sh` |

**Type System**: `Tools/buk/buv_validation.sh` enrolls each variable under a type, and validates it against that type and its constraints.

- **Scalar types**: `string`, `secret`, `xname`, `gname`, `fqin`, `bool`, `enum`, `decimal`, `odref`, `ipv4`, `port`.
- **List types**: `list_string`, `list_ipv4`, `list_gname`, `list_cidr`, `list_domain`.

**Why Config Regimes?**

1. **Separation of concerns**: code is portable, and configuration adapts it.
2. **Type safety**: validation catches errors early.
3. **Documentation**: each variable's purpose is enrolled beside its type.
4. **Tooling**: generic validators and renderers reduce boilerplate.
5. **Scalability**: multiple [Config Regimes](#Config-Regime) coexist without conflicts.

## Architecture

```
Project Root/
├── mymm_moorings/                     # Moorings: the project's bootstrap config (name is yours; naming specimen)
│   ├── burc.env                       # BURC assignment (project structure config)
│   └── buml_launchers/                # Moorings launchers (subdirectory name is fixed by the kit)
│       ├── launcher.buw_workbench.sh  # BUK's moorings launcher
│       └── launcher.myw_workbench.sh  # your moorings launcher (naming specimen)
│
├── tt/                                # TabTargets (tab-completion-friendly commands)
│   ├── z-launcher.sh                  # The trampoline every tabtarget execs into
│   ├── buw-tt-ll.ListLaunchers.sh     # List all moorings launchers
│   ├── buw-rcv.ValidateConfigRegime.sh # Validate BURC
│   └── myw-p.Provision.sh             # your command (naming specimen)
│
├── Tools/                             # BURC_TOOLS_DIR: installed kits and your own toolkits
│   ├── buk/                           # BUK core utilities (installed from a parcel)
│   │   ├── bul_launcher.sh            # The shared script every stub execs
│   │   ├── bud_dispatch.sh            # Dispatch system
│   │   ├── buc_command.sh             # Command utilities
│   │   ├── buv_validation.sh          # Validation (type system)
│   │   ├── buw_workbench.sh           # BUK workbench
│   │   ├── buwz_zipper.sh             # BUK workbench zipper
│   │   ├── burc_regime.sh             # BURC config regime module
│   │   ├── burs_regime.sh             # BURS config regime module
│   │   ├── burs_template.sh           # BURS field list and defaults
│   │   └── README.md                  # This file
│   │
│   └── myk/                           # your toolkit (naming specimen)
│       ├── myw_workbench.sh
│       ├── myz_zipper.sh
│       └── myp_cli.sh
│
├── .vvm/                              # Identity record naming the parcel installed here
│
└── ../station-files/                  # Developer machine configs (NOT in git; a sibling of the root)
    └── burs.env                       # BURS assignment (station config)
```

Which step creates each directory:

| Directory | Created by |
| --- | --- |
| `mymm_moorings/` | you, by hand, before the install |
| `mymm_moorings/buml_launchers/` | you, by hand, before the install; `buw-tt-cl` writes into it and refuses where it does not stand |
| `tt/` | you, by hand, before the install; `z-launcher.sh` in it is yours to write, and the `buw-tt-c*` doors write every tabtarget in it, a kit's and your own |
| `Tools/` | you, by hand, before the install; the install writes into it and refuses where it does not stand |
| `Tools/buk/` | the parcel install |
| `.vvm/` | the parcel install |
| `Tools/myk/` | you: your own workbench, zipper and CLI modules, written against the Module Contract below |
| `../station-files/` | you, or a station door the starter kit templates (see Installation below); outside the repository |

**Execution Flow**:

1. You invoke a tabtarget: `tt/buw-tt-ll.ListLaunchers.sh`.
2. The tabtarget says its configuration on one line, naming its [Moorings-Launcher](#Moorings-Launcher) first, and execs the trampoline, `tt/z-launcher.sh`, with its own basename ahead of it.
3. The trampoline changes to the repository root and execs the [Moorings-Launcher](#Moorings-Launcher) `mymm_moorings/buml_launchers/launcher.buw_workbench.sh`, handing it the configuration, the seat and the moorings directory as arguments and exporting nothing.
4. The [Moorings-Launcher](#Moorings-Launcher) execs the shared script `bul_launcher.sh` with the workbench path ahead of those arguments, and the shared script loads and enforces BURC and BURS, the station file's absence stopping it with the setup it needs, and execs dispatch with the workbench as coordinator.
5. Dispatch parses the colophon, frontispiece and imprints from the filename, creates the temporary and output directories, sets up the Station Log, and runs `buw_workbench.sh` with the colophon as its command.
6. The workbench kindles its zipper, and `buz_exec_lookup` execs the CLI module enrolled for `buw-tt-ll`.
7. Dispatch writes the transcript and propagates the exit status.

The trampoline is the only file that knows the moorings directory's name.
The kit reads [BURD\_CONFIG\_DIR](#burd_config_dir) rather than any fixed name, which is what lets one BUK serve every repository; so the trampoline is yours to write, and no door generates it.

## Installation

BUK arrives from a parcel: the parcel's install door writes it under the tools directory of a repository that already stands, and commits nothing.
The ordered road that stands such a repository up, with a ready template for every file placed by hand, the bootstrap seed among them, is the parcel starter kit's.
That kit stands beside this one in the parcel it arrived in; read its README before your first install.

What follows is the contract BUK places on a repository, each requirement stated once here and in full where the pointer leads.

- **A config regime file**, `burc.env`, in a moorings directory of your naming at the repository root. It declares exactly the twelve variables `Tools/buk/burc_regime.sh` enrolls, and its validator refuses fewer or more; the install door reads three of them, [BURC\_PROJECT\_ROOT](#burc_project_root), [BURC\_TOOLS\_DIR](#burc_tools_dir) and [BURC\_MANAGED\_KITS](#burc_managed_kits). See Config Regimes above.
- **The trampoline**, `tt/z-launcher.sh`, which is yours to write and no door generates. It has two duties: hold the moorings directory's name, the one place the kit learns it, and resolve the [Moorings-Launcher](#Moorings-Launcher) a tabtarget names under that directory's `buml_launchers/` subdirectory, a name the kit reads as a literal, handing the stub the moorings directory by argument and exporting nothing. See Architecture above.
- **[Moorings Launchers](#Moorings-Launcher) and tabtargets**, one stub per workbench and one tabtarget per door you use. The creation doors write every one, a kit's and your own alike, and only the first stub and the first tabtarget are placed by hand, in exactly the shapes those doors emit. See [Moorings Launchers](#Moorings-Launcher) and TabTargets above.
- **The doors you use, and no more.** A workbench routes whatever tabtargets stand and sweeps nothing at dispatch, so a partial roster is a smaller installation rather than a broken one. The roll call, `tt/buw-tt-rc.RollCall.sh`, reads every zipper the kits your `burc.env` declares carry. It lists each enrolled door not yet standing, with what it does and how it takes its folio, and names in red each standing door whose colophon no installed kit enrolls, the trace a kit edition leaves when it drops or renames a door. Stand the doors you want with the creation doors. Remove a door the roll call names, or install the kit edition that enrolls it. The source tree proves its own roster complete by test. See Zipper above.
- **The substrate's suite, only where the kennel kit is installed.** BUK holds no Rust, and its self-test crate and suite collar ship with the kennel kit, never with BUK. Where the kennel kit is installed, its own README says how to wean that suite.
- **A station file**, per machine and never committed, at the path [BURC\_STATION\_FILE](#burc_station_file) names from the repository root. Its fields and defaults stand in `Tools/buk/burs_template.sh`, and every door run before it exists stops and prints the fields it needs. See Config Regimes above.

Your own workbench's [Moorings-Launcher](#Moorings-Launcher) is then one door away, `tt/buw-tt-cl.CreateLauncher.sh Tools/myk/myw_workbench.sh myw_workbench`, and its tabtargets are made with the `buw-tt-c*` doors naming that stub.

## Components

### Module Prefix Registry

BUK modules use `bu{x}_` prefixes, where `{x}` identifies the module.

| Prefix | Purpose |
| --- | --- |
| `bubc_` | Bootstrap constants |
| `bubg_` | Generated constants: the surface forms of the words BUK governs |
| `buc_` | Command utilities, output formatting |
| `bud_` | Dispatch: environment setup, invokes the workbench |
| `bue_` | Exergue: stamps a build with the source position it was struck from |
| `buf_` | Fact-file primitives |
| `bug_` | Git utilities |
| `buh_` | Handbook: always-visible user interaction |
| `bul_` | The shared script every [Moorings-Launcher](#Moorings-Launcher) execs |
| `bupe_` | Parcel emplacement into a station that can dispatch |
| `bupr_` | Shared rendering for config regime CLI modules |
| `buq_` | Tabtarget structural qualification |
| `burc_` | Project-level config regime |
| `burd_` | Dispatch runtime config regime |
| `bure_` | Environment config regime: ambient overrides |
| `burs_` | Station-level config regime |
| `buur_` | Roll call: the installed kits' enrollments against the doors standing |
| `buut_` | TabTarget and [Moorings-Launcher](#Moorings-Launcher) creation |
| `buv_` | Type system, validation |
| `buw_` | BUK self-management workbench |
| `buwz_` | BUK workbench zipper |
| `bux_` | Dispatch test fixtures |
| `buym_` | Yelp: formatted string capture |
| `buz_` | Colophon registry through parallel arrays |

### BURD: Dispatch Runtime

**File**: `Tools/buk/bud_dispatch.sh`

<a id="BURD"></a>**BURD**

Ephemeral runtime state assembled by bud\_dispatch.sh during tabtarget execution.
Constructed inline, then written once to the run's dispatch file, which [BURD\_BURD\_FILE](#burd_dispatch_file) names: every coordinator and CLI below the dispatch reads it from that file and holds it kindled, the command module sourcing it.
Inlets, by group: Tabtarget Inlet (input), Derived Inlet (computed, parsed).

**Key Responsibilities**:

- Parse the tabtarget filename into tokens.
- Set up the environment: temporary directories, output directories, the Station Log.
- Source BURS, the station configuration.
- Resolve the color policy.
- Write the dispatch file once, in the temporary directory and copied into the output directory, before the workbench starts.
- Invoke the workbench with its context: the pointer to the dispatch file and the kit directory.
- Capture and propagate the exit status.
- Write the execution transcript.

Dispatch writes the variables below to its dispatch file, which the command module sources for the workbench and every command it runs, and exports them beside it.

#### Invocation Identity

<a id="burd_now_stamp"></a>**BURD\_NOW\_STAMP**

Unique timestamp combining date, time, PID, and random component.

<a id="burd_git_context"></a>**BURD\_GIT\_CONTEXT**

Git describe output capturing repository state at dispatch time.

<a id="burd_config_dir"></a>**BURD\_CONFIG\_DIR**

Absolute path to the project's config/moorings directory.
Handed by the project-intimate tabtarget trampoline (`tt/z-launcher.sh`) as an argument, set by `bul_launcher.sh` from it, and handed on to the dispatch as an argument in turn.

<a id="burd_seat"></a>**BURD\_SEAT**

The directory whose `tt/` the tabtarget was reached through, absolute and symlink-resolved.
The trampoline derives it from its own path and hands it to the [Moorings-Launcher](#Moorings-Launcher) as an argument; a trampoline that enters another tree than its own, as the census family's does, still hands the seat it stood in.

<a id="burd_dispatch_file"></a>**BURD\_BURD\_FILE**

The pointer: the path of this run's dispatch file, `burd.env` in [BURD\_TEMP\_DIR](#burd_temp_dir), which the dispatch writes once before the coordinator starts and copies under the same name into [BURD\_OUTPUT\_DIR](#burd_output_dir).
It crosses the exec beside [BURD\_BUK\_DIR](#burd_buk_dir), the one so a child can find the file and the other so it can find the kit's reader of it; `bul_launcher.sh` withdraws an inherited pointer and composes its own run's.

#### Token Explosion

The tabtarget's filename is split on [BURC\_TABTARGET\_DELIMITER](#burc_tabtarget_delimiter).
For `rbw-cr.Rack.tadmor.sh`, the first three tokens are `rbw-cr`, `Rack` and `tadmor`.
The first is the command the workbench is handed, and the third is the one token that crosses into [BURD](#BURD).

<a id="burd_token_3"></a>**BURD\_TOKEN\_3**

Positional token 3 from tabtarget split (the imprint, if present).

<a id="burd_target"></a>**BURD\_TARGET**

Complete tabtarget string as received by dispatch.

The workbench receives the colophon for routing, and a command receives its imprint as its folio.
The frontispiece is for human readability and is typically not used at runtime.

#### Directories

<a id="burd_temp_dir"></a>**BURD\_TEMP\_DIR**

Ephemeral directory for this dispatch invocation.
Written into the dispatch file, where CLI processes read it as the dispatch-composed scratch root for their own test fixtures instead of discovering one ambiently — the same read-from-the-file consumption pattern as [BURD\_TOOLS\_DIR](#burd_tools_dir).

<a id="burd_output_dir"></a>**BURD\_OUTPUT\_DIR**

Fixed output directory for this dispatch (`current/`).

<a id="burd_transcript"></a>**BURD\_TRANSCRIPT**

Path to the transcript file within the temporary directory.

<a id="burd_tools_dir"></a>**BURD\_TOOLS\_DIR**

Path to the project tools root directory, derived from [BURC\_TOOLS\_DIR](#burc_tools_dir) during dispatch setup.

<a id="burd_buk_dir"></a>**BURD\_BUK\_DIR**

Path to the BUK subdirectory, derived as [BURC\_TOOLS\_DIR](#burc_tools_dir)/buk during dispatch setup.

#### Station Log Paths

<a id="burd_log_last"></a>**BURD\_LOG\_LAST**

Absolute path to the "last" Station Log member, overwritten each dispatch.

<a id="burd_log_same"></a>**BURD\_LOG\_SAME**

Absolute path to the curated "same" Station Log member for the command+target combination.

<a id="burd_log_hist"></a>**BURD\_LOG\_HIST**

Absolute path to the timestamped historical Station Log member.

#### Control Variables

Set these before invoking a tabtarget to modify dispatch behavior.

<a id="BURE"></a>**BURE**

The ambient [Config-Regime](#Config-Regime) for caller-supplied behavioral overrides to BUK primitives.
Unlike file-sourced [Config Regimes](#Config-Regime), BURE variables are set directly in the caller's environment.
Kindled and validated by its own CLI, `bure_cli.sh`, the one site that kindles it; every other reader takes a value as the caller set it.
Inlet: Ambient Inlet — the one family whose values legitimately ride the session environment and its inheritance (BUr\_q2m).
Two sub-natures share the family, separated by doctrine: operator comfort dials (BURE\_COUNTDOWN, [BURE\_VERBOSE](#bure_verbose), [BURE\_COLOR](#bure_color), [BURE\_HYPERLINKS](#bure_hyperlinks)) and the test tweak seam (BURE\_TWEAK\_NAME, BURE\_TWEAK\_VALUE), which the Tweak Mechanism bounds to sparing, one-at-a-time use.

<a id="bure_verbose"></a>**BURE\_VERBOSE**

Verbosity level controlling diagnostic output, one of `0`, `1`, `2` or `3`.
`0` is quiet; `1` shows each module's verbose lines; `2` enables the bash trace in dispatch and shows debug messages; `3` shows debug and trace messages, without the bash trace.

<a id="bure_color"></a>**BURE\_COLOR**

Operator override for color output policy, input as auto/0/1 — read during dispatch, never written.
The resolved 0/1 verdict (also weighing the `NO_COLOR` convention and tty detection) is dispatch's own computation and lives under BURD\_COLOR (BUr\_q2m): a computed value staying under this ambient-family name would pass a spawn boundary as if it were operator input and be read stale downstream.

<a id="bure_hyperlinks"></a>**BURE\_HYPERLINKS**

Operator switch for the hyperlink escape, input as 1/0 (default 1) — read during dispatch, never written.
`0` is the plain-text fallback: every link renders its URL beside its text, without the OSC 8 escape, for a terminal or multiplexer that drops it.
The resolved verdict is dispatch's own computation and lives under BURD\_HYPERLINKS (BUr\_q2m).

Two dispatch modes are not ambient controls: they are static properties of a tabtarget, said by the `buuc_` words on its configuration line, which exports nothing, and never set from the environment, a launching harness stripping any inherited copy so each launched context chooses its own mode.

<a id="burd_no_log"></a>**BURD\_NO\_LOG**

The tabtarget's own declaration that its dispatch runs unlogged, said by the configuration word `buuc_nolog` — a static property of the tabtarget file, never inherited (BUr\_q2m).

<a id="burd_interactive"></a>**BURD\_INTERACTIVE**

The tabtarget's own declaration of interactive mode, said by the configuration word `buuc_interactive` — output goes to the terminal via uncurated tee rather than the curated Station Log pipeline.
Same inlet law as [BURD\_NO\_LOG](#burd_no_log): a static property of the tabtarget file, never inherited (BUr\_q2m).

#### The Three-Member Pattern

A dispatch that keeps a Station Log writes three files under [BURS\_LOG\_DIR](#burs_log_dir), one record read three ways:

| Member | Variable | Lifecycle | Purpose |
| --- | --- | --- | --- |
| **Historical** | [BURD\_LOG\_HIST](#burd_log_hist) | Never overwritten | This dispatch alone, every line stamped; the only race-free member |
| **Latest** | [BURD\_LOG\_LAST](#burd_log_last) | Overwritten by every dispatch | The most recent dispatch through the directory, whichever tabtarget ran |
| **Same-name** | [BURD\_LOG\_SAME](#burd_log_same) | Overwritten per tabtarget | The most recent dispatch of this one tabtarget, normalized so two runs over unchanged work differ nowhere |

The first two are overwritten by the next dispatch that shares their name, so the historical member is the one to read, and the dispatch prints all three paths.

**Filename Conventions**:

- Historical: `hist-{tabtarget}-{stamp}.{ext}`, for example `hist-buw-tt-ll-sh-20250101-143022-1234-567.txt`.
- Latest: `{BURC_LOG_LAST}.{ext}`, for example `last.txt`.
- Same-name: `same-{tabtarget}.{ext}`, for example `same-buw-tt-ll-sh.txt`.

The Station Log stands in the directory [BURS\_LOG\_DIR](#burs_log_dir) names in the station configuration.

### BUC: Command Utilities

**File**: `Tools/buk/buc_command.sh`

Common command-line utilities: output at each verbosity level, documentation of commands and their environment, error handling that dies through `buc_die_now`, and the `buc_execute` entry every CLI module ends on.

### BUV: Validation

**File**: `Tools/buk/buv_validation.sh`

The type system for Config Regimes.
The kindle of a [Config-Regime](#Config-Regime) opens its scope with `buv_regime_enroll`, may group its variables with `buv_group_enroll`, and enrolls each variable under its type with one `buv_{type}_enroll` call; the module then validates, renders and locks what it enrolled.

```bash
buv_regime_enroll MYR
buv_group_enroll "Paths"
buv_string_enroll  MYR_ROOT_DIR  1  512  "Root of the thing"
buv_xname_enroll   MYR_LOG_NAME  1   64  "Log file stem"
buv_enum_enroll    MYR_MODE      "Run mode" fast slow
buv_scope_sentinel MYR MYR_
buv_lock MYR
```

`buv_scope_sentinel` refuses any variable carrying the prefix that was not enrolled, and any that stands exported where its level declares no hand-off, `buv_vet` validates every enrolled variable in a scope, `buv_report` and `buv_render` display them, and `buv_lock` makes them readonly.

### BUW: BUK Workbench

**File**: `Tools/buk/buw_workbench.sh`

The self-management workbench for BUK itself.

**TabTarget Subsystem** (`buw-tt-*`):

- `buw-tt-ll`: list the [Moorings Launchers](#Moorings-Launcher) in `buml_launchers/`.
- `buw-tt-cbl <launcher> <name>...`: create batch tabtargets keeping a Station Log, the default.
- `buw-tt-cbn <launcher> <name>...`: create batch tabtargets keeping no Station Log.
- `buw-tt-cbo <launcher> <name>...`: create batch tabtargets whose command writes its own record.
- `buw-tt-cil <launcher> <name>...`: create interactive tabtargets keeping a Station Log.
- `buw-tt-cin <launcher> <name>...`: create interactive tabtargets keeping no Station Log.
- `buw-tt-cl <workbench> <name>`: create a [Moorings-Launcher](#Moorings-Launcher).
- `buw-tt-rc`: the roll call, naming each standing door whose colophon no installed kit enrolls (in red) and each enrolled colophon with no door standing. It judges a door only where the door execs a trampoline and the workbench of its [Moorings-Launcher](#Moorings-Launcher) stands in a kit [BURC\_MANAGED\_KITS](#burc_managed_kits) declares; a kit whose workbench keeps no zipper enrolls nothing, so a door over it is named.

**Config Regime Management**:

- `buw-rcv` and `buw-rcr`: validate and render BURC.
- `buw-rsv` and `buw-rsr`: validate and render BURS.
- `buw-rev` and `buw-rer`: validate and render BURE.
- `buw-SI`: write this machine's station file from the kit's station template.

**Parcel**:

- `buw-pe <parcel-dir>`: emplace an extracted parcel into this station.

## Creating a New Workbench

To create a new workbench:

1. **Study the delivered workbench** as a template: `Tools/buk/buw_workbench.sh`, the workbench, kindling and routing; `Tools/buk/buwz_zipper.sh`, its zipper, enrolling each colophon to a CLI module; and `Tools/buk/burs_cli.sh`, a CLI module the zipper enrolls.
2. **Create the workbench, its zipper and its CLI modules** in `Tools/{prefix}/`, following the Module Contract below.
3. **Create the [Moorings-Launcher](#Moorings-Launcher)** with `buw-tt-cl`: `tt/buw-tt-cl.CreateLauncher.sh Tools/myw/myw_workbench.sh myw_workbench`.
4. **Create tabtargets** with `buw-tt-cbl`, or the variant that fits: `tt/buw-tt-cbl.CreateTabTargetBatchLogging.sh mymm_moorings/buml_launchers/launcher.myw_workbench.sh myw-cmd.CommandName`.

## Module Contract

Every BUK module follows these rules, and a module of your own that follows them dispatches, kindles and documents itself the way BUK's do.
Each rule names a delivered module that shows it; when in doubt, read that module.

`myk`, `myw`, `myz` and `myp` below are naming specimens standing for your own prefix.

### Every module

| Rule | Shown in |
| --- | --- |
| The file is `{prefix}_{word}.sh`, and `set -euo pipefail` runs before any other statement | `Tools/buk/burs_regime.sh` |
| A public function is named `{prefix}_{word}`; a private one is named `z{prefix}_{word}` | `Tools/buk/buz_zipper.sh` (`buz_enroll` public, `zbuz_kindle` private) |
| Locals are declared `local`, named `z_{word}`, and made `local -r` when never reassigned | `Tools/buk/buz_zipper.sh` (`buz_enroll`) |
| Every expansion is braced and quoted: `"${z_name}"`, never `$z_name` | `Tools/buk/buz_zipper.sh` |
| A failure dies through `buc_die_now "message"`, never `echo` and `exit` | `Tools/buk/buz_zipper.sh` (`buz_enroll`) |
| The code runs under bash 3.2, the macOS default shell | `Tools/buk/buz_zipper.sh` (`buz_emit_const_str` states why its interface is per-pair) |

### A sourced module

A module other files `source` carries state only once it is kindled, so sourcing it defines functions and nothing more.

| Rule | Shown in |
| --- | --- |
| It guards against a second inclusion at the top, in the form shown below the table. Each process sources a module from one place, so a second inclusion is a wrong sourcing hierarchy and dies. A file sourced before `buc_command.sh` dies through its own `printf` to stderr and `exit 1`; a generated constant file alone returns quietly, being sourced by every module that cites it | `Tools/buk/burs_regime.sh`; `Tools/buk/buc_command.sh` (ahead of its own die); `Tools/buk/bubg_breviary.sh` (generated, returns) |
| A module holding state defines `z{prefix}_kindle`, which dies if already kindled, sets up that state, and ends `readonly Z<PREFIX>_KINDLED=1` | `Tools/buk/burs_regime.sh` (`zburs_kindle`) |
| It defines `z{prefix}_sentinel`, which dies unless `Z<PREFIX>_KINDLED` is `1` | `Tools/buk/burs_regime.sh` (`zburs_sentinel`) |
| Every function that reads kindled state calls the sentinel first | `Tools/buk/buz_zipper.sh` (`buz_enroll` calls `zbuz_sentinel`) |
| A kindle that needs another module kindled calls that module's sentinel first | `Tools/buk/buwz_zipper.sh` (`zbuwz_kindle` calls `zbuz_sentinel`) |
| Kindling is the caller's explicit act, in dependency order | `Tools/buk/buw_workbench.sh` |

The inclusion guard:

```bash
test -z "${Z<PREFIX>_SOURCED:-}" || buc_die_now "Module <prefix> multiply sourced - check sourcing hierarchy"
Z<PREFIX>_SOURCED=1
```

### A CLI module

A CLI module is what a zipper enrolls.
It is executed, never sourced, and it must be committed executable.

| Rule | Shown in |
| --- | --- |
| It sources `buc_command.sh` and `buym_yelp.sh` from `${BURD_BUK_DIR}` | `Tools/buk/burs_cli.sh` |
| Each command is a function `{prefix}_{verb}`, and a helper that is not a command is `z`-prefixed, since the help listing shows every function carrying the prefix | `Tools/buk/burs_cli.sh`; the listing is `zbuc_show_help` in `Tools/buk/buc_command.sh` |
| Each command opens with `buc_doc_brief "what it does"`, then a `buc_doc_shown` guard that returns early, so the help listing can call it without running it | `Tools/buk/burs_cli.sh` (`burs_validate`) |
| A furnish function `z{prefix}_furnish` opens with its `buc_doc_env_row` lines and a `buc_doc_env_done` guard that returns early, then sources and kindles what the commands need | `Tools/buk/burs_cli.sh` (`zburs_furnish`) |
| The last line of code is `buc_execute {prefix}_ "Title" z{prefix}_furnish "$@"` | `Tools/buk/burs_cli.sh` |

### A zipper

| Rule | Shown in |
| --- | --- |
| It is a sourced module named `{prefix}z_zipper.sh`, with the guard, kindle and sentinel above | `Tools/buk/buwz_zipper.sh` |
| Its kindle calls `zbuz_sentinel`, then one `buz_enroll` per colophon: constant name, colophon, CLI module filename, command function, channel, description | `Tools/buk/buwz_zipper.sh` |
| The channel says how the command receives its folio: `""` for none, `"imprint"` for the tabtarget filename's third token, `"param1"` for the first argument, and a passthrough channel for no folio and every argument as typed, which a door forwarding its arguments to a program of its own takes; the command reads its folio from `BUZ_FOLIO` | `Tools/buk/buwz_zipper.sh`; decoded in `buz_exec_lookup`, `Tools/buk/buz_zipper.sh` |

`buz_tome_seat` is needed only by a project that projects its colophons as constants into generated code; a zipper that only dispatches may omit it.

### A workbench

| Rule | Shown in |
| --- | --- |
| It sources `buc_command.sh`, `buym_yelp.sh`, `buv_validation.sh`, `burd_regime.sh` and `buz_zipper.sh` from BUK, then its own zipper | `Tools/buk/buw_workbench.sh` |
| It kindles `zbuv_kindle`, `zburd_kindle`, `zbuz_kindle`, then its own zipper's kindle | `Tools/buk/buw_workbench.sh` |
| It routes by calling `zburd_sentinel`, then `buz_exec_lookup "${z_command}" "<directory holding its CLI modules>" "$@"` | `Tools/buk/buw_workbench.sh` (`buw_route`) |

A consumer workbench, whole, in the shape `Tools/buk/buw_workbench.sh` takes:

```bash
#!/bin/bash
set -euo pipefail

MYW_SCRIPT_DIR="${BASH_SOURCE[0]%/*}"

source "${BURD_BUK_DIR}/buc_command.sh"
source "${BURD_BUK_DIR}/buym_yelp.sh"
source "${BURD_BUK_DIR}/buv_validation.sh"
source "${BURD_BUK_DIR}/burd_regime.sh"
source "${BURD_BUK_DIR}/buz_zipper.sh"
source "${MYW_SCRIPT_DIR}/myz_zipper.sh"

buc_context "${0##*/}"

zbuv_kindle
zburd_kindle
zbuz_kindle
zmyz_kindle

myw_main() {
  local z_command="${1:-}"
  shift || true
  test -n "${z_command}" || buc_die_now "No command specified"

  zburd_sentinel
  buz_exec_lookup "${z_command}" "${MYW_SCRIPT_DIR}" "$@"
}

myw_main "$@"
```

## Reference Implementation: BURC and BURS

BURC and BURS are BUK's own Config Regimes, serving both as the configuration BUK operates by and as the canonical demonstration of the Config Regime pattern.

### BURC

<a id="BURC"></a>**BURC**

The [Config-Regime](#Config-Regime) for project-level BUK settings.
BURC assignment files stand as `burc.env` under BURD\_MOORINGS\_DIR, and define repository structure and tabtarget infrastructure.
Inlet: Assignment Inlet.

**Assignment File**: `mymm_moorings/burc.env`

**Variables**:

<a id="burc_station_file"></a>**BURC\_STATION\_FILE**

Path to the developer's personal [BURS](#BURS) assignment file.

<a id="burc_tabtarget_dir"></a>**BURC\_TABTARGET\_DIR**

Project dir containing the tabtarget scripts.

<a id="burc_tabtarget_delimiter"></a>**BURC\_TABTARGET\_DELIMITER**

Single-character token separator in Tabtarget Vesture Inscriptions.

<a id="burc_tools_dir"></a>**BURC\_TOOLS\_DIR**

Project dir containing BUK utilities and project tool scripts.

<a id="burc_project_root"></a>**BURC\_PROJECT\_ROOT**

Repo root, expressed relative to the assignment file's location.

<a id="Endonym"></a>**Endonym**

A repository's own identity, as the repository itself declares it: the name it gives itself, which no reader derives from a directory, a remote or a path, standing distinct from every other repository's across the estate.
A repository states its own through BURC\_ENDONYM.

`BURC_ENDONYM` states the repository's [endonym](#Endonym) in its own assignment file, derived from nothing: the head `buon_`, then a lowercase letter, then lowercase letters and digits.
It is required, with no default, and a value not wearing the head is refused.

<a id="burc_managed_kits"></a>**BURC\_MANAGED\_KITS**

The kits this repository receives by parcel, carried as a [catena](#Catena).
Each element is a kit identifier — the kit's own directory name beneath [BURC\_TOOLS\_DIR](#burc_tools_dir).

The install door still reads this value comma-separated, so author it with commas until the door reads the whitespace shape.

<a id="burc_temp_root_dir"></a>**BURC\_TEMP\_ROOT\_DIR**

Parent directory for per-dispatch scratch subdirs (temp-\<stamp\>).

<a id="burc_output_root_dir"></a>**BURC\_OUTPUT\_ROOT\_DIR**

Parent directory containing `current/`.

<a id="burc_loosebox_root_dir"></a>**BURC\_LOOSEBOX\_ROOT\_DIR**

Parent directory holding one [loosebox](#Loosebox) per worktree.

<a id="burc_log_last"></a>**BURC\_LOG\_LAST**

Filename stem of the Station Log member holding the most recent dispatch's stream.

<a id="burc_log_ext"></a>**BURC\_LOG\_EXT**

File extension of every Station Log member, without leading dot.

**Example**:

```bash
BURC_STATION_FILE=../station-files/burs.env
BURC_TABTARGET_DIR=tt
BURC_TABTARGET_DELIMITER=.
BURC_TOOLS_DIR=Tools
BURC_PROJECT_ROOT=..
BURC_ENDONYM=buon_myproj
BURC_MANAGED_KITS=buk
BURC_TEMP_ROOT_DIR=../temp-buk
BURC_OUTPUT_ROOT_DIR=../output-buk
BURC_LOOSEBOX_ROOT_DIR=../boxes-buk
BURC_LOG_LAST=last
BURC_LOG_EXT=txt
```

BURC lets projects organize their directories differently while using the same BUK utilities.

### BURS

<a id="BURS"></a>**BURS**

The [Config-Regime](#Config-Regime) for developer-level BUK settings.
BURS assignment files are personal to each developer and not committed to version control.
Every path value it carries is relative to the project root, and enforce refuses an absolute one, naming the variable and the relative form; no override admits it.
The values judged are the assignment file's own: a dispatch's override is folded over a value for the composed child alone, and is never judged as the station's.
Inlet: Assignment Inlet.

**Assignment File**: `../station-files/burs.env`, at the path [BURC\_STATION\_FILE](#burc_station_file) names.

**Variables**:

<a id="burs_user"></a>**BURS\_USER**

Local developer username.

`BURS_TINCTURE` is a per-station tag of one to three lowercase alphanumeric characters, a letter leading and no hyphen, stable for the station's life and unique across the stations sharing a record.

<a id="burs_log_dir"></a>**BURS\_LOG\_DIR**

`station-log-buk`

Directory where the Station Log stands, relative to the project root.
The station template writes it as a folder beside the project root, so the clones standing side by side share one Station Log.

<a id="burs_tackroom"></a>**BURS\_TACKROOM**

`tackroom-buk`

Root of the tool store the clones beside a project draw from — the one place kits keep large immutable tooling rather than each clone holding its own copy.
Relative to the project root, as [BURS\_LOG\_DIR](#burs_log_dir) is, so a station holds one store beside each group of clones and may hold several.
An absolute [BURS\_TACKROOM](#burs_tackroom) is refused by [BURS](#BURS), naming the variable and the relative form, and no door makes a store at a path it then refuses.
[BURS](#BURS) leaves the field optional, and the station template carries no line for it: a station file omitting it is admitted, and a kit whose store is missing fails loud in its own voice and names this variable, never falling back to a per-clone copy or to the station user's personal tool homes.

<a id="burs_hayloft"></a>**BURS\_HAYLOFT**

`station-hayloft-buk`

Folder where a station keeps the archives of its aged Station Log members and run folders.
Relative to the project root, as [BURS\_LOG\_DIR](#burs_log_dir) is.
An absolute [BURS\_HAYLOFT](#burs_hayloft) is refused by [BURS](#BURS), naming the variable and the relative form.
[BURS](#BURS) takes no opinion on how a station keeps its archives beyond where they stand: the field is optional, the station template carries no line for it, and a kit that needs the folder refuses in its own voice, naming the line to add.

**Example**:

```bash
BURS_USER=alice
BURS_TINCTURE=a1
BURS_LOG_DIR=../station-log-buk
BURS_TACKROOM=../tackroom-buk
```

Each developer keeps their own station file, so where the Station Log stands and the other station preferences differ from machine to machine.

## Design Philosophy

### Portability

BUK serves any project unchanged: install it from a parcel, configure it through the assignment files of its [Config Regimes](#Config-Regime), and it works.
No modification to BUK code is needed.

### Immutability

The `Tools/buk/` directory stays the same across projects.
All project-specific behavior comes from configuration, not code changes.

### Configuration as Data

Config Regimes treat configuration as structured data with types, validation and documentation.
This eliminates an entire class of runtime errors.

### Discoverability

TabTargets and tab completion make commands discoverable.
Type `tt/buw-<TAB>` to see all BUK commands.

### Fail Fast

Every [Moorings-Launcher](#Moorings-Launcher) execs the shared script `bul_launcher.sh`, which validates [Config Regimes](#Config-Regime) before execution.
This catches configuration errors immediately, with helpful error messages.

### Exit Status Propagation

TabTarget systems must faithfully propagate the exit status of the executed command back to the invoking shell.
This is critical for:

- **CI/CD pipelines**, which rely on exit codes to determine success or failure.
- **Shell scripts**, which chain commands with `&&` or check `$?`.
- **Make rules**, which depend on prerequisite command success.

BUK achieves reliable status propagation through:

1. **`exec` in TabTargets**: replaces the shell process entirely, so the exit status flows directly to the caller without an intermediate shell's interference.
2. **`exec` in [Moorings Launchers](#Moorings-Launcher)**: the same benefit one layer down: the [Moorings-Launcher](#Moorings-Launcher) and the shared script `bul_launcher.sh` each exec what follows, so no wrapper shell masks the exit code.
3. **Pipeline status capture in dispatch**: when output is piped through `tee` into the Station Log, dispatch captures the command's own exit code rather than the pipeline's final status, which would be the exit code of `tee`.

**Anti-patterns to avoid**:

```bash
# BAD: semicolon masks exit status
command; echo "done"

# BAD: final command in pipeline determines status
command | tee logfile  # Returns tee's status, not command's

# GOOD: capture pipeline status explicitly
command | tee logfile; exit ${PIPESTATUS[0]}
```

### Coding Standards

Every BUK module follows the Module Contract above, which states each rule beside a delivered module that shows it.

## Future Directions

BUK's current scope covers portable CLI infrastructure and configuration management.
The following directions represent potential extensions that maintain portability while addressing enterprise development patterns and standards enforcement.

### Standards Installation and Awareness

Vision: inject enterprise bash practices into development workflows from session start, with the Module Contract as the anchor standard.
Rather than relying on LLM training defaults, developers work with pre-configured awareness of anti-patterns and best practices.
This prevents bad suggestions before they appear.

May eventually involve:

- Integration with `CLAUDE.md` to document enterprise bash standards.
- Session initialization that establishes standards context.
- Real-time guidance on pattern compliance.

### Hidden Configuration Workbench

Vision: a wholly internal workbench, separate from the portable BUK toolkit, that manages Claude Code-specific configuration and behavior using BUK's tabtarget, dispatch and config regime infrastructure internally.

May eventually involve:

- Project-specific hooks and configuration management.
- Behavior tuning that adjusts tool proclivities without per-session instruction.
- Hidden config files and internal tools not published with the portable BUK toolkit.

### Code Validation Skills

Vision: skills that validate bash code against enterprise standards in real time, catching deviations early, anchored by the Module Contract.

May eventually involve:

- Skills like `/validate-bash` and `/check-module-contract`.
- Integration with workbench validation functions.
- Forensic output for code review and standards enforcement.

## Contributing

When extending BUK:

1. **Follow the Module Contract** above.
2. **Maintain portability**: no project-specific logic in `Tools/buk/`.
3. **Use Config Regimes**: configuration belongs in the assignment files of [Config Regimes](#Config-Regime), not code.
4. **Document the config regime**: enroll every variable's type, constraints and purpose in its config regime module (`{regime}_regime.sh`).
5. **Add validation**: use the BUV type system for every config variable.

## License

Copyright 2025 Scale Invariant, Inc.

Licensed under the Apache License, Version 2.0.

## Author

Brad Hyslop \<bhyslop@scaleinvariant.org\>

## Glossary

<a id="Config-Regime"></a>**Config-Regime**

A structured configuration family: an assignment of values, and a config regime module enrolling each variable's type, constraints and purpose, which validates and renders them.

<a id="Assignment"></a>**Assignment**

A shell-sourceable file of `VAR=value` lines carrying one config regime's values.

<a id="Catena"></a>**Catena**

A config regime variable whose one value carries several elements, delimited by runs of whitespace.

<a id="Loosebox"></a>**Loosebox**

The place a worktree's derived and rebuildable build products stand, outside every source tree, one per worktree.
