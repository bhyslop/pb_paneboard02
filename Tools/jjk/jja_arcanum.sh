#!/bin/bash
#
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
# JJA Arcanum - Job Jockey installation and management
#
# Commands:
#   jja-c  Check installation status and ledger
#   jja-i  Install Job Jockey
#   jja-u  Uninstall Job Jockey (preserves .claude/jjm/ state)

set -euo pipefail

ZJJW_SCRIPT_DIR="${BASH_SOURCE[0]%/*}"

# Source dependencies
source "${ZJJW_SCRIPT_DIR}/../buk/buc_command.sh"

# Show filename on each displayed line
buc_context "${0##*/}"

# Configuration - can be overridden via environment
ZJJW_TARGET_DIR="${ZJJW_TARGET_DIR:-.}"
ZJJW_KIT_PATH="${ZJJW_KIT_PATH:-Tools/jjk/README.md}"

######################################################################
# Internal Helpers

# Returns 12-char hash of source files (arcanum + README)
zjjw_compute_source_hash() {
  local z_full
  z_full=$(cat "${ZJJW_SCRIPT_DIR}/jja_arcanum.sh" "${ZJJW_SCRIPT_DIR}/README.md" | shasum -a 256)
  echo "${z_full:0:12}"
}

# Given hash, returns brand number or empty string if not in ledger
zjjw_lookup_brand_by_hash() {
  local z_hash="${1}"
  jq -r --arg h "${z_hash}" '.[] | select(.hash == $h) | .v // empty' "${ZJJW_SCRIPT_DIR}/jjl_ledger.json"
}

# Returns brand from installed jjc-notch.md, or empty if not installed
zjjw_installed_brand() {
  local z_notch_file=".claude/commands/jjc-notch.md"
  if test -f "${z_notch_file}"; then
    grep -oP '(?<=^- Brand: )\d+' "${z_notch_file}" 2>/dev/null || true
  fi
}

######################################################################
# Command Emitters - one function per command file
#
# Each emits to stdout; caller redirects to file

zjjw_emit_heat_saddle() {
  {
    echo "---"
    echo "argument-hint: [favor]"
    echo "description: Mount heat and show context"
    echo "---"
    echo ""
    echo "Mount a Job Jockey heat and display full context for work."
    echo ""
    echo "**Usage:**"
    echo "- \`/jjc-heat-saddle\` - Auto-select if single heat, or show list"
    echo "- \`/jjc-heat-saddle ₣HHAAA\` - Mount specific heat by Favor (heat-only format)"
    echo ""
    echo "**Behavior:**"
    echo "- No argument + 0 heats: Show \"No heats\" message"
    echo "- No argument + 1 heat: Auto-saddle that heat"
    echo "- No argument + multiple heats: List heats and prompt for selection"
    echo "- With Favor argument: Saddle that specific heat (accepts ₣HH or ₣HHAAA)"
    echo ""
    echo "**Output sections:**"
    echo "1. Heat header (Favor, silks, datestamp)"
    echo "2. Paddock (full prose context from jjp_HH.md)"
    echo "3. Current pace (first pending pace)"
    echo "4. Remaining paces (other pending paces)"
    echo "5. Recent steeplechase (git log entries for current pace)"
    echo ""
    echo "**Tabtarget:** \`tt/jjw-hs.HeatSaddle.sh [favor]\`"
    echo ""
    echo "Configuration:"
    echo "- Target repo dir: ${ZJJW_TARGET_DIR}"
    echo "- Kit path: ${ZJJW_KIT_PATH}"
  }
}

