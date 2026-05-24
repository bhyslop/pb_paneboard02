#!/bin/bash
#
# Copyright 2026 Scale Invariant, Inc.
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
# BUF Fact - Dual-write fact-file primitives
#
# Writes fact-files to both BURD_OUTPUT_DIR and BURD_TEMP_DIR.
# BURD_OUTPUT_DIR is cleared on next dispatch (latest-command convenience).
# BURD_TEMP_DIR is durable (addressable by remote consumers).

set -euo pipefail

# Multiple inclusion guard (return 0 — sourced from non-BCG dispatch context)
test -z "${ZBUF_SOURCED:-}" || return 0
ZBUF_SOURCED=1

# Tinder constants (pure string literals — available at source time)
BUF_burx_env="burx.env"

# Multi-fact extension registry (BUK-domain only). Constant value matches
# constant name downcased; the buf_ext_ prefix in the value carries the
# owning module identity so any fact file is recognizable on disk.
BUF_EXT_ALIAS="buf_ext_alias"

# Write a named fact-file to both output and temp directories.
# Dies if either copy already exists (double-write indicates a bug).
# Args: <filename> <value>
buf_write_fact_single() {
  local -r z_filename="$1"
  local -r z_value="$2"
  local -r z_output_path="${BURD_OUTPUT_DIR}/${z_filename}"
  local -r z_temp_path="${BURD_TEMP_DIR}/${z_filename}"
  test ! -f "${z_output_path}" || { echo "FATAL: buf_write_fact_single: preexists in output dir: ${z_output_path}" >&2; return 1; }
  test ! -f "${z_temp_path}"   || { echo "FATAL: buf_write_fact_single: preexists in temp dir: ${z_temp_path}" >&2; return 1; }
  printf '%s\n' "${z_value}" > "${z_output_path}"
  printf '%s\n' "${z_value}" > "${z_temp_path}"
}

# Write a multi-element fact-file (<file_root>.<ext>) to both output and
# temp directories. Dies if either copy already exists. Extension is an
# opaque pass-through — no validation, no closed-set enforcement.
# Args: <file_root> <ext> <value>
buf_write_fact_multi() {
  local -r z_root="$1"
  local -r z_ext="$2"
  local -r z_value="$3"
  local -r z_filename="${z_root}.${z_ext}"
  local -r z_output_path="${BURD_OUTPUT_DIR}/${z_filename}"
  local -r z_temp_path="${BURD_TEMP_DIR}/${z_filename}"
  test ! -f "${z_output_path}" || { echo "FATAL: buf_write_fact_multi: preexists in output dir: ${z_output_path}" >&2; return 1; }
  test ! -f "${z_temp_path}"   || { echo "FATAL: buf_write_fact_multi: preexists in temp dir: ${z_temp_path}" >&2; return 1; }
  printf '%s\n' "${z_value}" > "${z_output_path}"
  printf '%s\n' "${z_value}" > "${z_temp_path}"
}

# eof
