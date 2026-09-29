// Copyright 2026 Scale Invariant, Inc.
// SPDX-License-Identifier: Apache-2.0
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

//! The command surface the shipped substrate spends, read at the substrate's own seat.
//!
//! A prill is the button of metal left in the cupel when the assay has driven
//! everything else off. What this hurdle drives off is every command-position
//! token the shipped bash spends that the console guide's floor and the
//! substrate's own declared inventory do not admit; what should remain is
//! nothing at all.
//!
//! WHY IT STANDS HERE AND NOT ONLY DOWNSTREAM. The estate's other reading of
//! this discipline is recipemuster's cupel fixture, which fires when that
//! consumer installs a fresh parcel — so a command outside the floor lands at
//! this kit's home unseen and meets a gate a week later, in another tree, under
//! another pace. A `mkfifo` did exactly that. The gate belongs at the authoring
//! seat, which is here.
//!
//! THE CORPUS IS THE SHIPPED BASH AND NOTHING ELSE — the `.sh` files standing
//! directly in the substrate, which are the files a parcel carries. This crate's
//! own `src/` and `tests/` are rust, and the kennel's bash is another kit's.
//!
//! THE JUDGEMENT IS MADE FROM OUTSIDE THE SHELL, like every hurdle here, but for
//! a second reason of its own: this one spawns nothing at all. It reads files and
//! judges tokens, so it needs no seat and no composed repository, and it runs
//! identically on a station that could not run bash.
//!
//! WHERE THE TOKENIZER LIVES. The command-position lexer below is a copy of
//! recipemuster's `rbtdru_bash::zrbtdru_command_words`, and it is a copy under a
//! stated removal condition rather than a fork: the estate wants one tokenizer,
//! and the single home would be a crate both trees depend on — a change in
//! recipemuster's tree, which the pace that wrote this file could not make.
//! REMOVAL CONDITION: when a crate exists that both this suite and the theurge
//! may depend on, the lexer moves there and both copies become imports. Until
//! then a defect found in either copy is repaired in both.

#![deny(warnings)]
#![allow(non_camel_case_types)]

use std::collections::BTreeSet;
use std::path::PathBuf;

use buk::buas_seat::buas_substrate;

// ── The allowlists ──────────────────────────────────────────

/// The console guide's POSIX Utility Allowlist, verbatim — the irreducible
/// floor. Each has no
/// bash 3.2 builtin replacement and is mandated by POSIX wherever bash runs, so
/// each needs no justification anywhere.
///
/// THE GUIDE IS THE SOURCE OF TRUTH AND THIS LIST IS ITS COPY, not a superset
/// of it: the consumer-side fixture this lint is ported from carries an eleventh
/// member on a precedent the operator overturned, and nothing is admitted here
/// that the guide does not carry.
const BUJP_FLOOR: &[&str] = &[
    "chmod", "cp", "date", "find", "mkdir", "mv", "rm", "sleep", "sort", "stty",
];

/// The substrate's declared dependencies — the Dependency Inventory in the
/// substrate's own specification, where each carries the justification the
/// console guide's Declared Dependency Principle demands.
///
/// THREE TIERS IN ONE LIST, because the lint asks one question of a token and the
/// tiering is the inventory's own reading: `git`, `openssl` and `tee` are
/// required wherever the substrate runs; `shellcheck` is the qualification door's
/// alone; and the four clipboard faces are probed and skipped, never required on
/// any station. A row is added HERE only after it is added THERE, and only after
/// the Declared Dependency Principle has been answered — where an
/// already-declared dependency serves, the caller is rewritten instead.
const BUJP_DECLARED: &[&str] = &[
    "git", "openssl", "tee",
    "shellcheck",
    "clip.exe", "pbcopy", "wl-copy", "xclip",
];

/// One evicted command and the replacement reported in its stead. Verbatim from
/// the console guide's "Evicted Utilities" table; the replacements are named so a refusal
/// carries its own remedy rather than sending the reader to the guide.
struct bujp_Eviction {
    command: &'static str,
    replacement: &'static str,
}

