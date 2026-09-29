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
# JJSL Wicket - the shell face of the JJ operator doors over vvx: the dispatch
# stiles (saddle, lunge, ostler) plus the lock-hygiene (sight, cashier),
# studbook founding (found), and estate-abuttal (abuttal) ceremonies.
#
# A wicket is the small gate set within the main one, taken singly and on foot
# while the great gate stays shut. That is what these doors are beside the
# equerry: each is one operator-sized way through to a store the equerry otherwise
# owns, and none of them is the equerry's own road.
#
# Since the launch inversion the doors are conventional tabtargets in the launch
# stand's own tt/ - run directly, through no infield shim. The operator's cwd is never
# read: the dispatch target is elected from the record (pace -> sire -> declared
# clone), and the launch stand's own repo root (PWD, where BUK dispatch anchors)
# is handed through as --kit-root, from which the equerry derives the infield. The
# door tabtargets carry their own BURD_NO_LOG in their BURD_* block (the TUI they
# hand the terminal to cannot run under the log tee), because a dispatch-mode flag
# is the tabtarget's static property, never ambient environment (BUr_q2m).
# The stile's approach itself is Rust: vvx jjo_usher (jjrds_stile.rs).

set -euo pipefail

# Multiple inclusion detection
test -z "${ZJJSL_SOURCED:-}" || buc_die_now "Module jjsl multiply sourced - check sourcing hierarchy"
ZJJSL_SOURCED=1

# The surface forms of the governed words this gate refuses in. IT IS SOURCED
# HERE, in the module that cites it, and not left to the dispatcher: this file is
# driven directly by a test that sources it against a scratch store with the
# dispatcher never running, which is the property its header advertises, and a
# citation resolved only through the dispatcher would die `unbound variable`
# under `set -u` on exactly that path. The breviary carries its own guard, so
# every sibling gate sourcing it too costs nothing.
source "${BASH_SOURCE[0]%/*}/jjsb_breviary.sh"

# The dirname the estate keeps under the operator's home. Standing presumption,
# not discovery: every repo and clone on this station lives beneath it, and the
# abuttal text below asserts the same geography in prose.
zjjsl_estate_dirname="projects"

# The studbook's fixed dirname within the infield peer ring. Bash face of the
# equerry's JJDB_STUDBOOK_DIRNAME (vov_veiled/jjk/src/jjr0/jjrvb_blotter.rs).
zjjsl_studbook_dirname="jjqs_studbook"

# The studbook line canon is homed on — the CORPUS trunk, where the estate texts
# stand and where the operator edits them through a vulgate billet. Bash face of
# the equerry's JJRDS_VULGATE (vov_veiled/jjk/src/jjr0/jjrds_stile.rs), which names
# this same branch.
zjjsl_corpus_trunk="vulgate"

# The remote the studbook's counterpart refs hang under. Bash face of the
# equerry's ZJJRFG_REMOTE (vov_veiled/jjccg/src/jjrfg_plaingit.rs).
zjjsl_studbook_remote="origin"

# The coordinate canon is READ AT — the corpus trunk's REMOTE COUNTERPART, in the
# farrier's counterpart form (jjrfg_counterpart, the same file as the remote
# above), which is the one coordinate every corpus read in the equerry already
# takes.
#
# No local corpus line is a coordinate canon reads at, and none is established: a
# corpus landing consigns to the remote from a vulgate billet and never through
# the clone, so a local line could stand only where something carried it forward
# by hand, and a freshly cloned studbook carries the counterpart and no local line
# at all — the station this read has to serve first. JJSVD-dispatch.adoc
# jjdd_abuttal, "Canon is read at the corpus trunk's remote counterpart, which the
# door gleans first".
zjjsl_corpus_counterpart="refs/remotes/${zjjsl_studbook_remote}/${zjjsl_corpus_trunk}"

# The abuttal's canon: the studbook subdirectory holding the estate's written
# customs, and the two texts within it. Each text is emplaced as a CLAUDE.md at
# the root it governs. These are REF-relative paths, never working-tree ones:
# canon is read out of the corpus counterpart ref, so which branch the studbook clone
# happens to have checked out is not a fact this door depends on — the same
# checkout-agnosticism the equerry's own studbook reads have (jjdb_read_pinned,
# and jjrsu_read over it for the salutations).
zjjsl_abuttal_dirname="estate"
zjjsl_abuttal_home_basename="abuttal-home.md"
zjjsl_abuttal_projects_basename="abuttal-projects.md"

######################################################################
# Internal

