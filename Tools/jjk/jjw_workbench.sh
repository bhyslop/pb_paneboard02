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
# JJW Workbench - Job Jockey installation and management
#
# Commands:
#   jjk-i  Install Job Jockey
#   jjk-u  Uninstall Job Jockey (preserves .claude/jjm/ state)

set -euo pipefail

ZJJW_SCRIPT_DIR="${BASH_SOURCE[0]%/*}"

# Source dependencies
source "${ZJJW_SCRIPT_DIR}/../buk/buc_command.sh"

# Configuration - can be overridden via environment
ZJJW_TARGET_DIR="${ZJJW_TARGET_DIR:-.}"
ZJJW_KIT_PATH="${ZJJW_KIT_PATH:-Tools/jjk/README.md}"

######################################################################
# Command Emitters - one function per command file
#
# Each emits to stdout; caller redirects to file

zjjw_emit_heat_saddle() {
  {
    echo "---"
    echo "argument-hint: [silks]"
    echo "description: Select active heat"
    echo "---"
    echo ""
    echo "Select the active Job Jockey heat and show recommended approach."
    echo ""
    echo "Use cases:"
    echo "- Session start (cold start)"
    echo "- Switching between multiple active heats"
    echo "- Explicit heat status review"
    echo ""
    echo "Note: After /jja-pace-wrap or /jja-notch, you do NOT need this command -"
    echo "those commands automatically analyze and propose the next pace."
    echo ""
    echo "Configuration:"
    echo "- Target repo dir: ${ZJJW_TARGET_DIR}"
    echo "- Kit path: ${ZJJW_KIT_PATH}"
    echo ""
    echo "Steps:"
    echo ""
    echo "1. Check for heat files in .claude/jjm/current/"
    echo "   - Look for files matching pattern \`jjh_b*.md\`"
    echo ""
    echo "2. Branch based on heat count:"
    echo ""
    echo "   **If 0 heats:**"
    echo "   - Announce: \"No active heat found\""
    echo "   - Ask: \"Would you like to start a new heat or promote an itch?\""
    echo "   - Stop and wait for user direction"
    echo ""
    echo "   **If 1 heat:**"
    echo "   - Read the heat file"
    echo "   - Note the heat's silks (kebab-case description from filename)"
    echo "   - Display heat name and brief context summary"
    echo "   - Display current pace (first bolded item in ## Remaining)"
    echo "   - Read the pace description and any files/context it references"
    echo "   - Analyze what the work entails"
    echo "   - Propose a concrete approach (2-4 bullets)"
    echo "   - Append APPROACH entry to steeplechase (.claude/jjm/current/jjc_*.md):"
    echo "     - Create steeplechase file if it doesn't exist (jjc_bYYMMDD-[silks].md)"
    echo "     - Entry format:"
    echo "       \`\`\`markdown"
    echo "       ---"
    echo "       ### YYYY-MM-DD HH:MM - [pace-silks] - APPROACH"
    echo "       **Proposed approach**:"
    echo "       - [bullet 1]"
    echo "       - [bullet 2]"
    echo "       ---"
    echo "       \`\`\`"
    echo "   - Ask: \"Ready to proceed with this approach?\""
    echo "   - On approval: begin work directly"
    echo ""
    echo "   **If 2+ heats:**"
    echo "   - List all heats by name"
    echo "   - Ask: \"Which heat would you like to work on?\""
    echo "   - Wait for selection, then proceed as above"
    echo ""
    echo "Error handling: If .claude/jjm/current/ doesn't exist, announce issue and stop."
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
    echo "1. Check for heat files in .claude/jjm/current/"
    echo "   - If 0 heats: announce \"No active heat to retire\" and stop"
    echo "   - If 2+ heats: ask which one to retire"
    echo "   - Note the heat's silks (kebab-case description from filename)"
    echo ""
    echo "2. Read the heat file and verify completion:"
    echo "   - Check for any incomplete paces (\`- [ ]\` items)"
    echo "   - If incomplete paces exist:"
    echo "     - List them"
    echo "     - Ask: \"These paces are incomplete. Mark them as discarded, or continue working?\""
    echo "     - If user wants to discard: mark them with \`- [~]\` prefix and note \"(discarded)\""
    echo "     - If user wants to continue: stop retirement process"
    echo ""
    echo "3. Determine filenames:"
    echo "   - Current filename pattern: \`jjh_bYYMMDD-description.md\`"
    echo "   - Extract the begin date (bYYMMDD) and description (silks)"
    echo "   - Generate retire date: today's date as rYYMMDD"
    echo "   - New filename: \`jjh_bYYMMDD-rYYMMDD-description.md\`"
    echo ""
    echo "   Example:"
    echo "   - Before: \`jjh_b251108-buk-rename.md\`"
    echo "   - After: \`jjh_b251108-r251127-buk-rename.md\`"
    echo ""
    echo "4. Merge steeplechase into heat file (if exists):"
    echo "   - Look for matching steeplechase: \`jjc_bYYMMDD-[silks].md\`"
    echo "   - If found:"
    echo "     - Append to heat file:"
    echo "       \`\`\`markdown"
    echo "       ## Steeplechase"
    echo "       [entire contents of steeplechase file]"
    echo "       \`\`\`"
    echo "     - Delete the steeplechase file (now merged)"
    echo "   - If not found: continue (no steeplechase to merge)"
    echo ""
    echo "5. Move the heat file:"
    echo "   \`\`\`bash"
    echo "   git mv .claude/jjm/current/jjh_b251108-buk-rename.md .claude/jjm/retired/jjh_b251108-r251127-buk-rename.md"
    echo "   \`\`\`"
    echo ""
    echo "6. Commit the retirement (JJ state repo only, no push):"
    echo "   \`\`\`bash"
    echo "   git add .claude/jjm/"
    echo "   git commit -m \"JJA: heat-retire - [heat description]\""
    echo "   \`\`\`"
    echo ""
    echo "7. Report completion:"
    echo "   \`\`\`"
    echo "   Retired heat: **BUK Rename**"
    echo "   - Began: 2025-11-08"
    echo "   - Retired: 2025-11-27"
    echo "   - File: .claude/jjm/retired/jjh_b251108-r251127-buk-rename.md"
    echo "   - Steeplechase: [merged | none]"
    echo "   \`\`\`"
    echo ""
    echo "8. Offer next steps:"
    echo "   - \"Would you like to start a new heat or promote an itch from jji_itch.md?\""
    echo ""
    echo "Error handling: If paths wrong or files missing, announce issue and stop."
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
    echo "8. Do NOT commit (preparatory work, accumulates until /jja-pace-wrap or /jja-notch)"
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
    echo "   - If not armed: refuse with \"This pace is not armed - use /jja-pace-arm first\""
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
    echo "8. Do NOT auto-complete the pace. User decides via /jja-pace-wrap"
    echo "   Work is NOT auto-committed. User can review and use /jja-notch."
    echo ""
    echo "Error handling: If paths wrong or files missing, announce issue and stop."
  }
}