/// The guide's eviction table. These have builtin or declared-dependency replacements
/// and are refused with the replacement named.
const BUJP_EVICTIONS: &[bujp_Eviction] = &[
    bujp_Eviction { command: "awk",       replacement: "read with IFS + parameter expansion" },
    bujp_Eviction { command: "base64",    replacement: "openssl enc -base64" },
    bujp_Eviction { command: "cut",       replacement: "read with IFS + parameter expansion" },
    bujp_Eviction { command: "grep",      replacement: "case / test / [[ =~ ]]" },
    bujp_Eviction { command: "head",      replacement: "read -r" },
    bujp_Eviction { command: "ls",        replacement: "glob expansion (for f in dir/*)" },
    bujp_Eviction { command: "mktemp",    replacement: "a counter-keyed name under BURD_TEMP_DIR/BUT_TEMP_DIR (never $$)" },
    bujp_Eviction { command: "sed",       replacement: "${var//pattern/repl} (extglob) / [[ =~ ]] BASH_REMATCH" },
    bujp_Eviction { command: "sha256sum", replacement: "openssl dgst -sha256 -r" },
    bujp_Eviction { command: "shasum",    replacement: "openssl dgst -sha256 -r" },
    bujp_Eviction { command: "tr",        replacement: "${var//old/new} parameter expansion" },
    bujp_Eviction { command: "wc",        replacement: "${#var} / ${#arr[@]}" },
];

/// Bash builtins and command-position keywords naming no external command.
/// Keywords carrying control-flow structure are handled in the lexer; the rest
/// stand here so a builtin reaching classification is cleared.
const BUJP_BUILTINS: &[&str] = &[
    ":", ".", "[", "[[", "]", "]]", "alias", "bg", "bind", "break", "builtin",
    "caller", "cd", "command", "compgen", "complete", "compopt", "continue",
    "coproc", "declare", "dirs", "disown", "echo", "enable", "eval", "exec",
    "exit", "export", "false", "fc", "fg", "getopts", "hash", "help", "history",
    "jobs", "kill", "let", "local", "logout", "mapfile", "popd", "printf",
    "pushd", "pwd", "read", "readarray", "readonly", "return", "set", "shift",
    "shopt", "source", "suspend", "test", "times", "trap", "true", "type",
    "typeset", "ulimit", "umask", "unalias", "unset", "wait",
];

/// Extension selecting the shipped bash from the substrate directory.
const BUJP_SH_EXT: &str = "sh";

// ── The lexer ───────────────────────────────────────────────
//
// A copy under the removal condition stated at this file's head. Its contract is
// stated by recipemuster's unit tests in rbtdtu_cupel.rs, line by line.
//
// SOUNDNESS RESTS ON THE CORPUS BEING SHELLCHECK-CLEAN, which the substrate is,
// so a command-position lexer suffices and no full shell parser is owed. Two
// limits are accepted with it: a command substitution nested inside a
// double-quoted string is not scanned, and `;&` / `;;&` read as a plain `;`.

/// Read one shell word starting at `*i`, advancing `*i` past it and `*line` over
/// any embedded newlines. Quoted segments and `${...}` expansions are consumed
/// as part of the word; an embedded `$(` STOPS the word, so the caller scans the
/// substituted command at its own command position.
fn zbujp_read_word(chars: &[char], i: &mut usize, line: &mut usize) -> String {
    let n = chars.len();
    let mut word = String::new();
    while *i < n {
        let c = chars[*i];
        match c {
            ' ' | '\t' | '\r' | '\n' => break,
            ';' | '|' | '&' | '<' | '>' | '(' | ')' | '`' | '#' => break,
            '\'' => {
                word.push(c);
                *i += 1;
                while *i < n && chars[*i] != '\'' {
                    if chars[*i] == '\n' {
                        *line += 1;
                    }
                    word.push(chars[*i]);
                    *i += 1;
                }
                if *i < n {
                    word.push(chars[*i]);
                    *i += 1;
                }
            }
            '"' => {
                word.push(c);
                *i += 1;
                while *i < n && chars[*i] != '"' {
                    if chars[*i] == '\\' && *i + 1 < n {
                        word.push(chars[*i]);
                        word.push(chars[*i + 1]);
                        *i += 2;
                        continue;
                    }
                    if chars[*i] == '\n' {
                        *line += 1;
                    }
                    word.push(chars[*i]);
                    *i += 1;
                }
                if *i < n {
                    word.push(chars[*i]);
                    *i += 1;
                }
            }
            '$' if *i + 1 < n && chars[*i + 1] == '(' => break,
            '$' if *i + 1 < n && chars[*i + 1] == '{' => {
                word.push('$');
                *i += 1;
                let mut depth = 0usize;
                while *i < n {
                    let d = chars[*i];
                    if d == '\n' {
                        *line += 1;
                    }
                    word.push(d);
                    *i += 1;
                    if d == '{' {
                        depth += 1;
                    } else if d == '}' {
                        depth -= 1;
                        if depth == 0 {
                            break;
                        }
                    }
                }
            }
            _ => {
                word.push(c);
                *i += 1;
            }
        }
    }
    word
}