zjjsl_kindle() {
  test -z "${ZJJSL_KINDLED:-}" || buc_die_now "jjsl already kindled"
  ZJJSL_VVX="${PWD}/Tools/vvk/bin/vvx"

  # The remedy names what stands where the reader stands, told apart without
  # guessing: a brand file under .vvk/ at the repository root means the engine
  # arrived by parcel, whose root carries the install bootstrap that emplaces it;
  # a repository with none is a forge, which builds it. A forge that also carries
  # a brand file is offered both, the build first.
  if ! test -x "${ZJJSL_VVX}"; then
    local -r z_build_remedy="build first (tt/vow-b.Build.sh)"
    local -r z_emplace_remedy="re-emplace the engine from its parcel: run vvi_install.sh at the extracted parcel's root, naming this repository's burc.env"
    local z_remedy="${z_build_remedy}"
    if test -f "${PWD}/.vvk/vvbf_brand.json"; then
      z_remedy="${z_emplace_remedy}"
      test ! -f "${PWD}/tt/vow-b.Build.sh" || z_remedy="${z_build_remedy}, or ${z_emplace_remedy}"
    fi
    buc_die_now "${JJSB_DENEGATIO_BASE_VERSAL} — the equerry-binary gate: no built binary stands at ${ZJJSL_VVX} - ${z_remedy} (JJr_s5f)"
  fi
  readonly ZJJSL_VVX

  # The infield peer ring is the launch stand's parent — the same derivation
  # the equerry makes from --kit-root — so the studbook clone carrying canon is
  # a join from here, never a scan.
  ZJJSL_INFIELD="${PWD%/*}"
  readonly ZJJSL_INFIELD

  ZJJSL_ESTATE_ROOT="${HOME}/${zjjsl_estate_dirname}"
  readonly ZJJSL_ESTATE_ROOT

  ZJJSL_STUDBOOK_ROOT="${ZJJSL_INFIELD}/${zjjsl_studbook_dirname}"
  readonly ZJJSL_STUDBOOK_ROOT

  # Corpus coordinates of the two texts — what is read; and the dispatch-temp
  # directory they are rendered into — where the comparison and the operator's
  # diff then see them. The rendered copies carry the canon dirname and
  # basenames, so a path printed at the confirm gate still reads as canon.
  ZJJSL_ABUTTAL_HOME_COORD="${zjjsl_corpus_counterpart}:${zjjsl_abuttal_dirname}/${zjjsl_abuttal_home_basename}"
  readonly ZJJSL_ABUTTAL_HOME_COORD

  ZJJSL_ABUTTAL_PROJECTS_COORD="${zjjsl_corpus_counterpart}:${zjjsl_abuttal_dirname}/${zjjsl_abuttal_projects_basename}"
  readonly ZJJSL_ABUTTAL_PROJECTS_COORD

  test -n "${BURD_TEMP_DIR:-}" || buc_die_now "jjsl abuttal: no BURD_TEMP_DIR - canon renders there, so this door must run under BUK dispatch"

  ZJJSL_ABUTTAL_CANON_DIR="${BURD_TEMP_DIR}/${zjjsl_abuttal_dirname}"
  readonly ZJJSL_ABUTTAL_CANON_DIR

  ZJJSL_ABUTTAL_HOME_CANON="${ZJJSL_ABUTTAL_CANON_DIR}/${zjjsl_abuttal_home_basename}"
  readonly ZJJSL_ABUTTAL_HOME_CANON

  ZJJSL_ABUTTAL_HOME_ECHO="${HOME}/CLAUDE.md"
  readonly ZJJSL_ABUTTAL_HOME_ECHO

  ZJJSL_ABUTTAL_PROJECTS_CANON="${ZJJSL_ABUTTAL_CANON_DIR}/${zjjsl_abuttal_projects_basename}"
  readonly ZJJSL_ABUTTAL_PROJECTS_CANON

  ZJJSL_ABUTTAL_PROJECTS_ECHO="${ZJJSL_ESTATE_ROOT}/CLAUDE.md"
  readonly ZJJSL_ABUTTAL_PROJECTS_ECHO

  readonly ZJJSL_KINDLED=1
}

zjjsl_sentinel() {
  test "${ZJJSL_KINDLED:-}" = "1" || buc_die_now "Module jjsl not kindled"
}