zjjw_emit_heat_retire() {
  {
    echo "You are retiring a completed Job Jockey heat."
    echo ""
    echo "Configuration:"
    echo "- Target repo dir: ${ZJJW_TARGET_DIR}"
    echo "- Kit path: ${ZJJW_KIT_PATH}"
    echo ""
    echo "Steps:"
    echo ""
    echo "1. Check for heats in studbook:"
    echo "   \`\`\`bash"
    echo "   tt/jjk-m.Muster.sh"
    echo "   \`\`\`"
    echo "   - If 0 heats: announce \"No active heat to retire\" and stop"
    echo "   - If 2+ heats: ask which one to retire (show Favor and silks)"
    echo "   - Note the heat's Favor (₣HH) and silks"
    echo ""
    echo "2. Verify completion by checking pace states:"
    echo "   - Run saddle to see pace list: \`tt/jjw-hs.HeatSaddle.sh ₣HHAAA\`"
    echo "   - If incomplete paces exist (status != complete):"
    echo "     - List them"
    echo "     - Ask: \"These paces are incomplete. Mark them as abandoned, or continue working?\""
    echo "     - If user wants to abandon: use tally to mark as abandoned"
    echo "     - If user wants to continue: stop retirement process"
    echo ""
    echo "3. Ensure clean worktree:"
    echo "   \`\`\`bash"
    echo "   git status --porcelain"
    echo "   \`\`\`"
    echo "   - If worktree is dirty: ask user to commit or stash changes first"
    echo ""
    echo "4. Execute retirement (creates trophy, updates studbook, archives paddock, commits, pushes):"
    echo "   \`\`\`bash"
    echo "   tt/jjw-hr.HeatRetire.sh ₣HHAAA"
    echo "   \`\`\`"
    echo ""
    echo "5. Report completion:"
    echo "   \`\`\`"
    echo "   Retired heat: ₣HH **[silks]**"
    echo "   - Trophy: .claude/jjm/retired/jjy_HH_YYMMDD-YYMMDD_silks.md"
    echo "   - Paddock archived: .claude/jjm/retired/jjp_HH_YYMMDD-YYMMDD.md"
    echo "   \`\`\`"
    echo ""
    echo "6. Offer next steps:"
    echo "   - \"Would you like to start a new heat or promote an itch from jji_itch.md?\""
    echo ""
    echo "Error handling: If jju_retire fails, report the error and stop."
  }
}

zjjw_emit_pace_new() {
  {
    echo "---"
    echo "argument-hint: [description-or-silks]"
    echo "---"
    echo ""
    echo "You are adding a new pace to the current Job Jockey heat."
    echo ""
    echo "Configuration:"
    echo "- Target repo dir: ${ZJJW_TARGET_DIR}"
    echo "- Kit path: ${ZJJW_KIT_PATH}"
    echo ""
    echo "Steps:"
    echo ""
    echo "1. Check for heat files in .claude/jjm/current/"
    echo "   - If 0 heats: announce \"No active heat\" and stop"
    echo "   - If 2+ heats: ask which one"
    echo ""
    echo "2. Read the heat file to understand context and existing paces"
    echo ""
    echo "3. Analyze the heat context and existing paces"
    echo ""
    echo "4. Propose a new pace:"
    echo "   - Title (bold format)"
    echo "   - Optional description"
    echo "   - Position in the list (explain reasoning)"
    echo ""
    echo "5. Present proposal:"
    echo "   \`\`\`"
    echo "   I propose adding pace '**[title]**' after '[existing pace]'"
    echo "   because [reasoning]."
    echo "   Should I add it there?"
    echo "   \`\`\`"
    echo ""
    echo "6. Wait for user approval or amendment"
    echo ""
    echo "7. If approved, update the heat file:"
    echo "   - Add pace to ## Remaining section at proposed position"
    echo ""
    echo "8. Do NOT commit (preparatory work, accumulates until /jjc-pace-wrap or /jjc-notch)"
    echo ""
    echo "9. Report what was added"
    echo ""
    echo "Error handling: If paths wrong or files missing, announce issue and stop."
  }
}