/// Classify a word sitting in command position as transparent or
/// value-introducing. `Some(true)` — a keyword whose successor is itself a
/// command. `Some(false)` — a keyword whose successor is a value. `None` — not a
/// keyword.
fn zbujp_keyword_kind(word: &str) -> Option<bool> {
    match word {
        "if" | "elif" | "while" | "until" | "then" | "else" | "do" | "!"
        | "time" | "fi" | "done" | "esac" => Some(true),
        "for" | "select" | "case" | "in" | "function" => Some(false),
        _ => None,
    }
}

/// True when `word` is a `NAME=`, `NAME+=` or `NAME[idx]=` assignment prefix — a
/// command may still follow on the same line (`FOO=bar cmd`), so command
/// position survives it.
fn zbujp_is_assignment(word: &str) -> bool {
    let bytes = word.as_bytes();
    if bytes.is_empty() {
        return false;
    }
    let first = bytes[0] as char;
    if !(first.is_ascii_alphabetic() || first == '_') {
        return false;
    }
    let mut k = 1;
    while k < bytes.len() {
        let ch = bytes[k] as char;
        if ch == '=' {
            return true;
        }
        if ch == '+' && k + 1 < bytes.len() && bytes[k + 1] == b'=' {
            return true;
        }
        if ch == '[' {
            return word.contains("]=");
        }
        if !(ch.is_ascii_alphanumeric() || ch == '_') {
            return false;
        }
        k += 1;
    }
    false
}

/// Advance `*i` past a balanced run of parentheses, tracking newlines. `depth`
/// counts the openers the caller already consumed. Quoted segments are skipped so
/// parens inside strings do not disturb the balance.
fn zbujp_skip_balanced_parens(chars: &[char], i: &mut usize, line: &mut usize, mut depth: usize) {
    let n = chars.len();
    while *i < n && depth > 0 {
        match chars[*i] {
            '(' => depth += 1,
            ')' => depth -= 1,
            '\n' => *line += 1,
            '\'' => {
                *i += 1;
                while *i < n && chars[*i] != '\'' {
                    if chars[*i] == '\n' {
                        *line += 1;
                    }
                    *i += 1;
                }
            }
            '"' => {
                *i += 1;
                while *i < n && chars[*i] != '"' {
                    if chars[*i] == '\\' && *i + 1 < n {
                        *i += 2;
                        continue;
                    }
                    if chars[*i] == '\n' {
                        *line += 1;
                    }
                    *i += 1;
                }
            }
            _ => {}
        }
        *i += 1;
    }
}