# Route one door through the Rust stile approach. cwd is unread: the target is
# elected from the record, and PWD (the launch stand's own root, where BUK
# dispatch has anchored) is handed through as --kit-root, from which the equerry
# derives the infield. A door invoked from an odd cwd is tolerated, never guarded.
zjjsl_door() {
  zjjsl_sentinel
  local -r z_door="${1}"
  # The turn bound, when the CALLING DOOR is an unattended one. It is a
  # parameter of this body and never an argument the operator types: each door
  # is a whole posture, so the operator picks the posture by picking the door
  # and types a target either way. Every rule ABOUT the bound is the equerry's —
  # the sub-frontier gate above all — because the tier it gates on is not known
  # until the plan resolves, and this shell reads no store.
  local -r z_turns="${2:-}"
  local -r z_target="${BUZ_FOLIO:-}"
  if test -z "${z_target}"; then
    buc_tabtarget "${JJZ_DISPATCH_HELP}"
    buc_die_now "jjsl ${z_door}: no target supplied (coronet or firemark) - the door above lists every door and what each takes"
  fi
  zjjsl_abuttal_gate
  # The station's other standing precondition, and the second of the neutrality
  # predicate's two seats: a studbook not at rest refuses the dispatch here,
  # before a kraal exists for the session to work from. Dormant until the perch
  # ref stands.
  jjsl_perch_gate "${ZJJSL_STUDBOOK_ROOT}"
  # The third, and the only one of the three that is live the moment it lands:
  # a station whose log.date carries no timezone would hand every billet a git
  # log its reader cannot place.
  jjsl_gnomon_gate "${ZJJSL_STUDBOOK_ROOT}"
  if test -n "${z_turns}"; then
    exec "${ZJJSL_VVX}" jjo_usher --door "${z_door}" --target "${z_target}" --kit-root "${PWD}" \
      --headless "${z_turns}"
  fi
  exec "${ZJJSL_VVX}" jjo_usher --door "${z_door}" --target "${z_target}" --kit-root "${PWD}"
}

######################################################################
# The estate abuttal
#
# The abuttal is the estate's written customs: two CLAUDE.md texts every
# session on this station loads ahead of any project's own — estate geography
# at the home root, estate rules at the projects root. Canon lives in the
# studbook, on its corpus trunk — where the operator edits it through a vulgate
# billet like any other corpus text — and is read at that trunk's remote
# counterpart, never from the clone's working tree and never from a local line,
# whichever branch the clone happens to stand on; the copies at the two roots are
# echoes, and jjsl_abuttal is their only writer.
#
# Both working doors refuse ahead of the approach when an echo is absent or has
# drifted from canon. The check is content, never presence: the texts this
# replaced were present and asserted, unconditionally, that the session reading
# them had started at the projects root — false in every child session, so every
# session that loaded them correctly judged them wrong and overrode the file.
# A top-level instruction a session can see is false trains that session to
# override the whole file, which is why a stale echo is a refusal and not a
# warning.

# Render one canon text out of the corpus counterpart into the dispatch temp,
# where the comparison below and the operator's diff can both see it as a file.
# The read is git's, against the ref rather than the clone's working tree, and
# that is the property to keep rather than a detail of where canon sits today: a
# clone standing on some other line still carries the ref, where a door reading
# the checkout would refuse a station whose canon is perfectly present. That
# refusal is exactly what a checkout-reading door did when the corpus left the
# blotter.
#
# ABSENCE HERE MEANS ONE OF TWO THINGS, and the refusal says both: the
# counterpart is a ref git itself maintains from the remote, so a coordinate that
# resolves to nothing is a clone that has never gleaned the studbook, or a remote
# whose corpus trunk does not carry the text. It is never a clone that holds canon
# and cannot see it, which is what a local-line read could report and this one
# cannot.
zjjsl_abuttal_render() {
  zjjsl_sentinel

  local -r z_coord="${1}"
  local -r z_dest="${2}"

  git -C "${ZJJSL_STUDBOOK_ROOT}" cat-file -e "${z_coord}" 2>/dev/null \
    || buc_die_now "${JJSB_DENEGATIO_BASE_VERSAL} — the canon-absent gate: no canon at ${z_coord} in ${ZJJSL_STUDBOOK_ROOT} - the counterpart is filled by gleaning, so either this clone has never reached the studbook remote, or that remote's corpus trunk does not carry the estate abuttal (JJr_s73)"

  git -C "${ZJJSL_STUDBOOK_ROOT}" show "${z_coord}" > "${z_dest}" \
    || buc_die_now "jjsl abuttal: cannot render canon ${z_coord} from ${ZJJSL_STUDBOOK_ROOT} to ${z_dest}"
}