zjjw_emit_pace_arm() {
  {
    echo "You are arming a pace for autonomous execution."
    echo ""
    echo "Configuration:"
    echo "- Target repo dir: ${ZJJW_TARGET_DIR}"
    echo "- Kit path: ${ZJJW_KIT_PATH}"
    echo ""
    echo "Steps:"
    echo ""
    echo "1. Check for current heat in .claude/jjm/current/"
    echo "   - If no heat: announce \"No active heat\" and stop"
    echo ""
    echo "2. Identify the pace to arm (from context or ask)"
    echo ""
    echo "3. Validate the pace spec is sufficient for autonomous execution:"
    echo "   - Objective: Is it clearly defined?"
    echo "   - Scope: Is it bounded (what files/areas to touch, what to avoid)?"
    echo "   - Success criteria: How do we know it worked?"
    echo "   - Failure behavior: What to do if stuck or blocked?"
    echo ""
    echo "4. If spec is insufficient:"
    echo "   - List specific gaps"
    echo "   - Help user refine the spec"
    echo "   - Do NOT arm until spec is healthy"
    echo ""
    echo "5. If spec is sufficient:"
    echo "   - Recommend model tier (haiku for mechanical, sonnet for judgment, opus for complex)"
    echo "   - Add \`[armed]\` marker to the pace title in the heat file"
    echo "   - Report: \"Pace armed and ready to fly\""
    echo ""
    echo "6. Do NOT execute the pace - arming is validation only"
    echo ""
    echo "Error handling: If paths wrong or files missing, announce issue and stop."
  }
}

zjjw_emit_pace_fly() {
  {
    echo "You are flying an armed pace - executing it autonomously."
    echo ""
    echo "Configuration:"
    echo "- Target repo dir: ${ZJJW_TARGET_DIR}"
    echo "- Kit path: ${ZJJW_KIT_PATH}"
    echo ""
    echo "Steps:"
    echo ""
    echo "1. Check for current heat in .claude/jjm/current/"
    echo "   - If no heat: announce \"No active heat\" and stop"
    echo "   - Note the heat's silks (kebab-case description from filename)"
    echo ""
    echo "2. Identify the pace to fly (from context or ask)"
    echo ""
    echo "3. Check the pace is armed:"
    echo "   - Look for \`[armed]\` marker in the pace title"
    echo "   - If not armed: refuse with \"This pace is not armed - use /jjc-pace-arm first\""
    echo ""
    echo "4. Present the spec and begin execution:"
    echo "   \`\`\`"
    echo "   Flying pace: **[title]**"
    echo "   Objective: [objective]"
    echo "   Scope: [scope]"
    echo "   Success: [criteria]"
    echo "   On failure: [behavior]"
    echo "   \`\`\`"
    echo ""
    echo "5. Execute the pace based solely on the spec"
    echo "   - If target repo != \`.\`, work in target repo directory: ${ZJJW_TARGET_DIR}"
    echo "   - Work from the spec, not from conversation context"
    echo "   - Stay within defined scope"
    echo "   - Stop when success criteria met OR failure condition hit"
    echo ""
    echo "6. Report outcome:"
    echo "   - Success: what was accomplished, evidence of success criteria"
    echo "   - Failure: what was attempted, why stopped, what's needed"
    echo "   - Modified files: list absolute paths"
    echo ""
    echo "7. Append FLY entry to steeplechase (.claude/jjm/current/jjc_*.md):"
    echo "   \`\`\`markdown"
    echo "   ---"
    echo "   ### YYYY-MM-DD HH:MM - [pace-silks] - FLY"
    echo "   **Spec**: [brief summary]"
    echo "   **Execution trace**: [key actions taken]"
    echo "   **Result**: success | failure | partial"
    echo "   **Modified files**: [list]"
    echo "   ---"
    echo "   \`\`\`"
    echo ""
    echo "8. Do NOT auto-complete the pace. User decides via /jjc-pace-wrap"
    echo "   Work is NOT auto-committed. User can review and use /jjc-notch."
    echo ""
    echo "Error handling: If paths wrong or files missing, announce issue and stop."
  }
}

