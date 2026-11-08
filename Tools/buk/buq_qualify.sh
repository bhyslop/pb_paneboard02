#!/bin/bash
# Copyright 2025 Scale Invariant, Inc.
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
# Bash Qualify Utility Library - Tabtarget structural qualification

set -euo pipefail

# The surface forms of the governed words this module speaks. The sourced file
# carries its own inclusion guard, so a sibling sourcing it costs nothing.
source "${BASH_SOURCE[0]%/*}/bubg_breviary.sh" || buc_die_now "Failed to source bubg_breviary.sh"

# Multiple inclusion guard
test -z "${ZBUQ_SOURCED:-}" || buc_die_now "Module buq multiply sourced - check sourcing hierarchy"
ZBUQ_SOURCED=1

# The moorings-layout names (launcher subdir), the console library and the yelp
# module are the furnish's to load

# Pinned shellcheck version. The shellcheck gate hard-fails if the running
# binary differs, locking every station to one version. The pin is exact, not a
# floor, for two reasons:
#   1. --rcfile (used by buq_shellcheck) did not exist before 0.10.0; an older
#      binary silently rejects the flag and runs rule-less — a false pass.
#   2. Check coverage and severity defaults drift across versions, so the same
#      tree can pass on one station and fail on another. The pin converts that
#      silent cross-station divergence into an immediate, actionable failure.
# Bump deliberately and in lockstep across every station platform (Linux,
# macOS): install the matching binary everywhere, then change this constant.
readonly BUQ_SHELLCHECK_VERSION="0.11.0"

######################################################################
# Tabtarget structural qualification