# Glean the studbook before canon is read out of it — JJSVD-dispatch.adoc
# jjdd_abuttal, "Canon is read at the corpus trunk's remote counterpart, which the
# door gleans first", which carries why the beat is owed.
#
# THE EQUERRY PERFORMS IT, and that is why this is one line rather than a bash
# fetch. The law is already written once and driven, so a second statement of it
# here would be a second thing to drift. The neutrality predicate beside it IS
# stated twice, and the difference is the whole rule: that seat cannot be reached
# from here, because dispatch never enters the command surface. This one can be
# reached, so it is called.
#
# THE GLEAN MOVES NO LINE and is opportunistic: it updates counterpart refs git
# itself maintains, so an unreachable remote leaves canon exactly where it last
# stood and the render above still meets it there. That is what lets a station
# whose echoes have drifted emplace canon offline, which the strict currency step
# the approach pays would not.
#
# Its exit is honoured all the same, and refusal is the only non-zero the door has.
zjjsl_corpus_freshen() {
  zjjsl_sentinel

  "${ZJJSL_VVX}" jjo_freshen --kit-root "${PWD}" \
    || buc_die_now "jjsl abuttal: the studbook could not be gleaned - see the refusal above"
}

# Prove the station can carry canon at all: the estate the abuttal's prose
# asserts is the ring the launch stand actually stands in, and both texts stand
# at the studbook's corpus counterpart. Emplacing a rule that says the estate is one
# place onto a station where it is another would install the very falsehood the
# abuttal retires.
zjjsl_abuttal_verify() {
  zjjsl_sentinel

  test "${ZJJSL_INFIELD}" = "${ZJJSL_ESTATE_ROOT}" \
    || buc_die_now "${JJSB_DENEGATIO_BASE_VERSAL} — the estate-ring gate: the launch stand's peer ring is ${ZJJSL_INFIELD}, but the abuttal's text asserts the estate is ${ZJJSL_ESTATE_ROOT} - reconcile the two before emplacing (JJr_s8y)"

  mkdir -p "${ZJJSL_ABUTTAL_CANON_DIR}" \
    || buc_die_now "jjsl abuttal: cannot create canon render directory ${ZJJSL_ABUTTAL_CANON_DIR}"

  zjjsl_corpus_freshen

  zjjsl_abuttal_render "${ZJJSL_ABUTTAL_HOME_COORD}"     "${ZJJSL_ABUTTAL_HOME_CANON}"
  zjjsl_abuttal_render "${ZJJSL_ABUTTAL_PROJECTS_COORD}" "${ZJJSL_ABUTTAL_PROJECTS_CANON}"
}

# True when the echo is byte-identical to its canon. The comparison is git's,
# not a builtin's: git is already the floor this whole system stands on, while
# `cmp` and `diff` are neither BUK-allowlisted nor worth declaring, and the same
# invocation that answers the question here renders the answer for the operator
# at the confirm gate below — one mechanism, so display and verdict cannot
# disagree. Fail-closed by construction: git reports an unreadable path as a
# difference rather than a distinct code, so every answer but "identical" sends
# the operator to the door, which is the safe direction for a launch gate.
zjjsl_abuttal_current_predicate() {
  zjjsl_sentinel

  local -r z_canon="${1}"
  local -r z_echo="${2}"

  test -f "${z_echo}" || return 1

  git diff --no-index --quiet -- "${z_canon}" "${z_echo}"
}

# The gate the working doors carry. Names its remedy by resolving the door's
# colophon rather than a filename, so a frontispiece rename cannot strand the
# operator at the one message that has to be actionable.
zjjsl_abuttal_gate() {
  zjjsl_sentinel
  zjjsl_abuttal_verify

  buym_tt_yawp "${JJZ_DISPATCH_ABUTTAL}"; local -r z_tt="${z_buym_yelp}"

  zjjsl_abuttal_current_predicate "${ZJJSL_ABUTTAL_HOME_CANON}" "${ZJJSL_ABUTTAL_HOME_ECHO}" \
    || buc_die_now "${JJSB_DENEGATIO_BASE_VERSAL} — the abuttal drift gate: the estate abuttal is absent or drifted at ${ZJJSL_ABUTTAL_HOME_ECHO} (canon ${ZJJSL_ABUTTAL_HOME_CANON}) - emplace it with ${z_tt} (JJr_ssp)"

  zjjsl_abuttal_current_predicate "${ZJJSL_ABUTTAL_PROJECTS_CANON}" "${ZJJSL_ABUTTAL_PROJECTS_ECHO}" \
    || buc_die_now "${JJSB_DENEGATIO_BASE_VERSAL} — the abuttal drift gate: the estate abuttal is absent or drifted at ${ZJJSL_ABUTTAL_PROJECTS_ECHO} (canon ${ZJJSL_ABUTTAL_PROJECTS_CANON}) - emplace it with ${z_tt} (JJr_ssp)"
}