zjjw_emit_pace_wrap() {
  local z_brand="${1}"  # Brand not used in new design, but accepted for consistency
  {
    echo "---"
    echo "argument-hint: [favor]"
    echo "description: Complete pace ceremony"
    echo "---"
    echo ""
    echo "Complete a pace and advance to the next one."
    echo ""
    echo "**Usage:**"
    echo "- \`/jjc-pace-wrap ₣HHPPP\` - Wrap the specified pace by Favor"
    echo ""
    echo "**What it does:**"
    echo "1. Validates clean worktree (fails if uncommitted changes - run /jjc-notch first)"
    echo "2. Pushes to remote (synchronous, must succeed)"
    echo "3. Marks pace complete in studbook (jju_tally)"
    echo "4. Creates WRAP steeplechase entry (jju_chalk, empty git commit)"
    echo "5. Finds next pending pace and displays it"
    echo ""
    echo "**Output:**"
    echo "- Wrapped pace Favor and description"
    echo "- Next pace Favor and description (or \"Heat complete\" if none)"
    echo ""
    echo "**Tabtarget:** \`tt/jjk-w.PaceWrap.sh ₣HHPPP\`"
    echo ""
    echo "**Note:** Claude remembers the next pace Favor from the output - no need to run /jjc-heat-saddle again."
    echo ""
    echo "Configuration:"
    echo "- Target repo dir: ${ZJJW_TARGET_DIR}"
    echo "- Kit path: ${ZJJW_KIT_PATH}"
  }
}


zjjw_emit_itch_add() {
  {
    echo "---"
    echo "argument-hint: [description-or-silks]"
    echo "---"
    echo ""
    echo "You are adding a new itch to the Job Jockey backlog."
    echo ""
    echo "Configuration:"
    echo "- Target repo dir: ${ZJJW_TARGET_DIR}"
    echo "- Kit path: ${ZJJW_KIT_PATH}"
    echo ""
    echo "Steps:"
    echo ""
    echo "1. Understand the itch from conversation context"
    echo "   - What future work is being captured?"
    echo "   - What's the core idea or problem?"
    echo ""
    echo "2. Read existing itches from .claude/jjm/jji_itch.md"
    echo "   - Note existing silks to avoid duplicates"
    echo ""
    echo "3. Generate unique silks (kebab-case identifier):"
    echo "   - 3-5 words, short enough to say aloud"
    echo "   - Must not duplicate existing itch silks"
    echo "   - Should be memorable and descriptive"
    echo ""
    echo "4. Append new itch section to .claude/jjm/jji_itch.md:"
    echo "   \`\`\`markdown"
    echo "   ## [silks]"
    echo "   [Brief description of the itch - what and why]"
    echo "   \`\`\`"
    echo ""
    echo "5. Report what was added (no confirmation step - user can request adjustment)"
    echo ""
    echo "6. Do NOT commit (accumulates until /jjc-notch)"
    echo ""
    echo "Error handling: If jji_itch.md missing, announce issue and stop."
  }
}

