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
# CMW Workbench - Concept Model Kit installation and management
#
# Commands:
#   cmk-i  Install Concept Model Kit
#   cmk-u  Uninstall Concept Model Kit

set -euo pipefail

ZCMW_SCRIPT_DIR="${BASH_SOURCE[0]%/*}"

# Source dependencies
source "${ZCMW_SCRIPT_DIR}/../buk/buc_command.sh"

# Show filename on each displayed line
buc_context "${0##*/}"

# Configuration - can be overridden via environment
ZCMW_KIT_PATH="${ZCMW_KIT_PATH:-Tools/cmk/README.md}"
ZCMW_KIT_DIR="$(dirname "${ZCMW_KIT_PATH}")"

# Hardcoded defaults
ZCMW_LENSES_DIR="lenses"
ZCMW_UPSTREAM_REMOTE="OPEN_SOURCE_UPSTREAM"

######################################################################
# Command Emitters - one function per command file
#
# Each emits to stdout; caller redirects to file

zcmw_emit_normalize() {
  {
    echo "---"
    echo "description: Apply whitespace normalization to concept model documents"
    echo "argument-hint: [file-path | all]"
    echo "---"
    echo ""
    echo "Invoke the cmsa-normalizer subagent to apply MCM whitespace normalization."
    echo ""
    echo "**Target:** \$ARGUMENTS"
    echo ""
    echo "Use the Task tool with:"
    echo "- \`subagent_type\`: \"cmsa-normalizer\""
    echo "- \`prompt\`: Include the target from arguments and configuration below"
    echo ""
    echo "**Configuration to pass:**"
    echo "- Lenses directory: ${ZCMW_LENSES_DIR}"
    echo "- Kit directory: ${ZCMW_KIT_DIR}"
    echo "- Kit path: ${ZCMW_KIT_PATH}"
    echo ""
    echo "**File Resolution** (include in prompt):"
    echo "When a filename is provided (not \"all\"):"
    echo "1. If it's a full path that exists → use it"
    echo "2. If it matches a file in lenses directory → use that"
    echo "3. If it matches a file in kit directory → use that"
    echo "4. Common aliases: \"MCM\" → mcm-MCM-MetaConceptModel.adoc, \"AXL\" → axl-AXLA-Lexicon.adoc"
  }
}

zcmw_emit_render() {
  {
    echo "---"
    echo "description: Transform concept model to ClaudeMark format"
    echo "argument-hint: [source-file] [full | --terms t1,t2 | --section \"Name\"]"
    echo "model: sonnet"
    echo "---"
    echo ""
    echo "You are transforming a concept model document to ClaudeMark format for LLM consumption."
    echo ""
    echo "**Configuration:**"
    echo "- Lenses directory: ${ZCMW_LENSES_DIR}"
    echo "- Kit directory: ${ZCMW_KIT_DIR}"
    echo "- Kit path: ${ZCMW_KIT_PATH}"
    echo ""
    echo "**Source:** \$1"
    echo "**Mode:** \$2 (default: full)"
    echo ""
    echo "**File Resolution:**"
    echo "When resolving the source file:"
    echo "1. If it's a full path that exists → use it"
    echo "2. If it matches a file in lenses directory → use that"
    echo "3. If it matches a file in kit directory → use that"
    echo "4. Common aliases: \"MCM\" → mcm-MCM-MetaConceptModel.adoc, \"AXL\" → axl-AXLA-Lexicon.adoc"
    echo ""
    echo "**ClaudeMark Syntax:**"
    echo "- Term definitions: \`### Term Name «term-id»\`"
    echo "- Term references: \`«term-id»\`"
    echo "- Prose flows naturally without AsciiDoc markup"
    echo "- Code literals: Standard backticks preserved"
    echo ""
    echo "**Transformation Rules:**"
    echo ""
    echo "1. **Extract term definitions**: For each \`[[anchor]]\` with definition, create:"
    echo "   \`\`\`markdown"
    echo "   ### Display Text «anchor»"
    echo "   Definition prose with «other-term» references."
    echo "   \`\`\`"
    echo ""
    echo "2. **Convert references**: \`{category_term}\` becomes \`«anchor»\` (using the anchor from the attribute definition)"
    echo ""
    echo "3. **Subsetting modes**:"
    echo "   - \`full\`: Include all terms"
    echo "   - \`--terms t1,t2\`: Include only listed terms (by anchor name)"
    echo "   - \`--section \"Name\"\`: Include only terms from that section"
    echo ""
    echo "4. **Strip annotations**: \`// ⟦...⟧\` comments do not appear in output (they inform transformation, not output)"
    echo ""
    echo "5. **Preserve structure**: Section hierarchy maps to heading levels"
    echo ""
    echo "**Output:** Write to \`${ZCMW_LENSES_DIR}/[source-basename]-claudemark.md\`"
    echo ""
    echo "**Validation before presenting:**"
    echo "- Verify all term references resolve"
    echo "- Check that semantic meaning is preserved"
    echo "- Report any transformation issues"
    echo ""
    echo "**Error handling:** If source not found, report and stop."
  }
}

