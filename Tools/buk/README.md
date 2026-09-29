# Bash Utility Kit (BUK)

A portable, graftable bash infrastructure for building maintainable command-line tools with configuration management, dispatch routing, and validation.

## Table of Contents

- [Overview](#overview)
- [Core Concepts](#core-concepts)
  - [Launchers](#launchers)
  - [Workbenches](#workbenches)
  - [Testbenches](#testbenches)
  - [Zipper](#zipper)
  - [TabTargets](#tabtargets)
  - [Config Regimes](#config-regimes)
- [Architecture](#architecture)
- [Installation](#installation)
- [BUK Components](#buk-components)
  - [Module Prefix Registry](#module-prefix-registry)
- [Creating a New Workbench](#creating-a-new-workbench)
- [Module Contract](#module-contract)
- [Reference Implementation: BURC/BURS](#reference-implementation-burcburs)

---

## Overview

BUK provides a three-layer architecture for bash-based CLI tools:

1. **BUK Core** (`Tools/buk/*.sh`) - Portable utilities with no project-specific knowledge
2. **BURC** (`mymm_moorings/burc.env`) - Project-level configuration defining repository structure
3. **BURS** (`../station-files/burs.env`) - Developer/machine-level configuration (not in git)

This separation allows BUK to be copied wholesale into any project and configured through regime files rather than code modification.

---

## Core Concepts

### Launchers

**Definition**: A launcher is a bootstrap script that validates configuration, loads regime files, and delegates to BUD (Bash Dispatch Utility). It serves as an **environment gate**—establishing a clean, validated execution context.

**Naming Pattern**: `launcher.{workbench_name}.sh`

**Location**: `rbml_launchers/` subdirectory of the moorings directory (the subdirectory name is fixed by the kit; the moorings directory itself is yours to name)

**Examples**:
- `mymm_moorings/rbml_launchers/launcher.buw_workbench.sh` - BUK workbench launcher
- `mymm_moorings/rbml_launchers/launcher.myw_workbench.sh` - a consumer's workbench launcher (`myw` is a naming specimen throughout this file, standing for your own prefix)

**Creation**: Use `tt/buw-tt-cl.CreateLauncher.sh` to create new launchers.

**Environment Gate Role**:

The launcher's environment gate function is critical for testbench isolation. When a testbench invokes a tabtarget under test, that tabtarget passes through its own launcher, which:
- Revalidates regime configuration
- Establishes fresh BUD environment
- Prevents testbench state from bleeding into the code under test

This ensures tests exercise real dispatch paths with proper isolation.

**Design Rationale**:
- Launchers catch configuration errors before BUD starts
- Environment gate guarantees isolation between dispatch layers
- Clear naming ties launcher to its workbench
- Shared logic in `launcher_common.sh` eliminates boilerplate

---

### Workbenches

**Definition**: A workbench is a multi-call bash script that routes commands to their implementations.

**Naming Pattern**: `{prefix}w_workbench.sh`

**Location**: `Tools/{toolkit}/` subdirectory

**Examples**:
- `Tools/buk/buw_workbench.sh` - BUK workbench (manages BUK itself)
- `Tools/myk/myw_workbench.sh` - a consumer's workbench (naming specimen)

**Structure**: a workbench holds no command logic. It kindles the dispatch
environment and its zipper, then hands the colophon to `buz_exec_lookup`, which
execs the CLI module the zipper enrolled for it. `Tools/buk/buw_workbench.sh` is
the whole pattern in under eighty lines; the rules it follows are stated in
[Module Contract](#module-contract).

**Key Characteristics**:
- Routes by zipper lookup, never by a hand-written `case`
- Kindles BUK's dispatch and zipper modules, then its own zipper
- Delegates every command to an executable CLI module
- Crash-fast error handling (`set -euo pipefail`)

---

### Testbenches

**Definition**: A testbench orchestrates test scenarios—invoking tabtargets under test and assessing their behavior.

**Naming Pattern**: `{prefix}t_testbench.sh`

**Two-Layer Dispatch**:

```
tt/myt-s.Scenario.sh → Launcher → BUD → myt_testbench.sh
                                              │
                                              ▼ invokes
                                    tt/myw-p.Provision.sh → Launcher → BUD → myw_workbench.sh
                                              │                           ▲
                                              ▼ assesses                  │
                                         [pass/fail]                 environment
                                                                        gate
```

**Critical**: Each tabtarget under test passes through its own launcher. The launcher acts as an **environment gate**—testbench configuration cannot bleed into workbench execution. This isolation ensures tests exercise real dispatch paths.

**Structure**: Setup preconditions → invoke tabtarget → assess results → report

The names in the diagram above are naming specimens; BUK itself ships no testbench.

---

### Zipper

**Definition**: A zipper is a module obeying the [Module Contract](#module-contract) whose kindle enrolls each colophon with its implementing module and command, and sets a symbolic constant holding the colophon string. Testbenches use those constants instead of hardcoded colophon strings.

**Naming Pattern**: `{prefix}z_zipper.sh`

**Location**: `Tools/{toolkit}/` subdirectory

**Examples**:
- `Tools/buk/buz_zipper.sh` - the base registry every zipper enrolls into
- `Tools/buk/buwz_zipper.sh` - BUK workbench zipper (a complete zipper to copy)

**Key Functions**:
- `buz_enroll VARNAME colophon module command channel description` — enroll one colophon; all six arguments required, and `VARNAME` is set to the colophon string
- `buz_exec_lookup colophon base_dir [args...]` — the workbench's dispatch: exec `base_dir/module command`, with the folio in `BUZ_FOLIO`

**Design Rationale**:
- Symbolic constants eliminate hardcoded colophon strings in tests
- Parallel arrays keep one row per enrolled colophon
- Each toolkit's zipper owns its colophon registry

---

### TabTargets

#### The TabTarget Pattern

A TabTarget is a design pattern for CLI discoverability that trades argument flexibility for command visibility. The key insight: `ls tt/` shows all available commands; `tt/prefix-<TAB>` narrows to a category.

**Essential characteristics** (implementation-independent):

- Shell scripts in a dedicated directory (conventionally `tt/`)
- Filename encodes command identity and embedded parameters
- Tokens parsed by a configurable delimiter (typically `.`)
- Delegates immediately to a dispatch mechanism
- Contains no business logic—purely a routing layer

**Implementation variants**:

| Variant | Flow | Execution Target |
|---------|------|------------------|
| **Bash dispatch** (BUK) | TabTarget → Launcher → BDU → Workbench | Bash script |
| **Makefile dispatch** (MBC) | TabTarget → Dispatch Script → Make | Makefile rules |

BUK implements the bash dispatch variant. The remainder of this section describes that implementation.

#### BUK TabTarget Implementation

**Definition**: In BUK, TabTargets are lightweight shell scripts in the `tt/` directory that delegate to workbenches via launchers.

**Naming Pattern**: `{colophon}.{frontispiece}[.{imprint}...].sh`

**Location**: `tt/` directory at project root (configurable via `BURC_TABTARGET_DIR`)

**Token Delimiter**: Configurable via `BURC_TABTARGET_DELIMITER` (typically `.`)

#### TabTarget Anatomy

TabTarget filenames encode structured information using publishing terminology:

| Token | Term | Purpose | Example |
|-------|------|---------|---------|
| 1 | **Colophon** | Routing identifier—what the workbench matches on | `rbw-cr` |
| 2 | **Frontispiece** | Human-readable description | `Rack` |
| 3+ | **Imprint** | Embedded parameter(s)—target/instance specifier | `tadmor` |

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
- `tt/buw-tt-ll.ListLaunchers.sh` - List launchers (no imprint)
- `tt/buw-rv.ValidateRegimes.sh` - Validate regimes (no imprint)
- `tt/rbw-cr.Rack.tadmor.sh` - Rack bottle on tadmor (with imprint)

**Creation**: Use the `buw-tt-*` commands to create tabtargets:
- `buw-tt-cbl` - Batch + logging (default)
- `buw-tt-cbn` - Batch + nolog (for secret-handling operations)
- `buw-tt-cil` - Interactive + logging (for shells)
- `buw-tt-cin` - Interactive + nolog (for secret entry)

**Token Parsing**:

BUD parses the filename into tokens using `BURC_TABTARGET_DELIMITER`:

| Filename | Colophon | Frontispiece | Imprint(s) |
|----------|----------|--------------|------------|
| `buw-ll.ListLaunchers.sh` | `buw-ll` | `ListLaunchers` | *(none)* |
| `rbw-cr.Rack.tadmor.sh` | `rbw-cr` | `Rack` | `tadmor` |

BUD extracts the colophon using `${filename%%${BURC_TABTARGET_DELIMITER}*}` and passes it to the workbench.

**Key Benefits**:
1. **Tab completion**: Type `tt/buw-` then press TAB to see all BUK commands
2. **Self-documenting**: Frontispiece describes what the command does
3. **Discoverability**: `ls tt/` shows all available commands
4. **Parameterization**: Imprints encode target-specific variants
5. **Lightweight**: No logic in tabtargets, just delegation

**Design Rationale**:
- Colophons route through the workbench to implementations
- Frontispieces serve as inline documentation for humans
- Imprints allow the same command to target different instances
- Delegating to launchers ensures validation happens on every invocation

---

### Config Regimes

**Definition**: A Config Regime is a structured configuration system consisting of:
- **Assignment** - Shell-sourceable file (`.env`) containing actual values
- **Regime Script** - Multi-call script that enrolls every variable's type and constraints, validates them, and renders them in human-readable form

**Namespace Identity**: Unique uppercase prefix (e.g., `BURC_`, `BURS_`, `RBRN_`, `RBRR_`) prevents variable collisions.

**Core Components**:

1. **Assignment File** (`{regime}.env`)
   - Concise filename (frequently sourced)
   - Shell-sourceable: `VAR=value` syntax, no spaces around `=`
   - Can use `${VAR}` expansion for derived values
   - Example: `mymm_moorings/burc.env`

2. **Regime Script** (`{regime}_regime.sh`)
   - Multi-call script with subcommands
   - Enrolls every variable — its type, its constraints, its one-line purpose — the delivered home of the regime's own documentation
   - Subcommands: `validate`, `render`, `info`
   - Example: `Tools/buk/burc_regime.sh`

**File Naming Pattern**:
- **Assignment**: `{regime}.env` (concise, frequently sourced)
- **Support files**: `{regime}_{full_word}.{ext}` (readable, self-documenting)

**Examples**:

| Regime | Assignment | Regime Script |
|--------|-----------|---------------|
| BURC | `mymm_moorings/burc.env` | `Tools/buk/burc_regime.sh` |
| BURS | `../station-files/burs.env` | `Tools/buk/burs_regime.sh` |

**Type System**:

BUK provides validation functions in `buv_validation.sh`:
- **Atomic types**: `string`, `xname`, `fqin`, `bool`, `decimal`, `ipv4`, `cidr`, `domain`, `port`
- **List types**: `ipv4_list`, `cidr_list`, `domain_list`
- Each type validated with min/max constraints

**Why Config Regimes?**

1. **Separation of concerns**: Code is portable, configuration adapts it
2. **Type safety**: Validation catches errors early
3. **Documentation**: Specifications are authoritative and version-controlled
4. **Tooling**: Generic validators and renderers reduce boilerplate
5. **Scalability**: Multiple regimes can coexist without conflicts

---

## Architecture

```
Project Root/
├── mymm_moorings/                     # Moorings: the project's bootstrap config (name is yours; naming specimen)
│   ├── burc.env                       # BURC assignment (project structure config)
│   └── rbml_launchers/                # Launcher stubs (subdirectory name is fixed by the kit)
│       ├── launcher.buw_workbench.sh  # BUK launcher stub
│       └── launcher.myw_workbench.sh  # your launcher stub (naming specimen)
│
├── tt/                                # TabTargets (tab-completion-friendly commands)
│   ├── z-launcher.sh                  # The trampoline every tabtarget execs into
│   ├── buw-tt-ll.ListLaunchers.sh     # List all launchers
│   ├── buw-rcv.ValidateConfigRegime.sh # Validate BURC
│   └── myw-p.Provision.sh             # your command (naming specimen)
│
├── Tools/                             # BURC_TOOLS_DIR: installed kits and your own toolkits
│   ├── buk/                           # BUK core utilities (installed from a parcel)
│   │   ├── bul_launcher.sh            # Shared launcher logic every stub sources
│   │   ├── bud_dispatch.sh            # Dispatch system
│   │   ├── buc_command.sh             # Command utilities
│   │   ├── buv_validation.sh          # Validation (type system)
│   │   ├── buw_workbench.sh           # BUK workbench
│   │   ├── buwz_zipper.sh             # BUK workbench zipper
│   │   ├── burc_regime.sh             # BURC regime module
│   │   ├── burs_regime.sh             # BURS regime module
│   │   ├── burs_template.sh           # BURS field list and defaults
│   │   └── README.md                  # This file
│   │
│   └── myk/                           # your toolkit (naming specimen)
│       ├── myw_workbench.sh
│       ├── myz_zipper.sh
│       └── myp_cli.sh
│
├── .vvk/                              # Brand file naming the parcel installed here
│
└── ../station-files/                  # Developer machine configs (NOT in git; a sibling of the root)
    └── burs.env                       # BURS assignment (station config)
```

Which step creates each directory:

| Directory | Created by |
|-----------|------------|
| `mymm_moorings/` | you, by hand, before the install |
| `mymm_moorings/rbml_launchers/` | you, by hand, before the install; `buw-tt-cl` writes into it and refuses where it does not stand |
| `tt/` | you, by hand, before the install; `z-launcher.sh` in it is yours to write, a kit's tabtargets are copied from a tree that has them, and the `buw-tt-c*` doors write your own |
| `Tools/` | you, by hand, before the install; the install writes into it and refuses where it does not stand |
| `Tools/buk/` | the parcel install |
| `.vvk/` | the parcel install |
| `Tools/myk/` | you: your own workbench, zipper and CLI modules, written against the [Module Contract](#module-contract) |
| `../station-files/` | you, or a station door the starter kit templates (see [Installation](#installation)); outside the repository |

**Execution Flow**:

```
User invokes TabTarget:
  $ tt/buw-tt-ll.ListLaunchers.sh
       ├── Colophon: buw-tt-ll
       └── Frontispiece: ListLaunchers

1. TabTarget execs the trampoline
   → tt/z-launcher.sh, with BURD_LAUNCHER=launcher.buw_workbench.sh

2. Trampoline resolves the launcher stub
   → mymm_moorings/rbml_launchers/launcher.buw_workbench.sh
   → changes to the repository root, exports BURD_CONFIG_DIR (the moorings), execs the stub

3. Launcher stub sources bul_launcher.sh, which validates regimes
   → loads and enforces BURC from BURD_CONFIG_DIR/burc.env
   → loads and enforces BURS from the station file BURC names
   → (If the station file is missing, prints the setup it needs and exits)

4. Launcher delegates to BURD
   → bud_dispatch.sh buw-tt-ll.ListLaunchers.sh

5. BURD sets up environment
   → Parses colophon, frontispiece, imprint(s) from filename
   → Creates temp/output directories
   → Sets up logging

6. BURD invokes Workbench
   → buw_workbench.sh, colophon as command, imprints as arguments

7. Workbench routes colophon
   → Kindles its zipper, then buz_exec_lookup execs the CLI module enrolled for "buw-tt-ll"
   → Returns exit status

8. BURD cleans up
   → Writes transcript
   → Propagates exit status
```

The trampoline is the only file that knows the moorings directory's name.
The kit reads `BURD_CONFIG_DIR` rather than any fixed name, which is what lets one BUK serve every repository;
so the trampoline is yours to write, and no door generates it.

---

## Installation

BUK arrives from a parcel: the parcel's install door writes it under the tools directory of a repository that already stands, and commits nothing.
The ordered road that stands such a repository up — with a ready template for every file placed by hand, the bootstrap seed among them — is the parcel starter kit's.
That kit stands beside this one in the parcel it arrived in; read its README before your first install.

What follows is the contract BUK places on a repository, each requirement stated once here and in full where the pointer leads.

- **A config regime file**, `burc.env`, in a moorings directory of your naming at the repository root.
  It declares exactly the ten variables `Tools/buk/burc_regime.sh` enrolls, and its validator refuses fewer or more; the install door reads three of them — `BURC_PROJECT_ROOT`, `BURC_TOOLS_DIR` and `BURC_MANAGED_KITS`. See [Config Regimes](#config-regimes).
- **The trampoline**, `tt/z-launcher.sh`, which is yours to write and no door generates.
  It has two duties: export `BURD_CONFIG_DIR` naming the moorings directory, and resolve the launcher a tabtarget names under that directory's `rbml_launchers/` subdirectory, a name the kit reads as a literal. See [Architecture](#architecture).
- **Launcher stubs and tabtargets**, one stub per workbench and one tabtarget per door you use.
  The doors write your own, a kit's tabtargets are copied from a tree that has them, and only the first stub and the first tabtarget are placed by hand, in exactly the shapes those doors emit. See [Launchers](#launchers) and [TabTargets](#tabtargets).
- **The doors you use, and no more.** A workbench routes whatever tabtargets stand and sweeps nothing at dispatch, so a partial roster is a smaller installation rather than a broken one. A kit's canonical tabtargets carry nothing of the repository they stand in, so copy the ones you want from a tree that has them, byte for byte, and mint only your own with the creation doors. The colophons BUK enrolls stand in `Tools/buk/buwz_zipper.sh`, and the source tree proves its own roster complete by test. See [Zipper](#zipper).
- **A station file**, per machine and never committed, at the path `BURC_STATION_FILE` names from the repository root.
  Its fields and defaults stand in `Tools/buk/burs_template.sh`, and every door run before it exists stops and prints the fields it needs. See [Config Regimes](#config-regimes).

Your own workbench's launcher stub is then one door away — `tt/buw-tt-cl.CreateLauncher.sh Tools/myk/myw_workbench.sh myw_workbench` — and its tabtargets are made with the `buw-tt-c*` doors naming that stub.

---

## BUK Components

### Module Prefix Registry

BUK modules use `bu{x}_` prefixes where `{x}` identifies the module.

| Prefix | Name | Status | Purpose |
|--------|------|--------|---------|
| `buc_` | command | Active | Command utilities, output formatting |
| `burd_` | dispatch | Active | Environment setup, invokes workbench |
| `buh_` | handbook | Active | Always-visible user interaction |
| `burc_` | regime-config | Active | Project-level Config Regime |
| `burs_` | regime-station | Active | Station-level Config Regime |
| `but_` | test | Active | Testing framework |
| `buut_` | tabtarget | Active | TabTarget/launcher creation |
| `buv_` | validation | Active | Type system, input validation |
| `buw_` | workbench | Active | BUK self-management workbench |
| `buz_` | zipper | Active | Colophon registry via parallel arrays |

**Conventions**:
- Three-letter: core modules (`buc_`, `bud_`)
- Four-letter: specialized modules (`burc_`, `buut_`)
- Reserved: planned but not yet implemented

---

### BURD - Bash Dispatch Utility

**File**: `Tools/buk/bud_dispatch.sh`

**Purpose**: Central dispatch system that sets up execution environment and invokes the workbench.

**Key Responsibilities**:
- Parse tabtarget filename into tokens
- Environment setup (temp dirs, output dirs, logging)
- Source BURS (station configuration)
- Resolve color policy
- Invoke workbench with proper context
- Capture and propagate exit status
- Generate execution transcript

#### Execution Context (Exported Variables)

BURD exports the following environment variables for workbench access:

**Invocation Identity**:

| Variable | Example | Description |
|----------|---------|-------------|
| `BURD_NOW_STAMP` | `20250101-143022-1234-567` | Unique timestamp: `YYYYMMDD-HHMMSS-PID-RANDOM` |
| `BURD_GIT_CONTEXT` | `v1.2.3-5-gabc123-dirty` | Output of `git describe --always --dirty --tags --long` |

**Token Explosion**:

TabTarget filenames are parsed into tokens using `BURC_TABTARGET_DELIMITER`. Each token is exported for workbench access:

| Variable | Semantic Role | For `rbw-cr.Rack.tadmor.sh` |
|----------|---------------|--------------------------------------|
| `BURD_TOKEN_1` | **Colophon** | `rbw-cr` |
| `BURD_TOKEN_2` | **Frontispiece** | `Rack` |
| `BURD_TOKEN_3` | **Imprint** | `tadmor` |
| `BURD_TOKEN_4` | Imprint (2nd) | *(empty)* |
| `BURD_TOKEN_5` | Imprint (3rd) | *(empty)* |
| `BURD_COMMAND` | Colophon | `rbw-cr` *(legacy, same as TOKEN_1)* |
| `BURD_TARGET` | Full filename | `rbw-cr.Rack.tadmor.sh` |
| `BURD_CLI_ARGS` | CLI arguments | *(extra arguments passed to tabtarget)* |

The workbench receives the colophon for routing and imprints as target parameters. The frontispiece is for human readability and typically not used at runtime.

This mirrors MBC's `MBC_TTPARAM__FIRST` through `MBC_TTPARAM__FIFTH` pattern.

**Directories**:

| Variable | Description |
|----------|-------------|
| `BURD_TEMP_DIR` | Ephemeral temp directory, unique per invocation; safe for intermediate files |
| `BURD_OUTPUT_DIR` | Output directory; cleared and recreated each run |
| `BURD_TRANSCRIPT` | Path to transcript file in temp directory |

**Logging** (paths, not file handles):

| Variable | Description |
|----------|-------------|
| `BURD_LOG_LAST` | Path to "last run" log |
| `BURD_LOG_SAME` | Path to same-name log |
| `BURD_LOG_HIST` | Path to historical log (timestamped) |

**Display**:

| Variable | Values | Description |
|----------|--------|-------------|
| `BURE_COLOR` | `auto`, `0`, or `1` | Operator override for color policy; read at dispatch, never written. The resolved verdict lands in `BURD_COLOR`; `NO_COLOR` is respected |

#### Control Variables

Set these *before* invoking a tabtarget to modify dispatch behavior (BURE is
the ambient override family — the only one set from the caller's environment):

| Variable | Values | Effect |
|----------|--------|--------|
| `BURE_VERBOSE` | `0`, `1`, `2`, `3` | `0`=quiet, `1`=debug output, `2`=bash trace (`set -x`), `3`=trace + deep diagnostics |

Two dispatch-mode flags exist but are *not* ambient controls: they are static
properties of a tabtarget, exported in its own `BURD_*` block, and never set
from the environment — a launching harness strips any inherited copy so each
launched context chooses its own mode:

| Variable | Values | Effect |
|----------|--------|--------|
| `BURD_NO_LOG` | any value | This tabtarget's dispatch runs unlogged (no log files, no station load, streams unmerged) |
| `BURD_INTERACTIVE` | any value | This tabtarget runs interactive: output to terminal via uncurated tee |

#### The Three-Log Pattern

BURD maintains three views of execution output to support different debugging scenarios:

| Log | Variable | Lifecycle | Purpose |
|-----|----------|-----------|---------|
| **Historical** | `BURD_LOG_HIST` | Never overwritten | Timestamped archive; enables audit trail and post-hoc debugging |
| **Latest** | `BURD_LOG_LAST` | Overwritten each invocation | Quick access to most recent run, regardless of command |
| **Same-name** | `BURD_LOG_SAME` | Overwritten per-command | Preserves last run of *this specific* tabtarget |

**Rationale**: Different debugging scenarios need different log access patterns:

- "What just happened?" → Latest log (`BURD_LOG_LAST`)
- "What happened last time I ran *this* command?" → Same-name log (`BURD_LOG_SAME`)
- "What happened at 3pm yesterday?" → Historical log (`BURD_LOG_HIST`)

**Filename Conventions**:

- Historical: `hist-{tabtarget}-{timestamp}.{ext}` (e.g., `hist-buw-ll-sh-20250101-143022.txt`)
- Latest: `{BURC_LOG_LAST}.{ext}` (e.g., `last.txt`)
- Same-name: `same-{tabtarget}.{ext}` (e.g., `same-buw-ll-sh.txt`)

The log directory is specified by `BURS_LOG_DIR` in the station configuration.

---

### BUC - Bash Utility Command

**File**: `Tools/buk/buc_command.sh`

**Purpose**: Common command-line utilities and helpers.

**Key Functions**:
- Command execution helpers
- Output formatting
- Error handling patterns

---

### BUV - Bash Utility Validation

**File**: `Tools/buk/buv_validation.sh`

**Purpose**: Type system for Config Regime validation.

**Validation Functions**:

BUV provides three function categories:

| Prefix | Purpose | Example |
|--------|---------|---------|
| `buv_val_*` | Core validators (take value directly) | `buv_val_string "$val" 1 255` |
| `buv_env_*` | Environment variable validators | `buv_env_string "VAR_NAME" 1 255` |
| `buv_opt_*` | Optional validators (allow empty) | `buv_opt_bool "OPTIONAL_FLAG"` |

**Atomic Types**:
- `string` - String with length constraints
- `xname` - System-safe identifier (xname = cross-platform name)
- `gname` - Group name identifier
- `fqin` - Fully Qualified Image Name
- `bool` - Boolean (`true`/`false`)
- `decimal` - Decimal number with range constraints
- `ipv4` - IPv4 address
- `cidr` - CIDR notation
- `domain` - Domain name
- `port` - Port number (1-65535)
- `odref` - Output directory reference

**List Types**:
- `list_ipv4` - Comma-separated IPv4 addresses
- `list_cidr` - Comma-separated CIDR blocks
- `list_domain` - Comma-separated domains

**Usage Example**:

```bash
# Validate an environment variable (most common usage)
buv_env_string "BURC_TABTARGET_DIR" 1 255 || exit 1
buv_env_xname  "BURC_LOG_LAST"            || exit 1

# Validate a value directly
buv_val_port "${some_port}" || exit 1

# Validate an optional variable (empty is OK)
buv_opt_bool "OPTIONAL_DEBUG_FLAG" || exit 1
```

---

### BUW - BUK Workbench

**File**: `Tools/buk/buw_workbench.sh`

**Purpose**: Self-management workbench for BUK itself.

**Commands**:

**TabTarget Subsystem** (`buw-tt-*`):
- `buw-tt-ll` - List launchers in `rbml_launchers/`
- `buw-tt-cbl <launcher> <name>...` - Create batch+logging tabtarget (default)
- `buw-tt-cbn <launcher> <name>...` - Create batch+nolog tabtarget
- `buw-tt-cil <launcher> <name>...` - Create interactive+logging tabtarget
- `buw-tt-cin <launcher> <name>...` - Create interactive+nolog tabtarget
- `buw-tt-cl <workbench> <name>` - Create launcher

**Regime Management**:
- `buw-rv` - Validate BURC and BURS regimes
- `buw-rr` - Render BURC and BURS configurations
- `buw-ri` - Show regime specification info

---

## Creating a New Workbench

To create a new workbench:

1. **Study the delivered workbench** as a template:
   - `Tools/buk/buw_workbench.sh` - the workbench, kindling and routing
   - `Tools/buk/buwz_zipper.sh` - its zipper, enrolling each colophon to a CLI module
   - `Tools/buk/burs_cli.sh` - a CLI module the zipper enrolls

2. **Create the workbench, its zipper and its CLI modules** in `Tools/{prefix}/`, following the [Module Contract](#module-contract)

3. **Create the launcher** using `buw-tt-cl`:
   ```bash
   tt/buw-tt-cl.CreateLauncher.sh Tools/myw/myw_workbench.sh myw_workbench
   ```

4. **Create tabtargets** using `buw-tt-cbl` (or appropriate variant):
   ```bash
   tt/buw-tt-cbl.CreateTabTargetBatchLogging.sh mymm_moorings/rbml_launchers/launcher.myw_workbench.sh myw-cmd.CommandName
   ```

---

## Module Contract

Every BUK module follows these rules, and a module of your own that follows them
dispatches, kindles and documents itself the way BUK's do. Each rule names a
delivered module that shows it; when in doubt, read that module.

`myk`, `myw`, `myz` and `myp` below are naming specimens standing for your own
prefix.

### Every module

| Rule | Shown in |
|------|----------|
| The file is `{prefix}_{word}.sh`, and `set -euo pipefail` runs before any other statement | `Tools/buk/burs_regime.sh` |
| A public function is named `{prefix}_{word}`; a private one is named `z{prefix}_{word}` | `Tools/buk/buz_zipper.sh` (`buz_enroll` public, `zbuz_kindle` private) |
| Locals are declared `local`, named `z_{word}`, and made `local -r` when never reassigned | `Tools/buk/buz_zipper.sh` (`buz_enroll`) |
| Every expansion is braced and quoted: `"${z_name}"`, never `$z_name` | `Tools/buk/buz_zipper.sh` |
| A failure dies through `buc_die_now "message"`, never `echo` and `exit` | `Tools/buk/buz_zipper.sh` (`buz_enroll`) |
| The code runs under bash 3.2, the macOS default shell | `Tools/buk/buz_zipper.sh` (`buz_emit_const_str` states why its interface is per-pair) |

### A sourced module

A module other files `source` carries state only once it is kindled, so
sourcing it defines functions and nothing more.

| Rule | Shown in |
|------|----------|
| It guards against a second inclusion at the top: `test -z "${Z<PREFIX>_SOURCED:-}" \|\| return 0`, then `Z<PREFIX>_SOURCED=1`. Where a second inclusion means a wrong sourcing hierarchy, it dies instead of returning | `Tools/buk/buwz_zipper.sh` (returns); `Tools/buk/burs_regime.sh` (dies) |
| A module holding state defines `z{prefix}_kindle`, which dies if already kindled, sets up that state, and ends `readonly Z<PREFIX>_KINDLED=1` | `Tools/buk/burs_regime.sh` (`zburs_kindle`) |
| It defines `z{prefix}_sentinel`, which dies unless `Z<PREFIX>_KINDLED` is `1` | `Tools/buk/burs_regime.sh` (`zburs_sentinel`) |
| Every function that reads kindled state calls the sentinel first | `Tools/buk/buz_zipper.sh` (`buz_enroll` calls `zbuz_sentinel`) |
| A kindle that needs another module kindled calls that module's sentinel first | `Tools/buk/buwz_zipper.sh` (`zbuwz_kindle` calls `zbuz_sentinel`) |
| Kindling is the caller's explicit act, in dependency order | `Tools/buk/buw_workbench.sh` |

### A CLI module

A CLI module is what a zipper enrolls. It is executed, never sourced, and it
must be committed executable.

| Rule | Shown in |
|------|----------|
| It sources `buc_command.sh` and `buym_yelp.sh` from `${BURD_BUK_DIR}` | `Tools/buk/burs_cli.sh` |
| Each command is a function `{prefix}_{verb}`, and a helper that is not a command is `z`-prefixed, since the help listing shows every function carrying the prefix | `Tools/buk/burs_cli.sh`; the listing is `zbuc_show_help` in `Tools/buk/buc_command.sh` |
| Each command opens with `buc_doc_brief "what it does"`, then `buc_doc_shown \|\| return 0`, so the help listing can call it without running it | `Tools/buk/burs_cli.sh` (`burs_validate`) |
| A furnish function `z{prefix}_furnish` opens with its `buc_doc_env_row` lines and `buc_doc_env_done \|\| return 0`, then sources and kindles what the commands need | `Tools/buk/burs_cli.sh` (`zburs_furnish`) |
| The last line of code is `buc_execute {prefix}_ "Title" z{prefix}_furnish "$@"` | `Tools/buk/burs_cli.sh` |

### A zipper

| Rule | Shown in |
|------|----------|
| It is a sourced module named `{prefix}z_zipper.sh`, with the guard, kindle and sentinel above | `Tools/buk/buwz_zipper.sh` |
| Its kindle calls `zbuz_sentinel`, then one `buz_enroll` per colophon: constant name, colophon, CLI module filename, command function, channel, description | `Tools/buk/buwz_zipper.sh` |
| The channel says how the command receives its folio: `""` for none, `"imprint"` for the tabtarget filename's third token, `"param1"` for the first argument; the command reads it from `BUZ_FOLIO` | `Tools/buk/buwz_zipper.sh`; decoded in `buz_exec_lookup`, `Tools/buk/buz_zipper.sh` |

`buz_tome_seat` is needed only by a project that projects its colophons as
constants into generated code; a zipper that only dispatches may omit it.

### A workbench

| Rule | Shown in |
|------|----------|
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

---

## Reference Implementation: BURC/BURS

BURC and BURS are BUK's own Config Regimes, serving as both:
1. **Implementation** - Working regimes for BUK's operation
2. **Example** - Canonical demonstration of the Config Regime pattern

### BURC - Bash Utility Regime Configuration

**Purpose**: Project-level configuration defining repository structure.

**Assignment File**: `mymm_moorings/burc.env`

**Variables**:

| Variable | Type | Purpose |
|----------|------|---------|
| `BURC_STATION_FILE` | string | Path to developer's BURS file (relative to project root) |
| `BURC_TABTARGET_DIR` | string | Directory containing tabtarget scripts |
| `BURC_TABTARGET_DELIMITER` | string | Token separator in tabtarget filenames |
| `BURC_TOOLS_DIR` | string | Directory containing tool scripts |
| `BURC_TEMP_ROOT_DIR` | string | Parent directory for temp directories |
| `BURC_OUTPUT_ROOT_DIR` | string | Parent directory for output directories |
| `BURC_LOOSEBOX_ROOT_DIR` | string | Parent directory holding one checkout-keyed loosebox per checkout |
| `BURC_LOG_LAST` | xname | Basename for "last run" log file |
| `BURC_LOG_EXT` | xname | Extension for log files (without dot) |

**Example**:
```bash
BURC_STATION_FILE=../station-files/burs.env
BURC_TABTARGET_DIR=tt
BURC_TABTARGET_DELIMITER=.
BURC_TOOLS_DIR=Tools
BURC_TEMP_ROOT_DIR=../temp-buk
BURC_OUTPUT_ROOT_DIR=../output-buk
BURC_LOOSEBOX_ROOT_DIR=../loosebox-buk
BURC_LOG_LAST=last
BURC_LOG_EXT=txt
```

**Key Insight**: BURC allows projects to organize directories differently while using the same BUK utilities.

---

### BURS - Bash Utility Regime Station

**Purpose**: Developer/machine-level configuration for personal preferences.

**Assignment File**: `../station-files/burs.env` (location defined by `BURC_STATION_FILE`)

**Variables**:

| Variable | Type | Purpose |
|----------|------|---------|
| `BURS_LOG_DIR` | string | Where this developer stores logs |

**Example**:
```bash
BURS_LOG_DIR=../_logs_buk
```

**Key Insight**: BURS is NOT checked into git. Each developer can have different logging preferences, parallelism settings, etc.

---

## Design Philosophy

### Portability

BUK is designed to be **graftable**: copy `Tools/buk/` into any project, configure via regime files, and it works. No modification to BUK code is needed.

### Immutability

The `Tools/buk/` directory remains unchanged across projects. All project-specific behavior comes from configuration, not code changes.

### Configuration as Data

Config Regimes treat configuration as structured data with types, validation, and documentation. This eliminates an entire class of runtime errors.

### Discoverability

TabTargets + tab completion make commands discoverable. Type `tt/buw-<TAB>` to see all BUK commands.

### Fail Fast

Launchers validate regimes before execution. This catches configuration errors immediately, with helpful error messages.

### Exit Status Propagation

TabTarget systems must faithfully propagate exit status from the executed command back to the invoking shell. This is critical for:

- **CI/CD pipelines** that rely on exit codes to determine success/failure
- **Shell scripts** that chain commands with `&&` or check `$?`
- **Make rules** that depend on prerequisite command success

BUK achieves reliable status propagation through:

1. **`exec` in TabTargets**: Replaces the shell process entirely, so exit status flows directly to the caller without intermediate shell interference.

2. **`exec` in Launchers**: Same benefit at the launcher layer—no wrapper shell to mask the exit code.

3. **Pipeline status capture in BDU**: When output is piped through `tee` for logging, BDU explicitly captures `PIPESTATUS[0]` (the command's exit code) rather than the pipeline's final status (which would be `tee`'s exit code).

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

Every BUK module follows the [Module Contract](#module-contract), which states
each rule beside a delivered module that shows it.

---

## Future Directions

BUK's current scope covers portable CLI infrastructure and configuration management. The following directions represent potential extensions that maintain portability while addressing enterprise development patterns and standards enforcement.

### Standards Installation & Awareness

Vision: Inject enterprise bash practices into development workflows from session start, with the Module Contract as the anchor standard. Rather than relying on LLM training defaults, developers work with pre-configured awareness of anti-patterns and best practices. This prevents bad suggestions before they appear.

May eventually involve:
- Integration with CLAUDE.md to document enterprise bash standards
- Session initialization that establishes standards context
- Real-time guidance on pattern compliance

### Hidden Configuration Workbench

Vision: A wholly internal workbench (separate from the portable BUK toolkit) that manages Claude Code-specific configuration and behavior using BUK's tabtarget/dispatch/regime infrastructure internally. Follows the Job Jockey installation model: detect, modify CLAUDE.md, register capabilities.

May eventually involve:
- Project-specific hooks and configuration management
- Behavior tuning that adjusts tool proclivities without per-session instruction
- Hidden config files and internal tools not published with the portable BUK toolkit

### Code Validation Skills

Vision: Skills that validate bash code against enterprise standards in real-time, catching deviations early. Anchored by the Module Contract.

May eventually involve:
- Skills like `/validate-bash`, `/check-module-contract`
- Integration with workbench validation functions
- Forensic output for code review and standards enforcement

---

## Contributing

When extending BUK:

1. **Follow the module contract** - See the "Module Contract" section above
2. **Maintain portability** - No project-specific logic in `Tools/buk/`
3. **Use Config Regimes** - Configuration belongs in regime files, not code
4. **Document the regime** - Enroll every variable's type, constraints, and purpose in the regime script (`{regime}_regime.sh`)
5. **Add validation** - Use BVU type system for all config variables
6. **Update README** - Keep this file as the authoritative source

---

## License

Copyright 2025 Scale Invariant, Inc.

Licensed under the Apache License, Version 2.0.

---

## Author

Brad Hyslop <bhyslop@scaleinvariant.org>
