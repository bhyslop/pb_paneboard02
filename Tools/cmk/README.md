# Concept Model Kit

## What is Concept Model Kit?

Concept Model Kit (CMK) is a system for creating, editing, and rendering MCM-conformant concept model documents. It provides tooling for human-directed, LLM-executed curation of technical specifications that use linked terminology and precise relationship mapping.

The kit supports:
- **Editing**: Whitespace normalization, mapping section cleanup, link validation
- **Rendering**: Transform concept models to ClaudeMark format for LLM consumption
- **Workflow**: Prepare contributions for upstream repositories (stripping proprietary content)

## Core Concepts

### Document Structure

Concept model documents follow the Meta Concept Model (MCM) specification. Key elements:

**Linked Term**: `{category_term}`
A reference to defined vocabulary. The curly braces invoke an AsciiDoc attribute that expands to display text with an anchor link.

**Attribute Reference**: `:category_term: <<anchor,Display Text>>`
Defined in the mapping section. Maps a category-prefixed attribute name to an anchor target and display text.

**Anchor**: `[[anchor_name]]`
A definition target that linked terms point to. Appears on its own line before the definition.

**Annotation**: `// ⟦content⟧`
A Strachey-bracket comment between anchor and definition. Used for type categorization when a referencing system (like AXL) is in context. Ignored during first-order document reading.

### Category Prefixes

Each linked term uses a category prefix that classifies it by conceptual role:
- Prefixes are declared in the mapping section header
- Common pattern: `mcm_` for Meta Concept Model terms
- Variant suffixes: `_s` (plural), `_p` (possessive), `_ed` (past), `_ing` (progressive)

### Whitespace Rules

MCM documents follow specific whitespace patterns for clean diff tracking:

1. **One sentence per line** - Each sentence ends with a line break
2. **Linked terms isolated** - Line breaks before and after standalone `{term}` references in prose (exception: terms at start of bullet items stay on the marker line, as AsciiDoc requires `* content` syntax)
3. **Term sequences isolated** - Each term in a sequence gets its own line, commas attached to preceding term
4. **Blank lines between paragraphs only** - Never within paragraphs or around list items
5. **Mapping section alignment** - The `<<` aligns to columns that are multiples of 10

### Definition Form Patterns

Three patterns for defining terms:

**Definition List Form** (`mcm_form_deflist`):
```asciidoc
[[term_anchor]]
// ⟦...⟧
{term_reference}::
Definition text following sentence-per-line rules.
```

**Bullet Form** (`mcm_form_bullet`):
```asciidoc
* [[field_anchor]]
// ⟦...⟧
{field_reference} defines the specific meaning within parent structure.
```

**Section Form** (`mcm_form_section`):
```asciidoc
[[sequence_anchor]]
// ⟦...⟧
=== {sequence_reference}

The sequence executes these steps:
```

## File Structure

### Kit Files

The kit directory contains:

- `README.md` - This file: conceptual reference
- `cmw_workbench.sh` - Installation and management script
- `MCM-MetaConceptModel.adoc` - Meta Concept Model specification
- `AXLA-Lexicon.adoc` - Axial Lexicon (optional, for AXL-annotated documents)
- `AXMCM-ClaudeMarkConceptMemo.md` - ClaudeMark format reference

### Project Files (created at install)

- `lenses/` - Project-specific concept model documents (MCM/AXL specs remain in kit directory)
- `.claude/commands/cma-*.md` - Generated command files
- `.claude/agents/cmsa-*.md` - Generated subagent files

### ClaudeMark Output

Rendered ClaudeMark files are placed in `lenses/` with `-claudemark.md` suffix:
- `my-spec.adoc` → `my-spec-claudemark.md`

## Actions

Concept Model Actions (CMA) are Claude Code slash commands for working with concept model documents.

### Editing Actions

#### `/cma-normalize`
Apply full MCM normalization to concept model documents.

**Usage**: `/cma-normalize [file-path | all]`

**Model**: `haiku` (mechanical, rule-based task)

**Behavior**:
- Text Normalization: One sentence per line, linked terms isolated, blank lines only between paragraphs
- Mapping Section Normalization: Per-category group alignment to multiples of 10 columns, alphabetized by display text
- Preserves code block contents unchanged

### Rendering Actions

#### `/cma-render`
Transform concept model document to ClaudeMark format.

**Usage**: `/cma-render [source-file] [full | --terms term1,term2 | --section "Section Name"]`

**Model**: `sonnet`

**Behavior**:
- Transforms AsciiDoc to ClaudeMark using guillimet syntax
- `full`: Include all terms
- `--terms`: Include only specified terms and their definitions
- `--section`: Include only terms from specified section
- Output placed in `lenses/` with `-claudemark.md` suffix
- Validates semantic fidelity before presenting

### Validation Actions

#### `/cma-validate`
Validate links, anchors, and optionally annotations.

**Usage**: `/cma-validate [file-path | all]`

**Behavior**:
- Verifies all `{term}` references have corresponding `:term:` definitions
- Verifies all `:term:` definitions have corresponding `[[anchor]]` targets
- Checks for orphaned anchors
- If AXL is in context: validates annotation format and motif references

### Workflow Actions

#### `/cma-prep-pr`
Prepare a branch for upstream contribution, stripping proprietary content.

**Usage**: `/cma-prep-pr`

**Behavior**:
- Syncs main with upstream
- Auto-detects next candidate branch number
- Squash merges develop to candidate branch
- Strips: `.claude/` directory, `lenses/` directory
- Generates consolidated commit message
- Stops for user review before push

#### `/cma-doctor`
Validate Concept Model Kit installation.

**Usage**: `/cma-doctor`

**Behavior**:
- Verifies kit file exists at configured path
- Verifies lenses directory exists
- Checks all command files present
- Reports any issues found

## Installation

### Prerequisites

- A git repository with a `CLAUDE.md` file
- Claude Code access to the repository

### Install

Run the workbench installation script:

```bash
./Tools/cmk/cmw_workbench.sh cmk-i
```

The script will:
1. Create `.claude/commands/` and `.claude/agents/` directories
2. Generate all command and subagent files
3. Create `lenses/` directory (if missing)
4. Patch `CLAUDE.md` with CMK configuration section

After installation, **restart Claude Code** for new commands to become available.

### Uninstall

To remove CMK while preserving `lenses/` content:

```bash
./Tools/cmk/cmw_workbench.sh cmk-u
```

### Configuration

The workbench uses this environment variable (optional):

- `ZCMW_KIT_PATH` - Path to kit file (default: `Tools/cmk/README.md`)

Defaults:
- Lenses directory: `lenses/`
- Upstream remote: `OPEN_SOURCE_UPSTREAM`

## Design Principles

1. **Context-efficient**: Commands carry only the knowledge they need
2. **Source of truth**: This README and the workbench are canonical; commands are derived
3. **Explicit invocation**: User controls when operations run
4. **Model-appropriate**: Haiku for mechanical tasks, Sonnet for judgment
5. **Git-friendly**: Clear commits, user controls push
6. **Proprietary-aware**: prep-pr strips internal content cleanly
7. **Portable**: Works across computers via relative paths
8. **Do No Harm**: If paths are misconfigured or files missing, announce issue and stop — don't guess or auto-fix

---

For the full Meta Concept Model specification, see `MCM-MetaConceptModel.adoc`.