buq_tabtargets() {
  local z_tt_dir="${1:-}"
  local z_project_root="${2:-}"
  test -n "${z_tt_dir}"       || buc_die_now "buq_tabtargets: ${BUBG_TABTARGET_BASE} directory required"
  test -n "${z_project_root}" || buc_die_now "buq_tabtargets: project root required"
  test -d "${z_tt_dir}"       || buc_die_now "buq_tabtargets: directory not found: ${z_tt_dir}"
  test "$#" -lt 2 || shift 2

  # Remaining arguments are glob patterns for exempt tabtargets
  local z_exemptions=("$@")

  # Each exemption glob becomes one anchored regular expression, matched below
  # through a single unquoted expansion: a variable standing unquoted in a case
  # pattern is never admitted, and a pattern a caller hands in cannot be spelled
  # at the site. '*' and '?' keep their glob sense, '.'
  # matches itself, and any other character a regular expression reads as an
  # operator is refused rather than guessed at.
  local z_exempt_regexes=()
  local z_glob=""
  local z_regex=""
  local z_char=""
  local z_ci=0
  for z_glob in "${z_exemptions[@]+"${z_exemptions[@]}"}"; do
    z_regex="^"
    z_ci=0
    while test "${z_ci}" -lt "${#z_glob}"; do
      z_char="${z_glob:${z_ci}:1}"
      case "${z_char}" in
        '*') z_regex+=".*" ;;
        '?') z_regex+="." ;;
        '.') z_regex+="[.]" ;;
        '['|']'|'^'|'$'|'+'|'('|')'|'{'|'}'|'|'|'\')
          buc_die_now "buq_tabtargets: exemption pattern '${z_glob}' carries '${z_char}', which the exemption match does not translate" ;;
        *) z_regex+="${z_char}" ;;
      esac
      z_ci=$((z_ci + 1))
    done
    z_exempt_regexes+=("${z_regex}\$")
  done

  buc_step "Qualifying tabtarget structure in ${z_tt_dir}"

  local z_fail_files=()
  local z_fail_reasons=()
  local z_count=0
  local z_exempt_count=0

  # Prescribed tabtarget form (from buut_tabtarget.sh generator), three lines:
  #   Line 1: #!/bin/bash
  #   Line 2: set -- 'launcher.<id>_workbench.sh[ buuc_…]' "$@"
  #   Line 3: exec "${BASH_SOURCE[0]%/*}/<trampoline>" "${0##*/}" "${@}"
  # The configuration line names the moorings launcher as a bare basename and at
  # most two buuc_ words, the own-log word standing alone; the trampoline
  # resolves the launcher directly under the launcher dir. The exec line is a
  # byte-identical constant within its trampoline's family: the trampoline is a
  # z-*.sh standing beside the tabtargets, one exec form per trampoline. A
  # tabtarget exports nothing, and an export line is refused by name.
  local -r z_prescribed_shebang='#!/bin/bash'
  local -r z_config_prefix="set -- '"
  local -r z_config_suffix="' \"\$@\""
  local -r z_exec_prefix='exec "${BASH_SOURCE[0]%/*}/'
  local -r z_exec_suffix='" "${0##*/}" "${@}"'

  local z_num_lines=0
  local z_config_line=""
  local z_exec_line=""
  local z_file=""
  for z_file in "${z_tt_dir}"/*.sh; do
    test -e "${z_file}" || continue
    z_count=$((z_count + 1))

    local z_basename="${z_file##*/}"

    # Check exemption patterns
    local z_is_exempt=0
    local z_exempt_regex=""
    for z_exempt_regex in "${z_exempt_regexes[@]+"${z_exempt_regexes[@]}"}"; do
      if [[ "${z_basename}" =~ ${z_exempt_regex} ]]; then z_is_exempt=1; break; fi
    done
    if test "${z_is_exempt}" = "1"; then
      z_exempt_count=$((z_exempt_count + 1))
      continue
    fi

    # Load file lines (load-then-iterate)
    local z_lines=()
    local z_line=""
    while IFS= read -r z_line || test -n "${z_line}"; do
      z_lines+=("${z_line}")
    done < "${z_file}"

    z_num_lines="${#z_lines[@]}"

    # An export line, wherever it stands, is refused by name ahead of the shape.
    local z_export_line=""
    for z_line in "${z_lines[@]+"${z_lines[@]}"}"; do
      case "${z_line}" in
        'export '*|*[[:space:]]'export '*) z_export_line="${z_line}" ;;
      esac
    done
    test -z "${z_export_line}" || {
      z_fail_files+=("${z_basename}")
      z_fail_reasons+=("carries an export line, which no tabtarget carries: '${z_export_line}'")
      continue
    }

    # Exactly three lines: shebang, configuration, exec
    test "${z_num_lines}" -eq 3 || {
      z_fail_files+=("${z_basename}")
      z_fail_reasons+=("expected 3 lines (shebang, configuration, exec), got ${z_num_lines}")
      continue
    }

    # Line 1: prescribed shebang
    test "${z_lines[0]}" = "${z_prescribed_shebang}" || {
      z_fail_files+=("${z_basename}")
      z_fail_reasons+=("line 1: expected '${z_prescribed_shebang}', got '${z_lines[0]}'")
      continue
    }

    # Line 2: the configuration line, its first word resolving to a moorings
    # launcher and every further word a buuc_ word.
    z_config_line="${z_lines[1]}"
    local z_configuration=""
    case "${z_config_line}" in
      "${z_config_prefix}"*"${z_config_suffix}")
        z_configuration="${z_config_line#"${z_config_prefix}"}"
        z_configuration="${z_configuration%"${z_config_suffix}"}"
        ;;
    esac
    local z_words=()
    read -r -a z_words <<< "${z_configuration}" || buc_die_now "Failed to split the configuration of ${z_basename}"
    local z_config_ok=1
    case "${z_words[0]:-}" in
      launcher.*_workbench.sh) ;;
      *) z_config_ok=0 ;;
    esac
    test "${#z_words[@]}" -le 3 || z_config_ok=0
    local z_w=0
    for z_w in "${!z_words[@]}"; do
      test "${z_w}" -gt 0 || continue
      case "${z_words[${z_w}]}" in
        "${BUBC_word_interactive}"|"${BUBC_word_nolog}") ;;
        "${BUBC_word_ownlog}") test "${#z_words[@]}" -eq 2 || z_config_ok=0 ;;
        *) z_config_ok=0 ;;
      esac
    done
    test "${z_config_ok}" = "1" || {
      z_fail_files+=("${z_basename}")
      z_fail_reasons+=("line 2: expected \"${z_config_prefix}launcher.<id>_workbench.sh[ buuc_…]${z_config_suffix}\", got '${z_config_line}'")
      continue
    }
    local z_launcher_path="${BURD_MOORINGS_DIR}/${BUBC_launchers_subdir}/${z_words[0]}"
    test -f "${z_project_root}/${z_launcher_path}" || {
      z_fail_files+=("${z_basename}")
      z_fail_reasons+=("stub not found: ${z_launcher_path}")
      continue
    }

    # Line 3: the byte-identical exec of a trampoline standing beside it.
    z_exec_line="${z_lines[2]}"
    local z_trampoline=""
    case "${z_exec_line}" in
      "${z_exec_prefix}"z-*.sh"${z_exec_suffix}")
        z_trampoline="${z_exec_line#"${z_exec_prefix}"}"
        z_trampoline="${z_trampoline%"${z_exec_suffix}"}"
        ;;
    esac
    # An unmatched line leaves the name empty, and the test then names the
    # directory itself, which is no file.
    test -f "${z_tt_dir}/${z_trampoline}" || {
      z_fail_files+=("${z_basename}")
      z_fail_reasons+=("line 3: expected '${z_exec_prefix}z-<trampoline>.sh${z_exec_suffix}' naming a trampoline beside it, got '${z_exec_line}'")
      continue
    }
  done

  # Every launcher stub standing under the launcher directory, held once whether
  # a tabtarget names it or not. Prescribed form (from buut_tabtarget.sh's
  # launcher door), two lines:
  #   Line 1: #!/bin/bash
  #   Line 2: exec "Tools/buk/bul_launcher.sh" "<workbench path>" "$@"
  # The workbench path is the stub's one varying token. A stub sources nothing,
  # and a source line is refused by name.
  local -r z_stub_prefix='exec "Tools/buk/bul_launcher.sh" "'
  local -r z_stub_suffix='" "$@"'
  local -r z_stub_dir="${z_project_root}/${BURD_MOORINGS_DIR}/${BUBC_launchers_subdir}"
  local z_stub_count=0
  local z_stub=""
  local z_stub_name=""
  local z_stub_lines=()
  local z_stub_line=""
  local z_source_line=""
  local z_stub_workbench=""
  for z_stub in "${z_stub_dir}"/launcher.*.sh; do
    test -e "${z_stub}" || continue
    z_stub_count=$((z_stub_count + 1))
    z_stub_name="${BUBC_launchers_subdir}/${z_stub##*/}"

    z_stub_lines=()
    while IFS= read -r z_stub_line || test -n "${z_stub_line}"; do
      z_stub_lines+=("${z_stub_line}")
    done < "${z_stub}"

    z_source_line=""
    for z_stub_line in "${z_stub_lines[@]+"${z_stub_lines[@]}"}"; do
      case "${z_stub_line}" in
        'source '*|'. '*|*[[:space:]]'source '*|*[[:space:]]'. '*) z_source_line="${z_stub_line}" ;;
      esac
    done
    test -z "${z_source_line}" || {
      z_fail_files+=("${z_stub_name}")
      z_fail_reasons+=("carries a source line, which no stub carries: '${z_source_line}'")
      continue
    }

    test "${#z_stub_lines[@]}" -eq 2 || {
      z_fail_files+=("${z_stub_name}")
      z_fail_reasons+=("expected 2 lines (shebang, exec), got ${#z_stub_lines[@]}")
      continue
    }

    test "${z_stub_lines[0]}" = "${z_prescribed_shebang}" || {
      z_fail_files+=("${z_stub_name}")
      z_fail_reasons+=("line 1: expected '${z_prescribed_shebang}', got '${z_stub_lines[0]}'")
      continue
    }

    # An unmatched line, or a workbench path carrying a quote, leaves the path
    # empty, and the test then refuses it.
    z_stub_workbench=""
    case "${z_stub_lines[1]}" in
      "${z_stub_prefix}"*"${z_stub_suffix}")
        z_stub_workbench="${z_stub_lines[1]#"${z_stub_prefix}"}"
        z_stub_workbench="${z_stub_workbench%"${z_stub_suffix}"}"
        ;;
    esac
    case "${z_stub_workbench}" in
      *'"'*) z_stub_workbench="" ;;
    esac
    test -n "${z_stub_workbench}" || {
      z_fail_files+=("${z_stub_name}")
      z_fail_reasons+=("line 2: expected '${z_stub_prefix}<workbench path>${z_stub_suffix}', got '${z_stub_lines[1]}'")
      continue
    }
  done

  local z_checked=$((z_count - z_exempt_count))
  local z_summary="Checked ${z_checked} tabtargets"
  test "${z_exempt_count}" = "0" || z_summary="${z_summary} (${z_exempt_count} exempt)"
  z_summary="${z_summary} and ${z_stub_count} stubs"
  buc_log_args "${z_summary}"

  local -r z_held=$((z_checked + z_stub_count))
  if (( ${#z_fail_files[@]} )); then
    local z_j=0
    for z_j in "${!z_fail_files[@]}"; do
      buc_warn "${z_fail_files[${z_j}]}: ${z_fail_reasons[${z_j}]}" || buc_die_now "Failed to warn"
    done
    buc_die_now "Tabtarget qualification failed: ${#z_fail_files[@]} of ${z_held} tabtargets and stubs"
  fi

  buc_log_args "All ${z_checked} tabtargets and ${z_stub_count} stubs structurally valid"
}

######################################################################
# Shellcheck qualification

buq_shellcheck() {
  local z_tools_dir="${1:-${BURD_TOOLS_DIR:-}}"
  local z_rcfile="${2:-${BURD_BUK_DIR:+${BURD_BUK_DIR}/busc_shellcheckrc}}"
  local z_result_file="${3:-${BURD_TEMP_DIR:+${BURD_TEMP_DIR}/buq_shellcheck_results.txt}}"
  test -n "${z_tools_dir}"   || buc_die_now "buq_shellcheck: tools directory required"
  test -n "${z_rcfile}"      || buc_die_now "buq_shellcheck: rcfile path required"
  test -n "${z_result_file}" || buc_die_now "buq_shellcheck: result file path required"

  # Args beyond the third are explicit extra .sh files to lint alongside the
  # tree under z_tools_dir — a consumer with load-bearing shell scripts outside
  # its tools dir (vessel/jailer context, charge hooks) enumerates them here.
  # Each must exist: a moved or renamed extra fails loud rather than silently
  # dropping out of coverage.
  local z_extra_files=()
  if (( $# > 3 )); then
    z_extra_files=("${@:4}")
  fi

  buc_step "Running shellcheck qualification"

  test -f "${z_rcfile}"    || buc_die_now "Shellcheck rcfile not found: ${z_rcfile}"
  test -d "${z_tools_dir}" || buc_die_now "Tools directory not found: ${z_tools_dir}"

  command -v shellcheck >/dev/null || buc_die_now "shellcheck not found — install from https://www.shellcheck.net"

  # Hard version pin — fail instantly if this station's shellcheck is not the
  # pinned version, before any check runs. Prevents silent cross-station
  # divergence (e.g. a pre-0.10.0 binary that rejects --rcfile). Keep stations
  # in lockstep; bump BUQ_SHELLCHECK_VERSION only after upgrading all of them.
  # The report is kept beside the result file, the one scratch place every
  # caller of this function names.
  local -r z_sc_report_file="${z_result_file}.version"
  local -r z_sc_report_stderr="${z_result_file}.version_stderr"
  shellcheck --version > "${z_sc_report_file}" 2> "${z_sc_report_stderr}" \
    || buc_die_now "shellcheck --version failed, so the pinned version ${BUQ_SHELLCHECK_VERSION} cannot be confirmed - see ${z_sc_report_stderr}"
  local z_sc_lines=()
  local z_sc_line=""
  while IFS= read -r z_sc_line || test -n "${z_sc_line}"; do
    z_sc_lines+=("${z_sc_line}")
  done < "${z_sc_report_file}"
  local z_sc_version=""
  local z_sc_i
  for z_sc_i in "${!z_sc_lines[@]}"; do
    case "${z_sc_lines[${z_sc_i}]}" in
      version:*)
        z_sc_version="${z_sc_lines[${z_sc_i}]#version:}"
        z_sc_version="${z_sc_version// /}"
        break
        ;;
    esac
  done
  test "${z_sc_version}" = "${BUQ_SHELLCHECK_VERSION}" || buc_die_now \
    "shellcheck version mismatch: found '${z_sc_version}', require '${BUQ_SHELLCHECK_VERSION}'. Install the pinned version ahead of the system binary on PATH — static release: https://github.com/koalaman/shellcheck/releases/tag/v${BUQ_SHELLCHECK_VERSION}"

  # Collect .sh files (load-then-iterate), each step writing a file under its
  # own guard beside the result file, so neither the listing's nor the sort's
  # failure is lost.
  local -r z_found_file="${z_result_file}.found"
  local -r z_sorted_file="${z_result_file}.sorted"
  find "${z_tools_dir}" -name '*.sh' -type f > "${z_found_file}" \
    || buc_die_now "buq_shellcheck: cannot list the shell files under ${z_tools_dir}"
  sort "${z_found_file}" > "${z_sorted_file}" \
    || buc_die_now "buq_shellcheck: cannot sort the listing ${z_found_file}"
  local z_files=()
  local z_file=""
  while IFS= read -r z_file || test -n "${z_file}"; do
    z_files+=("${z_file}")
  done < "${z_sorted_file}"

  local -r z_tree_count=${#z_files[@]}

  # Append the validated extra files after the tree set
  if (( ${#z_extra_files[@]} > 0 )); then
    local z_extra=""
    for z_extra in "${z_extra_files[@]}"; do
      test -f "${z_extra}" || buc_die_now "buq_shellcheck: extra file not found: ${z_extra}"
      z_files+=("${z_extra}")
    done
  fi

  local -r z_file_count=${#z_files[@]}
  buc_log_args "Found ${z_tree_count} shell files under ${z_tools_dir}; ${#z_extra_files[@]} explicit extra files"

  test "${#z_files[@]}" -gt 0 || buc_die_now "No .sh files found under ${z_tools_dir}"

  # Run shellcheck — capture output to temp file for forensics
  local z_status=0
  shellcheck --rcfile="${z_rcfile}" -S style -f gcc "${z_files[@]}" \
    > "${z_result_file}" 2>&1 \
    || z_status=$?

  if test "${z_status}" = "0"; then
    buc_step "Shellcheck qualification passed: ${z_file_count} files clean"
    return 0
  fi

  # Count and display findings
  local z_finding_count=0
  local z_discard
  while IFS= read -r z_discard || test -n "${z_discard:-}"; do
    z_finding_count=$((z_finding_count + 1))
  done < "${z_result_file}"
  buc_log_args "Shellcheck findings: ${z_finding_count} (see ${z_result_file})"

  local z_result_lines=()
  local z_line=""
  while IFS= read -r z_line || test -n "${z_line}"; do
    z_result_lines+=("${z_line}")
  done < "${z_result_file}"
  local z_ri
  for z_ri in "${!z_result_lines[@]}"; do
    buc_warn "${z_result_lines[${z_ri}]}"
  done

  buc_die_now "Shellcheck qualification failed: ${z_finding_count} findings across ${z_file_count} files"
}

# eof