# Emplace one echo. Absent, it is written outright; divergent, the change the
# overwrite would make is shown as a diff and confirm-gated — a hand-edited echo
# is either a change owed upstream to canon or one the operator means to
# discard, and only they can say which. A diff rather than the standing text
# whole, so what is at stake reads at a glance instead of by comparison.
zjjsl_abuttal_emplace() {
  zjjsl_sentinel
  local -r z_canon="${1}"
  local -r z_echo="${2}"

  if zjjsl_abuttal_current_predicate "${z_canon}" "${z_echo}"; then
    buc_step "Current, nothing owed: ${z_echo}"
    return 0
  fi

  if test -f "${z_echo}"; then
    buc_warn "Divergent echo at ${z_echo} - confirming discards every '+' line below and restores every '-' line from canon ${z_canon}:"

    # Color is forced from the dispatch verdict, never left to git. Under
    # dispatch this stream is a pipe — the log relay — so git's own tty probe
    # would answer no on a perfectly colored terminal; the pre-pipe truth lives
    # only in BURD_COLOR (BUr_q2m), which is the same reasoning buym applies to
    # its own rendering.
    local z_color="--no-color"
    test "${BURD_COLOR:-}" != "1" || z_color="--color=always"

    # git's own report, written where the operator reads it. Status 1 is the
    # expected verdict — the files differ, which is why we are asking — so it is
    # captured rather than left to trip set -e, and anything above it is a real
    # tool failure.
    local z_status=0
    git diff --no-index "${z_color}" -- "${z_canon}" "${z_echo}" >&2 || z_status=$?
    test "${z_status}" -le 1 || buc_die_now "jjsl abuttal: git diff failed with status ${z_status} comparing ${z_echo} against ${z_canon}"

    buc_require "About to OVERWRITE the divergent text above with canon." "abuttal"
  else
    buc_step "Absent echo at ${z_echo} - emplacing canon"
  fi

  cp "${z_canon}" "${z_echo}" || buc_die_now "jjsl abuttal: cannot write ${z_echo}"
}

######################################################################
# Commands

# Help: the door to try first, which is what the digit colophon is for — it sorts
# ahead of every letter under every collation. Lists each JJ door with what it
# takes and what it does, read straight off the zipper registry: a colophon's one
# home, and the one home of every fact printed here, so nothing on this listing
# can drift from the doors it describes. Naming no colophon lists the family;
# naming one lists that door alone.
jjsl_help() {
  zjjsl_sentinel
  buz_emit_roll "jjz" "${BURC_TABTARGET_DIR}" "${BUZ_FOLIO:-}"
}

jjsl_saddle() {
  zjjsl_sentinel
  zjjsl_door "saddle"
}

jjsl_lunge() {
  zjjsl_sentinel
  zjjsl_door "lunge"
}

# The unattended door: the SADDLE's own approach, launched with nobody at the
# keyboard and bounded.
#
# A SECOND DOOR OVER ONE MECHANISM, on this heat's own precedent — the ostler and
# the drover part at their charge and share everything else, and these two part
# at one posture. What the equerry holds is a flag, so nothing here forks the
# approach: the whole difference reaching the stile is a number.
#
# It is a second DOOR rather than a flag on the saddle because the two are
# different acts to the operator, not one act with a knob. A door is what the
# operator chooses; an unattended run is a thing they decide to do, and it earns
# its own name in the family listing.
jjsl_unattended() {
  zjjsl_sentinel
  zjjsl_door "saddle" "${JJZ_UNATTENDED_TURNS}"
}

