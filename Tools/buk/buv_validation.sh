#!/bin/bash
# Copyright 2025 Scale Invariant, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Author: Brad Hyslop <bhyslop@scaleinvariant.org>
#
# Bash Validation Utility Library
# Compatible with Bash 3.2 (e.g., macOS default shell)

# Multiple inclusion guard
[[ -n "${ZBUV_INCLUDED:-}" ]] && return 0
ZBUV_INCLUDED=1

# Source the console utility library
ZBUV_SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
source "${ZBUV_SCRIPT_DIR}/buc_command.sh"

buv_file_exists() {
  local filepath="$1"
  test -f "$filepath" || buc_die "Required file not found: $filepath"
}

buv_dir_exists() {
  local dirpath="$1"
  test -d "$dirpath" || buc_die "Required directory not found: $dirpath"
}

buv_dir_empty() {
  local dirpath="$1"
  test -d          "$dirpath"               || buc_die "Required directory not found: $dirpath"
  test -z "$(ls -A "$dirpath" 2>/dev/null)" || buc_die "Directory must be empty: $dirpath"
}

# Generic environment variable wrapper
buv_env_wrapper() {
  local func_name=$1
  local varname=$2
  eval "local val=\${$varname:-}" || buc_die "Variable '$varname' is not defined"
  shift 2

  ${func_name} "$varname" "$val" "$@"
}

# Generic optional wrapper - returns empty if value is empty
buv_opt_wrapper() {
  local func_name=$1
  local varname=$2
  eval "local val=\${$varname:-}" || buc_die "Variable '$varname' is not defined"

  # Empty is always valid for optional
  test -z "$val" && return 0

  shift 2
  ${func_name} "$varname" "$val" "$@"
}