zjjw_emit_notch_command() {
  local z_brand="${1}"
  {
    echo "You are dispatching a JJ-aware git commit (notch)."
    echo ""
    echo "Configuration:"
    echo "- Target repo dir: ${ZJJW_TARGET_DIR}"
    echo "- Kit path: ${ZJJW_KIT_PATH}"
    echo "- Brand: ${z_brand}"
    echo ""
    echo "Steps:"
    echo ""
    echo "1. Identify active heat from conversation context"
    echo "   - The heat should be unambiguous from prior conversation (e.g., heat-saddle, pace-wrap)"
    echo "   - If heat context is clear: proceed with that heat"
    echo "   - If no heat context or ambiguous: fail with \"No heat context - run /jjc-heat-saddle first\""
    echo "   - Do NOT fall back to filesystem checks or offer choices"
    echo ""
    echo "2. Extract heat silks from context"
    echo "   - Heat filename pattern: \`jjh_bYYMMDD-SILKS.md\`"
    echo "   - Example: \`jjh_b251227-cloud-first-light.md\` → silks = \`cloud-first-light\`"
    echo ""
    echo "3. Extract current pace from context (optional)"
    echo "   - If a specific pace is being worked: extract silks from title (\`**Fix quota bug**\` → \`fix-quota-bug\`)"
    echo "   - If no specific pace (general heat work, editing heat file): proceed without pace"
    echo ""
    echo "4. Check for new (untracked) files:"
    echo "   \`\`\`bash"
    echo "   git ls-files --others --exclude-standard"
    echo "   \`\`\`"
    echo "   - If any output: announce \"New files detected - stage manually first\" and stop"
    echo "   - New files require explicit user staging; notch only handles modified/deleted"
    echo ""
    echo "5. Dispatch notcher agent in background:"
    echo "   - Use Task tool with subagent_type='general-purpose', model='haiku', run_in_background=true"
    echo "   - Prompt template (substitute HEAT and optionally PACE at runtime):"
    echo "     \`\`\`"
    echo "     Git commit agent. Heat=HEAT, Pace=PACE (or none), Brand=${z_brand}"
    echo "     Format:"
    echo "       With pace: [jj:${z_brand}][HEAT/PACE] Summary"
    echo "       Without pace: [jj:${z_brand}][HEAT] Summary"
    echo "       Line 1 under 72 chars, imperative tense"
    echo "       Line 2: blank"
    echo "       Lines 3+: - Detail bullet per logical change"
    echo "     Process: git add -u, git diff --cached, write message, git commit -m \"...\", git push, report hash."
    echo "     \`\`\`"
    echo ""
    echo "6. Announce \"Notch dispatched\" and return immediately"
    echo "   - Do NOT wait for agent completion"
    echo "   - Do NOT re-engage with pace (user continues naturally)"
    echo "   - User can check background task status if needed"
    echo ""
    echo "Error handling: If heat context missing or ambiguous, fail immediately - do not attempt recovery."
  }
}

zjjw_emit_claudemd_section() {
  {
    echo "## Job Jockey Configuration"
    echo ""
    echo "Job Jockey (JJ) is installed for managing project initiatives."
    echo ""
    echo "**Concepts:**"
    echo "- **Heat**: Bounded initiative with coherent goals (3-50 sessions)"
    echo "- **Pace**: Discrete action within a heat; can be armed for autonomous execution"
    echo "- **Favor**: Identifier for heats/paces in command output (e.g., ₣AA)"
    echo "- **Silks**: Kebab-case name for heats/paces (e.g., \`cloud-first-light\`)"
    echo "- **Paddock**: Per-heat context displayed during saddle"
    echo "- **Steeplechase**: Execution history captured in git commits"
    echo "- **Trophy**: Archived heat with full history"
    echo "- **Itch**: Future work (any detail level)"
    echo "- **Scar**: Closed work with lessons learned"
    echo ""
    echo "- Target repo dir: \`${ZJJW_TARGET_DIR}\`"
    echo "- JJ Kit path: \`${ZJJW_KIT_PATH}\`"
    echo ""
    echo "**Available commands:**"
    echo "- \`/jjc-heat-saddle\` - Saddle up on heat at session start, analyze and propose approach"
    echo "- \`/jjc-heat-retire\` - Move completed heat to retired with datestamp"
    echo "- \`/jjc-pace-new\` - Add a new pace"
    echo "- \`/jjc-pace-arm\` - Validate pace spec and arm for autonomous execution"
    echo "- \`/jjc-pace-fly\` - Execute an armed pace autonomously"
    echo "- \`/jjc-pace-wrap\` - Mark pace complete, auto-notch, analyze next pace, propose approach"
    echo "- \`/jjc-itch-add\` - Add a new itch to the backlog"
    echo "- \`/jjc-notch\` - JJ-aware git commit and push"
    echo ""
    echo "**Important**: New commands are not available in this installation session. You must restart Claude Code before the new commands become available."
  }
}

######################################################################
# Main Commands