zjjw_emit_pace_wrap() {
  {
    echo "You are helping mark a pace complete in the current Job Jockey heat."
    echo ""
    echo "Configuration:"
    echo "- Target repo dir: ${ZJJW_TARGET_DIR}"
    echo "- Kit path: ${ZJJW_KIT_PATH}"
    echo ""
    echo "Steps:"
    echo ""
    echo "1. Check for current heat in .claude/jjm/current/"
    echo "   - If no heat: announce \"No active heat\" and stop"
    echo "   - If multiple: ask which one"
    echo "   - Note the heat's silks (kebab-case description from filename)"
    echo ""
    echo "2. Ask which pace to mark done (or infer from context)"
    echo ""
    echo "3. Summarize the pace completion based on chat context"
    echo "   - Focus on WHAT changed, not WHERE (no line numbers - they go stale)"
    echo "   - Include: file names, function/section names, nature of change"
    echo "   - Keep brief: one sentence, under 100 chars if possible"
    echo ""
    echo "4. Show proposed summary and ask for approval"
    echo ""
    echo "5. Update the heat file in .claude/jjm/current/:"
    echo "   - Move the pace to ## Done section"
    echo "   - Replace description with brief summary"
    echo "   - Bold the next pace in ## Remaining to mark it current (if any)"
    echo ""
    echo "6. Append WRAP entry to steeplechase (.claude/jjm/current/jjc_*.md):"
    echo "   - Create steeplechase file if it doesn't exist (jjc_bYYMMDD-[silks].md matching heat)"
    echo "   - Append entry in this format:"
    echo "   \`\`\`markdown"
    echo "   ---"
    echo "   ### YYYY-MM-DD HH:MM - [pace-silks] - WRAP"
    echo "   **Outcome**: [summary from step 3]"
    echo "   ---"
    echo "   \`\`\`"
    echo ""
    echo "7. Commit JJ state (this repo only, no push):"
    echo "   \`\`\`bash"
    echo "   git add .claude/jjm/current/"
    echo "   git commit -m \"JJA: pace-wrap - [brief description]\""
    echo "   \`\`\`"
    echo ""
    echo "8. Report what was done"
    echo ""
    echo "9. If there is a next pace (now first in ## Remaining):"
    echo "   - Read the pace description and any files/context it references"
    echo "   - Analyze what the work entails"
    echo "   - Propose a concrete approach (2-4 bullets)"
    echo "   - Append APPROACH entry to steeplechase:"
    echo "     \`\`\`markdown"
    echo "     ---"
    echo "     ### YYYY-MM-DD HH:MM - [pace-silks] - APPROACH"
    echo "     **Proposed approach**:"
    echo "     - [bullet 1]"
    echo "     - [bullet 2]"
    echo "     ---"
    echo "     \`\`\`"
    echo "   - Ask: \"Ready to proceed with this approach?\""
    echo "   - On approval: begin work directly (no /jja-heat-saddle needed)"
    echo ""
    echo "   If no next pace: announce \"All paces complete - ready to retire heat?\""
    echo ""
    echo "Error handling: If files missing or paths wrong, announce issue and stop."
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
    echo "6. Do NOT commit (accumulates until /jja-notch)"
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
    echo "   - If no heat context or ambiguous: fail with \"No heat context - run /jja-heat-saddle first\""
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
    echo "- **Heat**: Bounded initiative with coherent goals that are clear and present (3-50 sessions). Location: \`current/\` (active) or \`retired/\` (done)."
    echo "- **Pace**: Discrete action within a heat; can be armed for autonomous execution via \`/jja-pace-arm\`"
    echo "- **Itch**: Future work (any detail level), lives in jji_itch.md"
    echo "- **Scar**: Closed work with lessons learned, lives in jjs_scar.md"
    echo ""
    echo "- Target repo dir: \`${ZJJW_TARGET_DIR}\`"
    echo "- JJ Kit path: \`${ZJJW_KIT_PATH}\`"
    echo ""
    echo "**Available commands:**"
    echo "- \`/jja-heat-saddle\` - Saddle up on heat at session start, analyze and propose approach"
    echo "- \`/jja-heat-retire\` - Move completed heat to retired with datestamp"
    echo "- \`/jja-pace-new\` - Add a new pace"
    echo "- \`/jja-pace-arm\` - Validate pace spec and arm for autonomous execution"
    echo "- \`/jja-pace-fly\` - Execute an armed pace autonomously"
    echo "- \`/jja-pace-wrap\` - Mark pace complete, analyze next pace, propose approach"
    echo "- \`/jja-itch-add\` - Add a new itch to the backlog"
    echo "- \`/jja-notch\` - JJ-aware git commit, push, and re-engage with current pace"
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

  local z_full_hash
  z_full_hash=$(cat "${ZJJW_SCRIPT_DIR}/jjw_workbench.sh" "${ZJJW_SCRIPT_DIR}/README.md" | shasum -a 256)
  local z_hash="${z_full_hash:0:12}"

  local z_brand
  z_brand=$(jq -r --arg h "${z_hash}" '.[] | select(.hash == $h) | .v' "${z_ledger_file}") || buc_die "Failed to read ledger"

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
  test -f ".claude/jjm/jjs_scar.md" || echo "# Scars" > ".claude/jjm/jjs_scar.md"

  buc_step "Emitting command files"
  zjjw_emit_heat_saddle   > ".claude/commands/jja-heat-saddle.md"
  zjjw_emit_heat_retire   > ".claude/commands/jja-heat-retire.md"
  zjjw_emit_pace_new      > ".claude/commands/jja-pace-new.md"
  zjjw_emit_pace_arm      > ".claude/commands/jja-pace-arm.md"
  zjjw_emit_pace_fly      > ".claude/commands/jja-pace-fly.md"
  zjjw_emit_pace_wrap     > ".claude/commands/jja-pace-wrap.md"
  zjjw_emit_itch_add      > ".claude/commands/jja-itch-add.md"
  zjjw_emit_notch_command "${z_brand}" > ".claude/commands/jja-notch.md"

  buc_step "Patching CLAUDE.md"
  zjjw_emit_claudemd_section > "${BUD_TEMP_DIR}/jjw_claudemd_section.md"
  zjjw_patch_claudemd

  buc_step "Adding JJM edit permission to settings.local.json"
  local z_settings_file=".claude/settings.local.json"
  local z_permission='Edit(.claude/jjm/**)'
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
  rm -f .claude/commands/jja-*.md

  buc_step "Removing agent files"
  rm -f .claude/agents/jjsa-*.md

  buc_step "Removing CLAUDE.md section"
  zjjw_unpatch_claudemd

  buc_step "Removing JJM edit permission from settings.local.json"
  local z_settings_file=".claude/settings.local.json"
  local z_permission='Edit(.claude/jjm/**)'
  local z_temp_file="${BUD_TEMP_DIR}/jjw_settings_temp.json"

  if test -f "${z_settings_file}"; then
    jq --arg p "${z_permission}" '.permissions.allow = ((.permissions.allow // []) | map(select(. != $p)))' "${z_settings_file}" > "${z_temp_file}" || buc_die "Failed to remove permission"
    mv "${z_temp_file}" "${z_settings_file}" || buc_die "Failed to update settings file"
  fi

  buc_success "Job Jockey uninstalled (state preserved in .claude/jjm/)"
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
    jjk-i) jjw_install ;;
    jjk-u) jjw_uninstall ;;
    *)     buc_die "Unknown command: ${z_command}\nAvailable: jjk-i (install), jjk-u (uninstall)" ;;
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
