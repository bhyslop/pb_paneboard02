# Bash Utility Kit (BUK)

A portable, graftable bash infrastructure for building maintainable command-line tools with configuration management, dispatch routing, and validation.

## Table of Contents

- [Overview](#overview)
- [Core Concepts](#core-concepts)
  - [Launchers](#launchers)
  - [Workbenches](#workbenches)
  - [TabTargets](#tabtargets)
  - [Config Regimes](#config-regimes)
- [Architecture](#architecture)
- [Installation](#installation)
- [BUK Components](#buk-components)
- [Creating a New Workbench](#creating-a-new-workbench)
- [Reference Implementation: BURC/BURS](#reference-implementation-burcburs)

---

## Overview

BUK provides a three-layer architecture for bash-based CLI tools:

1. **BUK Core** (`Tools/buk/*.sh`) - Portable utilities with no project-specific knowledge
2. **BURC** (`.buk/burc.env`) - Project-level configuration defining repository structure
3. **BURS** (`../station-files/burs.env`) - Developer/machine-level configuration (not in git)

This separation allows BUK to be copied wholesale into any project and configured through regime files rather than code modification.

---

## Core Concepts

### Launchers

**Definition**: A launcher is a bootstrap script that validates configuration, loads regime files, and delegates to the BDU (Bash Dispatch Utility).

**Naming Pattern**: `launcher.{workbench_name}.sh`

**Location**: `.buk/` directory at project root

**Examples**:
- `.buk/launcher.buw_workbench.sh` - BUK workbench launcher
- `.buk/launcher.cccw_workbench.sh` - CCCK workbench launcher
- `.buk/launcher.rbk_Coordinator.sh` - RBW coordinator launcher

**Canonical Structure**:

```bash
#!/bin/bash
# Compatible with Bash 3.2 (e.g., macOS default shell)

z_project_root_dir="${0%/*}/.."
cd "${z_project_root_dir}" || exit 1

# Load BURC configuration
export BDU_REGIME_FILE="${z_project_root_dir}/.buk/burc.env"
source "${BDU_REGIME_FILE}" || exit 1

# Validate config regimes that are known at launch time
# NOTE: BURC and BURS are the standard BUK regimes (project structure + station config)
# These are always validated here because they're required for BDU operation.
#
# Other project-specific regimes (like RBRN, RBRR, etc.) may be validated later
# during workbench dispatch, when runtime context is available.
"${BURC_TOOLS_DIR}/buk/burc_regime.sh" validate "${z_project_root_dir}/.buk/burc.env" || {
  echo "ERROR: BURC validation failed" >&2
  "${BURC_TOOLS_DIR}/buk/burc_regime.sh" info
  exit 1
}

z_station_file="${z_project_root_dir}/${BURC_STATION_FILE}"
"${BURC_TOOLS_DIR}/buk/burs_regime.sh" validate "${z_station_file}" || {
  echo "ERROR: BURS validation failed: ${z_station_file}" >&2
  "${BURC_TOOLS_DIR}/buk/burs_regime.sh" info
  exit 1
}

# Set coordinator script (the workbench for this launcher)
export BDU_COORDINATOR_SCRIPT="${BURC_TOOLS_DIR}/buk/buw_workbench.sh"

# Delegate to BDU
exec "${BURC_TOOLS_DIR}/buk/bud_dispatch.sh" "${1##*/}" "${@:2}"
```

**Key Responsibilities**:
1. Establish project root context
2. Load BURC configuration
3. Validate required config regimes (fail early if misconfigured)
4. Specify which workbench coordinates commands
5. Delegate execution to BDU

**Design Rationale**:
- Launchers catch configuration errors before BDU starts
- Clear naming ties launcher to its workbench
- Validation output helps developers fix configuration issues
- `exec` replaces the launcher process (no extra process overhead)

**Regime Validation Timing**:

Config regimes fall into two categories based on when they can be validated:

1. **Launch-time regimes** (validated in launcher):
   - **BURC** - Project structure configuration (always required by BUK)
   - **BURS** - Developer station configuration (always required by BUK)
   - **RBRR** - Recipe Bottle Regime Repo (RBW project config, if using RBW)
   - These are known immediately at launch time

2. **Runtime regimes** (validated in workbench):
   - **RBRN** - Recipe Bottle Regime Nameplate (RBW service config, runtime-specific)
   - Other project-specific regimes that depend on runtime context
   - These are validated during workbench dispatch when context is available

**Guideline**: All launchers created by BUK should validate BURC and BURS. Additional regime validation is optional and workbench-specific.

---

### Workbenches

**Definition**: A workbench is a multi-call bash script that routes commands to their implementations.

**Naming Pattern**: `{prefix}w_workbench.sh` or `{prefix}k_Coordinator.sh`

**Location**: `Tools/{workbench}/` subdirectory

**Examples**:
- `Tools/buk/buw_workbench.sh` - BUK workbench (manages BUK itself)
- `Tools/ccck/cccw_workbench.sh` - CCCK workbench (container control)
- `Tools/rbw/rbk_Coordinator.sh` - RBW coordinator (recipe bottle management)

**Structure**:

```bash
#!/bin/bash
set -euo pipefail

# Route function
workbench_route() {
  local z_command="$1"
  shift

  case "${z_command}" in
    cmd1) workbench_cmd1 "$@" ;;
    cmd2) workbench_cmd2 "$@" ;;
    *)
      echo "ERROR: Unknown command: ${z_command}" >&2
      exit 1
      ;;
  esac
}

# Command implementations
workbench_cmd1() {
  # Implementation
}

workbench_cmd2() {
  # Implementation
}

# Main entry point
workbench_main() {
  local z_command="${1:-}"
  shift || true

  if [ -z "${z_command}" ]; then
    echo "ERROR: No command specified" >&2
    exit 1
  fi

  workbench_route "${z_command}" "$@"
}

workbench_main "$@"
```

**Key Characteristics**:
- Single-file coordinator that routes commands
- Follows multi-call pattern (single script, multiple commands via case routing)
- Loads configuration (BURC/BURS) as needed
- Can delegate to other scripts for complex operations
- Crash-fast error handling (`set -euo pipefail`)

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

**Naming Pattern**: `{command}.{description}.sh`

**Location**: `tt/` directory at project root (configurable via `BURC_TABTARGET_DIR`)

**Token Delimiter**: Configurable via `BURC_TABTARGET_DELIMITER` (typically `.`)

**Examples**:
- `tt/buw-ll.ListLaunchers.sh` - List launchers
- `tt/buw-rv.ValidateRegimes.sh` - Validate regimes
- `tt/ccck-ps.ProcessStatus.sh` - Show container processes

**Canonical Structure**:

```bash
#!/bin/bash
# TabTarget - delegates to {workbench} via launcher
exec "$(dirname "${BASH_SOURCE[0]}")/../.buk/launcher.{workbench}.sh" \
  "${0##*/}" "${@}"
```

**Command Token Parsing**:

The filename `buw-ll.ListLaunchers.sh` is parsed as:
- Full filename: `buw-ll.ListLaunchers.sh`
- First token (command): `buw-ll` (everything before first delimiter)
- Subsequent tokens: `ListLaunchers` (descriptive, for human readability)

BDU extracts the command token using `${filename%%${BURC_TABTARGET_DELIMITER}*}`.

**Key Benefits**:
1. **Tab completion**: Type `tt/buw-` then press TAB to see all BUK commands
2. **Self-documenting**: Filename describes what the command does
3. **Discoverability**: `ls tt/` shows all available commands
4. **Consistency**: All commands follow same invocation pattern
5. **Lightweight**: No logic in tabtargets, just delegation

**Design Rationale**:
- Leverages shell tab completion for command discovery
- Descriptive filenames serve as inline documentation
- Delegating to launchers ensures validation happens on every invocation
- Token-based parsing allows flexible, hierarchical command names

---

### Config Regimes

**Definition**: A Config Regime is a structured configuration system consisting of:
- **Specification** - Markdown document defining variables, types, and constraints
- **Assignment** - Shell-sourceable file (`.env`) containing actual values
- **Validator** - Script that enforces type rules and constraints
- **Renderer** - Script that displays configuration in human-readable format

**Namespace Identity**: Unique uppercase prefix (e.g., `BURC_`, `BURS_`, `RBRN_`, `RBRR_`) prevents variable collisions.

**Core Components**:

1. **Assignment File** (`{regime}.env`)
   - Concise filename (frequently sourced)
   - Shell-sourceable: `VAR=value` syntax, no spaces around `=`
   - Can use `${VAR}` expansion for derived values
   - Example: `.buk/burc.env`

2. **Specification File** (`{regime}_specification.md`)
   - Documents all variables, types, and constraints
   - Self-documenting, readable
   - Example: `Tools/buk/burc_specification.md`

3. **Regime Script** (`{regime}_regime.sh`)
   - Multi-call script with subcommands
   - Subcommands: `validate`, `render`, `info`
   - Example: `Tools/buk/burc_regime.sh`

**File Naming Pattern**:
- **Assignment**: `{regime}.env` (concise, frequently sourced)
- **Support files**: `{regime}_{full_word}.{ext}` (readable, self-documenting)

**Examples**:

| Regime | Assignment | Specification | Validator/Renderer |
|--------|-----------|---------------|-------------------|
| BURC | `.buk/burc.env` | `Tools/buk/burc_specification.md` | `Tools/buk/burc_regime.sh` |
| BURS | `../station-files/burs.env` | `Tools/buk/burs_specification.md` | `Tools/buk/burs_regime.sh` |

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
├── .buk/                              # Launcher directory (project-specific bootstrap)
│   ├── burc.env                       # BURC assignment (project structure config)
│   ├── launcher.buw_workbench.sh      # BUK launcher (with validation)
│   ├── launcher.cccw_workbench.sh     # CCCK launcher (with validation)
│   └── launcher.rbk_Coordinator.sh    # RBW launcher (with validation)
│
├── tt/                                # TabTargets (tab-completion-friendly commands)
│   ├── buw-ll.ListLaunchers.sh        # List all launchers
│   ├── buw-rv.ValidateRegimes.sh      # Validate BURC/BURS
│   └── ccck-ps.ProcessStatus.sh       # Container status
│
├── Tools/                             # Tool scripts (portable, reusable)
│   ├── buk/                           # BUK core utilities (graftable module)
│   │   ├── bud_dispatch.sh # Dispatch system
│   │   ├── buc_command.sh  # Command utilities
│   │   ├── but_test.sh     # Test utilities
│   │   ├── buv_validation.sh # Validation (type system)
│   │   ├── buw_workbench.sh           # BUK workbench
│   │   ├── burc_specification.md      # BURC spec
│   │   ├── burc_regime.sh             # BURC validator/renderer
│   │   ├── burs_specification.md      # BURS spec
│   │   ├── burs_regime.sh             # BURS validator/renderer
│   │   └── README.md                  # This file
│   │
│   ├── ccck/                          # CCCK workbench
│   │   └── cccw_workbench.sh
│   │
│   └── rbw/                           # RBW workbench
│       └── rbk_Coordinator.sh
│
└── ../station-files/                  # Developer machine configs (NOT in git)
    └── burs.env                       # BURS assignment (station config)
```

**Execution Flow**:

```
User invokes TabTarget:
  $ tt/buw-ll.ListLaunchers.sh

1. TabTarget delegates to Launcher
   → .buk/launcher.buw_workbench.sh buw-ll

2. Launcher validates regimes
   → burc_regime.sh validate .buk/burc.env
   → burs_regime.sh validate ../station-files/burs.env
   → (If validation fails, display info and exit)

3. Launcher delegates to BDU
   → bud_dispatch.sh buw-ll

4. BDU sets up environment
   → Creates temp/output directories
   → Sources BURS (station config)
   → Sets up logging

5. BDU invokes Workbench
   → buw_workbench.sh buw-ll

6. Workbench routes command
   → Case statement routes "buw-ll" to implementation
   → Executes command logic
   → Returns exit status

7. BDU cleans up
   → Writes transcript
   → Propagates exit status
```

---

## Installation

### Quick Start: Copy BUK into Your Project

1. **Copy BUK directory**:
   ```bash
   cp -r /path/to/source/Tools/buk ./Tools/
   ```

2. **Create `.buk` directory and BURC file**:
   ```bash
   mkdir -p .buk
   cat > .buk/burc.env <<'EOF'
   # Bash Utility Regime Configuration (BURC)
   # Project-level configuration for BUK

   BURC_STATION_FILE=../station-files/burs.env
   BURC_TABTARGET_DIR=tt
   BURC_TABTARGET_DELIMITER=.
   BURC_TOOLS_DIR=Tools
   BURC_TEMP_ROOT_DIR=../temp-buk
   BURC_OUTPUT_ROOT_DIR=../output-buk
   BURC_LOG_LAST=last
   BURC_LOG_EXT=txt
   EOF
   ```

3. **Create TabTarget directory**:
   ```bash
   mkdir -p tt
   ```

4. **Create station file location**:
   ```bash
   mkdir -p ../station-files
   cat > ../station-files/burs.env <<'EOF'
   # Bash Utility Regime Station (BURS)
   # Developer/machine-level configuration for BUK

   BURS_LOG_DIR=../_logs_buk
   EOF
   ```

5. **Validate installation**:
   ```bash
   Tools/buk/burc_regime.sh validate .buk/burc.env
   Tools/buk/burs_regime.sh validate ../station-files/burs.env
   ```

---

## BUK Components

### BUD - Bash Dispatch Utility

**File**: `Tools/buk/bud_dispatch.sh`

**Purpose**: Central dispatch system that sets up execution environment and delegates to workbenches.

**Key Responsibilities**:
- Parse tabtarget filename into tokens
- Environment setup (temp dirs, output dirs, logging)
- Source BURS (station configuration)
- Resolve color policy
- Invoke workbench with proper context
- Capture and propagate exit status
- Generate execution transcript

#### Execution Context (Exported Variables)

BUD exports the following environment variables for workbench access:

**Invocation Identity**:

| Variable | Example | Description |
|----------|---------|-------------|
| `BUD_NOW_STAMP` | `20250101-143022-1234-567` | Unique timestamp: `YYYYMMDD-HHMMSS-PID-RANDOM` |
| `BUD_GIT_CONTEXT` | `v1.2.3-5-gabc123-dirty` | Output of `git describe --always --dirty --tags --long` |

**Token Explosion**:

TabTarget filenames are parsed into tokens using `BURC_TABTARGET_DELIMITER`. Each token is exported for workbench access:

| Variable | For `buw-tc.CreateTabTarget.sh` |
|----------|--------------------------------|
| `BUD_TOKEN_1` | `buw-tc` |
| `BUD_TOKEN_2` | `CreateTabTarget` |
| `BUD_TOKEN_3` | `sh` |
| `BUD_TOKEN_4` | *(empty)* |
| `BUD_TOKEN_5` | *(empty)* |
| `BUD_COMMAND` | `buw-tc` *(legacy, same as TOKEN_1)* |
| `BUD_TARGET` | `buw-tc.CreateTabTarget.sh` *(full filename)* |
| `BUD_CLI_ARGS` | *(extra arguments passed to tabtarget)* |

This mirrors MBC's `MBC_TTPARAM__FIRST` through `MBC_TTPARAM__FIFTH` pattern.

**Directories**:

| Variable | Description |
|----------|-------------|
| `BUD_TEMP_DIR` | Ephemeral temp directory, unique per invocation; safe for intermediate files |
| `BUD_OUTPUT_DIR` | Output directory; cleared and recreated each run |
| `BUD_TRANSCRIPT` | Path to transcript file in temp directory |

**Logging** (paths, not file handles):

| Variable | Description |
|----------|-------------|
| `BUD_LOG_LAST` | Path to "last run" log |
| `BUD_LOG_SAME` | Path to same-name log |
| `BUD_LOG_HIST` | Path to historical log (timestamped) |

**Display**:

| Variable | Values | Description |
|----------|--------|-------------|
| `BUD_COLOR` | `0` or `1` | Color policy after terminal detection; respects `NO_COLOR` |

#### Control Variables

Set these *before* invoking a tabtarget to modify dispatch behavior:

| Variable | Values | Effect |
|----------|--------|--------|
| `BUD_VERBOSE` | `0`, `1`, `2` | `0`=quiet, `1`=debug output, `2`=bash trace (`set -x`) |
| `BUD_NO_LOG` | any value | Disables all logging |
| `BUD_INTERACTIVE` | any value | Line-buffered output mode for interactive commands |

#### The Three-Log Pattern

BDU maintains three views of execution output to support different debugging scenarios:

| Log | Variable | Lifecycle | Purpose |
|-----|----------|-----------|---------|
| **Historical** | `BDU_LOG_HIST` | Never overwritten | Timestamped archive; enables audit trail and post-hoc debugging |
| **Latest** | `BDU_LOG_LAST` | Overwritten each invocation | Quick access to most recent run, regardless of command |
| **Same-name** | `BDU_LOG_SAME` | Overwritten per-command | Preserves last run of *this specific* tabtarget |

**Rationale**: Different debugging scenarios need different log access patterns:

- "What just happened?" → Latest log (`BDU_LOG_LAST`)
- "What happened last time I ran *this* command?" → Same-name log (`BDU_LOG_SAME`)
- "What happened at 3pm yesterday?" → Historical log (`BDU_LOG_HIST`)

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

### BUT - Bash Utility Test

**File**: `Tools/buk/but_test.sh`

**Purpose**: Testing framework for bash scripts.

**Key Functions**:
- Test case definition
- Assertion helpers
- Test runner

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

**Launcher Management**:
- `buw-ll` - List launchers in `.buk/`
- `buw-lc <name>` - Create new launcher from template
- `buw-lv <name>` - Validate existing launcher

**TabTarget Management**:
- `buw-tc <workbench> <name>` - Create new tabtarget

**Regime Management**:
- `buw-rv` - Validate BURC and BURS regimes
- `buw-rr` - Render BURC and BURS configurations
- `buw-ri` - Show regime specification info

---

## Creating a New Workbench

### Step 1: Plan Your Workbench

Decide:
- **Workbench name**: `{prefix}w_workbench.sh` (e.g., `myw_workbench.sh`)
- **Commands**: What operations will it provide?
- **Config Regime** (optional): Does it need project-specific config?

### Step 2: Create Workbench Directory

```bash
mkdir -p Tools/myw
```

### Step 3: Create Workbench Script

```bash
cat > Tools/myw/myw_workbench.sh <<'EOF'
#!/bin/bash
set -euo pipefail

MYW_SCRIPT_DIR="${BASH_SOURCE[0]%/*}"

myw_route() {
  local z_command="$1"
  shift

  case "${z_command}" in
    myw-hello)
      echo "Hello from myw workbench!"
      ;;
    myw-info)
      echo "Workbench info goes here"
      ;;
    *)
      echo "ERROR: Unknown command: ${z_command}" >&2
      exit 1
      ;;
  esac
}

myw_main() {
  local z_command="${1:-}"
  shift || true

  if [ -z "${z_command}" ]; then
    echo "ERROR: No command specified" >&2
    exit 1
  fi

  myw_route "${z_command}" "$@"
}

myw_main "$@"
EOF

chmod +x Tools/myw/myw_workbench.sh
```

### Step 4: Create Launcher

```bash
cat > .buk/launcher.myw_workbench.sh <<'EOF'
#!/bin/bash
z_project_root_dir="${0%/*}/.."
cd "${z_project_root_dir}" || exit 1
export BDU_REGIME_FILE="${z_project_root_dir}/.buk/burc.env"
source "${BDU_REGIME_FILE}" || exit 1

# Validate regimes
"${BURC_TOOLS_DIR}/buk/burc_regime.sh" validate "${z_project_root_dir}/.buk/burc.env" || {
  echo "ERROR: BURC validation failed" >&2
  "${BURC_TOOLS_DIR}/buk/burc_regime.sh" info
  exit 1
}

z_station_file="${z_project_root_dir}/${BURC_STATION_FILE}"
"${BURC_TOOLS_DIR}/buk/burs_regime.sh" validate "${z_station_file}" || {
  echo "ERROR: BURS validation failed: ${z_station_file}" >&2
  "${BURC_TOOLS_DIR}/buk/burs_regime.sh" info
  exit 1
}

export BDU_COORDINATOR_SCRIPT="${BURC_TOOLS_DIR}/myw/myw_workbench.sh"
exec "${BURC_TOOLS_DIR}/buk/bud_dispatch.sh" "${1##*/}" "${@:2}"
EOF

chmod +x .buk/launcher.myw_workbench.sh
```

### Step 5: Create TabTargets

```bash
cat > tt/myw-hello.SayHello.sh <<'EOF'
#!/bin/bash
exec "$(dirname "${BASH_SOURCE[0]}")/../.buk/launcher.myw_workbench.sh" \
  "${0##*/}" "${@}"
EOF

chmod +x tt/myw-hello.SayHello.sh

cat > tt/myw-info.ShowInfo.sh <<'EOF'
#!/bin/bash
exec "$(dirname "${BASH_SOURCE[0]}")/../.buk/launcher.myw_workbench.sh" \
  "${0##*/}" "${@}"
EOF

chmod +x tt/myw-info.ShowInfo.sh
```

### Step 6: Test Your Workbench

```bash
tt/myw-hello.SayHello.sh
tt/myw-info.ShowInfo.sh
```

---

## Reference Implementation: BURC/BURS

BURC and BURS are BUK's own Config Regimes, serving as both:
1. **Implementation** - Working regimes for BUK's operation
2. **Example** - Canonical demonstration of the Config Regime pattern

### BURC - Bash Utility Regime Configuration

**Purpose**: Project-level configuration defining repository structure.

**Assignment File**: `.buk/burc.env`

**Variables**:

| Variable | Type | Purpose |
|----------|------|---------|
| `BURC_STATION_FILE` | string | Path to developer's BURS file (relative to project root) |
| `BURC_TABTARGET_DIR` | string | Directory containing tabtarget scripts |
| `BURC_TABTARGET_DELIMITER` | string | Token separator in tabtarget filenames |
| `BURC_TOOLS_DIR` | string | Directory containing tool scripts |
| `BURC_TEMP_ROOT_DIR` | string | Parent directory for temp directories |
| `BURC_OUTPUT_ROOT_DIR` | string | Parent directory for output directories |
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

All BUK utilities follow these enterprise bash patterns:

- **Bash 3.2 compatibility** - Works with macOS default shell
- **Multi-call script pattern** - Single script handles multiple commands via case routing
- **Crash-fast error handling** - Use `set -euo pipefail` at script start
- **Braced, quoted variable expansion** - Always `"${var}"`, never `$var`
- **Kindle/sentinel boilerplate** - Guard against multiple source inclusion

---

## Future Directions

BUK's current scope covers portable CLI infrastructure and configuration management. The following directions represent potential extensions that maintain portability while addressing enterprise development patterns and standards enforcement.

### Standards Installation & Awareness

Vision: Inject enterprise bash practices into development workflows from session start, leveraging patterns like BCG as anchor standards. Rather than relying on LLM training defaults, developers work with pre-configured awareness of anti-patterns and best practices. This prevents bad suggestions before they appear.

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

Vision: Skills that validate bash code against enterprise standards in real-time, catching deviations early. Anchored by BCG anti-patterns and best practices.

May eventually involve:
- Skills like `/validate-bash`, `/check-bcg-compliance`
- Integration with workbench validation functions
- Forensic output for code review and standards enforcement

---

## Contributing

When extending BUK:

1. **Follow coding standards** - See the "Coding Standards" section above
2. **Maintain portability** - No project-specific logic in `Tools/buk/`
3. **Use Config Regimes** - Configuration belongs in regime files, not code
4. **Write specifications** - Document new regimes in `{regime}_specification.md`
5. **Add validation** - Use BVU type system for all config variables
6. **Update README** - Keep this file as the authoritative source

---

## License

Copyright 2025 Scale Invariant, Inc.

Licensed under the Apache License, Version 2.0.

---

## Author

Brad Hyslop <bhyslop@scaleinvariant.org>