zcmw_emit_validate() {
  {
    echo "---"
    echo "description: Validate concept model links and annotations"
    echo "argument-hint: [file-path | all]"
    echo "---"
    echo ""
    echo "You are validating the structural integrity of concept model documents."
    echo ""
    echo "**Configuration:**"
    echo "- Lenses directory: ${ZCMW_LENSES_DIR}"
    echo "- Kit directory: ${ZCMW_KIT_DIR}"
    echo "- Kit path: ${ZCMW_KIT_PATH}"
    echo ""
    echo "**Target:** \$ARGUMENTS (use \"all\" for all .adoc files in lenses directory)"
    echo ""
    echo "**File Resolution:**"
    echo "When a filename is provided (not \"all\"):"
    echo "1. If it's a full path that exists → use it"
    echo "2. If it matches a file in lenses directory → use that"
    echo "3. If it matches a file in kit directory → use that"
    echo "4. Common aliases: \"MCM\" → mcm-MCM-MetaConceptModel.adoc, \"AXL\" → axl-AXLA-Lexicon.adoc"
    echo ""
    echo "**Validation Checks:**"
    echo ""
    echo "1. **Reference completeness**:"
    echo "   - Every \`{term}\` used in prose has a \`:term:\` definition in mapping section"
    echo "   - Report: \"Reference to undefined term: {missing_term}\""
    echo ""
    echo "2. **Definition completeness**:"
    echo "   - Every \`:term:\` definition has a \`[[anchor]]\` target somewhere in document"
    echo "   - Report: \"Definition without anchor: :term:\""
    echo ""
    echo "3. **Anchor orphans**:"
    echo "   - Every \`[[anchor]]\` has at least one reference via \`{term}\` or \`<<anchor,...>>\`"
    echo "   - Report: \"Orphaned anchor: [[unused_anchor]]\" (warning, not error)"
    echo ""
    echo "4. **Annotation format** (if AXL context detected):"
    echo "   - Strachey brackets properly formed: \`// ⟦...⟧\`"
    echo "   - Content is space-separated terms"
    echo "   - First term is relationship (e.g., \`axl_voices\`)"
    echo "   - Report: \"Malformed annotation at line N\""
    echo ""
    echo "**Output format:**"
    echo "\`\`\`"
    echo "Validating: filename.adoc"
    echo "- Errors: N"
    echo "  - Reference to undefined term: {foo}"
    echo "  - Definition without anchor: :bar:"
    echo "- Warnings: M"
    echo "  - Orphaned anchor: [[baz]]"
    echo "- Annotations: P checked, Q issues"
    echo "\`\`\`"
    echo ""
    echo "**Summary:** Report total errors/warnings across all files."
    echo ""
    echo "**Error handling:** Continue validation even if some files have issues."
  }
}