/// Every command-position token in a bash source, paired with its 1-based line.
/// A token is in command position at the start of the script, after any command
/// separator (`;`, `|`, `&`, `&&`, `||`, newline, `(`, `$(`, a backtick, an open
/// brace group) and after a transparent keyword. Assignments, redirections,
/// `[[ ]]` contents, comments, here-doc bodies and arithmetic are excluded.
fn zbujp_command_words(src: &str) -> Vec<(usize, String)> {
    let chars: Vec<char> = src.chars().collect();
    let n = chars.len();
    let mut out: Vec<(usize, String)> = Vec::new();
    let mut i = 0usize;
    let mut line = 1usize;
    let mut cmd_pos = true;
    let mut paren_depth = 0usize;
    let mut in_dbracket = false;
    let mut pending_heredoc: Option<String> = None;
    // case…esac nesting. Each frame tracks the position within a `case`:
    // 0 = subject (between `case` and `in`), 1 = pattern (suppress recording;
    // `|` is alternation, not a pipe), 2 = branch body (record commands).
    let mut case_stack: Vec<u8> = Vec::new();

    while i < n {
        let c = chars[i];

        if c == '\n' {
            i += 1;
            line += 1;
            cmd_pos = true;
            if let Some(delim) = pending_heredoc.take() {
                loop {
                    let start = i;
                    while i < n && chars[i] != '\n' {
                        i += 1;
                    }
                    let body: String = chars[start..i].iter().collect();
                    let had_nl = i < n;
                    if had_nl {
                        i += 1;
                        line += 1;
                    }
                    if body.trim() == delim {
                        break;
                    }
                    if !had_nl {
                        break;
                    }
                }
            }
            continue;
        }
        if c == ' ' || c == '\t' || c == '\r' {
            i += 1;
            continue;
        }
        if c == '\\' && i + 1 < n && chars[i + 1] == '\n' {
            i += 2;
            line += 1;
            continue;
        }
        if c == '#' {
            while i < n && chars[i] != '\n' {
                i += 1;
            }
            continue;
        }
        if c == ';' {
            i += 1;
            if i < n && chars[i] == ';' {
                i += 1;
                // `;;` ends a case branch — the next token opens a new pattern.
                if let Some(top) = case_stack.last_mut() {
                    *top = 1;
                }
                cmd_pos = false;
                continue;
            }
            if !in_dbracket {
                cmd_pos = true;
            }
            continue;
        }
        if c == '|' {
            i += 1;
            if i < n && chars[i] == '|' {
                i += 1;
            }
            // Within a case pattern `|` is alternation, not a pipe.
            if case_stack.last() == Some(&1) {
                continue;
            }
            if !in_dbracket {
                cmd_pos = true;
            }
            continue;
        }
        if c == '&' {
            if i + 1 < n && chars[i + 1] == '>' {
                i += 2;
                if i < n && chars[i] == '>' {
                    i += 1;
                }
                cmd_pos = false;
                continue;
            }
            i += 1;
            if i < n && chars[i] == '&' {
                i += 1;
            }
            if !in_dbracket {
                cmd_pos = true;
            }
            continue;
        }
        if c == '<' {
            if i + 1 < n && chars[i + 1] == '<' {
                if i + 2 < n && chars[i + 2] == '<' {
                    i += 3;
                    cmd_pos = false;
                    continue;
                }
                i += 2;
                if i < n && chars[i] == '-' {
                    i += 1;
                }
                while i < n && (chars[i] == ' ' || chars[i] == '\t') {
                    i += 1;
                }
                let mut delim = String::new();
                let quote = if i < n && (chars[i] == '\'' || chars[i] == '"') {
                    let q = chars[i];
                    i += 1;
                    Some(q)
                } else {
                    None
                };
                while i < n {
                    let d = chars[i];
                    match quote {
                        Some(qc) => {
                            if d == qc {
                                i += 1;
                                break;
                            }
                            delim.push(d);
                            i += 1;
                        }
                        None => {
                            if d == ' ' || d == '\t' || d == '\n' || d == ';'
                                || d == '&' || d == '|' || d == '<' || d == '>'
                                || d == '(' || d == ')'
                            {
                                break;
                            }
                            if d == '\\' {
                                i += 1;
                                continue;
                            }
                            delim.push(d);
                            i += 1;
                        }
                    }
                }
                if !delim.is_empty() {
                    pending_heredoc = Some(delim);
                }
                cmd_pos = false;
                continue;
            }
            i += 1;
            if i < n && chars[i] == '&' {
                i += 1;
            }
            cmd_pos = false;
            continue;
        }
        if c == '>' {
            i += 1;
            if i < n && (chars[i] == '>' || chars[i] == '&') {
                i += 1;
            }
            cmd_pos = false;
            continue;
        }
        if c == '(' {
            if i + 1 < n && chars[i + 1] == '(' {
                // Arithmetic `(( … ))` — not a command list.
                i += 2;
                zbujp_skip_balanced_parens(&chars, &mut i, &mut line, 2);
                cmd_pos = false;
                continue;
            }
            i += 1;
            paren_depth += 1;
            cmd_pos = true;
            continue;
        }
        if c == ')' {
            i += 1;
            if paren_depth > 0 {
                paren_depth -= 1;
                cmd_pos = false;
            } else if case_stack.last() == Some(&1) {
                // Pattern terminator — the branch body's command list follows.
                if let Some(top) = case_stack.last_mut() {
                    *top = 2;
                }
                cmd_pos = true;
            } else {
                cmd_pos = true;
            }
            continue;
        }
        if c == '`' {
            i += 1;
            cmd_pos = true;
            continue;
        }
        if c == '$' {
            if i + 1 < n && chars[i + 1] == '(' {
                if i + 2 < n && chars[i + 2] == '(' {
                    // Arithmetic substitution `$(( … ))` — not a command.
                    i += 3;
                    zbujp_skip_balanced_parens(&chars, &mut i, &mut line, 2);
                    cmd_pos = false;
                    continue;
                }
                i += 2;
                paren_depth += 1;
                cmd_pos = true;
                continue;
            }
            let _ = zbujp_read_word(&chars, &mut i, &mut line);
            cmd_pos = false;
            continue;
        }
        if c == '{' {
            if i + 1 < n && (chars[i + 1] == ' ' || chars[i + 1] == '\t' || chars[i + 1] == '\n') {
                i += 1;
                cmd_pos = true;
                continue;
            }
            let _ = zbujp_read_word(&chars, &mut i, &mut line);
            cmd_pos = false;
            continue;
        }
        if c == '}' {
            i += 1;
            continue;
        }

        let word_line = line;
        let word = zbujp_read_word(&chars, &mut i, &mut line);
        if word.is_empty() {
            i += 1;
            continue;
        }
        if word == "[[" {
            if cmd_pos {
                in_dbracket = true;
            }
            cmd_pos = false;
            continue;
        }
        if word == "]]" {
            in_dbracket = false;
            cmd_pos = false;
            continue;
        }
        if in_dbracket {
            continue;
        }
        // case…esac structure — tracked regardless of command position, so a
        // branch pattern is never mistaken for a command.
        if word == "case" {
            case_stack.push(0);
            cmd_pos = false;
            continue;
        }
        if word == "esac" {
            case_stack.pop();
            cmd_pos = false;
            continue;
        }
        if word == "in" && case_stack.last() == Some(&0) {
            if let Some(top) = case_stack.last_mut() {
                *top = 1;
            }
            cmd_pos = false;
            continue;
        }
        if case_stack.last() == Some(&1) {
            cmd_pos = false;
            continue;
        }
        if !cmd_pos {
            continue;
        }
        if zbujp_is_assignment(&word) {
            // `NAME=( … )` array literal — the elements are data, not commands.
            let mut j = i;
            while j < n && (chars[j] == ' ' || chars[j] == '\t') {
                j += 1;
            }
            if j < n && chars[j] == '(' {
                i = j + 1;
                zbujp_skip_balanced_parens(&chars, &mut i, &mut line, 1);
            }
            continue;
        }
        match zbujp_keyword_kind(&word) {
            Some(true) => continue,
            Some(false) => {
                cmd_pos = false;
                continue;
            }
            None => {}
        }
        out.push((word_line, word));
        cmd_pos = false;
    }
    out
}

