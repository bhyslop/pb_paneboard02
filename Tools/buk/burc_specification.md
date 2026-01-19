# BURC - Bash Utility Regime Configuration Specification

## Overview

BURC (Bash Utility Regime Configuration) defines project-level configuration for BUK (Bash Utility Kit). These settings describe how a specific project is organized and are shared by all team members. This file should be committed to version control.

**Assignment File**: `.buk/burc.env`

## Variables

### BURC_STATION_FILE

**Type**: String (file path)

**Required**: Yes

**Purpose**: Path to the developer's personal BURS station file.

**Constraints**:
- Must be a non-empty string
- Should be a relative or absolute path
- Typically points outside the project tree (e.g., `../station-files/burs.env`)

**Example**: `../station-files/burs.env`

---

### BURC_TABTARGET_DIR

**Type**: String (directory path)

**Required**: Yes

**Purpose**: Directory containing tabtarget scripts (shell tab-completable command shortcuts).

**Constraints**:
- Must be a non-empty string
- Should be a relative path from project root
- Directory must exist

**Example**: `tt`

---

### BURC_TABTARGET_DELIMITER

**Type**: String (single character)

**Required**: Yes

**Purpose**: Token delimiter character used in tabtarget filenames.

**Constraints**:
- Must be exactly one character
- Typically `.` or `-`

**Example**: `.`

---

### BURC_TOOLS_DIR

**Type**: String (directory path)

**Required**: Yes

**Purpose**: Directory containing BUK utilities and project tool scripts.

**Constraints**:
- Must be a non-empty string
- Should be a relative path from project root
- Directory must exist

**Example**: `Tools`

---

### BURC_PROJECT_ROOT

**Type**: String (directory path)

**Required**: Yes (for VVK install/uninstall operations)

**Purpose**: Path from burc.env's location to the project root directory.

**Constraints**:
- Must be a non-empty string
- Path is resolved relative to the directory containing burc.env
- Must resolve to a valid directory

**Example**: `..` (when burc.env is at `{project_root}/.buk/burc.env`)

---

### BURC_MANAGED_KITS

**Type**: String (comma-separated list)

**Required**: Yes (for VVK release and install operations)

**Purpose**: Comma-separated list of kits included in vvx. At release time, determines which kits are built into the binary and included in the parcel. At install time, must exactly match the parcel's kit list (prevents binary capability leakage).

**Constraints**:
- Must be a non-empty string
- No spaces around commas
- At release: each kit must exist in the kit forge
- At install: must exactly match parcel's kit list (order independent)

**Example**: `buk,jjk,vvk`

---

### BURC_TEMP_ROOT_DIR

**Type**: String (directory path)

**Required**: Yes

**Purpose**: Root directory where BUK creates temporary directories for intermediate files.

**Constraints**:
- Must be a non-empty string
- Should be a relative or absolute path
- Parent directory should exist (will be created if needed)

**Example**: `../temp-buk`

---

### BURC_OUTPUT_ROOT_DIR

**Type**: String (directory path)

**Required**: Yes

**Purpose**: Root directory where BUK writes command output files.

**Constraints**:
- Must be a non-empty string
- Should be a relative or absolute path
- Parent directory should exist (will be created if needed)

**Example**: `../output-buk`

---

### BURC_LOG_LAST

**Type**: String (filename stem)

**Required**: Yes

**Purpose**: Filename stem for "last run" log file (latest command execution log).

**Constraints**:
- Must be a non-empty string
- Should be a simple identifier (no path separators)

**Example**: `last`

---

### BURC_LOG_EXT

**Type**: String (file extension)

**Required**: Yes

**Purpose**: File extension for log files (without leading dot).

**Constraints**:
- Must be a non-empty string
- Should be a simple extension (no path separators)
- Typically `txt` or `log`

**Example**: `txt`

---

## Validation

Use `burc_regime.sh validate <file>` to validate a BURC assignment file.

## Info

Use `burc_regime.sh info` to display this specification.

## Render

Use `burc_regime.sh render <file>` to display current configuration values.