zcmw_emit_prep_pr() {
  {
    echo "---"
    echo "description: Prepare branch for upstream PR contribution"
    echo "---"
    echo ""
    echo "You are preparing a PR branch for upstream contribution, stripping proprietary content."
    echo ""
    echo "**Configuration:**"
    echo "- Lenses directory: ${ZCMW_LENSES_DIR}"
    echo "- Kit directory: ${ZCMW_KIT_DIR}"
    echo "- Kit path: ${ZCMW_KIT_PATH}"
    echo "- Upstream remote: ${ZCMW_UPSTREAM_REMOTE}"
    echo ""
    echo "**Execute these steps:**"
    echo ""
    echo "0. **Request permissions upfront:**"
    echo "   - Ask user for permission to execute all git operations needed"
    echo "   - Get approval before proceeding"
    echo ""
    echo "1. **Verify develop is clean and pushed:**"
    echo "   - Check \`git status\` on develop branch"
    echo "   - Push any uncommitted changes to origin/develop"
    echo ""
    echo "2. **Sync main with upstream:**"
    echo "   - \`git checkout main\`"
    echo "   - \`git fetch ${ZCMW_UPSTREAM_REMOTE}\`"
    echo "   - \`git pull ${ZCMW_UPSTREAM_REMOTE} main\`"
    echo "   - If pull fails, **ABORT** and ask user to resolve"
    echo "   - \`git push origin main\`"
    echo ""
    echo "3. **Determine candidate branch (ask user):**"
    echo "   - List existing local candidate branches: \`git branch -a | grep candidate-\`"
    echo "   - Find highest batch number (NNN) and revision (R) from local branches"
    echo "   - Ask user using AskUserQuestion tool:"
    echo "     - **New delivery**: Previous PR was merged → create candidate-{N+1}-1"
    echo "     - **Reissue/fix**: Previous PR pending or rejected → create candidate-{N}-{R+1}"
    echo "   - If no prior candidates exist, default to candidate-001-1"
    echo "   - Confirm the branch name with user before proceeding"
    echo ""
    echo "4. **Create candidate branch:**"
    echo "   - \`git checkout -b candidate-NNN-R main\`"
    echo ""
    echo "5. **Squash merge develop:**"
    echo "   - Show commits: \`git log main..develop --oneline\`"
    echo "   - Execute: \`git merge --squash develop\`"
    echo ""
    echo "6. **Strip proprietary content:**"
    echo "   - \`git rm -rf --ignore-unmatch .claude/\`"
    echo "   - \`git rm -rf --ignore-unmatch ${ZCMW_LENSES_DIR}/\`"
    echo "   - Verify removal with \`git ls-files\`"
    echo ""
    echo "7. **Generate commit:**"
    echo "   - Analyze changes for consolidated message"
    echo "   - Filter out commits that only touch stripped files"
    echo "   - Create commit (no attribution footer)"
    echo ""
    echo "8. **Final review:**"
    echo "   - Show \`git log -1 --stat\`"
    echo "   - Display push instructions"
    echo "   - **STOP** - user reviews and pushes manually"
    echo ""
    echo "**Important:**"
    echo "- Be methodical, show output at each step"
    echo "- Stop immediately on errors"
    echo "- User maintains control over final push"
  }
}