# The two groom doors, and everything they share.
#
# Both stand a groom kraal over ZERO OR MORE heats — no billet of any kind, a
# store this session can work in nowhere else — and they part only in the charge
# the equerry composes: the OSTLER tends, the DROVER drives. One mechanism, two
# fronts, so the shell half is one body called twice rather than two bodies to
# drift apart.
#
# The heats arrive by two roads because the folio channel carries exactly one:
# BUZ_FOLIO holds the first, the shell holds the rest, and the two are joined
# here into repeated --heat options. NAMING NONE IS NOT A MISUSE TO GUARD
# AGAINST — it is the estate console, which provisions every registered sire —
# so unlike the stiles above these doors assert no target and die on nothing.
#
# The heat tokens pass through unchecked. Typing them has ONE home, the equerry,
# which strips the ₣ glyph an operator reads off a report and names a coronet
# back to them as a pace where a heat was wanted; a second check here would be a
# second wording to drift.
zjjsl_groom_door() {
  zjjsl_sentinel
  local -r z_verb="${1}"
  shift

  zjjsl_abuttal_gate
  jjsl_perch_gate "${ZJJSL_STUDBOOK_ROOT}"
  jjsl_gnomon_gate "${ZJJSL_STUDBOOK_ROOT}"

  local -a z_heats=()
  test -z "${BUZ_FOLIO:-}" || z_heats+=(--heat "${BUZ_FOLIO}")
  local z_heat=""
  for z_heat in "$@"; do
    z_heats+=(--heat "${z_heat}")
  done

  exec "${ZJJSL_VVX}" "${z_verb}" ${z_heats[@]+"${z_heats[@]}"} --kit-root "${PWD}"
}

# Ostler: the operator's planning seat, where dockets are cut, curried, reslated
# and indult. Named for the inn's horse-groom, who tends every horse and rides
# none.
jjsl_ostler() {
  zjjsl_sentinel
  zjjsl_groom_door jjo_ostler "$@"
}

# Drover: the ruling layer over a wave of heats — the overseer role, which reads
# each session's report and rules at a deliberately high bar on whether any
# further action is warranted. Named for the drover who drives a herd where the
# ostler tends one horse.
#
# IT HOLDS NO LAUNCH POWER, and that is the door's contract rather than an
# omission: the operator remains the sole dispatcher, so this door stands the
# ruling seat up and dispatches nothing from it.
jjsl_drover() {
  zjjsl_sentinel
  zjjsl_groom_door jjo_drover "$@"
}

# The VAQUERO door: the immediate-work crossing.
#
# It stands an IMMEDIATE-WORK KRAAL over one heat on one sire — an outspan, a
# work billet and a vulgate billet — and launches a session that enrolls its own
# pace, works it, and closes before the chat ends. Named for the mounted cattle
# worker: competent solo work done fast and without ceremony, which is the
# crossing's character exactly.
#
# ONE DOOR, TWO REQUIRED TARGETS, and the requirement is what dissolved the pair
# that stood here. Two doors existed because a firemark and a sire handle cannot
# be told apart BY SHAPE, so a single door taking one optional argument would
# have had to guess which it held. Taking both, always, removes the guess without
# a parser: position says which is which, and there is nothing left for a second
# colophon to discriminate.
#
# The heat rides the folio channel like every other door's target; the sire is
# the one positional behind it. Both are asserted HERE rather than left to the
# equerry, on the required-target doors' own rule — a door that takes a target
# refuses without one and names the help door.
jjsl_vaquero() {
  zjjsl_sentinel

  if test -z "${BUZ_FOLIO:-}"; then
    buc_tabtarget "${JJZ_DISPATCH_HELP}"
    buc_die_now "jjsl vaquero: no heat supplied - this door opens a crossing over one heat on one sire, and takes both; the door above lists every door and what each takes"
  fi
  local -r z_sire="${1:-}"
  if test -z "${z_sire}"; then
    buc_tabtarget "${JJZ_DISPATCH_HELP}"
    buc_die_now "jjsl vaquero: no sire supplied - this crossing provisions a work billet at dispatch, so the tree it is cut from must be named, and it must already stand in the heat"
  fi

  zjjsl_abuttal_gate
  jjsl_perch_gate "${ZJJSL_STUDBOOK_ROOT}"
  jjsl_gnomon_gate "${ZJJSL_STUDBOOK_ROOT}"

  exec "${ZJJSL_VVX}" jjo_vaquero --heat "${BUZ_FOLIO}" --sire "${z_sire}" --kit-root "${PWD}"
}

# Sight every JJ blotter lock and report — read-only, always safe MECHANICALLY
# (JJSVD jjdd_cashier, sight-and-report mode). Breaks nothing; a script or the
# operator may run it freely. An AGENT may not run it in service of lock
# recovery — sight is the cashier's on-ramp, and cashiering is a human-only
# ceremony: the agent's whole move on lock-held is stop and surface.
jjsl_sight() {
  zjjsl_sentinel
  buc_step "Lock recovery is a human-only ceremony: an agent stops at lock-held and surfaces it - never cashiers (operator doors: tt/jjw-c.CheckLock.sh, tt/jjw-C.ClearLock.sh)"
  "${ZJJSL_VVX}" jjo_probate --cwd "${PWD}"
}

