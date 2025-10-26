# PaneBoard Refactoring Roadmap

**Generated:** 2025-10-26
**Purpose:** Document Rust best practices and architectural improvements identified during code review

---

## Priority 1: Eliminate Lazy Static for Single-Threaded State ⭐⭐⭐⭐⭐

**Impact:** High | **Difficulty:** Medium | **Type:** Architecture

### The Problem

Currently using global `lazy_static!` + `Mutex` for state that's only accessed from a single thread (CGEventTap callback):

```rust
// Current: pbmsa_alttab.rs:20
lazy_static! {
    pub static ref ALT_TAB_SESSION: Arc<Mutex<AltTabSession>> = ...;
}

// Usage has hidden dependencies and runtime overhead
let mut session = ALT_TAB_SESSION.lock().unwrap();
```

**Issues:**
- Runtime locking overhead for single-threaded data
- Hidden dependencies (functions don't declare what state they need)
- Difficult to test (global state)
- Loses Rust's compile-time borrow checking

### The Solution

Pass state through FFI context pointers, achieving compile-time safety:

```rust
// New context structure
struct AppContext {
    // Single-threaded state (no locks needed!)
    alt_tab_session: AltTabSession,
    clipboard_session: ClipboardSession,
    form: Form,

    // Multi-threaded state (keep locks only here)
    mru_stack: Arc<Mutex<Vec<MruWindowEntry>>>,
    active_observers: Arc<Mutex<HashMap<u32, SendObserver>>>,
}

// Modified callback uses context pointer
extern "C" fn tap_cb(
    _proxy: *mut c_void,
    event_type: u32,
    event: *mut c_void,
    user_data: *mut c_void  // ← Pass state here
) -> *mut c_void {
    unsafe {
        let ctx = &mut *(user_data as *mut AppContext);

        // Compile-time borrow checking! No mutex!
        ctx.alt_tab_session.active = true;

        // Only lock for truly shared data
        let mru = ctx.mru_stack.lock().unwrap();
    }
}

// In main:
pub unsafe fn run_quadrant_poc() -> ! {
    let ctx = Box::new(AppContext {
        alt_tab_session: AltTabSession::default(),
        clipboard_session: ClipboardSession::default(),
        form: Form::load_from_file(&displays),
        mru_stack: Arc::new(Mutex::new(Vec::new())),
        active_observers: Arc::new(Mutex::new(HashMap::new())),
    });

    let ctx_ptr = Box::into_raw(ctx);

    let tap = CGEventTapCreate(
        K_CG_SESSION_EVENT_TAP,
        K_CG_HEAD_INSERT_EVENT_TAP,
        K_CG_EVENT_TAP_OPTION_DEFAULT,
        CG_EVENT_MASK_ALL,
        tap_cb,
        ctx_ptr as *mut c_void,  // ← Pass context
    );

    CFRunLoopRun();
}
```

### Benefits

- ✅ Zero runtime locking overhead for single-threaded state
- ✅ Compile-time borrow checking (Rust's core value proposition)
- ✅ Explicit dependencies in function signatures
- ✅ Easily testable without globals
- ✅ Clear separation: single-threaded vs multi-threaded state

### Files to Refactor

| File | Global to Eliminate | Single-threaded? | Action |
|------|---------------------|------------------|--------|
| `pbmsa_alttab.rs:20` | `ALT_TAB_SESSION` | ✅ Yes | Move to `AppContext` |
| `pbmcl_clipboard.rs:9` | `CLIPBOARD_HISTORY` | ✅ Yes | Move to `AppContext` |
| `pbmcl_clipboard.rs:11` | `CLIPBOARD_SESSION` | ✅ Yes | Move to `AppContext` |
| `pbmp_pane.rs:48` | `FORM` | ✅ Yes (read-mostly) | Move to `AppContext` |
| `pbmsm_mru.rs:32` | `MRU_STACK` | ❌ No (AXObservers!) | **Keep Mutex** |
| `pbmbo_observer.rs:45` | `ACTIVE_OBSERVERS` | ❌ No (Swift + AX) | **Keep Mutex** |

### Sources

- **Rust API Guidelines:** https://rust-lang.github.io/api-guidelines/
- **Rust Design Patterns (Interior Mutability):** https://rust-unofficial.github.io/patterns/patterns/behavioural/strategy.html

---

## Priority 2: Document All `unsafe` Blocks with SAFETY Comments ⭐⭐⭐⭐⭐

**Impact:** High | **Difficulty:** Easy | **Type:** Documentation

### The Problem

**90 unsafe blocks** across 10 files with minimal documentation of safety invariants.

```rust
// Current: pbmp_pane.rs:68
unsafe fn visible_frame_with_quirks_for_index(...) -> Option<VisibleFrame> {
    if let Some(display_info) = ADJUSTED_DISPLAYS.get(display_index) {
        return display_info.live_viewport(screen);
    }
    visible_frame_for_screen(screen)
}
```

### The Solution

Every `unsafe` block must have a `SAFETY:` comment explaining invariants:

```rust
/// Get visible frame with display quirks applied
///
/// # Safety
/// This function is unsafe because it calls FFI functions that interact with
/// macOS NSScreen objects. Caller must ensure:
/// - `screen` is a valid NSScreen pointer from objc2_app_kit
/// - `display_index` is within bounds (enforced by Vec::get)
/// - `ADJUSTED_DISPLAYS` is initialized (guaranteed by lazy_static at startup)
unsafe fn visible_frame_with_quirks_for_index(
    screen: &objc2_app_kit::NSScreen,
    display_index: usize
) -> Option<VisibleFrame> {
    // SAFETY: Vec::get provides bounds checking, returns None if out of range
    if let Some(display_info) = ADJUSTED_DISPLAYS.get(display_index) {
        // SAFETY: screen is a valid NSScreen reference from caller
        return display_info.live_viewport(screen);
    }
    // SAFETY: screen is a valid NSScreen reference from caller
    visible_frame_for_screen(screen)
}
```

### Template

```rust
// For unsafe functions:
/// # Safety
/// This function is unsafe because [reason].
/// Caller must ensure:
/// - [invariant 1]
/// - [invariant 2]
unsafe fn foo() { ... }

// For unsafe blocks:
unsafe {
    // SAFETY: [why this specific operation is safe]
    do_unsafe_thing();
}
```

### Files Affected

All files with `unsafe` (90 occurrences):
- `pbmp_pane.rs` (17 instances)
- `pbmbo_observer.rs` (10 instances)
- `pbmba_ax.rs` (23 instances)
- `pbmbe_eventtap.rs` (4 instances)
- `pbmsa_alttab.rs` (6 instances)
- `pbmcl_clipboard.rs` (6 instances)
- `pbmbd_display.rs` (18 instances)
- `pbmsm_mru.rs` (4 instances)
- `main.rs` (1 instance)

### Sources

- **Official Rust Unsafe Guidelines:** https://doc.rust-lang.org/book/ch20-01-unsafe-rust.html
- **Rust Unsafe Code Guidelines (WG):** https://rust-lang.github.io/unsafe-code-guidelines/
- **PingCAP Style Guide (Unsafe):** https://pingcap.github.io/style-guide/rust/unsafe.html
- **Comprehensive Understanding of Unsafe Rust:** https://rustmagazine.org/issue-3/understand-unsafe-rust/

**Key principle from sources:**
> "Each usage of unsafe must be accompanied by a clear, concise comment explaining what assumptions are being made."

---

## Priority 3: Replace `.unwrap()` on Mutex Locks with Proper Error Handling ⭐⭐⭐⭐

**Impact:** High | **Difficulty:** Easy | **Type:** Robustness

### The Problem

**58 `.unwrap()` calls** across 10 files, many on Mutex locks which will panic if poisoned:

```rust
// Current: pbmp_pane.rs:60, 103, 112, etc.
let form = FORM.lock().unwrap();  // Panics if mutex poisoned!
```

### The Solution

**Option A: Use `.expect()` with descriptive messages**
```rust
let form = FORM.lock().expect("FORM mutex poisoned - this is a bug");
```

**Option B: Recover from poisoned mutex (best for production)**
```rust
let form = match FORM.lock() {
    Ok(guard) => guard,
    Err(poisoned) => {
        eprintln!("WARNING: FORM mutex poisoned, recovering data");
        poisoned.into_inner()  // Recover the data despite poison
    }
};
```

**Option C: Propagate errors with `?` operator**
```rust
fn reload_config() -> Result<(), String> {
    let mut form = FORM.lock()
        .map_err(|e| format!("Failed to lock FORM: {:?}", e))?;
    form.reload()?;
    Ok(())
}
```

### Files Affected

High-impact locations (mutex locks):
- `pbmp_pane.rs:60, 103, 112, 165, 717, 831` (6 instances)
- `pbmbo_observer.rs:70, 86, 139, 145, 156, 177, 195, 236, 306` (9 instances)
- `pbmsa_alttab.rs` (2 instances)
- `pbmcl_clipboard.rs` (7 instances)

Total: **58 unwraps** across all files

### Sources

- **Error Handling Best Practices:** https://medium.com/@Murtza/error-handling-best-practices-in-rust-a-comprehensive-guide-to-building-resilient-applications-46bdf6fa6d9d
- **Rust By Example (Error Handling):** https://doc.rust-lang.org/rust-by-example/error.html
- **Result Type Guide:** https://leapcell.medium.com/rusts-result-type-error-handling-made-easy-3e7a3b038214

**Key principle from sources:**
> "Good programs don't panic, so it's very rare that using unwrap or expect is actually the right thing to do - usually, we should either use match and handle the None case explicitly, or propagate the Option using ?."

---

## Priority 4: Replace `lazy_static` with `std::sync::LazyLock` ⭐⭐⭐

**Impact:** Low | **Difficulty:** Easy | **Type:** Modernization

### The Problem

Using external `lazy_static` crate when Rust 1.80+ provides `LazyLock` in stdlib:

```rust
// Current: pbmp_pane.rs:48
lazy_static! {
    static ref FORM: Mutex<Form> = {
        unsafe { /* ... */ }
    };
}
```

**Note:** This is lower priority than Priority 1 (eliminating the global entirely).

### The Solution

```rust
use std::sync::LazyLock;

static FORM: LazyLock<Mutex<Form>> = LazyLock::new(|| {
    unsafe {
        let displays = gather_all_display_info();
        Mutex::new(Form::load_from_file(&displays))
    }
});
```

### Benefits

- ✅ Zero external dependencies (remove `lazy_static = "1.4"` from Cargo.toml)
- ✅ Slightly faster build times
- ✅ Modern idiomatic Rust (stdlib since 1.80)
- ✅ Same functionality, cleaner syntax

### Files Affected

All 6 lazy_static usages:
- `pbmp_pane.rs:48` (2 statics: `FORM`, `ADJUSTED_DISPLAYS`)
- `pbmsm_mru.rs:32` (`MRU_STACK`)
- `pbmbo_observer.rs:45` (2 statics: `ACTIVE_OBSERVERS`, `PID_TO_BUNDLE`)
- `pbmsa_alttab.rs:20` (`ALT_TAB_SESSION`)
- `pbmcl_clipboard.rs:9` (2 statics: `CLIPBOARD_HISTORY`, `CLIPBOARD_SESSION`)

After completing this, remove from `Cargo.toml:10`:
```toml
lazy_static = "1.4"  # ← DELETE THIS LINE
```

### Sources

- **Rust 1.80 Release Notes:** https://blog.rust-lang.org/2024/07/25/Rust-1.80.0.html
- **std::sync::LazyLock docs:** https://doc.rust-lang.org/std/sync/struct.LazyLock.html

---

## Priority 5: Create Safe Wrapper Functions for Repetitive `unsafe` FFI ⭐⭐⭐⭐

**Impact:** Medium | **Difficulty:** Medium | **Type:** API Design

### The Problem

Repetitive unsafe FFI patterns scattered throughout codebase:

```rust
// Pattern repeated many times:
unsafe {
    let mut value_ref: CFTypeRef = std::ptr::null();
    let result = AXUIElementCopyAttributeValue(element, attr, &mut value_ref);
    if result == KAX_ERROR_SUCCESS && !value_ref.is_null() {
        // ... use value_ref
        CFRelease(value_ref);
    }
}
```

### The Solution

Encapsulate unsafe FFI in safe abstractions:

```rust
// In pbmba_ax.rs - expand AxElement with safe methods
impl AxElement {
    /// Get an AX attribute value
    ///
    /// # Safety
    /// Caller must ensure self.0 is a valid AXUIElementRef
    ///
    /// # Errors
    /// Returns `AxError::Permission` if accessibility not granted
    /// Returns `AxError::Platform(code)` for other AX errors
    pub unsafe fn get_attribute(&self, attr: &str) -> Result<CFTypeRef, AxError> {
        let attr_cf = CFString::new(attr);
        let mut value_ref: CFTypeRef = std::ptr::null();

        let result = AXUIElementCopyAttributeValue(
            self.0,
            attr_cf.as_concrete_TypeRef(),
            &mut value_ref
        );

        match result {
            KAX_ERROR_SUCCESS if !value_ref.is_null() => Ok(value_ref),
            KAX_ERROR_PERMISSION_DENIED => Err(AxError::Permission),
            KAX_ERROR_CANNOT_COMPLETE => Err(AxError::Constrained),
            code => Err(AxError::Platform(code)),
        }
    }

    /// Get a string attribute
    pub unsafe fn get_string_attribute(&self, attr: &str) -> Result<String, AxError> {
        let value_ref = self.get_attribute(attr)?;
        let cf_string = CFString::wrap_under_get_rule(value_ref as _);
        Ok(cf_string.to_string())
    }

    /// Get window list
    pub unsafe fn get_windows(&self) -> Result<Vec<AxElement>, AxError> {
        let windows_ref = self.get_attribute("AXWindows")?;
        let count = CFArrayGetCount(windows_ref);

        let mut windows = Vec::new();
        for i in 0..count {
            let window_ref = CFArrayGetValueAtIndex(windows_ref, i) as AXUIElementRef;
            windows.push(AxElement(window_ref));
        }

        CFRelease(windows_ref);
        Ok(windows)
    }
}

// Usage becomes clean and type-safe:
unsafe {
    let app = AxElement::from_pid(pid)?;
    let windows = app.get_windows()?;

    for window in windows {
        let title = window.get_string_attribute("AXTitle")?;
        println!("Window: {}", title);
    }
}
```

### Benefits

- ✅ DRY (Don't Repeat Yourself)
- ✅ Single location for unsafe FFI patterns
- ✅ Type-safe Result handling
- ✅ Easier to review and audit unsafe code
- ✅ Centralized CFRelease management (prevents leaks)

### Files to Refactor

Locations with repetitive AX patterns:
- `pbmp_pane.rs` (window enumeration, attribute getting)
- `pbmsm_mru.rs` (window ID extraction)
- `pbmbo_observer.rs` (observer setup patterns)

### Sources

- **Rust Design Patterns (Newtype):** https://rust-unofficial.github.io/patterns/patterns/behavioural/newtype.html
- **API Guidelines (Wrapper Types):** https://rust-lang.github.io/api-guidelines/interoperability.html

---

## Priority 6: Add Integration Tests ⭐⭐⭐

**Impact:** Medium | **Difficulty:** Medium | **Type:** Testing

### The Problem

No visible test files in `poc/src/`. Complex tiling and MRU logic is untested.

### The Solution

Create `poc/tests/` directory with integration tests:

**File: `poc/tests/mru_tests.rs`**
```rust
use paneboard_poc::pbmsm_mru::{MruWindowEntry, ActivationState};

#[test]
fn test_mru_ordering() {
    let mut stack = Vec::new();

    let entry1 = MruWindowEntry {
        window_id: 1,
        pid: 100,
        bundle_id: "com.app1".to_string(),
        title: "Window 1".to_string(),
        activation_state: ActivationState::Known,
    };

    let entry2 = MruWindowEntry {
        window_id: 2,
        pid: 200,
        bundle_id: "com.app2".to_string(),
        title: "Window 2".to_string(),
        activation_state: ActivationState::Known,
    };

    stack.push(entry1.clone());
    stack.push(entry2.clone());

    // Most recent should be at front
    assert_eq!(stack[0].window_id, 1);
    assert_eq!(stack[1].window_id, 2);
}

#[test]
fn test_mru_deduplication() {
    // Test that same window doesn't appear twice
    // (requires extracting MRU logic into testable functions)
}
```

**File: `poc/tests/layout_tests.rs`**
```rust
// Test quadrant calculations, frame positioning, etc.
// Requires refactoring to separate pure functions from FFI
```

### Sources

- **Rust Testing Guide:** https://doc.rust-lang.org/book/ch11-00-testing.html
- **Integration Testing:** https://doc.rust-lang.org/book/ch11-03-test-organization.html

---

## Additional Improvements (Lower Priority)

### 7. Use `thiserror` for Custom Error Types

Instead of `String` errors, define proper error enums:

```rust
use thiserror::Error;

#[derive(Error, Debug)]
pub enum PaneBoardError {
    #[error("Accessibility permission denied")]
    AccessibilityDenied,

    #[error("Window not found: {0}")]
    WindowNotFound(u32),

    #[error("AX error: {0}")]
    AxError(#[from] AxError),

    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),
}
```

**Source:** https://docs.rs/thiserror/latest/thiserror/

### 8. Run `cargo clippy` and Address Warnings

```bash
cargo clippy -- -W clippy::all -W clippy::pedantic
```

**Source:** https://github.com/rust-lang/rust-clippy

### 9. Run `miri` to Detect Undefined Behavior

```bash
cargo +nightly miri test
```

**Source:** https://github.com/rust-lang/miri

---

## Summary Table

| Priority | Refactor | Impact | Difficulty | Files Affected |
|----------|----------|--------|------------|----------------|
| 1 | Pass state through FFI context | ⭐⭐⭐⭐⭐ High | 🟡 Medium | 6 files |
| 2 | Document unsafe blocks | ⭐⭐⭐⭐⭐ High | 🟢 Easy | 10 files (90 blocks) |
| 3 | Replace .unwrap() on locks | ⭐⭐⭐⭐ High | 🟢 Easy | 10 files (58 calls) |
| 4 | Migrate to LazyLock | ⭐⭐⭐ Low | 🟢 Easy | 5 files (6 statics) |
| 5 | Safe FFI wrapper functions | ⭐⭐⭐⭐ Medium | 🟡 Medium | 3 files |
| 6 | Add integration tests | ⭐⭐⭐ Medium | 🟡 Medium | New files |

---

## References

### Official Rust Documentation
- **The Rust Book (Unsafe):** https://doc.rust-lang.org/book/ch20-01-unsafe-rust.html
- **Rust By Example (Error Handling):** https://doc.rust-lang.org/rust-by-example/error.html
- **std::sync::LazyLock:** https://doc.rust-lang.org/std/sync/struct.LazyLock.html

### Community Resources
- **Rust Design Patterns:** https://rust-unofficial.github.io/patterns/
- **Idiomatic Rust Collection:** https://github.com/mre/idiomatic-rust
- **Rust API Guidelines:** https://rust-lang.github.io/api-guidelines/

### Unsafe Code Guidelines
- **Official Unsafe Code Guidelines:** https://rust-lang.github.io/unsafe-code-guidelines/
- **PingCAP Unsafe Style Guide:** https://pingcap.github.io/style-guide/rust/unsafe.html
- **Understanding Unsafe Rust:** https://rustmagazine.org/issue-3/understand-unsafe-rust/

### Error Handling
- **Error Handling Best Practices:** https://medium.com/@Murtza/error-handling-best-practices-in-rust-a-comprehensive-guide-to-building-resilient-applications-46bdf6fa6d9d
- **Result and Option Guide:** https://bitfieldconsulting.com/posts/rust-errors-option-result

### Tools
- **Clippy (Linter):** https://github.com/rust-lang/rust-clippy
- **Miri (UB Detector):** https://github.com/rust-lang/miri
- **thiserror (Error Derive):** https://docs.rs/thiserror/latest/thiserror/

---

## Notes

- All recommendations are based on **Rust 1.90** (your current version)
- Priority 1 should be done **before** Priority 4 (no point modernizing globals you're eliminating)
- Priority 2 and 3 can be done incrementally file-by-file
- This is a PoC - balance learning value vs time investment

**Last Updated:** 2025-10-26