zcmw_emit_doctor() {
  {
    echo "---"
    echo "description: Validate Concept Model Kit installation"
    echo "---"
    echo ""
    echo "You are validating the Concept Model Kit installation."
    echo ""
    echo "**Configuration:**"
    echo "- Kit path: ${ZCMW_KIT_PATH}"
    echo "- Lenses directory: ${ZCMW_LENSES_DIR}"
    echo "- Upstream remote: ${ZCMW_UPSTREAM_REMOTE}"
    echo ""
    echo "**Checks to perform:**"
    echo ""
    echo "1. **Kit file:**"
    echo "   - Verify \`${ZCMW_KIT_PATH}\` exists and is readable"
    echo "   - Report: ✓ Kit file found / ✗ Kit file not found"
    echo ""
    echo "2. **Lenses directory:**"
    echo "   - Verify \`${ZCMW_LENSES_DIR}\` exists"
    echo "   - List .adoc files found"
    echo "   - Report: ✓ Lenses directory with N documents / ✗ Missing"
    echo ""
    echo "3. **Command files:**"
    echo "   - Check for all expected files in \`.claude/commands/\`:"
    echo "     - cma-normalize.md"
    echo "     - cma-render.md"
    echo "     - cma-validate.md"
    echo "     - cma-prep-pr.md"
    echo "     - cma-doctor.md"
    echo "   - Report: ✓ All 5 commands present / ✗ Missing: [list]"
    echo ""
    echo "4. **Subagent files:**"
    echo "   - Check for all expected files in \`.claude/agents/\`:"
    echo "     - cmsa-normalizer.md"
    echo "   - Report: ✓ All 1 subagents present / ✗ Missing: [list]"
    echo ""
    echo "5. **Git remote** (for prep-pr):"
    echo "   - Check if \`${ZCMW_UPSTREAM_REMOTE}\` remote exists"
    echo "   - Report: ✓ Remote configured / ⚠ Remote not found (prep-pr may fail)"
    echo ""
    echo "6. **CLAUDE.md integration:**"
    echo "   - Verify CMK configuration section exists"
    echo "   - Report: ✓ CLAUDE.md configured / ✗ Missing configuration"
    echo ""
    echo "**Output format:**"
    echo "\`\`\`"
    echo "Concept Model Kit Health Check"
    echo "=============================="
    echo "Kit:        ✓ Found at ${ZCMW_KIT_PATH}"
    echo "Lenses:     ✓ ${ZCMW_LENSES_DIR}/ with N documents"
    echo "Commands:   ✓ All 5 commands installed"
    echo "Subagents:  ✓ All 1 subagents installed"
    echo "Remote:     ✓ ${ZCMW_UPSTREAM_REMOTE} configured"
    echo "CLAUDE.md:  ✓ Configured"
    echo ""
    echo "Status: HEALTHY"
    echo "\`\`\`"
    echo ""
    echo "Or if issues:"
    echo "\`\`\`"
    echo "Status: NEEDS ATTENTION"
    echo "- Missing command: cma-render.md"
    echo "- Missing subagent: cmsa-normalizer.md"
    echo "- Remote ${ZCMW_UPSTREAM_REMOTE} not configured"
    echo "\`\`\`"
  }
}

