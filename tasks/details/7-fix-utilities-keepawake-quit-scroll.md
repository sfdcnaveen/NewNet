# 7-fix-utilities-keepawake-quit-scroll

- Number: 7
- Slug: fix-utilities-keepawake-quit-scroll

## Notes

### 1. Keep Awake Lid-Closed Clamshell Mode (`KeepAwakeService.swift`)
- When `preventLidSleep` is enabled:
  - Establishes `kIOPMAssertionTypePreventUserIdleSystemSleep` and `kIOPMAssertionTypePreventUserIdleDisplaySleep` assertions.
  - Executes `/usr/bin/pmset -a disablesleep 1` (with passwordless `sudo -n` fallback matching standard clamshell sudoers rules).
  - Power management state reflects `SleepDisabled 1`.
- When Keep Awake is disabled, toggled OFF, or on application termination (`deinit` and `handleAppWillTerminate`):
  - Automatically and unconditionally executes `/usr/bin/pmset -a disablesleep 0` to restore standard macOS power management.
  - Releases all IOKit assertions (`IOPMAssertionRelease`).
  - Clears any orphaned kernel flag on app launch.

### 2. Real-Time Quit on Close (`QuitOnCloseService.swift`)
- Replaced polling/deactivation notifications with active `AXObserver` (`AXObserverCreate`) on regular GUI apps (`activationPolicy == .regular`).
- Listens for `kAXUIElementDestroyedNotification`, `kAXWindowCreatedNotification`, and `kAXMainWindowChangedNotification` on both the application element and standard windows.
- In `isStandardWindow`, strictly queries `kAXRoleAttribute == kAXWindowRole` and `kAXSubroleAttribute == kAXStandardWindowSubrole` (or `"AXFullScreenWindow"`).
- In real time (0ms immediate check + 50ms verification), terminates the app via `app.terminate()` when its standard window count drops to 0.
- Rigorous exclusions: Finder (`com.apple.finder`), web browsers (Safari, Chrome, Firefox, Arc, Edge, Brave, etc.), user exceptions, and NewNet itself.

### 3. Apple HIG Controls & UI Polish (`UtilitiesDashboardView.swift` & `SettingsView.swift`)
- **Inverse Mouse Scrolling**: Completely removed Vertical and Horizontal sub-checkboxes. Features a single, clean `.toggleStyle(.switch)`.
- **Keep Awake Clamshell UX**: Added a dedicated row for **"Keep awake when lid is closed"** with subtitle `"Prevents Mac sleep or lock when the display lid is shut"` and standard `.toggleStyle(.switch)`.
- Fully conforms to Apple HIG design principles, SF Pro semantic weights, and Liquid Glass materials.

### 4. Build & Test Verification
- `make diagnose`: Passed
- `make build`: Succeeded with 0 warnings
- `make test`: 37/37 unit tests passed with 0 failures
- Local behavior test verified: `pmset -g | grep SleepDisabled` correctly transitions between `1` and `0`.