# String validator with optional length constraints
buv_val_string() {
  local varname=$1
  local val=$2
  local min=$3
  local max=$4
  local default=${5-}  # empty permitted

  # Validate required parameters
  test -n "$varname" || buc_die "varname parameter is required"
  test -n "$min"     || buc_die "min parameter is required for varname '$varname'"
  test -n "$max"     || buc_die "max parameter is required for varname '$varname'"

  # Use default if value is empty and default provided
  if [ -z "$val" -a -n "$default" ]; then
    val="$default"
  fi

  # Allow empty if min=0
  if [ "$min" = "0" -a -z "$val" ]; then
    echo "$val"
    return 0
  fi

  # Otherwise must not be empty
  test -n "$val" || buc_die "$varname must not be empty"

  # Check length constraints if max provided
  if [ -n "$max" ]; then
    test ${#val} -ge $min || buc_die "$varname must be at least $min chars, got '${val}' (${#val})"
    test ${#val} -le $max || buc_die "$varname must be no more than $max chars, got '${val}' (${#val})"
  fi

  echo "$val"
}

# Cross-context name validator (system-safe identifier)
buv_val_xname() {
  local varname=$1
  local val=$2
  local min=$3
  local max=$4
  local default=${5-}  # empty permitted

  # Validate required parameters
  test -n "$varname" || buc_die "varname parameter is required"
  test -n "$min"     || buc_die "min parameter is required for varname '$varname'"
  test -n "$max"     || buc_die "max parameter is required for varname '$varname'"

  # Use default if value is empty and default provided
  if [ -z "$val" -a -n "$default" ]; then
    val="$default"
  fi

  # Allow empty if min=0
  if [ "$min" = "0" -a -z "$val" ]; then
    echo "$val"
    return 0
  fi

  # Otherwise must not be empty
  test -n "$val" || buc_die "$varname must not be empty"

  # Check length constraints
  test ${#val} -ge $min || buc_die "$varname must be at least $min chars, got '${val}' (${#val})"
  test ${#val} -le $max || buc_die "$varname must be no more than $max chars, got '${val}' (${#val})"

  # Must start with letter and contain only allowed chars
  test $(echo "$val" | grep -E '^[a-zA-Z][a-zA-Z0-9_-]*$') || \
    buc_die "$varname must start with letter and contain only letters, numbers, underscore, hyphen, got '$val'"

  echo "$val"
}

# Google-style resource identifier (lowercase, digits, hyphens)
# Must start with a letter, end with letter/digit.
# Examples: GCP project IDs, GAR repo IDs.
buv_val_gname() {
  local varname=$1
  local val=$2
  local min=$3
  local max=$4
  local default=${5-}  # empty permitted

  # Required params
  test -n "$varname" || buc_die "varname parameter is required"
  test -n "$min"     || buc_die "min parameter is required for varname '$varname'"
  test -n "$max"     || buc_die "max parameter is required for varname '$varname'"

  # Defaulting
  if [ -z "$val" -a -n "$default" ]; then
    val="$default"
  fi

  # Allow empty if min=0
  if [ "$min" = "0" -a -z "$val" ]; then
    echo "$val"
    return 0
  fi

  # Non-empty and length window
  test -n "$val" || buc_die "$varname must not be empty"
  test ${#val} -ge $min || buc_die "$varname must be at least $min chars, got '${val}' (${#val})"
  test ${#val} -le $max || buc_die "$varname must be no more than $max chars, got '${val}' (${#val})"

  # Pattern: ^[a-z][a-z0-9-]*[a-z0-9]$
  test "$(echo "$val" | grep -E '^[a-z][a-z0-9-]*[a-z0-9]$')" || \
    buc_die "$varname must match ^[a-z][a-z0-9-]*[a-z0-9]$ (lowercase letters, digits, hyphens; start with a letter; end with letter/digit), got '$val'"

  echo "$val"
}

# Fully Qualified Image Name component validator
buv_val_fqin() {
  local varname=$1
  local val=$2
  local min=$3
  local max=$4
  local default=${5-}  # empty permitted

  # Validate required parameters
  test -n "$varname" || buc_die "varname parameter is required"
  test -n "$min"     || buc_die "min parameter is required for varname '$varname'"
  test -n "$max"     || buc_die "max parameter is required for varname '$varname'"

  # Use default if value is empty and default provided
  if [ -z "$val" -a -n "$default" ]; then
    val="$default"
  fi

  # Allow empty if min=0
  if [ "$min" = "0" -a -z "$val" ]; then
    echo "$val"
    return 0
  fi

  # Otherwise must not be empty
  test -n "$val" || buc_die "$varname must not be empty"

  # Check length constraints
  test ${#val} -ge $min || buc_die "$varname must be at least $min chars, got '${val}' (${#val})"
  test ${#val} -le $max || buc_die "$varname must be no more than $max chars, got '${val}' (${#val})"

  # Allow letters, numbers, dots, hyphens, underscores, forward slashes, colons
  test $(echo "$val" | grep -E '^[a-zA-Z0-9][a-zA-Z0-9:._/-]*$') || \
    buc_die "$varname must start with letter/number and contain only letters, numbers, colons, dots, underscores, hyphens, forward slashes, got '$val'"

  echo "$val"
}

# Boolean validator
buv_val_bool() {
  local varname=$1
  local val=$2
  local default=${3-}

  # Validate required parameters
  test -n "$varname" || buc_die "varname parameter is required"

  # Use default if value is empty and default provided
  if [ -z "$val" -a -n "$default" ]; then
    val="$default"
  fi

  test -n "$val" || buc_die "$varname must not be empty"
  test "$val" = "0" -o "$val" = "1" || buc_die "$varname must be 0 or 1, got: '$val'"

  echo "$val"
}

# Decimal range validator
buv_val_decimal() {
  local varname=$1
  local val=$2
  local min=$3
  local max=$4
  local default=${5-}

  # Validate required parameters
  test -n "$varname" || buc_die "varname parameter is required"
  test -n "$min"     || buc_die "min parameter is required for varname '$varname'"
  test -n "$max"     || buc_die "max parameter is required for varname '$varname'"

  # Use default if value is empty and default provided
  if [ -z "$val" -a -n "$default" ]; then
    val="$default"
  fi

  test -n "$val" || buc_die "$varname must not be empty"
  test $val -ge $min -a $val -le $max || buc_die "$varname value '$val' must be between $min and $max"

  echo "$val"
}

# IPv4 validator
buv_val_ipv4() {
  local varname=$1
  local val=$2
  local default=${3-}  # empty permitted

  # Validate required parameters
  test -n "$varname" || buc_die "varname parameter is required"

  # Use default if value is empty and default provided
  if [ -z "$val" -a -n "$default" ]; then
    val="$default"
  fi

  test -n "$val" || buc_die "$varname must not be empty"
  test $(echo $val | grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}$') || buc_die "$varname has invalid IPv4 format: '$val'"

  echo "$val"
}

# CIDR validator
buv_val_cidr() {
  local varname=$1
  local val=$2
  local default=${3-}

  # Validate required parameters
  test -n "$varname" || buc_die "varname parameter is required"

  # Use default if value is empty and default provided
  if [ -z "$val" -a -n "$default" ]; then
    val="$default"
  fi

  test -n "$val" || buc_die "$varname must not be empty"
  test $(echo $val | grep -E '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$') || buc_die "$varname has invalid CIDR format: '$val'"

  echo "$val"
}

# Domain validator
buv_val_domain() {
  local varname=$1
  local val=$2
  local default=${3-}

  # Validate required parameters
  test -n "$varname" || buc_die "varname parameter is required"

  # Use default if value is empty and default provided
  if [ -z "$val" -a -n "$default" ]; then
    val="$default"
  fi

  test -n "$val" || buc_die "$varname must not be empty"
  test $(echo $val | grep -E '^[a-zA-Z0-9][a-zA-Z0-9\.-]*[a-zA-Z0-9]$') || buc_die "$varname has invalid domain format: '$val'"

  echo "$val"
}

# Port validator
buv_val_port() {
  local varname=$1
  local val=$2
  local default=${3-}

  # Validate required parameters
  test -n "$varname" || buc_die "varname parameter is required"

  # Use default if value is empty and default provided
  if [ -z "$val" -a -n "$default" ]; then
    val="$default"
  fi

  test -n "$val" || buc_die "$varname must not be empty"
  test $val -ge 1 -a $val -le 65535 || buc_die "$varname value '$val' must be between 1 and 65535"

  echo "$val"
}

# OCI/Docker image reference that MUST be digest-pinned
# Accepts:
#   - Any registry host: letters, digits, dots, hyphens; optional :port
#   - Repository path: one or more slash-separated lowercase segments [a-z0-9._-]
#   - Mandatory digest: @sha256:<64 lowercase hex>
#
# Examples:
#   docker.io/stedolan/jq@sha256:...
#   ghcr.io/anchore/syft@sha256:...
#   gcr.io/go-containerregistry/gcrane@sha256:...
#   us-central1-docker.pkg.dev/my-proj/my-repo/tool@sha256:...
buv_val_odref() {
  local varname=$1
  local val=$2
  local default=${3-}  # empty permitted (only if caller wants to allow empty)

  test -n "$varname" || buc_die "varname parameter is required"

  # Defaulting when allowed by caller
  if [ -z "$val" -a -n "$default" ]; then
    val="$default"
  fi

  # Must not be empty here (use buv_opt_odref for optional)
  test -n "$val" || buc_die "$varname must not be empty"

  # Enforce digest-pinned image ref:
  #   host[:port]/repo(/subrepo)@sha256:64hex
  #   - host: [a-z0-9.-]+ with optional :port
  #   - each repo segment: [a-z0-9._-]+ (lowercase)
  #   - digest algo fixed to sha256 with 64 lowercase hex chars
  local _re='^[a-z0-9.-]+(:[0-9]{2,5})?/([a-z0-9._-]+/)*[a-z0-9._-]+@sha256:[0-9a-f]{64}$'
  echo "$val" | grep -Eq "$_re" || buc_die "$varname has invalid image reference format (require host[:port]/repo@sha256:<64hex>), got '$val'"

  echo "$val"
}

# List validators
buv_val_list_ipv4() {
  local varname=$1
  local val=$2

  # Validate required parameters
  test -n "$varname" || buc_die "varname parameter is required"

  test -z "$val" && return 0  # Empty lists allowed

  local item_num=0
  for item in $val; do
    item_num=$((item_num + 1))
    test $(echo $item | grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}$') || buc_die "$varname item #$item_num has invalid IPv4 format: '$item'"
  done
}

buv_val_list_cidr() {
  local varname=$1
  local val=$2

  # Validate required parameters
  test -n "$varname" || buc_die "varname parameter is required"

  test -z "$val" && return 0  # Empty lists allowed

  local item_num=0
  for item in $val; do
    item_num=$((item_num + 1))
    test $(echo $item | grep -E '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$') || buc_die "$varname item #$item_num has invalid CIDR format: '$item'"
  done
}

buv_val_list_domain() {
  local varname=$1
  local val=$2

  # Validate required parameters
  test -n "$varname" || buc_die "varname parameter is required"

  test -z "$val" && return 0  # Empty lists allowed

  local item_num=0
  for item in $val; do
    item_num=$((item_num + 1))
    test $(echo $item | grep -E '^[a-zA-Z0-9][a-zA-Z0-9\.-]*[a-zA-Z0-9]$') || buc_die "$varname item #$item_num has invalid domain format: '$item'"
  done
}

# Environment variable validators
buv_env_string()             { buv_env_wrapper "buv_val_string"           "$@"; }
buv_env_xname()              { buv_env_wrapper "buv_val_xname"            "$@"; }
buv_env_gname()              { buv_env_wrapper "buv_val_gname"            "$@"; }
buv_env_fqin()               { buv_env_wrapper "buv_val_fqin"             "$@"; }
buv_env_bool()               { buv_env_wrapper "buv_val_bool"             "$@"; }
buv_env_decimal()            { buv_env_wrapper "buv_val_decimal"          "$@"; }
buv_env_ipv4()               { buv_env_wrapper "buv_val_ipv4"             "$@"; }
buv_env_cidr()               { buv_env_wrapper "buv_val_cidr"             "$@"; }
buv_env_domain()             { buv_env_wrapper "buv_val_domain"           "$@"; }
buv_env_port()               { buv_env_wrapper "buv_val_port"             "$@"; }
buv_env_odref()              { buv_env_wrapper "buv_val_odref"            "$@"; }

# Environment list validators
buv_env_list_ipv4()          { buv_env_wrapper "buv_val_list_ipv4"        "$@"; }
buv_env_list_cidr()          { buv_env_wrapper "buv_val_list_cidr"        "$@"; }
buv_env_list_domain()        { buv_env_wrapper "buv_val_list_domain"      "$@"; }

# Optional validators
buv_opt_bool()               { buv_opt_wrapper "buv_val_bool"             "$@"; }
buv_opt_range()              { buv_opt_wrapper "buv_val_decimal"          "$@"; }
buv_opt_ipv4()               { buv_opt_wrapper "buv_val_ipv4"             "$@"; }
buv_opt_cidr()               { buv_opt_wrapper "buv_val_cidr"             "$@"; }
buv_opt_domain()             { buv_opt_wrapper "buv_val_domain"           "$@"; }
buv_opt_port()               { buv_opt_wrapper "buv_val_port"             "$@"; }

# eof