jjw_install() {
  buc_step "Clearing previous installation"
  jjw_uninstall

  buc_step "Computing brand from kit content"
  local z_ledger_file="${ZJJW_SCRIPT_DIR}/jjl_ledger.json"
  local z_temp_file="${BUD_TEMP_DIR}/jjw_ledger_temp.json"

  local z_hash
  z_hash=$(zjjw_compute_source_hash)

  local z_brand
  z_brand=$(zjjw_lookup_brand_by_hash "${z_hash}")

  if test -z "${z_brand}"; then
    buc_step "Registering new ledger entry"
    local z_max_version
    z_max_version=$(jq 'map(.v) | max // 599' "${z_ledger_file}") || buc_die "Failed to compute max version"
    z_brand=$((z_max_version + 1))

    local z_commit
    z_commit=$(git -C "${ZJJW_SCRIPT_DIR}" rev-parse --short HEAD) || buc_die "Failed to get git commit"

    local z_date
    z_date=$(date +%Y-%m-%d)

    jq --argjson v "${z_brand}" --arg h "${z_hash}" --arg c "${z_commit}" --arg d "${z_date}" \
      '. + [{"v": $v, "hash": $h, "commit": $c, "date": $d}]' \
      "${z_ledger_file}" > "${z_temp_file}" || buc_die "Failed to update ledger"
    mv "${z_temp_file}" "${z_ledger_file}" || buc_die "Failed to write ledger file"
  fi

  buc_step "Creating directory structure"
  mkdir -p ".claude/commands"
  mkdir -p ".claude/jjm/current"
  mkdir -p ".claude/jjm/retired"
  test -f ".claude/jjm/jji_itch.md" || echo "# Itches" > ".claude/jjm/jji_itch.md"
  test -f ".claude/jjm/jjz_scar.md" || echo "# Scars" > ".claude/jjm/jjz_scar.md"

  buc_step "Emitting command files"
  zjjw_emit_heat_saddle   > ".claude/commands/jjc-heat-saddle.md"
  zjjw_emit_heat_retire   > ".claude/commands/jjc-heat-retire.md"
  zjjw_emit_pace_new      > ".claude/commands/jjc-pace-new.md"
  zjjw_emit_pace_arm      > ".claude/commands/jjc-pace-arm.md"
  zjjw_emit_pace_fly      > ".claude/commands/jjc-pace-fly.md"
  zjjw_emit_pace_wrap "${z_brand}" > ".claude/commands/jjc-pace-wrap.md"
  zjjw_emit_itch_add      > ".claude/commands/jjc-itch-add.md"
  zjjw_emit_notch_command "${z_brand}" > ".claude/commands/jjc-notch.md"

  buc_step "Patching CLAUDE.md"
  zjjw_emit_claudemd_section > "${BUD_TEMP_DIR}/jjw_claudemd_section.md"
  zjjw_patch_claudemd

  buc_step "Adding JJM edit permission to settings.local.json"
  local z_settings_file=".claude/settings.local.json"
  # Single leading slash = project-relative path per https://code.claude.com/docs/en/iam
  local z_permission='Edit(/.claude/jjm/**)'
  local z_temp_file="${BUD_TEMP_DIR}/jjw_settings_temp.json"

  if ! test -f "${z_settings_file}"; then
    echo '{"permissions":{"allow":["'"${z_permission}"'"]}}' > "${z_settings_file}"
  else
    local z_exists
    z_exists=$(jq --arg p "${z_permission}" '.permissions.allow // [] | index($p)' "${z_settings_file}") || buc_die "Failed to read settings"
    if test "${z_exists}" = "null"; then
      jq --arg p "${z_permission}" '.permissions.allow = ((.permissions.allow // []) + [$p])' "${z_settings_file}" > "${z_temp_file}" || buc_die "Failed to add permission"
      mv "${z_temp_file}" "${z_settings_file}" || buc_die "Failed to update settings file"
    fi
  fi

  buc_success "Job Jockey installed"
  echo ""
  echo "Restart Claude Code for new commands to become available."
}