# Cashier a derelict lock-holder (JJSVD jjdd_cashier, break mode). A HUMAN-ONLY
# ceremony: the confirm gate is THIS door's contract, not the break sequence's —
# the sequence is mechanism, the deliberateness is the door's — and the gate is
# deliberately unskippable (no BURE_CONFIRM route, in either value): the
# operator's typed word at their own terminal is the only key. An agent never
# runs this door; it stops and surfaces the lock-held refusal instead.
jjsl_cashier() {
  zjjsl_sentinel
  test -z "${BURE_CONFIRM:-}" || buc_die_now "jjsl cashier: this gate cannot be skipped or preset - cashiering is a human-only ceremony, typed by the operator at this terminal"
  local -r z_cwd="${PWD}"

  # The report the operator judges from - the Rust verb owns its format.
  "${ZJJSL_VVX}" jjo_probate --cwd "${z_cwd}"

  buc_require "About to CASHIER the locks reported above - dismissing whoever holds them." "cashier"

  "${ZJJSL_VVX}" jjo_probate --cwd "${z_cwd}" --break
}

# Muck: destroy a named billet (JJSVD jjdd_muck). Plan-then-confirm:
# the report is shown first, the operator answers, then the destroy runs — the
# constellation's one deliberate data-loss surface.
jjsl_muck() {
  zjjsl_sentinel
  zjjsl_muck_confirmed
}

# Plan-then-confirm body for the muck door. The confirm gate is THIS door's
# contract, not the reap's: the report is shown, the operator answers, and
# only then does the SAME resolution get destroyed.
zjjsl_muck_confirmed() {
  zjjsl_sentinel
  local -r z_cwd="${PWD}"
  local -r z_target="${BUZ_FOLIO:-}"
  if test -z "${z_target}"; then
    buc_tabtarget "${JJZ_DISPATCH_HELP}"
    buc_die_now "jjsl muck: no target supplied (a yard dirname, or the coronet/firemark identity behind one) - the door above lists every door and what each takes"
  fi

  # The report the operator judges from - the Rust door owns its format.
  "${ZJJSL_VVX}" jjo_condemn --cwd "${z_cwd}" --target "${z_target}"

  buc_require "About to MUCK the billet reported above - deliberate data loss, dismissing whatever it carries." "muck"

  "${ZJJSL_VVX}" jjo_condemn --cwd "${z_cwd}" --target "${z_target}" --execute
}

# Found the studbook from nothing (JJSAS Founding-and-cutover, jjdb_found_studbook).
# An irreversible ceremony — a genesis commit pushed to the studbook remote — so
# the confirm gate is THIS door's contract, mirroring cashier: the resolved plan
# is shown first (the door's own dry run), the operator answers, then the real
# found runs. The invocation cwd elects the hippodrome (a bare tabtarget run
# self-anchors to the kit repo, itself a legitimate hippodrome).
#
# Takes the studbook REMOTE as its folio and the salutation directory as the
# second argument. The remote has no default: no estate's address is compiled
# into the equerry, and the plan the operator confirms prints the remote named
# here. A relative salutation directory resolves against the launch stand's
# root, where this trampoline anchors.
jjsl_found() {
  zjjsl_sentinel
  local -r z_cwd="${PWD}"
  local -r z_remote="${BUZ_FOLIO:-}"
  if test -z "${z_remote}"; then
    buc_tabtarget "${JJZ_DISPATCH_HELP}"
    buc_die_now "jjsl found: no studbook remote supplied - the founding publishes its genesis to the remote you name, and no estate's remote is compiled in; name it, then the salutation directory"
  fi
  local -r z_salutations="${1:-}"
  if test -z "${z_salutations}"; then
    buc_tabtarget "${JJZ_DISPATCH_HELP}"
    buc_die_now "jjsl found: no salutation directory supplied - the founding seeds the estate's salutation texts, one per roster entry, from the directory you name"
  fi

  # The plan the operator judges from - the Rust door owns its format.
  "${ZJJSL_VVX}" jjo_found --cwd "${z_cwd}" --remote "${z_remote}" --salutations "${z_salutations}" --dry-run

  buc_require "About to FOUND the studbook shown above - a genesis commit pushed to its remote, irreversible." "found"

  "${ZJJSL_VVX}" jjo_found --cwd "${z_cwd}" --remote "${z_remote}" --salutations "${z_salutations}"
}