zcmw_emit_normalizer_agent() {
  {
    echo "---"
    echo "name: cmsa-normalizer"
    echo "description: Normalization for concept model documents. Enforces MCM normalization rules."
    echo "model: haiku"
    echo "tools: Read, Edit, Grep, Glob"
    echo "---"
    echo ""
    echo "You are applying MCM normalization to concept model documents. This is a two-phase process:"
    echo "- Phase 1: Text Normalization (whitespace rules)"
    echo "- Phase 2: Mapping Section Normalization (alignment and ordering)"
    echo ""
    echo "**Configuration:**"
    echo "- Lenses directory: ${ZCMW_LENSES_DIR}"
    echo "- Kit directory: ${ZCMW_KIT_DIR}"
    echo "- Kit path: ${ZCMW_KIT_PATH}"
    echo ""
    echo "---"
    echo ""
    echo "## Phase 1: Text Normalization"
    echo ""
    echo "**CRITICAL CONSTRAINT - Whitespace Only:**"
    echo "This phase adjusts ONLY line breaks and blank lines. You must NOT change any words, punctuation, or sentence structure. The document content must be identical before and after - only the placement of newlines changes."
    echo ""
    echo "**DO NOT:**"
    echo "- Reword or rephrase any text"
    echo "- Split compound sentences into multiple sentences"
    echo "- Join sentences together"
    echo "- Add new text or delete existing text"
    echo "- Change punctuation"
    echo "- \"Improve\" clarity or readability through rewording"
    echo "- Fix grammar or spelling (report issues but do not fix)"
    echo ""
    echo "**VERIFICATION**: After each edit, confirm the exact same characters exist - only newline positions may differ."
    echo ""
    echo "**Whitespace Rules to Apply:**"
    echo ""
    echo "1. **One sentence per line**: Break at EXISTING sentence boundaries (periods, question marks, exclamation points followed by space and capital letter). Do not create new sentences by restructuring."
    echo ""
    echo "2. **Linked terms isolated**: When a \`{term_reference}\` appears standalone in prose:"
    echo "   - Line break before the term"
    echo "   - Line break after the term"
    echo "   - **Exception**: Terms at start of bullet items stay on the marker line (AsciiDoc requires \`* content\` syntax)"
    echo "   - Example A (mid-sentence) - BEFORE:"
    echo "     \`\`\`"
    echo "     The system uses {excm_processor} to handle requests."
    echo "     \`\`\`"
    echo "   - Example A - AFTER:"
    echo "     \`\`\`"
    echo "     The system uses"
    echo "     {excm_processor}"
    echo "     to handle requests."
    echo "     \`\`\`"
    echo "   - Example B (start of sentence) - BEFORE:"
    echo "     \`\`\`"
    echo "     Previous sentence ends here."
    echo "     {excm_term} starts a new sentence."
    echo "     \`\`\`"
    echo "   - Example B - AFTER:"
    echo "     \`\`\`"
    echo "     Previous sentence ends here."
    echo "     {excm_term}"
    echo "     starts a new sentence."
    echo "     \`\`\`"
    echo ""
    echo "3. **Term sequences**: Each term in a sequence gets its own line:"
    echo "   - Line break before each term"
    echo "   - Line break after each term"
    echo "   - Commas stay attached to preceding term (like periods stay with sentences)"
    echo "   - Connectives like \"and\" or \"or\" get their own line"
    echo "   - Example:"
    echo "     \`\`\`"
    echo "     The interface supports"
    echo "     {excm_drag},"
    echo "     {excm_drop},"
    echo "     and"
    echo "     {excm_scroll}"
    echo "     operations."
    echo "     \`\`\`"
    echo ""
    echo "4. **Blank lines between paragraphs only**:"
    echo "   - One blank line between paragraphs"
    echo "   - No blank lines within paragraphs"
    echo "   - No blank lines around list items (except before bulleted lists in Task Lens sections)"
    echo "   - No blank lines around code blocks"
    echo ""
    echo "5. **Preserve code blocks**: Content inside \`----\` fences is opaque. Do not modify."
    echo ""
    echo "6. **Punctuation stays attached**: Periods, commas stay with their text, not on separate lines."
    echo ""
    echo "**Phase 1 Process:**"
    echo "1. Read the target file(s)"
    echo "2. **Search phase**: Use Grep to find all \`\\{[a-z_]+\\}\` patterns outside code blocks. This creates your checklist of terms to verify."
    echo "3. **Check each term**: For every term found, verify it has:"
    echo "   - Line break immediately before (or is after bullet marker \`* \`)"
    echo "   - Line break immediately after (or punctuation like \`,\` then line break)"
    echo "   - Skip terms inside \`----\` code fences"
    echo "4. Fix all violations found"
    echo "5. **Verify**: Search again to confirm no inline terms remain (terms with text on same line before AND after)"
    echo ""
    echo "**Self-check**: Verify that removing all newlines from both versions produces identical text. If not, you have made unauthorized content changes - revert and try again."
    echo ""
    echo "---"
    echo ""
    echo "## Phase 2: Mapping Section Normalization"
    echo ""
    echo "**Scope**: The mapping section is delimited by \`// tag::mapping-section[]\` and \`// end::mapping-section[]\` markers, or from document start to first section heading if no markers."
    echo ""
    echo "**Category Group Definition**: A category group is a contiguous block of attribute references preceded by a category comment header (lines starting with \`//\` that describe the category)."
    echo ""
    echo "**Rules to Apply:**"
    echo ""
    echo "1. **Per-category alignment**: Within each category group, align all \`<<\` to the smallest multiple of 10 columns that accommodates the longest attribute name in that group."
    echo "   - Measure from line start to \`<<\`"
    echo "   - Column options: 30, 40, 50, 60..."
    echo "   - Different category groups may have different alignment columns"
    echo ""
    echo "2. **Alphabetical ordering**: Within each category group, sort entries alphabetically by the display text (what appears after the comma in \`<<anchor,Display Text>>\`)."
    echo ""
    echo "3. **Preserve category headers**: Do not modify comment lines that serve as category group delimiters."
    echo ""
    echo "4. **Preserve section markers**: Keep \`// tag::mapping-section[]\` and \`// end::mapping-section[]\` exactly as they are."
    echo ""
    echo "5. **One entry per line**: Each \`:attribute:\` definition on its own line."
    echo ""
    echo "6. **Variant grouping**: Keep related variants together (base term, then _s, _p, _ed, _ing variants), sorted by the base term's display text."
    echo ""
    echo "**Example transformation:**"
    echo ""
    echo "BEFORE (misaligned, unsorted):"
    echo "\`\`\`asciidoc"
    echo "// Service Account Hierarchy"
    echo ":rbtr_governor:           <<rbtr_governor,Governor Role>>"
    echo ":rbtr_payor:                 <<rbtr_payor,Payor Role>>"
    echo ":rbtr_mason:        <<rbtr_mason,Mason Role>>"
    echo "\`\`\`"
    echo ""
    echo "AFTER (aligned to column 30, sorted by display text):"
    echo "\`\`\`asciidoc"
    echo "// Service Account Hierarchy"
    echo ":rbtr_governor:           <<rbtr_governor,Governor Role>>"
    echo ":rbtr_mason:              <<rbtr_mason,Mason Role>>"
    echo ":rbtr_payor:              <<rbtr_payor,Payor Role>>"
    echo "\`\`\`"
    echo ""
    echo "**Phase 2 Process:**"
    echo "1. Locate the mapping section"
    echo "2. Identify category groups (by comment headers)"
    echo "3. For each category group:"
    echo "   - Find the longest attribute name"
    echo "   - Calculate alignment column (round up to next multiple of 10, minimum 30)"
    echo "   - Sort entries by display text"
    echo "   - Reformat with proper alignment"
    echo "4. Write the updated mapping section"
    echo ""
    echo "---"
    echo ""
    echo "## Edit Tool Warning"
    echo ""
    echo "When using the Edit tool, \`{term}\` references must remain as single braces. Do NOT escape or double them. The Edit tool takes literal strings - write \`{mcm_term}\` not \`{{mcm_term}}\`."
    echo ""
    echo "---"
    echo ""
    echo "## Error Handling"
    echo ""
    echo "- If file not found or not .adoc, report and stop."
    echo "- If mapping section not found, skip Phase 2 but continue with Phase 1."
    echo "- Report all issues encountered but continue processing where possible."
  }
}

