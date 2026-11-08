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
# Co-maintained constants - do not hand-edit.
# The human-presentation surface forms of the governed words homed in BUK.
# A string that spells one of these words in its own bytes has left the home.
# Beside them, the colophons, exit codes and suggested values attached at definitions, each named for the definition it is attached at.
# Beside them, the face names this kit's documents wear, each named for the anchor it is worn on.

test -z "${ZBUBG_SOURCED:-}" || return 0
ZBUBG_SOURCED=1

readonly BUBG_ENDONYM_BASE="endonym"
readonly BUBG_ENDONYM_BASE_VERSAL="ENDONYM"
readonly BUBG_ENDONYM_BASE_LETTRINE="Endonym"
readonly BUBG_ENDONYM_PLURAL="endonyms"
readonly BUBG_ENDONYM_PLURAL_VERSAL="ENDONYMS"
readonly BUBG_ENDONYM_PLURAL_LETTRINE="Endonyms"
readonly BUBG_ENDONYM_POSSESSIVE="endonym's"
readonly BUBG_ENDONYM_POSSESSIVE_VERSAL="ENDONYM'S"
readonly BUBG_ENDONYM_POSSESSIVE_LETTRINE="Endonym's"
readonly BUBG_LOOSEBOX_BASE="loosebox"
readonly BUBG_LOOSEBOX_BASE_VERSAL="LOOSEBOX"
readonly BUBG_LOOSEBOX_BASE_LETTRINE="Loosebox"
readonly BUBG_LOOSEBOX_PLURAL="looseboxes"
readonly BUBG_LOOSEBOX_PLURAL_VERSAL="LOOSEBOXES"
readonly BUBG_LOOSEBOX_PLURAL_LETTRINE="Looseboxes"
readonly BUBG_LOOSEBOX_POSSESSIVE="loosebox's"
readonly BUBG_LOOSEBOX_POSSESSIVE_VERSAL="LOOSEBOX'S"
readonly BUBG_LOOSEBOX_POSSESSIVE_LETTRINE="Loosebox's"
readonly BUBG_MOORINGS_BASE="moorings"
readonly BUBG_MOORINGS_BASE_VERSAL="MOORINGS"
readonly BUBG_MOORINGS_BASE_LETTRINE="Moorings"
readonly BUBG_MOORINGS_POSSESSIVE="moorings'"
readonly BUBG_MOORINGS_POSSESSIVE_VERSAL="MOORINGS'"
readonly BUBG_MOORINGS_POSSESSIVE_LETTRINE="Moorings'"
readonly BUBG_STATION_BASE="station"
readonly BUBG_STATION_BASE_VERSAL="STATION"
readonly BUBG_STATION_BASE_LETTRINE="Station"
readonly BUBG_STATION_PLURAL="stations"
readonly BUBG_STATION_PLURAL_VERSAL="STATIONS"
readonly BUBG_STATION_PLURAL_LETTRINE="Stations"
readonly BUBG_STATION_POSSESSIVE="station's"
readonly BUBG_STATION_POSSESSIVE_VERSAL="STATION'S"
readonly BUBG_STATION_POSSESSIVE_LETTRINE="Station's"
readonly BUBG_STATION_LOG_BASE="station log"
readonly BUBG_STATION_LOG_BASE_VERSAL="STATION LOG"
readonly BUBG_STATION_LOG_BASE_LETTRINE="Station log"
readonly BUBG_STATION_LOG_PLURAL="station logs"
readonly BUBG_STATION_LOG_PLURAL_VERSAL="STATION LOGS"
readonly BUBG_STATION_LOG_PLURAL_LETTRINE="Station logs"
readonly BUBG_STATION_LOG_POSSESSIVE="station log's"
readonly BUBG_STATION_LOG_POSSESSIVE_VERSAL="STATION LOG'S"
readonly BUBG_STATION_LOG_POSSESSIVE_LETTRINE="Station log's"
readonly BUBG_TABTARGET_BASE="tabtarget"
readonly BUBG_TABTARGET_BASE_VERSAL="TABTARGET"
readonly BUBG_TABTARGET_BASE_LETTRINE="Tabtarget"
readonly BUBG_TABTARGET_PLURAL="tabtargets"
readonly BUBG_TABTARGET_PLURAL_VERSAL="TABTARGETS"
readonly BUBG_TABTARGET_PLURAL_LETTRINE="Tabtargets"
readonly BUBG_TABTARGET_POSSESSIVE="tabtarget's"
readonly BUBG_TABTARGET_POSSESSIVE_VERSAL="TABTARGET'S"
readonly BUBG_TABTARGET_POSSESSIVE_LETTRINE="Tabtarget's"
readonly BUBG_TWEAK_BASE="tweak"
readonly BUBG_TWEAK_BASE_VERSAL="TWEAK"
readonly BUBG_TWEAK_BASE_LETTRINE="Tweak"
readonly BUBG_TWEAK_PLURAL="tweaks"
readonly BUBG_TWEAK_PLURAL_VERSAL="TWEAKS"
readonly BUBG_TWEAK_PLURAL_LETTRINE="Tweaks"
readonly BUBG_TWEAK_POSSESSIVE="tweak's"
readonly BUBG_TWEAK_POSSESSIVE_VERSAL="TWEAK'S"
readonly BUBG_TWEAK_POSSESSIVE_LETTRINE="Tweak's"
readonly BUBG_BATCH_AMANUENSIS_BASE="amanuensis"
readonly BUBG_BATCH_AMANUENSIS_BASE_VERSAL="AMANUENSIS"
readonly BUBG_BATCH_AMANUENSIS_BASE_LETTRINE="Amanuensis"
readonly BUBG_BATCH_AMANUENSIS_PLURAL="amanuenses"
readonly BUBG_BATCH_AMANUENSIS_PLURAL_VERSAL="AMANUENSES"
readonly BUBG_BATCH_AMANUENSIS_PLURAL_LETTRINE="Amanuenses"
readonly BUBG_BATCH_AMANUENSIS_POSSESSIVE="amanuensis's"
readonly BUBG_BATCH_AMANUENSIS_POSSESSIVE_VERSAL="AMANUENSIS'S"
readonly BUBG_BATCH_AMANUENSIS_POSSESSIVE_LETTRINE="Amanuensis's"
readonly BUBG_DESUETUDE_BASE="desuetude"
readonly BUBG_DESUETUDE_BASE_VERSAL="DESUETUDE"
readonly BUBG_DESUETUDE_BASE_LETTRINE="Desuetude"
readonly BUBG_DESUETUDE_POSSESSIVE="desuetude's"
readonly BUBG_DESUETUDE_POSSESSIVE_VERSAL="DESUETUDE'S"
readonly BUBG_DESUETUDE_POSSESSIVE_LETTRINE="Desuetude's"
readonly BUBG_LAUNCHER_BASE="moorings launcher"
readonly BUBG_LAUNCHER_BASE_VERSAL="MOORINGS LAUNCHER"
readonly BUBG_LAUNCHER_BASE_LETTRINE="Moorings launcher"
readonly BUBG_LAUNCHER_PLURAL="moorings launchers"
readonly BUBG_LAUNCHER_PLURAL_VERSAL="MOORINGS LAUNCHERS"
readonly BUBG_LAUNCHER_PLURAL_LETTRINE="Moorings launchers"
readonly BUBG_LAUNCHER_POSSESSIVE="moorings launcher's"
readonly BUBG_LAUNCHER_POSSESSIVE_VERSAL="MOORINGS LAUNCHER'S"
readonly BUBG_LAUNCHER_POSSESSIVE_LETTRINE="Moorings launcher's"
readonly BUBG_CONFIG_RENDER_PEDIMENT="buw-rcr"
readonly BUBG_CONFIG_VALIDATE_PEDIMENT="buw-rcv"
readonly BUBG_ENVIRONMENT_RENDER_PEDIMENT="buw-rer"
readonly BUBG_ENVIRONMENT_VALIDATE_PEDIMENT="buw-rev"
readonly BUBG_HAYLOFT_SOCLE="station-hayloft-buk"
readonly BUBG_LOG_DIR_SOCLE="station-log-buk"
readonly BUBG_STATION_INIT_PEDIMENT="buw-SI"
readonly BUBG_STATION_RENDER_PEDIMENT="buw-rsr"
readonly BUBG_STATION_VALIDATE_PEDIMENT="buw-rsv"
readonly BUBG_TACKROOM_SOCLE="tackroom-buk"
readonly BUBG_EMPLACE_PEDIMENT="buw-pe"
readonly BUBG_BAND_CHAIN_PEDIMENT="buw-xb"
readonly BUBG_BATCH_AMANUENSIS_PEDIMENT="buw-tt-cbo"
readonly BUBG_BATCH_LOGGING_PEDIMENT="buw-tt-cbl"
readonly BUBG_BATCH_NOLOG_PEDIMENT="buw-tt-cbn"
readonly BUBG_DELAY_PEDIMENT="buw-xd"
readonly BUBG_INTERACTIVE_LOGGING_PEDIMENT="buw-tt-cil"
readonly BUBG_INTERACTIVE_NOLOG_PEDIMENT="buw-tt-cin"
readonly BUBG_LAUNCHER_STUB_PEDIMENT="buw-tt-cl"
readonly BUBG_LIST_LAUNCHERS_PEDIMENT="buw-tt-ll"
readonly BUBG_ROLL_CALL_PEDIMENT="buw-tt-rc"
readonly BUBG_DESUETUDE_DENTIL=119
readonly BUBG_BAILOUT_ANTA=101
readonly BUBG_BAND_FRIEZE_BASE=100
readonly BUBG_BAND_FRIEZE_WIDTH=24
readonly BUBG_BARRED_PSEPHOS=3
readonly BUBG_CLEAN_DENTIL=108
readonly BUBG_ECH_ANTA=101
readonly BUBG_ENROLL_DENTIL=101
readonly BUBG_FENCED_PSEPHOS=4
readonly BUBG_FLUNK_ANTA=100
readonly BUBG_MISFIRE_ANTA=125
readonly BUBG_OVERGROWN_ANTA=100
readonly BUBG_OVERTIME_ANTA=124
readonly BUBG_REGIME_DENTIL=100
readonly BUBG_SELFTEST_DENTIL=123
readonly BUBG_SYNCHRONY_DENTIL=117
readonly BUBG_WORKTREE_DENTIL=121
readonly BUBG_BUSPL_LAUNCHER_PROSOPON="Moorings-Launcher"
readonly BUBG_BUSPM_FORMULARY_PROSOPON="Formulary"
readonly BUBG_BUSPM_WORKBENCH_PROSOPON="Workbench"
readonly BUBG_BUSPM_TESTBENCH_PROSOPON="Testbench"
readonly BUBG_BUSPC_COLOPHON_PROSOPON="Colophon"
readonly BUBG_BUSPF_FRONTISPIECE_PROSOPON="Frontispiece"
readonly BUBG_BUSPI_IMPRINT_PROSOPON="Imprint"
readonly BUBG_BUKRO_KINDLE_PROSOPON="Kindle"
readonly BUBG_BUKRO_VALIDATE_PROSOPON="Validate"
readonly BUBG_BUKRO_RENDER_PROSOPON="Render"
readonly BUBG_BURC_REGIME_PROSOPON="BURC"
readonly BUBG_BURS_REGIME_PROSOPON="BURS"
readonly BUBG_BURD_REGIME_PROSOPON="BURD"
readonly BUBG_BURE_REGIME_PROSOPON="BURE"
readonly BUBG_BUS_CONFIG_REGIME_PROSOPON="Config-Regime"
readonly BUBG_BUS_ASSIGNMENT_PROSOPON="Assignment"
readonly BUBG_BUS_CATENA_PROSOPON="Catena"
readonly BUBG_BUS_LOOSEBOX_PROSOPON="Loosebox"
readonly BUBG_BUS_ENDONYM_PROSOPON="Endonym"

# eof
