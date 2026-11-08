#!/bin/bash
#
# Copyright 2026 Scale Invariant, Inc.
# SPDX-License-Identifier: Apache-2.0
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
# BUF Fact - Fact-file primitives (produce + consume)
#
# Produce side (buf_write_fact_*): writes fact-files to both BURD_OUTPUT_DIR
# and BURD_TEMP_DIR. BURD_OUTPUT_DIR (current/) is promoted to BURD_PREVIOUS_DIR
# (previous/) on next dispatch; BURD_TEMP_DIR is durable. The dispatch writes
# its own two files through this side: the dispatch regime (burd.env), written
# once before the coordinator starts, and the exchange file (burx.env).
#
# Consume side (buf_read_fact_capture, buf_elect_fact_capture, buf_relay): a
# downstream tabtarget reads the prior tabtarget's facts from BURD_PREVIOUS_DIR —
# the depth-1 cross-tabtarget chain. buf_relay forwards the prior baton into
# current/ so it survives one more hop; buf_read_fact_capture reads one named
# fact and fails hard if it is absent; buf_elect_fact_capture prefers an express
# value and falls back to the chained fact (express-or-chain). The two reads are
# _capture-suffixed: stdout-once-or-return-1, the caller guards with || buc_die_now.

set -euo pipefail

# Multiple inclusion guard — dies through printf and exit, since the dispatcher
# sources this module before buc_command.sh is loaded
test -z "${ZBUF_SOURCED:-}" || { printf '%s\n' "Module buf multiply sourced - check sourcing hierarchy" >&2 || exit 1; exit 1; }
ZBUF_SOURCED=1

# Tinder constants (pure string literals — available at source time)
readonly BUF_burx_env="burx.env"
readonly BUF_burd_env="burd.env"

# Multi-fact extension registry (BUK's own domain only). Constant value matches
# constant name downcased; the buf_ext_ prefix in the value carries the
# owning module identity so any fact file is recognizable on disk.
BUF_EXT_ALIAS="buf_ext_alias"

# This module is sourced ahead of the console library, so it carries no buc_*
# voice: a failure is written to stderr and the shell exits through this die.
zbuf_die() {
  printf 'FATAL: %s\n' "$*" >&2 || exit 1
  exit 1
}

# Write a named fact-file to both output and temp directories.
# Dies if either copy already exists (double-write indicates a bug).
# Args: <filename> <value>
buf_write_fact_single() {
  local -r z_filename="${1}"
  local -r z_value="${2}"
  local -r z_output_path="${BURD_OUTPUT_DIR}/${z_filename}"
  local -r z_temp_path="${BURD_TEMP_DIR}/${z_filename}"
  test ! -f "${z_output_path}" || zbuf_die "buf_write_fact_single: preexists in output dir: ${z_output_path}"
  test ! -f "${z_temp_path}"   || zbuf_die "buf_write_fact_single: preexists in temp dir: ${z_temp_path}"
  printf '%s\n' "${z_value}" > "${z_output_path}" || zbuf_die "buf_write_fact_single: cannot write ${z_output_path}"
  printf '%s\n' "${z_value}" > "${z_temp_path}"   || zbuf_die "buf_write_fact_single: cannot write ${z_temp_path}"
}

# Write a multi-element fact-file (<file_root>.<ext>) to both output and
# temp directories. Dies if either copy already exists. Extension is an
# opaque pass-through — no validation, no closed-set enforcement.
# Args: <file_root> <ext> <value>
buf_write_fact_multi() {
  local -r z_root="${1}"
  local -r z_ext="${2}"
  local -r z_value="${3}"
  local -r z_filename="${z_root}.${z_ext}"
  local -r z_output_path="${BURD_OUTPUT_DIR}/${z_filename}"
  local -r z_temp_path="${BURD_TEMP_DIR}/${z_filename}"
  test ! -f "${z_output_path}" || zbuf_die "buf_write_fact_multi: preexists in output dir: ${z_output_path}"
  test ! -f "${z_temp_path}"   || zbuf_die "buf_write_fact_multi: preexists in temp dir: ${z_temp_path}"
  printf '%s\n' "${z_value}" > "${z_output_path}" || zbuf_die "buf_write_fact_multi: cannot write ${z_output_path}"
  printf '%s\n' "${z_value}" > "${z_temp_path}"   || zbuf_die "buf_write_fact_multi: cannot write ${z_temp_path}"
}

# Forward the prior dispatch's facts (BURD_PREVIOUS_DIR) into this dispatch's
# output (BURD_OUTPUT_DIR) — the baton forward, so a multi-hop chain survives
# past one tabtarget. No-op when there is no prior dispatch (first run). Files
# already present in current/ are preserved, never clobbered — this keeps the
# current dispatch's own reserved files (e.g. burx.env) and any fact already
# written. Per the install ordering invariant, buf_relay runs FIRST, before
# any buf_read_fact_capture / buf_write_fact in the consuming tabtarget.
buf_relay() {
  test -d "${BURD_PREVIOUS_DIR}" || return 0
  mkdir -p "${BURD_OUTPUT_DIR}" || zbuf_die "buf_relay: cannot create output dir: ${BURD_OUTPUT_DIR}"
  local z_src z_dst
  for z_src in "${BURD_PREVIOUS_DIR}"/*; do
    test -f "${z_src}" || continue
    z_dst="${BURD_OUTPUT_DIR}/${z_src##*/}"
    test ! -e "${z_dst}" || continue
    cp "${z_src}" "${z_dst}" || zbuf_die "buf_relay: copy failed: ${z_src} -> ${z_dst}"
  done
}

# Read a single named fact from the prior dispatch (BURD_PREVIOUS_DIR), emitting
# its bare value (trailing newline stripped) on stdout. Fails hard if the fact
# is absent — a missing upstream fact is a broken chain, not a default-to-empty.
# Single-form only: the value is an opaque singular string, never parsed here.
# _capture shape: stdout once or return 1, writing nothing to stderr; the
# caller guards with || buc_die_now, naming the fact.
# Args: <filename>
buf_read_fact_capture() {
  local -r z_filename="${1}"
  local -r z_path="${BURD_PREVIOUS_DIR}/${z_filename}"
  test -f "${z_path}" || return 1
  local z_fact
  z_fact=$(<"${z_path}") || return 1
  printf '%s' "${z_fact}"
}

# Resolve a value express-or-chain: emit the express value if it is non-empty,
# otherwise fall through to the chained fact (buf_read_fact_capture). Fails (the
# read returns 1) only when express is empty AND the chained fact is absent — a
# broken chain. Generic over any fact constant: the express value and the fact
# filename are both arguments, so each verb stays its own caller. Never relays
# itself — relaying is the caller's explicit act (buf_relay first, then elect),
# keeping this primitive a pure read.
# _capture shape: stdout once or return 1; the caller guards with || buc_die_now.
# Args: <express_value> <fact_filename>
buf_elect_fact_capture() {
  local -r z_express="${1}"
  local -r z_filename="${2}"
  local z_value="${z_express}"
  if test -z "${z_value}"; then
    z_value=$(buf_read_fact_capture "${z_filename}") || return 1
  fi
  printf '%s' "${z_value}"
}

# eof