zcmw_emit_claudemd_section() {
  {
    echo "## Concept Model Kit Configuration"
    echo ""
    echo "Concept Model Kit (CMK) is installed for managing concept model documents."
    echo ""
    echo "**Configuration:**"
    echo "- Lenses directory: \`${ZCMW_LENSES_DIR}\`"
    echo "- Kit path: \`${ZCMW_KIT_PATH}\`"
    echo "- Upstream remote: \`${ZCMW_UPSTREAM_REMOTE}\`"
    echo ""
    echo "**Concept Model Patterns:**"
    echo "- **Linked Terms**: \`{category_term}\` - references defined vocabulary"
    echo "- **Attribute References**: \`:category_term: <<anchor,Display Text>>\` - in mapping section"
    echo "- **Anchors**: \`[[anchor_name]]\` - definition targets"
    echo "- **Annotations**: \`// ⟦content⟧\` - Strachey brackets for type categorization"
    echo ""
    echo "**Available commands:**"
    echo "- \`/cma-normalize\` - Apply full MCM normalization (haiku)"
    echo "- \`/cma-render\` - Transform to ClaudeMark (sonnet)"
    echo "- \`/cma-validate\` - Check links and annotations"
    echo "- \`/cma-prep-pr\` - Prepare upstream contribution"
    echo "- \`/cma-doctor\` - Validate installation"
    echo ""
    echo "**Subagents:**"
    echo "- \`cmsa-normalizer\` - Haiku-enforced MCM normalization (text, mapping, validation)"
    echo ""
    echo "For full MCM specification, see \`${ZCMW_KIT_DIR}/mcm-MCM-MetaConceptModel.adoc\`."
    echo ""
    echo "**Important**: Restart Claude Code session after installation for new commands and subagents to become available."
  }
}