# Admit a sire to the register (JJS0 jjsuv_keuring). Takes BOTH the clone and
# the handle, on the crossing door's precedent: the clone is the folio and the
# handle the second argument.
#
# The clone is NAMED rather than stood in, and that is forced rather than
# chosen. This trampoline normalizes cwd to the tabtarget's own repo root
# whatever directory the operator typed from, so a door electing its target from
# cwd could only ever admit the tree the door itself lives in — never the tree
# being admitted. PWD still travels, because the infield it sits in is the ring
# the named clone is resolved against and the studbook is derived from.
#
# The confirm gate is THIS door's contract, on the founding door's pattern: the
# resolved plan is shown first (the door's own dry run, which gates before it
# prints, so the operator is never asked to confirm a plan that would refuse),
# the operator answers, then the real admission runs. Unlike the founding it is
# not irreversible — a wrong row is struck by turnout — but it writes a record
# every dispatch on this station will resolve against, so it is shown and
# answered for rather than simply run.
jjsl_keuring() {
  zjjsl_sentinel
  local -r z_cwd="${PWD}"
  local -r z_clone="${BUZ_FOLIO:-}"
  if test -z "${z_clone}"; then
    buc_tabtarget "${JJZ_DISPATCH_HELP}"
    buc_die_now "jjsl ${JJSB_KEURING_BASE}: no clone supplied - this door admits a sire standing in the infield ring and takes its dirname, then the handle; the door above lists every door and what each takes"
  fi
  local -r z_handle="${1:-}"
  if test -z "${z_handle}"; then
    buc_tabtarget "${JJZ_DISPATCH_HELP}"
    buc_die_now "jjsl ${JJSB_KEURING_BASE}: no handle supplied - a handle is allotted rather than observed, so no property of the clone can stand in for it: name the sire's major project prefix"
  fi

  # The plan the operator judges from - the Rust door owns its format.
  "${ZJJSL_VVX}" jjo_keuring --cwd "${z_cwd}" --clone "${z_clone}" --handle "${z_handle}" --dry-run

  buc_require "About to ADMIT the sire shown above to the register - every dispatch on this station resolves against it." "${JJSB_KEURING_BASE}"

  "${ZJJSL_VVX}" jjo_keuring --cwd "${z_cwd}" --clone "${z_clone}" --handle "${z_handle}"
}

# Remove a sire from the register (JJS0 jjsuv_turnout). Takes the HANDLE alone,
# as its folio, and that single value is the whole parting from the admission
# beside it: an admission records a tree and so must be told which one, while a
# removal names a row the register already holds every fact about. The clone may
# not even stand on this station any more, and a door that asked for it would
# refuse for a reason that has nothing to do with whether the sire may leave.
#
# PWD still travels, for the one job it does at either door: it gives the infield
# the studbook is derived from.
#
# The confirm gate is THIS door's contract, on the admission's pattern: the
# resolved plan is shown first (the door's own dry run, which gates before it
# prints, so a handle something still holds prints its holders instead of a plan
# and is never confirmed), the operator answers, then the strike runs.
jjsl_turnout() {
  zjjsl_sentinel
  local -r z_cwd="${PWD}"
  local -r z_handle="${BUZ_FOLIO:-}"
  if test -z "${z_handle}"; then
    buc_tabtarget "${JJZ_DISPATCH_HELP}"
    buc_die_now "jjsl ${JJSB_TURNOUT_BASE}: no handle supplied - this door strikes a sire named by its handle alone, no tree being read; the door above lists every door and what each takes"
  fi

  # The plan the operator judges from - the Rust door owns its format.
  "${ZJJSL_VVX}" jjo_turnout --cwd "${z_cwd}" --handle "${z_handle}" --dry-run

  buc_require "About to STRIKE the sire shown above from the register - every dispatch on this station resolves against it." "${JJSB_TURNOUT_BASE}"

  "${ZJJSL_VVX}" jjo_turnout --cwd "${z_cwd}" --handle "${z_handle}"
}

# Emplace the estate abuttal on this station: canon over both echoes. The one
# writer of those copies, so an operator who wants the estate's rules changed
# edits canon in the studbook and runs this door — never the copies, which the
# working doors would then refuse as drift.
jjsl_abuttal() {
  zjjsl_sentinel
  zjjsl_abuttal_verify

  zjjsl_abuttal_emplace "${ZJJSL_ABUTTAL_HOME_CANON}"     "${ZJJSL_ABUTTAL_HOME_ECHO}"
  zjjsl_abuttal_emplace "${ZJJSL_ABUTTAL_PROJECTS_CANON}" "${ZJJSL_ABUTTAL_PROJECTS_ECHO}"

  buc_success "Estate abuttal stands at ${ZJJSL_ABUTTAL_HOME_ECHO} and ${ZJJSL_ABUTTAL_PROJECTS_ECHO}"
}

# eof