jjw_uninstall() {
  buc_step "Removing command files"
  rm -f .claude/commands/jj*.md

  buc_step "Removing agent files"
  rm -f .claude/agents/jjsa-*.md

  buc_step "Removing CLAUDE.md section"
  zjjw_unpatch_claudemd

  buc_step "Removing JJM edit permission from settings.local.json"
  local z_settings_file=".claude/settings.local.json"
  # Single leading slash = project-relative path per https://code.claude.com/docs/en/iam
  local z_permission='Edit(/.claude/jjm/**)'
  local z_temp_file="${BUD_TEMP_DIR}/jjw_settings_temp.json"

  if test -f "${z_settings_file}"; then
    jq --arg p "${z_permission}" '.permissions.allow = ((.permissions.allow // []) | map(select(. != $p)))' "${z_settings_file}" > "${z_temp_file}" || buc_die "Failed to remove permission"
    mv "${z_temp_file}" "${z_settings_file}" || buc_die "Failed to update settings file"
  fi

  buc_success "Job Jockey uninstalled (state preserved in .claude/jjm/)"
}

jjw_check() {
  local z_ledger_file="${ZJJW_SCRIPT_DIR}/jjl_ledger.json"

  # Compute current source hash and look up in ledger
  local z_hash
  z_hash=$(zjjw_compute_source_hash)

  local z_source_brand
  z_source_brand=$(zjjw_lookup_brand_by_hash "${z_hash}")

  # Get installed brand (if any)
  local z_installed_brand
  z_installed_brand=$(zjjw_installed_brand)

  # Display status
  echo "Source hash: ${z_hash}"
  if test -n "${z_source_brand}"; then
    echo "Source brand: ${z_source_brand}"
  else
    echo "Source brand: (not registered)"
  fi

  if test -n "${z_installed_brand}"; then
    echo "Installed brand: ${z_installed_brand}"
  else
    echo "Installed brand: (none)"
  fi

  echo ""
  echo "Ledger entries:"
  jq -r '.[] | "  \(.v)  \(.date)  \(.hash)  \(.commit)"' "${z_ledger_file}"

  echo ""
  if test -n "${z_source_brand}"; then
    echo "Status: OK (source registered as brand ${z_source_brand})"
    exit 0
  else
    echo "Status: UNKNOWN (source not in ledger, install will register)"
    exit 1
  fi
}

zjjw_patch_claudemd() {
  local z_section_file="${BUD_TEMP_DIR}/jjw_claudemd_section.md"
  local z_prompt_file="${BUD_TEMP_DIR}/jjw_patch_prompt.txt"

  test -f "${z_section_file}" || buc_die "Section file not found: ${z_section_file}"

  local z_section_content
  z_section_content=$(<"${z_section_file}")
  test -n "${z_section_content}" || buc_die "Section content is empty"

  {
    echo "In CLAUDE.md, find the '## Job Jockey Configuration' section."
    echo "Replace everything from that header until the next '## ' header (or end of file) with this exact content:"
    echo ""
    echo "${z_section_content}"
    echo ""
    echo "If no such section exists, append at end of file."
    echo "Preserve all other content exactly as-is."
  } > "${z_prompt_file}"

  local z_prompt
  z_prompt=$(<"${z_prompt_file}")

  claude --setting-sources user \
    --allowedTools "Read,Edit,Write" \
    -p "${z_prompt}" || buc_die "Claude CLI failed to patch CLAUDE.md"
}

zjjw_unpatch_claudemd() {
  local z_prompt="In CLAUDE.md, find the '## Job Jockey Configuration' section. Remove everything from that header until the next '## ' header (or end of file). If no such section exists, do nothing. Preserve all other content exactly as-is."

  claude --setting-sources user \
    --allowedTools "Read,Edit,Write" \
    -p "${z_prompt}" 2>/dev/null || true
}

######################################################################
# Routing

jjw_route() {
  local z_command="${1:-}"
  shift || true

  case "${z_command}" in
    jja-c) jjw_check ;;
    jja-i) jjw_install ;;
    jja-u) jjw_uninstall ;;
    *)     buc_die "Unknown command: ${z_command}\nAvailable: jja-c (check), jja-i (install), jja-u (uninstall)" ;;
  esac
}

jjw_main() {
  local z_command="${1:-}"
  shift || true

  test -n "${z_command}" || buc_die "No command specified"

  jjw_route "${z_command}" "$@"
}

jjw_main "$@"

# eof