######################################################################
# Main Commands

cmw_install() {
  buc_step "Clearing previous installation"
  cmw_uninstall

  buc_step "Creating directory structure"
  mkdir -p ".claude/commands"
  mkdir -p ".claude/agents"
  mkdir -p "${ZCMW_LENSES_DIR}"

  buc_step "Emitting command files"
  zcmw_emit_normalize   > ".claude/commands/cma-normalize.md"
  zcmw_emit_render      > ".claude/commands/cma-render.md"
  zcmw_emit_validate    > ".claude/commands/cma-validate.md"
  zcmw_emit_prep_pr     > ".claude/commands/cma-prep-pr.md"
  zcmw_emit_doctor      > ".claude/commands/cma-doctor.md"

  buc_step "Emitting subagent files"
  zcmw_emit_normalizer_agent > ".claude/agents/cmsa-normalizer.md"

  buc_step "Patching CLAUDE.md"
  zcmw_emit_claudemd_section > "${BUD_TEMP_DIR}/cmw_claudemd_section.md"
  zcmw_patch_claudemd

  buc_success "Concept Model Kit installed"
  echo ""
  echo "Restart Claude Code for new commands to become available."
}

cmw_uninstall() {
  buc_step "Removing command files"
  rm -f .claude/commands/cma-*.md

  buc_step "Removing subagent files"
  rm -f .claude/agents/cmsa-*.md

  buc_step "Removing CLAUDE.md section"
  zcmw_unpatch_claudemd

  buc_success "Concept Model Kit uninstalled"
}

zcmw_patch_claudemd() {
  local z_section_file="${BUD_TEMP_DIR}/cmw_claudemd_section.md"
  local z_prompt_file="${BUD_TEMP_DIR}/cmw_patch_prompt.txt"

  test -f "${z_section_file}" || buc_die "Section file not found: ${z_section_file}"

  local z_section_content
  z_section_content=$(<"${z_section_file}")
  test -n "${z_section_content}" || buc_die "Section content is empty"

  {
    echo "In CLAUDE.md, find the '## Concept Model Kit Configuration' section."
    echo "Replace everything from that header until the next '## ' header (or end of file) with this exact content:"
    echo ""
    echo "${z_section_content}"
    echo ""
    echo "If no such section exists, insert it before '## Current Context' if that section exists, otherwise append at end of file."
    echo "Preserve all other content exactly as-is."
  } > "${z_prompt_file}"

  local z_prompt
  z_prompt=$(<"${z_prompt_file}")

  claude --setting-sources user \
    --allowedTools "Read,Edit,Write" \
    -p "${z_prompt}" || buc_die "Claude CLI failed to patch CLAUDE.md"
}

zcmw_unpatch_claudemd() {
  local z_prompt="In CLAUDE.md, find the '## Concept Model Kit Configuration' section. Remove everything from that header until the next '## ' header (or end of file). If no such section exists, do nothing. Preserve all other content exactly as-is."

  claude --setting-sources user \
    --allowedTools "Read,Edit,Write" \
    -p "${z_prompt}" 2>/dev/null || true
}

######################################################################
# Routing

cmw_route() {
  local z_command="${1:-}"
  shift || true

  case "${z_command}" in
    cmk-i) cmw_install ;;
    cmk-u) cmw_uninstall ;;
    *)     buc_die "Unknown command: ${z_command}\nAvailable: cmk-i (install), cmk-u (uninstall)" ;;
  esac
}

cmw_main() {
  local z_command="${1:-}"
  shift || true

  test -n "${z_command}" || buc_die "No command specified"

  cmw_route "${z_command}" "$@"
}

cmw_main "$@"

# eof