// ── Reading the substrate ───────────────────────────────────

/// Harvest locally-defined function names from one source. Matches both the
/// `name() {` and `function name` forms.
fn zbujp_collect_functions(src: &str, out: &mut BTreeSet<String>) {
    for raw in src.lines() {
        let trimmed = raw.trim_start();
        let rest = if let Some(after) = trimmed.strip_prefix("function ") {
            after.trim_start()
        } else {
            trimmed
        };
        let mut name = String::new();
        for ch in rest.chars() {
            if ch.is_ascii_alphanumeric() || ch == '_' || ch == '-' {
                name.push(ch);
            } else {
                break;
            }
        }
        if name.is_empty() {
            continue;
        }
        let after_name = rest[name.len()..].trim_start();
        if after_name.starts_with("()") || trimmed.starts_with("function ") {
            out.insert(name);
        }
    }
}

/// The shipped bash: every `.sh` standing DIRECTLY in the substrate directory,
/// sorted. The depth is the scope — this crate's `src/` and `tests/` are rust,
/// and a parcel carries the flat files alone.
fn zbujp_shipped() -> Vec<PathBuf> {
    let substrate = buas_substrate();
    let entries = std::fs::read_dir(&substrate)
        .unwrap_or_else(|e| panic!("cannot read the substrate at {}: {}", substrate.display(), e));
    let mut out: Vec<PathBuf> = entries
        .flatten()
        .map(|e| e.path())
        .filter(|p| p.is_file() && p.extension().and_then(|e| e.to_str()) == Some(BUJP_SH_EXT))
        .collect();
    out.sort();
    assert!(
        !out.is_empty(),
        "no shipped bash stands in the substrate at {}",
        substrate.display()
    );
    out
}

