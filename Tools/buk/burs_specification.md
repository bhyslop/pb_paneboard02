# BURS - Bash Utility Regime Station Specification

## Overview

BURS (Bash Utility Regime Station) defines developer/machine-level configuration for BUK (Bash Utility Kit). These settings are personal preferences specific to an individual developer's workstation and should NOT be committed to version control.

**Assignment File**: `../station-files/burs.env` (location configurable via `BURC_STATION_FILE`)

## Variables

### BURS_LOG_DIR

**Type**: String (directory path)

**Required**: Yes

**Purpose**: Directory where this developer keeps log files from BUK operations.

**Constraints**:
- Must be a non-empty string
- Should be a relative or absolute path
- Parent directory should exist (directory itself will be created if needed)

**Example**: `../_logs_buk`

---

## Future Variables

The following variables are proposed but not yet implemented:

### BURS_MAX_JOBS

**Type**: Decimal (positive integer)

**Required**: No

**Purpose**: Maximum number of parallel jobs for this machine.

**Constraints**:
- Must be a positive integer
- Typical range: 1-16

**Example**: `4`

---

## Validation

Use `burs_regime.sh validate <file>` to validate a BURS assignment file.

## Info

Use `burs_regime.sh info` to display this specification.

## Render

Use `burs_regime.sh render <file>` to display current configuration values.
