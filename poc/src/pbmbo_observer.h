// SPDX-License-Identifier: Apache-2.0
// Copyright 2025 Scale Invariant

#ifndef PBMSO_OBSERVER_H
#define PBMSO_OBSERVER_H

#include <stdint.h>
#include <stdbool.h>

// Callback type: invoked when app activation changes
// pid: process ID of activated app
// bundle: UTF-8 null-terminated bundle identifier (e.g., "com.apple.Safari")
// name: UTF-8 null-terminated localized name (e.g., "Safari")
typedef void (*activation_callback_t)(int32_t pid, const char* bundle, const char* name);

// Callback type: invoked when app terminates
// pid: process ID of terminated app
typedef void (*termination_callback_t)(int32_t pid);

// Callback type: invoked during prepopulation for each running app
// pid: process ID
// bundle: UTF-8 null-terminated bundle identifier
// name: UTF-8 null-terminated localized name
// is_known: true if this is the frontmost app (KNOWN), false for others (GUESS)
typedef void (*prepopulation_callback_t)(int32_t pid, const char* bundle, const char* name, bool is_known);

// Register the focus observer
// Starts listening to NSWorkspace app activation and termination notifications
// Calls the provided callbacks on each event
void pbmso_register_observer(activation_callback_t activation_callback, termination_callback_t termination_callback);

// Prepopulate MRU with currently running apps
// Scans NSWorkspace.runningApplications and calls callback for each .regular app
// Frontmost app is marked as KNOWN, others as GUESS
void pbmso_prepopulate_mru(prepopulation_callback_t callback);

#endif // PBMSO_OBSERVER_H