/// Judge one command-position token. `Some(detail)` when it breaches the
/// discipline, `None` when it is admitted. A token carrying an expansion or a
/// quote cannot be statically named, so it is not judged at all.
fn zbujp_judge(command: &str, locals: &BTreeSet<String>) -> Option<String> {
    if command.is_empty()
        || command.contains('$')
        || command.contains('`')
        || command.contains('"')
        || command.contains('\'')
    {
        return None;
    }
    let base = command.rsplit('/').next().unwrap_or(command);
    if BUJP_BUILTINS.contains(&base) {
        return None;
    }
    if locals.contains(command) || locals.contains(base) {
        return None;
    }
    if BUJP_FLOOR.contains(&base) {
        return None;
    }
    if BUJP_DECLARED.contains(&base) {
        return None;
    }
    for ev in BUJP_EVICTIONS {
        if ev.command == base {
            return Some(format!("evicted by the console guide — use {}", ev.replacement));
        }
    }
    Some(
        "outside the POSIX Utility Allowlist and the substrate's declared \
         dependencies — name the irreducible need, or rewrite the caller onto a \
         declared dependency"
            .to_string(),
    )
}

/// The whole reading: every breach the shipped bash carries, rendered one per
/// line as `file:line: command — why`.
#[test]
fn bujp_the_shipped_bash_spends_no_undeclared_command() {
    let files = zbujp_shipped();

    let mut sources: Vec<(String, String)> = Vec::new();
    for path in &files {
        let name = path
            .file_name()
            .and_then(|s| s.to_str())
            .unwrap_or_default()
            .to_string();
        let src = std::fs::read_to_string(path)
            .unwrap_or_else(|e| panic!("cannot read {}: {}", path.display(), e));
        sources.push((name, src));
    }

    // The function universe is the shipped bash itself: these modules source one
    // another, so a call reaching a sibling's function resolves here and needs no
    // wider walk.
    let mut locals: BTreeSet<String> = BTreeSet::new();
    for (_, src) in &sources {
        zbujp_collect_functions(src, &mut locals);
    }

    let mut report = String::new();
    let mut count = 0usize;
    for (name, src) in &sources {
        for (line, command) in zbujp_command_words(src) {
            if let Some(detail) = zbujp_judge(&command, &locals) {
                count += 1;
                report.push_str(&format!("{}:{}: {} — {}\n", name, line, command, detail));
            }
        }
    }

    assert!(
        count == 0,
        "{} command-dependency breach(es) in the shipped substrate bash:\n{}",
        count,
        report
    );
}
