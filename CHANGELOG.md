# mJig Changelog

All notable changes to `start-mjig.ps1` are documented in this file.

---

## [Latest] - Unreleased

Changes since last commit (b18bdce - "Naming overhaul, Windows Terminal restore fix, cursor rules, notification cleanup"):

### Added
- **Stats box content** — the previously empty middle rows of the stats panel (full view) now display five sections with graceful degradation: Session (running time, start time, moves/skipped/%, streak), Movement (last move dist/duration/elapsed, total/avg, range), Interruptions & Timing (KB/mouse interrupts, clean-streak best, actual vs. set interval, animation duration Avg/Min/Max), Direction Totals (px per N/NE/E/SE/S/SW/W/NW), and Settings Snapshot. On tall enough terminals a sixth section shows the Last Movement Curve — a rotated 2D ASCII path diagram inside an inner bordered box with two-row mathematical equations (`ease(t)` and `L(t)`).
- **`$script:Stats*` tracking variables** — 20 new script-scoped counters initialized in `Start-mJig.psm1` and tracked in both inline and worker modes: `StatsMoveCount`, `StatsSkipCount`, `StatsCurrentStreak`, `StatsLongestStreak`, `StatsTotalDistancePx`, `StatsLastMoveDist`, `StatsMinMoveDist`, `StatsMaxMoveDist`, `StatsKbInterruptCount`, `StatsMsInterruptCount`, `StatsLongestCleanStreak`, `StatsCleanStreak`, `StatsAvgActualIntervalSecs`, `StatsLastMoveTick`, `StatsAvgDurationMs`, `StatsMinDurationMs`, `StatsMaxDurationMs`, `StatsDirectionCounts`, `StatsLastCurveParams`. Synced to the viewer via 22 new fields in the IPC `state` message (including `statsWorkerStartTime` which corrects `$ScriptStartTime` in viewer mode to reflect the worker's actual start time).
- **`$script:StatsScrollInterruptCount` / `$script:StatsClickInterruptCount`** — separate counters for scroll-wheel and mouse-click interrupts (tracked via `PeekConsoleInput` in inline/viewer mode; always 0 in worker mode). Sent in IPC state messages as `statsScrollInterruptCount` / `statsClickInterruptCount`.
- **Curve params in `Get-SmoothMovementPath` return** — the function now returns `Distance`, `StartArcAmt`, `StartArcSign`, `BodyCurveAmt`, `BodyCurveSign`, `BodyCurveType` alongside `Points` and `TotalTimeMs`. These are captured into `$script:StatsLastCurveParams` after each move and sent to the viewer via IPC, enabling the curve diagram to be reconstructed from parameters at render time.
- **Viewer visual state persistence** — when a viewer disconnects and a new one connects, the worker restores output mode (full/min/incognito), the incognito previous-view (so exiting incognito returns to the correct mode), title preset (index, emoji, window title string), manual pause state, whether the Settings panel was open, and which sub-dialog was active inside Settings (End Time / Mouse Movement / Options). Visual state is carried as a `visualState` field in the `welcome` IPC message; applied immediately after `Connect-WorkerPipe` returns, before the first render.
- **`viewerState` IPC message** (viewer → worker): `{ type='viewerState'; activeDialog=$string|$null; activeSubDialog=$string|$null }` — `activeDialog` is `'settings'|'quit'|'info'|$null`. Sent before/after every dialog opens/closes. The `activeSubDialog` field tracks which sub-dialog is currently open inside Settings. Settings close sync sends `output(activeDialog=$null)`, clearing the field.
- **`$_viewerVisualState` worker variable** — hashtable maintained by `Start-WorkerLoop` tracking the last-known viewer visual state including `activeDialog` and `activeSubDialog` fields. Initialized from `$script:` defaults; updated on every `output`, `title`, and `viewerState` message; included in every `welcome` message.
- **`-RestoreSubDialog` and `-ViewerPipeWriter` parameters on `Show-SettingsDialog`** — when `-RestoreSubDialog 'time'|'movement'|'options'` is set, the dialog auto-triggers the sub-dialog after initial render. `-ViewerPipeWriter` carries the pipe stream so Settings can send `viewerState` updates internally.
- **`$script:_PendingReopenQuit`** — viewer-side bool; set when `VisualState.activeDialog = 'quit'` on reconnect; handled in the `$forceRedraw` block to restore the Quit confirmation dialog.
- **`$script:_PendingReopenInfo`** — viewer-side bool; set when `VisualState.activeDialog = 'info'` on reconnect; handled in the `$forceRedraw` block to restore the Info/About dialog.
- **`$script:_PendingRestoreSubDialog`** — viewer-side variable set from `$pipeResult.VisualState.activeSubDialog` on reconnect; consumed by the `PendingReopenSettings` reopen path and cleared immediately after, so the sub-dialog restore fires exactly once.
- **Apply/Cancel buttons on `Show-OptionsDialog`** — replaces the previous "Close" button. Apply (hotkey `a`, Enter) keeps all changes made during the session. Cancel (hotkey `c`, Escape, click outside) reverts all changes (`$script:Output`, `$script:DebugMode`, `$script:NotificationsEnabled`, `$script:TitlePresetIndex`/`$script:WindowTitle`/`$script:TitleEmoji`) to values captured at dialog open. Cancel also calls `Set-ThemeProfile` if the debug theme was toggled. Return type updated to `@{ NeedsRedraw; TitleChanged }`.
- **Apply/Cancel buttons on `Show-ThemeDialog`** — the dialog now has height 9 (was 7) with a blank row and Apply/Cancel row appended below the existing Next-theme button. Apply (hotkey `a`, Enter) keeps the current theme. Cancel (hotkey `c`, Escape, click outside) reverts to the theme active when the dialog opened via `Set-ThemeProfile -Name $initialThemeName`.

### Changed
- **Dialog button hotkey letters** — all dialog button hotkey letters changed from `"Yellow"` to `"Green"` in the default and base theme configurations. Exception: debug theme retains `"Yellow"` for `MoveDialogButtonHotkey` (DarkGreen background) and `"White"` for `QuitDialogButtonHotkey` (Magenta background).
- **Dialog button backgrounds** — `SettingsDialogButtonBg`, `TimeDialogButtonBg`, `MoveDialogButtonBg`, `InfoDialogButtonBg`, and `ThemeDialogButtonBg` changed from `"Blue"` to `"DarkCyan"` in the default theme.
- **Stats section order** — "Travel Distance" moved before "Performance" in the stats box graceful-degradation priority order (was: Session, Movement, Performance, Travel; now: Session, Movement, Travel, Performance).
- **Stats interrupts row** — removed "Clean best" from the Interrupts row; replaced with separate "Click" and "Scroll" counts. New format: `KB N  Mouse N  Click N  Scroll N`.
- **Stats travel distance** — "Total:" value moved from its own row to the end of the directional distance row (`→ Npx  ← Npx  ↑ Npx  ↓ Npx  Total: Npx`), reducing the Travel section from 4 to 3 rows.
- **Stats section and box titles** — all section titles now include a trailing colon (`Session:`, `Movement:`, `Travel Distance:`, `Performance:`, `Settings:`). The outer stats box header now reads `Stats:`.
- **"Last Movement's Curve" title alignment** — shifted one character right for better visual centering above the inner curve diagram box.
- **Default interval** — `$IntervalSeconds` default changed from `10` to `5`.
- **Default travel distance and variance** — `$TravelDistance` default changed from `100` to `400`; `$TravelVariance` default changed from `5` to `365`.
- **`LastMovementTime` update timing** — `$LastMovementTime` is now only set inside the `if ($PosUpdate)` block (successful move), not on skip paths. This ensures the "Last Move elapsed time" counter in the stats display reflects actual successful moves only.
- **Skip stats guard** — skip-event stat increments are now guarded by `if (-not $isFirstRun -and -not $script:ManualPause)` to prevent false skip counts during manual pause.
- **`output` IPC message** now carries `previousView` (the mode to restore when exiting incognito, or `$null`) and `settingsOpen` (`$false` on all normal output-toggle sends).
- **`title` IPC message** now carries `titlePresetIndex` so the worker can restore the correct preset index to a new viewer.
- **Tier 1 notification crash guard** — `$script:_Tier1NotifyFailed` flag is set immediately before `ShowToast` and cleared on success. If an uncatchable COM exception (e.g. `AccessViolationException` from a vtable mismatch) escapes all inner catch blocks, the flag remains set and all subsequent calls skip Tier 1 for the session, preventing repeated crashes and falling through to Tier 2.
- **Tier 2 notification timing fix** — removed the `finally { Remove-Item $regKey }` from the PS51 subprocess path. The AUMID registry key is now left alive until `Remove-Notification` sweeps it at worker exit. This fixes a race where the key was deleted at the 500ms mark while PS51 (which takes 800–1500ms to start on Windows 11) had not yet read it, causing silent notification failure. `Start-Sleep -Milliseconds 500` also removed from Tier 2 — the worker loop is no longer blocked while waiting for PS51.

---

## [b18bdce] - 2026-03-15

### Changed
- **Terminology & naming standards overhaul** — Comprehensive rename of functions, variables, parameters, log messages, notification bodies, and code comments to align with PowerShell approved verbs, PascalCase, and application-facing terminology. Functions renamed: `Draw-MainFrame` → `Write-MainFrame`, `Draw-DialogShadow` → `Write-DialogShadow`, `Draw-ResizeLogo` → `Write-ResizeLogo`, `Write-ButtonImmediate` → `Write-MenuButton`, `Get-ValueWithVariance` → `Get-VariedValue`, `Send-ResizeExitWakeKey` → `Send-ConsoleWakeKey`, `Invoke-DialogExitCleanup` → `Invoke-DialogCleanup`, `Invoke-PostDialogCleanup` → `Reset-PostDialogState`. All parameters normalized to PascalCase; cryptic abbreviations replaced; notification bodies purged of architecture terms; log messages and UI labels normalized throughout.
- **Nine `.cursor/rules/*.mdc` files added** — codify all naming, rendering, IPC, dialog, P/Invoke, theme, resize, and project conventions for AI agent context loading.
- **`AGENTS.md` promoted to project root** — moved from `resources/AGENTS.md` to `AGENTS.md` at the project root as the authoritative AI context document.
- **Toast notification format simplified** — redundant title line removed; `-Title` parameter dropped from `Show-Notification`; body text is now action only. `Dispose-Notification` renamed to `Remove-Notification`.
- **Debug-mode exit pause** — provisioner `finally` block shows a `Press any key to exit...` prompt (yellow) in `-DebugMode` before clearing the console.
- **Bug fixes** — `Add-DebugLogEntry` call site corrected; `$tomorrow` typo fixed; unused `$currentTime` removed from `Start-WorkerLoop.ps1`.

### Fixed
- **Windows Terminal minimize/restore** — `focus` IPC handler now correctly finds and restores minimized Windows Terminal windows. Root cause: `GetAncestor(..., GA_ROOT=2)` only traverses the parent chain; Windows Terminal sets the ConPTY pseudo-window as an *owned* window (not a child), so `GA_ROOT` returned the hidden pseudo-window rather than the real WT main window. Changed to `GetAncestor(..., GA_ROOTOWNER=3)` to traverse the owner chain. Additional fixes: `GetWindow` + `AllowSetForegroundWindow` P/Invoke added; worker calls `AllowSetForegroundWindow(viewerPid)` before sending `focus`; `PostMessage WM_SYSCOMMAND/SC_RESTORE` fallback for cross-process WinUI windows; `FindMainWindowByProcessId` now filters owned popup HWNDs via `GW_OWNER` check. Resolved handle cached in `$script:_ViewerTerminalHwnd`.

---

## [8b03d07] - 2026-03-15

### Added
- **Instant terminal close (`_mJigCloseHandlerX`)** — Module Runspace Provisioner now registers a native `SetConsoleCtrlHandler` C# callback (`_mJigCloseHandlerX`) before `BeginInvoke()`. When the terminal X button is clicked (CTRL_CLOSE_EVENT = 2) or the session logs off/shuts down (types 5/6), the callback calls `TerminateProcess(GetCurrentProcess(), 0)` — a kernel-level instant kill with no .NET shutdown sequence, no finalizers, no ProcessExit handlers. Eliminates the previous 1–5 second hang caused by `Environment.Exit(0)` running finalizers, or the synchronous `$_ps.Invoke()` blocking inside a .NET method until PowerShell's 5-second CTRL_CLOSE grace period expired.
- **Fast viewer disconnect detection** — Worker stores `$_viewerProcess = Get-Process -Id $_clientPid` on viewer connect and checks `$_viewerProcess.HasExited` at the top of each 50ms tick. Detects viewer process death immediately (within one tick) instead of waiting for the named pipe to report `IsConnected = $false`, which could lag several seconds.
- **Viewer PID in auth handshake** — Viewer now includes its own `$PID` as `viewerPid` in the auth message sent to the worker (`Connect-WorkerPipe.ps1`). Worker uses this as the primary PID source for `$_clientPid`; `GetNamedPipeClientProcessId` P/Invoke is now a fallback used only when `viewerPid` is absent from the auth message.
- **Diagnostic file wipe on startup** — When `-Diag` is set, all existing `*.txt` files in `_diag/` are deleted at the very start of initialization before any new diagnostic files are created. Each run starts with a clean slate.

### Changed
- **Provisioner: `Invoke()` → `BeginInvoke()` + poll loop** — Replaced the synchronous `$_ps.Invoke()` call with `$_ps.BeginInvoke()` + a 50ms `Start-Sleep` polling loop. The outer thread now stays in interruptible PowerShell sleeps instead of blocking inside a .NET method, allowing `TerminateProcess` (called from the `_mJigCloseHandlerX` OS callback thread) to terminate the process instantly.
- **Viewer terminal detection allowlist** — `Start-WorkerLoop.ps1` process-tree traversal now uses an explicit allowlist (`$_terminalAllowList`: `windowsterminal`, `alacritty`, `wezterm`, `conemu`, `cmder`, `mintty`, etc.) when identifying the viewer's host terminal to spawn a new viewer into. If traversal reaches a process not in either the skip list or the allowlist, it stops and falls back to launching `pwsh.exe` directly. Prevents incorrect terminal identification (e.g. File Explorer opening) when the viewer was launched from an unusual parent process such as an elevated `pwsh.exe`.

### Fixed
- **Ctrl+C returns to shell prompt and disconnects worker** — Wrapped the `:process` main loop and its cleanup section in `try/finally`. On Ctrl+C, `PipelineStoppedException` previously bypassed the `break process` cleanup path entirely, leaving the pipe client handle open so the worker never detected a disconnect and the process exited with code 1 instead of returning to the prompt. The `finally` block now always disposes the viewer pipe and releases the mutex regardless of how the loop exits. `Show-DiagnosticFiles` remains in the normal-exit path only (not called on Ctrl+C).
- **`PSInvalidOperationException` on every other Ctrl+C** — Added `$_ps.EndInvoke($_asyncResult)` in the provisioner `finally` block, called after `$_ps.Stop()`. `Stop()` signals the pipeline to stop and waits for `PipelineFinishedEvent`, but the `BatchInvocationWorkItem` thread pool thread may still be finalizing when `Stop()` returns. `EndInvoke()` waits on `IAsyncResult.AsyncWaitHandle`, which is only signaled once that thread has fully exited, preventing a race where `Dispose()` closes the `PSDataCollection` while the work item thread is still writing to it.

---

## [e15f8c0] - 2026-03-12

### Added
- **`-Title` parameter** — custom window title override (e.g., `Start-mJig -Title "Windows Update"`).
- **`-Headless` switch** — fire-and-forget mode: spawns the background worker then exits immediately (no TUI). Auto-detected when the console window is hidden (e.g., from a scheduled task).
- **Options sub-dialog** (`Show-OptionsDialog.ps1`) — accessed via Settings → `(o)ptions`. Contains output mode toggle, debug toggle, notification enable/disable, and window title preset cycler.
- **Notification toggle** — `$script:NotificationsEnabled` guard; toggled via Options dialog.
- **Window title presets with emojis** — each built-in title has an associated emoji: mJig (rat), Windows Update (arrows), System Health Check (stethoscope), Background Services (gear), Windows Defender Scan (shield), Performance Monitor (chart). Emojis display in the header and as the notification tray icon.
- **Dynamic header** — header row shows the active title preset name and emoji (e.g., `Windows Update(🔄)`) instead of the hardcoded `mJig(🐀)`.
- **Custom notification tray icon** — renders the current title's emoji via WPF `FormattedText`/`RenderTargetBitmap` (DirectWrite-backed, auto-cropped transparent PNG). Falls back to GDI `TextRenderer` if WPF unavailable. Icon updates when the title preset is cycled. `NotifyIcon.Text` (tooltip) tracks the current window title.
- **Ephemeral custom AUMID** — each toast registers a unique `HKCU:\Software\Classes\AppUserModelId\svc_<PipeName>_<PID>_<seq>` registry key (with `DisplayName` and `IconUri`), fires the toast, sleeps 50ms for the toast system to read it, then removes the key in `finally`. PID ensures uniqueness across sessions (Windows caches AUMID metadata persistently). On first notification call each session, all stale `svc_<PipeName>_*` keys from previous sessions are enumerated and deleted.
- **Per-action notification icons** — `Show-Notification` takes a mandatory `-Action` parameter (`started`, `paused`, `resumed`, `quit`, `disconnected`, `endtime`). Each action has a dedicated emoji rendered to a cached PNG (`mjig_notify_<action>.png`): rocket, pause button, play button, stop sign, electric plug, alarm clock. AUMID `IconUri` uses the title emoji PNG (`$script:_TrayIconPath`); toast `appLogoOverride` uses the action emoji PNG.
- **Interactive system tray icon** — the worker's `NotifyIcon` now has a right-click context menu (Open `'title'`, Pause/Resume, Quit) and responds to left-click. Event handlers set `$script:_TrayAction`; the worker loop checks this flag each tick after `[System.Windows.Forms.Application]::DoEvents()`. Open focuses the viewer (or spawns one if none is connected). Pause/Resume mirrors the hotkey path. Quit cleanly exits the worker.
- **`focus` IPC message** — new worker-to-viewer message type. Worker sends it when the tray Open action fires. Viewer responds by calling `ShowWindow(SW_RESTORE=9)` + `SetForegroundWindow` on its own console window handle (`GetConsoleWindow`), bringing the terminal to the foreground. If no viewer is connected, the worker spawns a new terminal via `Start-Process`.
- **`Update-TrayIcon` function** — extracted from `Show-Notification`; re-renders the tray icon PNG, updates `NotifyIcon.Icon`/tooltip, and updates the Open menu label to `Open '<currentTitle>'`. Called immediately when the worker receives a `title` IPC message, so the tray icon tracks title changes in real time without waiting for a toast.
- **`Update-TrayPauseLabel` function** — updates the Pause/Resume context menu item text. Called on every pause state change (hotkey, viewer IPC, tray menu).
- **Notification diagnostics** (`_diag/notify.txt`) — when `-Diag` is enabled, all notification entries, successes, and failures are logged. Tags: `[ENTRY]`, `[RENDER-TRAY]`, `[RENDER-ACTION]`, `[TIER1-OK]`, `[TIER1-COM]`, `[TIER1-SKIP]`, `[TIER2-OK]`, `[TIER2-PS51]`, `[TIER3-BALLOON]`, `[ERROR]`. Added to `Show-DiagnosticFiles` listing (color: Blue).
- **Title IPC sync** — viewer sends `title` message (with `windowTitle` and `titleEmoji`) to the worker when the title preset changes, ensuring worker notifications and tray icon use the correct title and emoji.
- **Viewer-only tray icon suppression** — viewer processes set `$script:_SkipTrayIcon = $true`; `Update-TrayIcon` returns immediately, preventing duplicate tray icons. Only the worker creates a `NotifyIcon`.
- **White action icon rendering** — `RenderEmojiToPng` now uses `Brushes.White` instead of `Brushes.Black` so action icons are visible on dark notification backgrounds.
- **Stealth pipe/mutex names** (`Get-SessionIdentifier.ps1`) — deterministic SHA256-derived hex names from system boot properties. No "mJig" string in pipe or mutex names.
- **Randomized P/Invoke namespace** — `mJiggAPI` replaced with a random `ns_*` namespace on each session. All call sites use `$script:MouseAPI` / `$script:KeyboardAPI` / `$script:ToastAPI` type variables.
- **Native WinRT Toast API** (`$script:ToastAPI`) — raw COM interop for WinRT `ToastNotificationManager` from PowerShell 7 (no subprocess, no WinRT projection). Manually activates WinRT classes via `combase.dll` (`RoActivateInstance`, `RoGetActivationFactory`, `WindowsCreateString`), defines COM interfaces with manual `IInspectable` vtable stubs, and passes raw `IntPtr` HSTRINGs to bypass broken `HString`/`IInspectable` marshaling in .NET 6+. Falls back to a `powershell.exe` 5.1 subprocess, then `NotifyIcon.ShowBalloonTip()` as last resort.
- **Pipe ACL** (`New-SecurePipeServer.ps1`) — restricts named pipe to the current user via `PipeSecurity`.
- **Pipe authentication handshake** — viewer sends encrypted auth token after connecting; worker validates before accepting commands.
- **Pipe message encryption** (`Protect-PipeMessage.ps1`) — AES-256-CBC encryption for all IPC traffic with per-message random IV. Key derived from session identifier.
- **Encoded worker spawn** — worker process arguments use `-EncodedCommand` (Base64) instead of plaintext `-Command`.
- **PowerShell logging suppression** — disables Script Block Logging, Module Logging, and Transcription in the current session via reflection (no admin, no registry changes).
- **`IsWindowVisible` P/Invoke** — added to Mouse class for headless auto-detection.

### Changed
- **Settings dialog** — row 8 is now `(o)ptions` (opens sub-dialog); row 10 is `(t)heme` (placeholder, no-op). Output and debug toggles moved into Options sub-dialog.
- **Header pause/resume button** — replaced the `(o)utput` button with a clickable pause (⏸) / resume (▶) symbol that toggles `$script:ManualPause` (same behavior as `Shift+M+P` hotkey: notification, log entry, pipe message to worker in viewer mode). Symbol turns green when paused.
- **Clickable "Full"/"Min" label** — the output-mode label next to the pause button is now clickable and toggles between `full` and `min` output (replaces the `o` keyboard shortcut in the main loop).
- **Removed `o` keyboard hotkey** from the main loop — output mode can now only be toggled by clicking the header label or via the Settings dialog's `(o)utput` toggle.
- Added `$script:PauseEmoji` and `$script:PlayEmoji` cached emoji constants.
- Added `$script:ModeLabelBounds` for the clickable mode label hit region; `$script:ModeButtonBounds` now tracks the pause button instead of the old output button.
- `ModeLabelBounds` is nulled alongside `ModeButtonBounds` in hidden/incognito mode.

### Changed
- **Atomic flush rendering** — replaced all `clear-host` + `Flush-Buffer` pairs in the main render loop with single `Flush-Buffer -ClearFirst` calls (embeds `ESC[2J` in the VT100 string so clear + redraw happen in one atomic `[Console]::Write()`). Eliminates the visible blank-screen flash during forced redraws.
- **Flicker-free Settings reopen** — added `-DeferFlush` switch to `Show-SettingsDialog`. When reopening Settings after a sub-dialog (Time, Movement, Options), the main frame and Settings dialog are both buffered before a single atomic `Flush-Buffer -ClearFirst`, eliminating the half-second gap where the main frame was visible without the Settings overlay.
- **Resize handler exit** — `Invoke-ResizeHandler` no longer calls `[Console]::Clear()` on exit. The resize logo stays visible until the caller's `Flush-Buffer -ClearFirst` atomically replaces it with the next frame. Mid-loop artifact cleanup `[Console]::Clear()` (every 50 draws) is preserved.
- **Dead variable cleanup** — removed 12 unused variables from `Start-mJig.psm1` (`OutputLine`, `LastResizeDetection`, `PendingResize`, `ResizeClearedScreen`, `LastResizeLogoTime`, `ENABLE_EXTENDED_FLAGS`, `scrollDetected`, `time`, `outputline`, `_bpH`, `_hBg`/`_hrBg`/`_fBg`/`_mrBg`). Changed scope-chain variables (`PreviousIntervalKeys`, `ResizeThrottleMs`) to `$script:` scope. Fixed 3 `$null` comparison order warnings.

### Fixed
- **`Marshal.SizeOf` crash in worker process** — `[Marshal]::SizeOf(($script:LastInputType -as [type]))` threw `MethodInvocationException` on .NET Core because PowerShell resolved the generic `SizeOf<T>(T)` overload instead of `SizeOf(Type)`. Passing the already-created struct instance (`$lii`) avoids the overload ambiguity. Fixed in both `Start-WorkerLoop.ps1` (worker) and `Start-mJig.psm1` (viewer main loop).
- **`New-SecurePipeServer` crash when `PipeSecurity` unavailable** — the `NamedPipeServerStream` constructor overload accepting `PipeSecurity` is not available on all .NET runtimes. Added try/catch fallback: attempts ACL-restricted pipe first, falls back to standard pipe without ACL if it throws.
- **Viewer "Invalid response from worker" on connect** — `Connect-WorkerPipe` used `Read-PipeMessage` (async `ReadLineAsync`) to read the welcome message. If the task wasn't immediately complete, it returned `$null`, then a fallback synchronous `ReadLine()` raced with the still-pending async task on the same stream. Replaced with a clean synchronous `ReadLine()` → decrypt → parse for the welcome handshake.
- **Worker fatal errors silently swallowed** — the `try/catch` around `Start-WorkerLoop` only logged to `$script:_wsDiagFile` which could be null. Now also writes `[FATAL]` entries to `worker-ipc.txt` (always available when `-Diag` is set).
- **Pipe connection failure exits without diagnostic prompt** — both early-return paths after `Connect-WorkerPipe` returns `$null` (viewer reconnect and fresh spawn) now call `Show-DiagnosticFiles` before exiting when `-Diag` is enabled.
- **Quit bypassed all cleanup** — `break process` references a `:process` label on the main loop. A linter cleanup pass had removed the label but left the 4 `break process` statements intact. In PowerShell, `break` with a non-existent label exits the entire function, silently skipping `Dispose-Notification`, pipe cleanup, `Show-DiagnosticFiles`, and mutex release. Restored the `:process` label.
- **1240 non-terminating errors in viewer mode** — `$script:previousKeyStates` was lazily initialized inside the `if (-not $_isViewerMode)` block, but the mouse button check that uses it runs in both modes. Added a null guard before the mouse button `for` loop.

---

## [bd3766d] - 2026-03-09

Changes since last commit (435dc34 - "Multi-file module split, post-exit diagnostic dump, unified exit flow"):

### Added
- **Windows toast notifications** (`Private/Helpers/Show-Notification.ps1`) — uses `System.Windows.Forms.NotifyIcon.ShowBalloonTip()` (no new dependencies; assembly already loaded). Fires on: worker init, viewer disconnect, worker quit/endtime, manual pause/resume. `Dispose-Notification` cleans up the tray icon on exit.
- **Global hotkeys** (`Private/Helpers/Test-GlobalHotkey.ps1`) — `Shift+M+P` toggles manual pause/resume; `Shift+M+Q` performs an immediate quit (no confirmation dialog). Uses `GetAsyncKeyState` polling (already declared in `mJiggAPI.Mouse`), works from any process including the hidden headless worker. Debounce flag prevents repeat firing. In viewer mode the **worker** is the sole hotkey detector (fast 50ms tick loop); it forwards state changes to the viewer via pipe (`togglePause` / `stopped` messages). In standalone mode the main loop polls directly.
- **Manual pause/resume** — new `$script:ManualPause` flag skips movement when set. Toggled via `Shift+M+P` global hotkey. While paused, new log entries are suppressed (discarded in both standalone and viewer IPC paths). A "Paused (hotkey)" / "Resumed (hotkey)" log entry is added to the main window on each toggle.
- **Viewer `togglePause` IPC handler** — both viewer IPC read loops (main-loop path and wait-loop path) now handle incoming `'togglePause'` messages from the worker, updating `$script:ManualPause` and adding the worker-provided log entry to `$LogArray`.
- **VK constants** — added `VK_SHIFT`, `VK_M`, `VK_P`, `VK_Q` to `mJiggAPI.Keyboard` class in `Initialize-PInvoke.ps1`.
- **`Add-DebugLogEntry` helper** (`Private/Helpers/`) — standardized debug log entry creation, replacing 11+ inline `[PSCustomObject]@{...}` boilerplate sites in the main loop and dialogs.
- **Dialog shared helpers** (`Private/Helpers/`) — extracted 5 helper functions from duplicated dialog code:
  - `Get-DialogButtonLayout` — centralized button width calculations (icon, bracket, paren adjustments).
  - `Get-DialogMouseClick` — PeekConsoleInput-based mouse click detection, reuses pre-allocated buffer.
  - `Read-DialogKeyInput` — key-up event reader consuming from console input.
  - `Invoke-DialogExitCleanup` — standardized dialog close sequence (shadow clear, area erase, cursor restore, state reset).
  - `Invoke-PostDialogCleanup` — post-dialog redraw flag setup via `[ref]` parameters + `clear-host`.
- **`Invoke-CursorMovement` helper** (`Private/Helpers/`) — shared cursor animation loop with drift detection, used by both main loop and `Start-WorkerLoop`. Returns abort info (step, drift, actual position) for caller-specific side effects.
- **`Write-HotkeyLabel` helper** (`Private/Rendering/`) — hotkey-parsed label renderer replacing 6 identical `-split "([()])"` + loop + `Write-Buffer` blocks in `Draw-MainFrame` and `Write-ButtonImmediate`.

### Changed
- **Global hotkey detection moved to worker-only** — in viewer mode, the viewer's main loop (multi-second iterations) was too slow to reliably catch `GetAsyncKeyState` key state. Hotkey detection now runs exclusively in the worker's 50ms tick loop. The worker sends `{ type = 'togglePause'; paused = $bool; logMsg = $hashtable }` or `{ type = 'stopped'; reason = 'quit' }` to the viewer via pipe. The viewer no longer calls `Test-GlobalHotkey` when `$_isViewerMode` is true. Standalone mode (no worker) still polls hotkeys directly in the main loop.
- **`Draw-DialogShadow` / `Clear-DialogShadow` merged** — `Draw-DialogShadow` now accepts a `-Clear` switch; `Clear-DialogShadow` is a thin backward-compatible wrapper.
- **Pre-allocated hot-path objects** — `System.Drawing.Point` and `mJiggAPI.POINT` reused in `Get-MousePosition`; `INPUT_RECORD[]` buffer shared across all dialogs; main loop `$flushBuffer` reuses existing peek buffer.
- **Cached constants at script scope** — emoji characters (`HourglassEmoji`, `LockEmoji`, `GearEmoji`, `RedXEmoji`, `CheckmarkEmoji`) and `VirtualScreen` bounds computed once at startup instead of per-frame/per-call. (Previously included `MouseEmoji`; now replaced by dynamic `$script:TitleEmoji` codepoint per title preset.)
- **Reduced `Get-Date` calls** — `Draw-MainFrame` now accepts a `-Date` parameter from the main loop's existing `$date` variable.
- **Deduplicated stats box variables** — removed redundant `$boxWidth`/`$showStatsBox`/`$logWidth` recalculation in `Draw-MainFrame`.
- **Replaced `Where-Object` pipelines** — `$intervalMouseInputs | Where-Object` replaced with `foreach` loops in both main loop and viewer mode input aggregation.
- **Optimized `Write-Buffer` segment allocation** — uses `[object[]]::new(6)` with index assignment instead of `@(...)` array expression.
- **`Draw-ResizeLogo`** — uses existing script-scoped box-drawing characters instead of redefining them locally.
- **All 5 dialogs refactored** — `Show-TimeChangeDialog`, `Show-QuitConfirmationDialog`, `Show-SettingsDialog`, `Show-InfoDialog`, and `Show-MovementModifyDialog` now use the extracted helper functions.

### Fixed
- **`PeekConsoleInput` return type** — corrected from `uint` to `bool` with `[return: MarshalAs(UnmanagedType.Bool)]` in the P/Invoke declaration.
- **Removed duplicate `$LogArray` initialization** — redundant `New-Object` call removed; single initialization covers all paths.
- **Removed dead `$waitForKeyUp` scriptblock** — unused code in `Show-StartupComplete`.
- **Fixed unused variables** — `$testKey` replaced with `$null`; `$addTypeResult` replaced with `$null`.

---

## [435dc34] - 2026-03-08

### Added
- **Multi-file module split** — split monolithic `Start-mJig.psm1` (~9,000 lines) into ~39 dot-sourced `.ps1` files under `Private/` (Config, Startup, Rendering, Dialogs, IPC, Helpers). Skeleton retains params, provisioner, init, and main loop (~3,000 lines). All files are dot-sourced inside the `Start-mJig` function body to preserve PowerShell's scope chain.
- **Build pipeline** — `Start-mJig/Build/Build-Module.ps1` recombines skeleton + Private/ files into a single monolithic `.psm1` in `dist/`. GitHub Actions workflow (`.github/workflows/build.yml`) runs the build on `v*` tag push and creates a release.
- **Post-exit diagnostic dump (`Show-DiagnosticFiles`)** — when running with `-Diag`, after quitting (or end time reached) a 15-second countdown prompt offers to print all diagnostic files to the console. Each file is displayed in a distinct color (startup=Cyan, settle=Yellow, input=Green, ipc=Magenta, worker-ipc=DarkCyan), limited to 100 rows per file. Files exceeding the limit show a truncation message with the full file path. Auto-skips on timeout or N/Escape; flushes buffered keypresses before prompting to prevent accidental input.

### Changed
- **Centralized resize handling** — extracted the ~900-line inline main frame rendering block into a new `Draw-MainFrame` function (`-ClearFirst`, `-Force`, `-NoFlush` parameters). All resize detection call sites (main loop wait-loop normal/hidden, post-wait-loop, and all five dialog resize handlers) now follow a unified flow: `Invoke-ResizeHandler` (shows resize logo, blocks until stable) → caller updates host dimensions → `Draw-MainFrame -Force -NoFlush` → optional parent callback → queue dialog redraw → single `Flush-Buffer -ClearFirst`. Previously, dialog resize handlers silently re-centered without showing the logo or redrawing the main frame.
- **Consolidated main loop resize detection** — merged the separate normal-mode and hidden-mode resize checks in the wait loop into a single block that runs in both modes. Text zoom detection remains normal-mode only. Eliminated ~30 lines of duplicated state-update code.
- **Screen state tracking** — added `$script:CurrentScreenState` variable (values: `"startup"`, `"main"`, `"hidden"`, `"dialog-time"`, `"dialog-movement"`, `"dialog-quit"`, `"dialog-settings"`, `"dialog-info"`). Set by `Draw-MainFrame` and at dialog entry/exit. `Invoke-ResizeHandler` now accepts a `-PreviousScreenState` parameter (defaults to current state) and stores it in `$script:LastResizePreviousState`.
- **Parent chain redraw on resize** — `Show-TimeChangeDialog` and `Show-MovementModifyDialog` now accept an optional `-ParentRedrawCallback` scriptblock parameter. When opened from `Show-SettingsDialog`, the callback redraws Settings in offfocus mode between the main frame and the sub-dialog. All dialog resize handlers now use `Draw-MainFrame -Force -NoFlush` followed by a single `Flush-Buffer -ClearFirst` for atomic painting, eliminating the visual flash from the previous double-flush pattern (main frame flush + dialog flush).
- **Resize stabilization time reduced** — `$ResizeThrottleMs` changed from 1500ms to 100ms. The resize handler now exits as soon as the window size has been stable for 100ms and the left mouse button is released, providing a much snappier resize experience.

### Fixed
- **Click detection broken after resize refactor** — `PeekConsoleInput` stopped detecting mouse events after `[Console]::Clear()` / `clear-host` calls stripped `ENABLE_MOUSE_INPUT` from the console input mode. Root cause: the `mJiggAPI.Mouse` class was missing `GetConsoleMode` and `SetConsoleMode` DllImport declarations, making `Restore-ConsoleInputMode` a silent no-op. Fixed by adding the missing DllImports and adding `Restore-ConsoleInputMode` calls after `[Console]::Clear()` in the pre-main-loop setup, `Invoke-ResizeHandler` hidden-mode exit, and at the wait loop entry point (catches all dialog exit `clear-host` calls).
- **Main frame renders at half-size during nested dialog resize** — when a sub-dialog (Time/Movement) was resized from within Settings, `Draw-MainFrame` used the main loop's stale `$HostWidth`/`$HostHeight` instead of the newly resized dimensions. Root cause: `Show-SettingsDialog` created local `[ref]$currentHostWidth` sub-refs that pointed to Settings' local variables, not the main loop's refs. The sub-dialog updated its refs, but `Draw-MainFrame` read from the main loop scope chain. Fixed by passing the top-level `$HostWidthRef`/`$HostHeightRef` directly to sub-dialogs instead of creating intermediate local refs.
- **Settings dialog renders with wrong dimensions during sub-dialog resize** — the `$settingsParentRedraw` callback rendered Settings at the sub-dialog's width/height instead of its own. Root cause: PowerShell scope-chain shadowing — when the callback ran inside the sub-dialog, `$dialogWidth`, `$dialogHeight`, and `$dialogLines` resolved to the sub-dialog's values (e.g., Movement's 30×17) instead of Settings' (26×12). Fixed by saving Settings' values with unique prefixed names (`$_stgDialogWidth`, `$_stgDialogHeight`, `$_stgDialogLines`) and shadowing the conflicting variables as local assignments at the top of each callback.
- **Resize screen briefly re-appears after closing a dialog that handled a resize** — after a dialog closed, the main loop's `$oldWindowSize` was stale (pre-resize), causing the next iteration to detect a false size change and re-trigger `Invoke-ResizeHandler`. Fixed by syncing `$oldWindowSize` and `$OldBufferSize` to the current window state at every dialog exit path in the wait loop (Settings, Movement, Time, Quit, Info — both NeedsRedraw and normal close paths).
- **Min-view log row staircase offset** — log rows in "Min" output were indented by an increasing number of spaces (row 0 = 0 extra, row 1 = 1 extra, etc.). Root cause: `$logStartX = $_bpH - 2` evaluated to `-1` with the default `BorderPadH = 1`, causing `Write-Buffer`/`Flush-Buffer` to skip VT100 cursor positioning entirely (requires both X >= 0 and Y >= 0). Without positioning, each row's text appended at the previous row's end cursor, and `$availableWidth` (`HostWidth + 1`) overflowed the screen width, wrapping each row one character further right. Fixed by clamping `$logStartX` to `Max(0, $_bpH - 2)` and `$availableWidth` to `Min(logWidth + 2, HostWidth - logStartX)`.
- **Debug click log wiping entire LogArray** — clicking in the console in debug mode replaced all log entries with a single click-detection log. Root cause: 23 debug logging sites used an inverted guard `if (-not ($LogArray -is [Array])) { $LogArray = @() }` which always evaluated to true (LogArray is a `List[object]`, not an `[Array]`), wiping the list on every debug log add. Also used `$LogArray +=` which converts the List to a plain array. Fixed all 26 sites to use `$null = $LogArray.Add(...)` with no guard, consistent with the IPC log handler pattern.
- **Detected Inputs only showing "Mouse"** — the stats box "Detected Inputs" section never displayed Keyboard or Scroll/Other categories in viewer mode. Three root causes: (1) the worker never set `keyboardInputDetected` because it has no console input buffer for `PeekConsoleInput`; (2) the viewer overwrote its local PeekConsoleInput detections with the worker's limited state on every IPC message; (3) the `$_detInputs`/`$PreviousIntervalKeys` was rebuilt solely from worker data, discarding viewer-local evidence. Fixed by: adding keyboard/other inference to the worker (`GetLastInputInfo` activity + no mouse movement → `keyboardInputDetected`), OR-merging worker and viewer detections instead of overwriting, and adding a `keyboardInferred` flag so the display shows "Keyboard" (definitive, from PeekConsoleInput) vs "Keyboard/Other" (inferred, when console not focused).
- **Detected Inputs showing "Mouse, Keyboard/Other" for single-device input** — the stats box always displayed both Mouse and Keyboard/Other regardless of which device was active. Two root causes: (1) the worker's keyboard inference (`if userInputDetected and not mouseInputDetected → keyboardInputDetected`) ran on every 50ms tick, so on the first tick `GetLastInputInfo` could detect activity before `Test-MouseMoved` confirmed a >2px movement — latching `keyboardInputDetected = true` permanently for that iteration; (2) the viewer ran its own `GetLastInputInfo` detection in viewer mode (no `$_isViewerMode` guard), which used elimination logic ("no keyboard/scroll/mouse evidence → must be mouse") before the worker's state message arrived, falsely classifying keyboard activity as mouse movement. Fixed by: deferring the worker's keyboard inference to just before the state message is sent (after all 10 ticks of evidence have accumulated), and guarding the viewer's `GetLastInputInfo` block with `if (-not $_isViewerMode)` so the viewer relies exclusively on the worker's input classification via IPC.
- **Quit paths now run full cleanup** — both quit confirmation exit paths (mouse click and keyboard `q`) previously used `return` to exit the function immediately, skipping viewer pipe disposal and mutex release. Changed to `break process` so all exit paths (quit and end time) flow through the unified cleanup section: pipe disposal → diagnostic dump prompt (if `-Diag`) → mutex release.
- **Scroll wheel showing both "Keyboard/Other" and "Scroll/Other"** — scrolling the mouse wheel in the focused console displayed both labels in the Detected Inputs stats box. Root cause: the headless worker has no console input buffer, so `GetLastInputInfo` activity with no mouse movement was inferred as keyboard/other. The viewer OR-merged this with its own PeekConsoleInput scroll detection, producing both labels. Fixed by suppressing the worker-inferred "Keyboard/Other" when the viewer locally detected scroll (`$scrollDetectedInInterval`), since the scroll activity fully explains the `GetLastInputInfo` activity the worker observed.

---

## [c39052d] - 2026-03-04

### Added
- **IPC Settings Epoch Guard** — incrementing `$_settingsEpoch` counter on the viewer side and `$_workerSettingsEpoch` on the worker side. Prevents stale `state` messages (buffered in the pipe while a dialog was open) from overwriting viewer-side settings after the user changes them. The viewer skips any incoming `state` message whose `epoch` is less than its own `$_settingsEpoch`. Log and stopped messages are always processed regardless of epoch.
- **Epoch included in all viewer-to-worker messages** — `settings`, `endtime`, and `output` messages from the viewer now include an `epoch` field. The worker captures this epoch and includes it in every outgoing `state` message. Six viewer send sites covered: `s` hotkey (settings+endtime+output), `m` hotkey (movement), `t` hotkey (endtime), `v`/`o` output toggle, incognito toggle, and the PendingReopenSettings reopen path.
- **`Send-PipeMessageNonBlocking` function** — async write variant using `FlushAsync()` with a `[ref]$PendingFlush` pattern. If a previous flush hasn't completed (viewer not draining during a dialog), the message is skipped instead of blocking the worker. Used for periodic `state` and `log` messages.
- **64KB pipe buffers** — all `NamedPipeServerStream` constructors (initial + 4 reconnection paths) now specify 65536 bytes for in/out buffer sizes, providing ~80 seconds of buffering for state messages during dialog interactions.
- **Worker-side IPC diagnostics (`_diag/worker-ipc.txt`)** — logs viewer connect/disconnect, command receipt, and state message send/skip events when `-Diag` is enabled. The `-Diag` flag is now forwarded to the worker process on spawn.
- **Viewer-side IPC diagnostics (`_diag/ipc.txt`)** — logs dialog open/close, pipe send attempts with results, and main loop re-entry events when `-Diag` is enabled.

### Changed
- **Provisioner error stream handling** — non-terminating errors from the child runspace are no longer dumped as a wall of repeated messages on quit. In normal mode they are silently suppressed. In `-DebugMode` they are deduplicated by message + line number and shown as a compact summary (e.g., "3536 non-terminating errors, 2 unique: Line 1926 x1768").
- **`$_pendingWriteFlush` management** — new variable in `Start-WorkerLoop` tracking the async flush state. Reset at all 5 viewer disconnect/reconnect paths to prevent stale async tasks from interfering with new pipe operations.
- **`$_writeSkipCount`** — counter for consecutive state messages skipped due to pending flush, used for diagnostic logging in the worker.

### Removed
- **`IDEAS.md`** — removed from repository.

---

## [a22c95b] - 2026-03-03

### Added
- **IPC Background Worker Architecture** — `Start-mJig` now spawns a hidden background worker process by default. The worker handles mouse jiggling, key simulation, and input detection via a named pipe (`\\.\pipe\mJig_IPC`). The caller's terminal becomes a viewer that renders the TUI from IPC state updates. Closing the terminal no longer stops mJig; reconnect from any terminal by running `Start-mJig` again.
- **`-Inline` parameter** — run in legacy single-process mode (no background worker). Useful for debugging or environments where background processes are undesirable.
- **`-_WorkerMode` parameter** [DontShow] — internal entry point for the hidden background worker process. Never called by users.
- **`-_PipeName` parameter** [DontShow] — internal named pipe identifier (default `'mJig_IPC'`).
- **`Start-WorkerLoop` function** — headless jiggling loop with `NamedPipeServerStream` IPC server. Accepts one viewer at a time. Sends `welcome`, `state` (every 500ms), `log`, and `stopped` messages. Processes `settings`, `endtime`, `output`, and `quit` commands from the viewer. Resilient pipe reconnection: if `BeginWaitForConnection` fails after a viewer disconnect, the pipe server is disposed and recreated from scratch.
- **`Connect-WorkerPipe` function** — connection-only function that connects to the worker's named pipe as a client, performs the welcome handshake, and returns the pipe client/reader/writer (or `$null` on failure). The viewer then falls through into the main `:process` loop with `$_isViewerMode = $true`.
- **`Send-PipeMessage` / `Read-PipeMessage` helper functions** — JSON-line serialization/deserialization over `StreamWriter`/`StreamReader`. `Read-PipeMessage` uses asynchronous `ReadLineAsync()` with a `[ref]$PendingTask` pattern to prevent blocking on named pipes when no data is available.
- **Log Replay Buffer** — worker maintains a circular buffer of the last 30 log messages. On viewer connect, all buffered entries are replayed so the viewer has immediate context.
- **Worker spawn via WMI** — first instance: releases mutex, spawns the worker via `Invoke-CimMethod -ClassName Win32_Process -MethodName Create` so the worker is not part of the terminal's job object and survives when the viewer terminal is closed. Falls back to `Start-Process` if WMI is unavailable, then to inline mode on complete spawn failure. Uses the same PowerShell executable as the caller (`[System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName`).
- **Viewer reconnect** — when mutex is already held (worker running), the script enters viewer mode directly without spawning.
- **Viewer main loop integration** — the viewer reuses the existing main `:process` loop's rendering and input handling. The loop checks `$_isViewerMode` at key points to skip movement/timing logic while keeping the full TUI. State variables (`$script:IntervalSeconds`, `$script:LoopIteration`, `$cooldownActive`, `$mouseInputDetected`, `$keyboardInputDetected`, `$PreviousIntervalKeys`, etc.) are updated from worker IPC `state` messages so the stats box and UI reflect the worker's live state.
- **Detected inputs in viewer stats** — worker's periodic `state` messages now include `mouseInputDetected`, `keyboardInputDetected`, and `userInputDetected` flags. The viewer applies these to `$PreviousIntervalKeys` so the "Detected Inputs" stats box shows live input detection from the worker. Cooldown status (`cooldownActive`, `cooldownRemaining`) is also computed live in each state message.
- **Worker input detection bootstrap** — `GetLastInputInfo` and mouse position tracking in the worker are guarded with `if ($null -ne $workerLastAutomatedMouseMovement)` to skip input detection until the first movement completes, preventing a permanent "User input skip" deadlock.

### Changed
- **Mutex check** — no longer errors when another instance is running. Instead, connects as a viewer to the existing worker.
- **Console setup** — guarded with `-not $_WorkerMode` to skip VT100/cursor/buffer setup for the headless worker process.
- **Startup screen** — skipped for viewer reconnect (only shown for first-run inline mode).

---

## [0653dd2] - 2026-03-03

Changes since last commit (3ee5163 - "Configurable border padding, layered chrome backgrounds, log/menu layout refinements"):

### Performance
- **`$LogArray` ring buffer** — replaced the plain `@()` array (fully rebuilt every frame via 40+ `+=` operations) with a `System.Collections.Generic.List[object]`. Per-frame update now calls `RemoveAt(0)` + `Add()` instead of cloning and rebuilding the entire array. Eliminates ~40 array copies and ~40 `PSCustomObject` allocations per main loop iteration. A defensive re-wrap converts any plain array (e.g., from dialog `+=` usage) back to a List at the top of each render cycle.
- **`$points` pre-allocation in `Get-SmoothMovementPath`** — replaced `$points = @()` + `+=` in the easing loop with a fixed-size `[object[]]::new($numPoints + 1)` array. Eliminates ~100 array-copy operations per movement cycle.
- **Hot-loop object hoisting** — pre-allocated `$_waitPeekBuffer` (32-element `INPUT_RECORD[]`), `$lii` (`LASTINPUTINFO`), and `$pressedMenuKeys` before the main loop; cleared/reused each iteration instead of reallocating every 50ms tick. Replaced `$intervalMouseInputs` plain `@()` array with a `System.Collections.Generic.HashSet[string]`; all `-notcontains` + `+=` patterns replaced with `HashSet.Add()` (O(1), no reallocation).
- **`TimeZoneInfo.ClearCachedData()` rate-limited** — moved from every main loop iteration to at most once per hour via a `$lastTzCacheClear` timestamp check. Eliminates unnecessary OS timezone re-queries every 2-4 seconds.
- **`$script:MenuItemsBounds` converted to `List[hashtable]`** — `.Clear()` and `.Add()` replace the `= @()` + `+=` pattern on every render frame, eliminating per-frame array reallocations for menu click bounds.
- **`$date` refreshed in wait loop** — `$date = Get-Date` now runs at the top of each 50ms `:waitLoop` tick. All duplicate `(Get-Date).ToString("HH:mm:ss")` pairs in the main loop body now use `$date.ToString("HH:mm:ss")`, eliminating redundant DateTime allocations.

### Added
- **`Start-mJig.psm1`** — the script has been converted to a true PowerShell module. `start-mjig.ps1` is replaced by `Start-mJig.psm1` (same content, new format). Load with `Import-Module .\Start-mJig\Start-mJig.psm1` then call `Start-mJig`.
- **`Start-mJig.psd1`** — module manifest declaring version `1.0.0`, GUID, `FunctionsToExport = @('Start-mJig')`, `RequiredAssemblies = @('System.Windows.Forms')`, and PSData tags.
- **Module Runspace Provisioner** (lines ~71-100 of `Start-mJig.psm1`) — on every call from the user's session, `Start-mJig` transparently provisions a fresh `InitialSessionState::CreateDefault2()` runspace (no profile, no PSModulePath modules, no user aliases/variables) with the caller's `$Host` passed through for console TUI access and `ApartmentState = STA`. The function re-invokes itself inside that runspace with all parameters forwarded, then `return`s. The provisioned runspace is disposed in a `finally` block on exit.
- **`[switch]$_InModuleRunspace`** — hidden private parameter (`[Parameter(DontShow = $true)]`) added to `Start-mJig`. Set to `$true` only by the provisioner on re-entry. Prevents recursive provisioning with no global scope usage and no cleanup required.

### Removed
- **`start-mjig.ps1`** — replaced by `Start-mJig.psm1`. A backup was saved to `.backups/start-mjig.ps1.bak4`.

---

## [3ee5163] - 2026-02-28

Changes since last commit (bb04ba8 - "Startup screen, unified resize handler, mouse click UP with per-button colors"):

### Added
- **`$script:Output`** — script-scoped copy of the `$Output` parameter, initialized at startup alongside the other `$script:*` parameter copies. Allows dialogs and the main loop to share and modify the output mode via a consistent variable.
- **`$script:DebugMode`** — script-scoped copy of `$DebugMode`, initialized as `[bool]$DebugMode` at startup. Enables runtime toggling of debug mode from the Settings dialog; synced back to `$DebugMode` in the main loop after the dialog closes.
- **Inline output toggle in Settings dialog (row 8)** — replaces the old `(o)utput` sub-dialog button. Clicking or pressing `o` inside Settings cycles `$script:Output` between `"full"` and `"min"` immediately, displaying the current mode as `(o)utput: Full` or `(o)utput: Min`. No sub-dialog or screen repaint needed.
- **Inline debug toggle in Settings dialog (row 10)** — new `🔍|(d)ebug: On/Off` row. Clicking or pressing `d` toggles `$script:DebugMode`. Shows `On ` or `Off` as the current state. Both toggled values log a change entry.
- **`$emojiDebug` (🔍, U+1F50D)** — magnifying glass emoji used for the debug row in the Settings dialog.

### Changed
- **Settings dialog height** — expanded from 10 to 12 rows to accommodate the output toggle (row 8), debug toggle (row 10), and their blank spacer rows (9, 11).
- **`$calcButtonVars`** — removed static `$outputPad`, `$outputButtonStartX/EndX` (pads are now dynamic per current mode); added `$outputButtonStartX/EndX` and `$debugButtonStartX/EndX` as full inner-row clickable areas (`$dialogX + 1` to `$dialogX + $dialogWidth - 2`).
- **`$dialogLines` array** — extended from 11 entries (indices 0-10) to 13 entries (indices 0-12) for the expanded layout.
- **`$drawSettingsDialog` render scriptblock** — rows 8 and 10 now compute dynamic label text and padding at render time (reading `$script:Output` / `$script:DebugMode`) and call `$drawSettingsBtnRow` directly; bottom border moved to `$dialogHeight` (row 12).
- **`(o)` hotkey in main loop** — now also sets `$script:Output = $Output` after toggling to keep script scope in sync with local var.
- **Incognito toggle (`i` hotkey)** — now also sets `$script:Output = $Output` after the mode change.
- **Settings dialog call sites** — both the primary `s`-hotkey handler and the `$script:PendingReopenSettings` reopen path now sync `$DebugMode = $script:DebugMode` (and the existing `$Output = $script:Output`) after the dialog returns.
- **`$Output` ValidateSet** — removed `"dib"` (was a placeholder; no separate rendering path existed). Accepted values are now `"min"`, `"full"`, `"hidden"`.

### Removed
- **`Show-OutputSelectDialog`** — full-screen centered picker dialog for output mode. Replaced by the inline toggle in the Settings dialog.
- **`OutputDialog*` theme variables** — `$script:OutputDialogBg/Shadow/Border/Title/Text/SelectedFg/SelectedBg/ButtonBg/ButtonText/ButtonHotkey` removed since the dialog they styled no longer exists.


- **`$script:MenuButtonShowIcon`** (`$true`) — show/hide the emoji icon prefix on all main menu bar buttons. When `$false` the emoji and separator are omitted and the label starts at the button's left edge.
- **`$script:MenuButtonSeparator`** (`"|"`) — the separator character rendered between the icon and label on main menu buttons. Any single character (or short string) works.
- **`$script:MenuButtonOnClickSeparatorFg`** (`"Black"`) — dedicated pressed-state color for the `|` separator on main menu buttons. Previously inherited from `MenuButtonOnClickFg`.
- **`$script:MenuButtonShowBrackets`** (`$false`) — when `$true`, wraps each main menu button in `[ ]` brackets (e.g. `"[👁 |toggle_(v)iew]"`).
- **`$script:MenuButtonBracketFg`** (`"DarkCyan"`) / **`$script:MenuButtonBracketBg`** (`"DarkBlue"`) — normal-state foreground and background colors for main menu button brackets.
- **`$script:MenuButtonOnClickBracketFg`** (`"Black"`) / **`$script:MenuButtonOnClickBracketBg`** (`"DarkCyan"`) — pressed-state bracket colors for main menu buttons.
- **`$script:DialogButtonShowIcon`** (`$true`) — show/hide the emoji icon prefix (`✅`/`❌`) on action buttons in the Quit, Time, and Move dialogs.
- **`$script:DialogButtonSeparator`** (`"|"`) — the separator character rendered between the icon and label on dialog buttons.
- **`$script:DialogButtonShowBrackets`** (`$false`) — when `$true`, wraps each dialog action button in `[ ]` brackets (e.g. `"[✅ |(u)pdate]"`).
- **`$script:DialogButtonBracketFg`** (`"White"`) / **`$script:DialogButtonBracketBg`** (`$null`) — bracket colors for dialog buttons. `$null` background = terminal default, which renders transparent over the dialog background.
- **`$script:MenuButtonShowHotkeyParens`** (`$false`) / **`$script:DialogButtonShowHotkeyParens`** (`$false`) — independently control whether `()` appear around hotkey letters on menu bar buttons and dialog buttons respectively. The letter is still highlighted in its hotkey color when parens are hidden.
- **Per-button hotkey colors** — `$script:MenuButtonHotkey`, `$script:MenuButtonOnClickHotkey`, `$script:QuitButtonHotkey`, `$script:QuitButtonOnClickHotkey`, `$script:SettingsButtonHotkey`, `$script:SettingsButtonOnClickHotkey`, `$script:DialogButtonButtonHotkey` — independent hotkey letter foreground colors for each button group/state.
- **`(o)utput` mode button in header** — replaces the old `(v)iew` toggle. Displays as `[(o)utput]` (clickable) with `|` separator and current mode name (`Full` / `Min`) rendered as non-clickable decorative text after the button. Hotkey changed from `v` to `o`.
- **Hidden clickable regions in header** — "End⏳/HH:MM" opens the Set End Time dialog; "Current⏳/HH:MM" opens Windows date/time settings (`control.exe timedate.cpl`); mJig logo opens the Info dialog. All are invisible (no visual button styling).
- **`Show-InfoDialog`** — info/about dialog showing current version, update check via GitHub Releases API (`https://github.com/ziaprazid0ne/mJig`), and configuration summary. Accessible via `?`, `/`, mJig logo click, or `[?]` help button.
- **`[?]` help menu button** — shown in full output mode only (hidden in minimal/narrow views). Hotkeys `?` and `/`. Positioned to the right of the gap, left of Quit. Opens the Info dialog.
- **`Show-QuitConfirmationDialog` repositioned** — dialog now appears right-aligned, bottom-docked above the menu separator, no drop shadow. Padding: 1 blank row/column on top, left, right (but not bottom) using terminal-default background for a clean pop-over appearance.
- **Quit dialog slide-up animation** — animates from behind the separator/menu bar using a clip-from-below reveal. 9 frames, 15ms per frame. The box appears to rise from behind the menu bar rather than appearing on top of it.
- **Separate quit button theme variables** — `$script:QuitButton{Bg,Text,Hotkey,SeparatorFg,BracketFg,BracketBg}` / `QuitButtonOnClick{Bg,Fg,Hotkey,SeparatorFg,BracketFg,BracketBg}` allow independent styling for the quit button. `OnClick*` defaults match the Quit dialog colors.
- **`Show-SettingsDialog`** — slide-up mini-dialog consolidating end-time and movement configuration. Replaces `set_end_time` and `modify_movement` menu buttons with a single `(s)ettings` button. Two stacked option buttons: `[⏳|(t)ime]` and `[🛠|(m)ovement]`. Hotkey `s`.
- **Settings dialog onfocus/offfocus states** — dialog dims to offfocus colors while a sub-dialog (time/movement) is open, returns to onfocus when the sub-dialog closes.
- **Settings dialog sub-dialog background cleanup** — when a sub-dialog closes inside Settings, the full main screen is repainted before Settings reopens (via `$script:PendingReopenSettings` flag + `SkipAnimation = $true` on reopen). Prevents blank/corrupted log areas behind the reopened settings box.
- **Settings dialog re-click to close** — clicking the `(s)ettings` menu button while the dialog is visible closes it.
- **`$script:SettingsDialog{Bg,Border,Title,Text,ButtonBg,ButtonText,ButtonHotkey}`** and **`SettingsDialogOffFocus*`** — onfocus and offfocus color sets for the Settings dialog.
- **`$script:SettingsButton*`** — dedicated theme variables for the Settings menu bar button (normal and onclick states). `OnClick*` defaults match `SettingsDialog*` so the button highlights to match the open dialog.
- **`$script:PendingReopenSettings`** — script-scoped flag used by the main loop to reopen Settings after a full screen repaint following a sub-dialog close.
- **System timezone / time change detection** — `[System.TimeZoneInfo]::ClearCachedData()` called at the top of each main loop iteration so the displayed current time updates immediately when the system clock or timezone is changed.
- **`(i)ncognito` button replaces `(h)ide_output`** — the menu button label is now `(i)ncognito` with hotkey `i`. The minimal `(i)` button shown in incognito mode also uses hotkey `i`. The old `h` hotkey no longer does anything. In incognito mode, only `i` (exit incognito) and `q` (quit) are processed; all other hotkeys are blocked.

### Changed
- **Menu button rendering** — the `menuFormat -eq 0` path in the main render loop, quit item render, and `Write-ButtonImmediate` all now branch on `$script:MenuButtonShowIcon`/`$script:MenuButtonShowBrackets` and use `$script:MenuButtonSeparator` instead of the hardcoded `"|"`. A local `$contentX` offset shifts icon/text by 1 when brackets are on.
- **Menu width calculations** — `$menuBracketWidth` (`2` or `0`) added alongside `$menuIconWidth` and included in `$format0Width`, `$quitWidth`, and `$itemDisplayWidth` so the format auto-select logic stays correct in all combinations.
- **`$script:MenuItemsBounds` schema** — every bounds entry now also stores `pipeFg`, `bracketFg`, `bracketBg`, `onClickPipeFg`, `onClickBracketFg`, `onClickBracketBg` so `Write-ButtonImmediate` can restore exact colors on drag-off.
- **`Write-ButtonImmediate` signature** — added optional `$pipeFg`, `$bracketFg`, `$bracketBg` parameters (default to script-scope vars). Both call sites (LMB DOWN and drag-off UP) now resolve and pass the appropriate normal/onclick bracket colors from the bounds entry.
- **Dialog button rendering** — all three dialogs (Quit, Time, Move) compute `$dlgBracketWidth` and conditionally render `[`/`]` around each button. Button `$contentX` offsets and `$btn2X` include the bracket width.
- **Dialog padding** — `$bottomLinePadding` / `$buttonPadding` formulas updated to subtract `2 * $dlgBracketWidth` so the border column is still reached in all combinations of icon and bracket settings.
- **Dialog click bounds** — `$updateButtonStartX/EndX` and `$cancelButtonStartX/EndX` (and their resize-handler counterparts) now include `$dlgBracketWidth` / `$_moveDlgBW` so click detection remains accurate regardless of icon and bracket settings.
- **`modify_(m)ovement` hotkey changed** — was previously mapped differently; `m` now opens the Settings dialog (which contains movement) when not in hidden mode, and works in full and minimal output modes (previously full only).
- **`(o)utput` mode button hotkey** — changed from `v` to `o`; button label changed from `(m)ode` to `(o)utput`.
- **Settings dialog width** — reduced from 35 to 24 columns for a tighter visual fit.
- **`o` (output toggle) blocked in incognito mode** — adding `$Output -ne "hidden"` guard prevents `o` from exiting incognito; only `i` can do so.
- **Info dialog hotkey `i` removed** — `i` is now the incognito toggle. Info dialog remains accessible via `?`, `/`, mJig logo click, and the `[?]` help button.

### Fixed
- **Dialog clear area off-by-one** — clear loops in `Show-TimeChangeDialog`, `Show-MovementModifyDialog`, `Show-QuitConfirmationDialog`, and `Show-InfoDialog` now use `$i -le $dialogHeight` (was `$i -lt`), ensuring the bottom border row is always cleared when a dialog closes.


### Added (UI Layout & Theming overhaul)

- **`$script:BorderPadV`** (`3`) — replaces `$script:BorderPad` for the **top/bottom** blank-row border count. Minimum 1. Controls how many rows of padding appear above the header and below the menu bar. Only the innermost row of each group receives the `HeaderBg` / `FooterBg` color; extra rows beyond 1 stay transparent (default background, ANSI 49).
- **`$script:BorderPadH`** (`3`) — new companion variable for the **left/right** column border width. Minimum 1. Governs how many columns of padding appear on each side of every chrome row. Only the innermost column (`X = $_bpH - 1` and `X = $HostWidth - $_bpH`) carries the group background; outer columns are transparent.
- **`$script:HeaderBg`** — background color applied to the 3-row header group: the top blank, the header content row, and the top separator.
- **`$script:FooterBg`** — background color applied to the 3-row footer group: the bottom separator, the menu bar content row, and the bottom blank.
- **`$script:HeaderRowBg`** (`"DarkGray"`) — background color applied **only** to the header content row, inset by `$_bpH` on each side so it does not bleed into the padding columns.
- **`$script:MenuRowBg`** (`"DarkGray"`) — background color applied **only** to the menu bar content row, with the same inset logic.
- **`Write-Buffer -NoWrap` switch** — disables ANSI auto-wrap (`\e[?7l`) before the segment and re-enables it (`\e[?7h`) after. Used when writing to the last character of the last console row to prevent an unwanted scroll. Stored as a `NoWrap` flag in each `RenderQueue` entry.
- **2-char inner row padding** — header and menu bar rows now include 2 explicit row-bg spaces (`$_hrBg` / `$_mrBg`) just inside the group-bg char on each side, so content is not flush against the background boundary.

### Changed (UI Layout & Theming overhaul)

- **`$script:BorderPad` removed** — replaced by `$script:BorderPadV` and `$script:BorderPadH`. Local render variable `$_bp` split into `$_bpV` (vertical calculations) and `$_bpH` (horizontal calculations).
- **Header content start X** — "mJig(" and all subsequent header elements now begin at `X = $_bpH + 2` (group-bg char + 2-char inner padding). `$headerLeftWidth` updated to exclude the removed leading spaces; `$remainingSpace` reduced by `2 * ($_bpH + 2)` to keep clock centering accurate.
- **`$script:HeaderLogoBounds.startX`** updated to `$_bpH + 2` to match the new content position.
- **Menu bar content start X** — `$currentMenuX` now starts at `$_bpH + 2`; the leading `"  "` write removed. Quit button anchored to `$HostWidth - $_bpH - 2 - $quitWidth`.
- **Transparent outer padding on all chrome rows** — all coloured rows (header blank, header content, top separator, bottom separator, menu content, footer blank) now write `$_bpH - 1` transparent-bg spaces on each outer side instead of filling the full `$_bpH` columns with group background. This matches the existing top/bottom blank-row transparency behaviour.
- **Log area respects `$_bpH`** — `$logWidth` reduced by `2 * $_bpH` (plus `+1` right-side extension to reach the group-bg char column). `$logStartX = $_bpH - 2` (flush with the group-bg char). `$availableWidth = $logWidth + 2`. Stats-box separator X = `$_bpH + $logWidth + 1`. `$showStatsBox` minimum-width threshold increased by `2 * $_bpH`.
- **`$Rows` formula** — uses `$_bpV` instead of the removed `$_bp`. `$Rows = [math]::Max(1, $HostHeight - 4 - 2 * $_bpV)`.
- **Footer blank NoWrap path** — when `$_bpV = 1` **and** `$_bpH > 1`, each side of the footer blank is written as separate segments (transparent left, group-bg centre, transparent right with `-NoWrap` on the last segment) to prevent the console scroll while still achieving full-width background coverage.

---

## [bb04ba8] - 2026-02-27

Changes since last commit (ccb6b63 - "Cleaning things up."):

### Added
- **`Show-StartupScreen` function** - Initial "Initializing..." loading screen shown at script start (skipped in `-DebugMode` and `-Output hidden`). Runs before VT100 is fully set up so it uses `Write-Host`. Shows a decorative box with "mJig is starting up..." messaging.
- **`Show-StartupComplete` function** - "Initialization Complete" screen shown after startup. Displays current parameters in a box. Behavior depends on whether any parameters were passed: no params → "Press any key to continue" (waits indefinitely); params passed → 7-second auto-continue countdown with "any key to skip". Includes `drawCompleteScreen` and `drainWakeKeys` nested helpers and calls `Invoke-ResizeHandler` when the window is resized while the screen is displayed.
- **`Invoke-ResizeHandler` function** - Unified, blocking resize handler usable from any context after initialization (startup screens, main loop, hidden mode). Draws the resize logo in normal mode or clears to blank in hidden mode. Polls at 1ms intervals, redraws on every size change, clears every 50 redraws to prevent artifact buildup. Exits only when the window has been stable for `$ResizeThrottleMs` (1500ms) **and** LMB is released. Always calls `Restore-ConsoleInputMode` and `Send-ResizeExitWakeKey` on exit. Returns the final stable `[System.Management.Automation.Host.Size]` object.
- **`drainWakeKeys` nested helper** (inside `Show-StartupComplete`) - Drains the console input buffer after `Invoke-ResizeHandler` returns. Reads and discards `VK_RMENU` (keycode 165, the synthetic wake key injected by `Send-ResizeExitWakeKey`) while returning `$true` if any real (non-wake) key was consumed. Used to prevent the injected wake key from falsely dismissing the welcome screen as if the user pressed a real key.
- **`Write-ButtonImmediate` function** - New helper that renders a single menu button at specified colors and flushes immediately. Used for instant press/release visual feedback without waiting for the next full frame render. Supports both emoji-pipe format (format 0) and text-only formats (format 1/2). Stored in bounds entries as `displayText` and `format`.
- **Per-button color properties in `$script:MenuItemsBounds`** - Every bounds entry now includes `fg`, `bg`, `hotkeyFg`, `onClickFg`, `onClickBg`, `onClickHotkeyFg`. Applies to all four build sites: regular menu items, quit button, hidden `(h)` button, and the clear-on-hide path.
- **Onclick color theme variables** - `$script:MenuButtonOnClickBg` (`"DarkCyan"`), `$script:MenuButtonOnClickFg` (`"Black"`), `$script:MenuButtonOnClickHotkey` (`"Black"`) added to the theme colors section as defaults for the pressed button state.
- **Button press state tracking variables** - `$script:PressedMenuButton` (hotkey of button currently held), `$script:ButtonClickedAt` (timestamp of confirmed UP-over-button click), `$script:PendingDialogCheck` (flag for render loop to decide immediate vs. persistent color restore), `$script:LButtonWasDown` (previous LMB console state for UP-transition detection).

### Changed
- **All resize detection paths now route through `Invoke-ResizeHandler`** - The previous three independent resize implementations (main wait loop tight redraw loop + outer stability check, hidden-mode polling loop, and welcome screen simple redraw) have all been replaced with calls to `Invoke-ResizeHandler`. The function provides consistent resize behavior (logo, stability wait, LMB gate, input mode restore, wake key) everywhere the window can be resized.
- **`$oldWindowSize` and `$OldBufferSize` initialized before main loop** - Both variables are set to the current window/buffer size immediately before the `:process while ($true)` loop starts. Previously they were `$null` at first iteration, causing `$windowSizeChanged = $true` unconditionally and triggering a spurious resize screen on every startup.
- **Second (outside-wait-loop) resize detection block rewritten** - The per-iteration resize check that runs after the wait loop (guarded by `if (-not $forceRedraw)`) was still using the old detect-pending-draw-stability pattern. Replaced with a simple `Invoke-ResizeHandler` call on actual size change, with text-zoom detection retained.
- **Welcome screen keypress detection hardened against injected wake keys** - The `while (-not $Host.UI.RawUI.KeyAvailable)` pattern replaced with an explicit `$keyPressed` flag loop. `KeyAvailable` + `ReadKey` calls filter out `VK_RMENU` (165) and only set `$keyPressed = $true` on genuine key presses. The countdown loop uses the same `drainWakeKeys` function so an auto-skip only fires on real keys.
- **Mouse button click triggers on UP, not DOWN** - `PeekConsoleInput` handler now tracks LMB DOWN→UP transitions using `$script:LButtonWasDown`. DOWN: detects the button under the cursor and immediately paints it in onclick colors via `Write-ButtonImmediate`. UP over button: triggers action (`$script:ConsoleClickCoords`). UP outside button (drag-off): 100ms delay then `Write-ButtonImmediate` with normal colors — no action fires.
- **Menu render loop uses per-button colors** - Before rendering each item (regular menu, quit, hidden `(h)`), the render resolves local color variables by checking `$script:PressedMenuButton` against the button's hotkey. Pressed button renders with `onClickFg`/`onClickBg`/`onClickHotkeyFg`; all others use their normal colors.
- **Popup buttons persist onclick color while dialog is open; toggle buttons restore immediately** - On confirmed click (UP over button), `$script:PendingDialogCheck = $true` is set. The menu render loop checks this flag: if no dialog is open, clears `$script:PressedMenuButton` immediately. For popup-opening actions the dialog is blocking; when it closes the next render fires the restore.
- **Resize UI defers exit while LMB is held** - All resize exit points now check `GetAsyncKeyState(0x01)` after the stability timer expires. If LMB is still held the exit is deferred (timer not reset). Exits the moment the mouse is released.

### Fixed
- **Resize screen triggered immediately on every startup** - `$oldWindowSize` was `$null` before the first main loop iteration, making `$windowSizeChanged` always `$true`. Fixed by initializing both tracking variables to the live window/buffer size just before the main loop.
- **Welcome screen dismissed prematurely after resize** - `Send-ResizeExitWakeKey` injects a synthetic `VK_RMENU` keypress to re-engage Windows Terminal mouse routing. That injected key landed in the console input buffer and caused `KeyAvailable` to return `$true`, making the welcome screen exit as if the user pressed a real key. Fixed via `drainWakeKeys` and explicit VK_RMENU filtering in the keypress check.
- **Resize not detected during welcome screen** - The original welcome screen only compared sizes and redrew its own content; it never entered the resize handler so the logo never appeared. Now calls `Invoke-ResizeHandler` when a size change is detected.
- **User mouse movement ignored during automated movement animation** - The movement animation loop ran to completion without checking for user mouse input. Now checks actual cursor position after each step; if drifted >3px the animation aborts, sets `$script:userInputDetected`, skips the simulated keypress, and starts the auto-resume timer.
- **Welcome screen resize detection never worked (root causes fully diagnosed and fixed via `_diag/welcome.txt`)**:
  - `getSize` (and `handleResize` inner loop) switched from `$Host.UI.RawUI.WindowSize` to direct Win32 `GetConsoleScreenBufferInfo` P/Invoke on the stdout handle, bypassing all managed caching layers.
  - `Restore-ConsoleInputMode` + `Send-ResizeExitWakeKey` now called once before the polling loop starts to prime Windows Terminal's input routing.
  - `drainWakeKeys` completely rewritten (see Changed section).
- **Welcome screen dismissed itself immediately without user input** - Three compounding bugs in the original `drainWakeKeys`: (1) it returned early on the first non-165 key (stale Enter KeyUp from script launch), leaving the synthetic Alt KeyDown in the buffer; (2) `VK_RMENU` (165) is reported as `VK_MENU` (18) by the Windows console input layer — the old 165-only filter missed it entirely; (3) `ReadKey("IncludeKeyDown")` blocks indefinitely on KeyUp events, causing the entire poll loop to freeze on tick 1. All three fixed by the rewritten `drainWakeKeys`.

### Changed
- **`drainWakeKeys` (nested in `Show-StartupComplete`) completely rewritten** - Now drains the entire input buffer on every call (no early return). Uses `IncludeKeyDown,IncludeKeyUp` to prevent blocking on KeyUp events. Filters all modifier VKs: 16 (Shift), 17 (Ctrl), 18 (VK_MENU / synthetic Alt), 160–165 (L/R Shift, Ctrl, Alt variants). Returns `$true` only for a non-modifier `KeyDown=true` event. The `$_wakeVKs` filter array is defined in the enclosing `Show-StartupComplete` scope and accessed via PowerShell's dynamic scoping.
- **`getSize` (nested in `Show-StartupComplete`) rewritten** - Now calls `[mJiggAPI.Mouse]::GetConsoleScreenBufferInfo` on `GetStdHandle(-11)` (stdout) directly and derives width/height from `srWindow`. Falls back to `$Host.UI.RawUI.WindowSize` only if the P/Invoke fails.
- **`handleResize` inner polling loop** - Also uses `GetConsoleScreenBufferInfo` directly (reuses a pre-allocated `$_hrCsbi` struct per invocation) rather than `$Host.UI.RawUI.WindowSize`.

### Added
- **`_diag/welcome.txt` always-on diagnostic** - `Show-StartupComplete` always writes a timestamped diagnostic log to `Start-mJig/_diag/welcome.txt` (no `-Diag` flag required). Logs every `getSize` call with raw CSBI values vs PS-host values, every `drainWakeKeys` event read, `KeyAvailable` state, resize detection transitions, and `handleResize`/`drawCompleteScreen` entry/exit points. Read with: `Get-Content "c:\Projects\mJigg\Start-mJig\_diag\welcome.txt"`

---

## [cee9bf8] - 2026-02-22

### Commit Message
"VT100 flicker-free rendering, clickable buttons via PeekConsoleInput, buffered frame output"

Changes since commit 4ddbfc2 ("Evidence-based input detection, security hardening, scroll/mouse hook removal"):

### Added
- `$script:MenuClickHotkey` - Script-scoped variable for menu click hotkey (was previously used but never initialized)
- `$script:ConsoleClickCoords` - Script-scoped variable storing character cell X/Y from the last left-click detected via `PeekConsoleInput` MOUSE_EVENT records
- **Mouse click detection via PeekConsoleInput** - Main loop, Time dialog, Movement dialog, and Quit dialog all detect left-button clicks by reading native `MOUSE_EVENT` records from the console input buffer. The console provides exact character cell coordinates, eliminating all pixel-to-character math.
- **Movement dialog field click selection** - Clicking on a field row in the Modify Movement dialog now switches the active field to the clicked row, redraws only the affected rows (no flicker), and positions the cursor at the end of that field's input
- **Quit dialog Yes/No button click support** - The quit confirmation dialog now responds to mouse clicks on the Yes and No buttons
- **Buffered frame rendering** - `Write-Buffer`, `Flush-Buffer`, `Clear-Buffer` functions and `$script:RenderQueue` (`System.Collections.Generic.List[hashtable]`). All UI rendering now writes to an in-memory queue first, then flushes to the console in a single burst per frame.
- **VT100/ANSI single-write rendering** - `Flush-Buffer` builds a single string with embedded VT100 escape sequences (cursor positioning, color changes, cursor visibility) via `StringBuilder`, then outputs the entire frame with one `[Console]::Write()` call. Eliminates 55-80 separate `Write-Host` calls per frame.
- **VT100 processing enabled on stdout** - `ENABLE_VIRTUAL_TERMINAL_PROCESSING` (0x0004) enabled on the output handle via `SetConsoleMode` during console setup
- **UTF-8 console encoding** - `[Console]::OutputEncoding` set to `[System.Text.Encoding]::UTF8` for correct emoji rendering via `[Console]::Write()`
- **ConsoleColor-to-ANSI mapping tables** - `$script:AnsiFG` and `$script:AnsiBG` hashtables mapping all 16 `[ConsoleColor]` values to ANSI SGR codes (30-37/90-97 for FG, 40-47/100-107 for BG)
- **`$script:CursorVisible` tracking variable** - Tracks cursor visibility state for conditional cursor show/hide in VT100 sequences
- **`$script:ESC` variable** - Stores `[char]27` for VT100 escape sequence construction
- **`-ClearFirst` switch on `Flush-Buffer`** - Embeds `ESC[2J` (clear screen) in the VT100 string for atomic clear+redraw with no visible flash
- **`-ClearFirst` switch on `Draw-ResizeLogo`** - Passes through to `Flush-Buffer -ClearFirst`
- **Hidden view `(h)` button** - Clickable button in bottom-right corner of hidden mode, behaves like the hide_output toggle

### Changed
- **All rendering paths use buffered output** - Header, separators, log entries, stats box, menu bar, all three dialogs (Time, Movement, Quit), dialog shadows, field redraws, resize logo, and dialog cleanup all write through `Write-Buffer` instead of directly to the console. `Flush-Buffer` is called at well-defined frame boundaries.
- **Emoji positions computed statically** - Menu bar, header, and dialog button rows no longer read `$Host.UI.RawUI.CursorPosition.X` after writing emojis. Instead, positions are calculated mathematically (emoji = 2 display cells), and menu item bounds (`$script:MenuItemsBounds`) are tracked by arithmetic rather than cursor position reads.
- **Click detection architecture** - Replaced the previous `GetAsyncKeyState` + `Get-MousePosition` + screen-pixel-to-character-cell conversion approach with native console input buffer events. `PeekConsoleInput` reads `MOUSE_EVENT` records which provide exact character cell coordinates directly from the console.
- **Left-button guard added** - Click-to-button mapping in the main loop only processes left button presses (dwButtonState & 0x0001), preventing accidental menu triggers from other mouse buttons.
- **Debug mode gate removed** - Click detection logic now runs in all modes, not just when `$DebugMode` is enabled. Debug logging remains conditional.
- **Simplified hit-testing** - All click detection now uses simple character cell comparisons. No pixel math, tolerance percentages, or expanded bounding boxes.
- **Cursor visibility via VT100** - All `[Console]::CursorVisible` assignments replaced with VT100 `ESC[?25l`/`ESC[?25h` sequences and `$script:CursorVisible` tracking. `Flush-Buffer` conditionally shows cursor at end of frame based on tracked state.
- **Default colors use ANSI 39/49** - Segments without explicit FG/BG colors emit ANSI "default foreground" (39) and "default background" (49) codes instead of mapping console's current color, preserving the terminal's true default/transparent background.
- **Atomic screen clear+redraw** - All `Clear-Host` + rendering pairs replaced with `Flush-Buffer -ClearFirst`, embedding the screen clear in the VT100 string so clear and redraw happen in a single `[Console]::Write()` call with no visible blank flash. Affects resize logo, dialog resize, and hidden view.
- **Hidden view clears old menu bounds** - `$script:MenuItemsBounds` cleared when entering hidden mode so old buttons are not clickable.

### Removed
- `Convert-ScreenToConsole` function - Screen pixel to console cell conversion (replaced by PeekConsoleInput native coords)
- `Test-ClickInBounds` function - Pixel-based hit-test with tolerance expansion (replaced by exact cell matching)
- `Get-ConsoleWindowHandle` function - Cached window handle lookup (no longer needed without pixel conversion)
- `$script:CachedConsoleHandle`, `$script:LastClickDebug`, `$script:ClickTolerancePct` variables
- `RECT` struct, `ScreenToClient`, `GetWindowRect`, `GetClientRect` P/Invoke declarations
- `CONSOLE_FONT_INFOEX` struct, `GetCurrentConsoleFontEx` P/Invoke declaration
- `ReadConsoleOutputAttribute` and `WriteConsoleOutputAttribute` P/Invoke declarations (unused remnants from previous emoji background fix attempt)
- All `[Console]::CursorVisible` references (replaced by VT100 sequences)
- Segment merging optimization in `Flush-Buffer` (no longer needed -- VT100 color changes are just bytes in the string, not separate API calls)
- Separate `Clear-Host` calls before rendering (replaced by `-ClearFirst` flag)

### Fixed
- **Clickable menu buttons not working** - The entire click-to-button coordinate conversion pipeline was gated behind `if ($DebugMode)`, making click detection silently fail in normal operation. Replaced with always-on PeekConsoleInput approach.
- **Undefined `$gotCursorPos` variable** - The main loop checked `if ($gotCursorPos)` which was never defined, causing coordinate conversion to always be skipped.
- **`$mousePoint` vs `$mousePos` variable mismatch** - Code retrieved mouse position into `$mousePos` but attempted to read from `$mousePoint`, which was never populated.
- **Quit dialog click detection** - `$keyProcessed` and `$char` were reset immediately after being set by `$script:DialogButtonClick`, wiping out the click result.
- **Click detection broke after Modify Movement dialog** - Added `$script:DialogButtonBounds = $null` cleanup on dialog close.
- **Window resize triggered quit dialog** - Resolved by switching to PeekConsoleInput, which only fires MOUSE_EVENT records when the console is focused.
- **Button bounds tightened to visible characters** - Click areas now correspond exactly to rendered emoji+pipe+text characters.
- **UI strobing/flicker** - Replaced 55-80 `Write-Host` calls per frame with single VT100 `[Console]::Write()` call, reducing frame render time from 55-160ms to sub-millisecond.
- **Grey background on default areas** - VT100 renderer now uses ANSI code 49 (default background) instead of mapping `[Console]::BackgroundColor` to an explicit color.
- **Emoji background on 2-column emoji** - `Write-Buffer -Wide` appends a trailing space with the background color for wide emojis; the explicit pipe positioning overwrites the space.
- **Hidden view resize crash** - `SetCursorPosition` out-of-bounds during resize replaced by VT100 positioning (no exception possible).
- **Hidden view strobing** - Full-frame clear+redraw now atomic via `Flush-Buffer -ClearFirst`.

---

## [4ddbfc2] - 2026-02-21

### Commit Message
"Evidence-based input detection, security hardening, scroll/mouse hook removal"

Changes since commit 3f27144 ("still working towords initial release"):

### Added
- `mJiggAPI.LASTINPUTINFO` struct, `GetLastInputInfo`, and `GetTickCount64` P/Invoke for passive system-wide input detection
- `mJiggAPI.KEY_EVENT_RECORD` struct for reading keyboard events from the console input buffer
- `KEY_EVENT_RECORD` overlay added to `INPUT_RECORD` union (at FieldOffset 4, alongside MouseEvent)
- `PeekConsoleInput`-based keyboard event detection -- reads KEY_EVENT records (EventType 0x0001) from the console input buffer to provide evidence-based keyboard detection without scanning key codes
- `PeekConsoleInput`-based scroll wheel detection -- reads MOUSE_EVENT records with scroll flag (EventType 0x0002, dwEventFlags 0x0004)
- Mouse movement inference via `GetLastInputInfo` -- when system activity is detected but no keyboard, scroll, or click evidence exists, it is classified as mouse movement
- Console input buffer flush after simulated keypress to prevent stale Right Alt events from being detected as user keyboard input
- `_diag/input.txt` diagnostic log for PeekConsoleInput + GetLastInputInfo detection
- `.gitignore` to exclude `_diag/` folder and backup files from git

### Changed
- **Input Detection Architecture**: Complete overhaul of input classification. All input types are now evidence-based:
  - **Keyboard**: Detected via `PeekConsoleInput` KEY_EVENT records (filtered for simulated VK 0xA5). Only peeked, not consumed, so menu hotkey handler can still read them.
  - **Scroll**: Detected via `PeekConsoleInput` MOUSE_EVENT with scroll flag. Consumed to prevent buffer buildup.
  - **Mouse clicks**: Detected via `GetAsyncKeyState` VK 0x01-0x06 (unchanged).
  - **Mouse movement**: Detected via `Test-MouseMoved` position polling or inferred by `GetLastInputInfo` when no other input type explains the activity.
  - **`GetLastInputInfo`**: No longer infers "keyboard" -- only sets `$script:userInputDetected` and infers mouse movement by elimination.
- **Mouse movement display label**: Changed from emoji (🐀) to text "Mouse" in the detected inputs display
- **Scroll/Input Detection**: Replaced system-wide low-level mouse hook (`WH_MOUSE_LL` / `mJiggAPI.MouseHook`) with `PeekConsoleInput` + `GetLastInputInfo`-based detection. Uses `GetTickCount64` for 64-bit tick math to avoid overflow on systems with >24.9 days uptime.
- **Diagnostics folder**: Moved from `$env:TEMP\mjig_diag\` to `_diag/` relative to the script location, so agents and users can access logs directly in the project directory
- Resize quote color changed from `DarkGray` to `White`

### Removed
- `mJiggAPI.MouseHook` class and all associated P/Invoke definitions (`SetWindowsHookEx`, `UnhookWindowsHookEx`, `CallNextHookEx`, `GetModuleHandle`, `PeekMessage`, `MSG`, `MSLLHOOKSTRUCT`, `LowLevelMouseProc`)
- `$PreviousMouseWheelDelta` tracking variable (no longer needed)
- Mouse hook install/uninstall/ProcessMessages calls from initialization, debug pause, and main loop
- Keyboard inference from `GetLastInputInfo` -- the flawed "if not mouse, must be keyboard" logic has been removed entirely

### Fixed
- Mouse cursor lag during debug "press any key" pause and potentially during busy main loop sections, caused by `WH_MOUSE_LL` hook starving the system message pump
- False "Keyboard" labels appearing when only mouse movement or scroll wheel was used -- caused by `GetLastInputInfo` incorrectly defaulting to keyboard when `Test-MouseMoved` had brief polling gaps
- Menu hotkeys not responding -- `PeekConsoleInput` was consuming KEY_EVENT records from the buffer before the menu hotkey handler (`$Host.UI.RawUI.ReadKey`) could read them. Fixed by only peeking (not consuming) keyboard events.

### Security
- **Removed `Get-KeyName` function** -- eliminated VK-code-to-name mapping table that security scanners flag as keylogger pattern
- **Removed full 256-code `GetAsyncKeyState` keyboard scan** -- the `for ($keyCode = 0; $keyCode -le 255; ...)` loop that polled every virtual key code every ~50ms has been replaced with a focused mouse-button-only loop (VK 0x01-0x06)
- **Removed `GetAsyncKeyState` from `Keyboard` class** -- the API is now only exposed in the `Mouse` class, reducing the P/Invoke surface
- **Removed `PressedKeys` real-time display scan** -- the secondary 256-code scan that populated real-time key state for the stats box has been removed entirely
- **Keyboard detection now evidence-based** -- `$keyboardInputDetected` is set only when actual KEY_EVENT records are found in the console input buffer via `PeekConsoleInput`. No key identity is captured beyond filtering the simulated VK 0xA5.
- **Stats box shows categories, not key names** -- "Detected Inputs" now displays `Mouse`, `Keyboard`, `LButton`, `Scroll/Other` etc. instead of specific key names like `A, LShift, Space`
- **Removed `$PressedKeys` and `$intervalKeys`** -- variables that accumulated specific key names are removed; only boolean flags and category labels remain

---

## [3f27144] - 2026-02-21

### Commit Message
"still working towords initial release, there is now a changelog.md for better tracking of changes across commits. and a context.md for quicker training of agents."

Changes since commit 8014293 ("a bit broken but with a bunch of updates"):

### Added

#### New Parameters
- `-DebugMode` switch - Enables verbose logging during initialization and runtime
- `-Diag` switch - Enables file-based diagnostics to `$env:TEMP\mjig_diag\`
- `-EndVariance` (int) - Random variance in minutes for end time
- `-IntervalSeconds` (double) - Base interval between movement cycles (was hardcoded)
- `-IntervalVariance` (double) - Random variance for intervals (was hardcoded)
- `-MoveSpeed` (double) - Movement animation duration in seconds
- `-MoveVariance` (double) - Random variance for movement speed
- `-TravelDistance` (double) - Cursor travel distance in pixels
- `-TravelVariance` (double) - Random variance for travel distance
- `-AutoResumeDelaySeconds` (double) - Cooldown timer after user input

#### New Functions
- `Get-KeyName` - Standalone helper function for mapping VK codes to readable names *(removed in latest -- see Security section)*
- `Find-WindowHandle` - Window handle lookup using EnumWindows
- `Get-Padding` - Calculate padding for dialog layouts
- `Get-TimeSinceMs` - Calculate milliseconds elapsed since a timestamp
- `Get-ValueWithVariance` - Generate random values with variance
- `Get-MousePosition` - Wrapper for GetCursorPos API
- `Test-MouseMoved` - Check if mouse has moved beyond threshold
- `Draw-DialogShadow` / `Clear-DialogShadow` - Dialog drop shadow rendering
- `Write-SimpleDialogRow` / `Write-SimpleFieldRow` - Dialog row rendering helpers
- `Show-MovementModifyDialog` - Runtime movement settings modification
- `Show-QuitConfirmationDialog` - Quit confirmation with runtime stats
- `Show-TimeChangeDialog` - Runtime end time modification
- `Draw-ResizeLogo` - Centered logo during window resize

#### New Features
- **Theme System**: Centralized color variables (`$script:MenuButton*`, `$script:Header*`, `$script:StatsBox*`, `$script:QuitDialog*`, `$script:TimeDialog*`, `$script:MoveDialog*`, `$script:Resize*`, `$script:Text*`)
- **Box-Drawing Characters**: All box chars now use `[char]` casts to avoid encoding issues
- **Duplicate Instance Detection**: Prevents running multiple mJig instances
- **Mouse Click Support**: Menu items and dialog buttons are clickable
- **Menu Item Bounds Tracking**: `$script:MenuItemsBounds` for click detection
- **Stats Box**: Real-time display of detected keyboard/mouse inputs (full view)
- **Window Resize Handling**: Clears screen, shows centered logo with decorative box
- **Resize Quotes**: Random playful quotes displayed during resize (`$script:ResizeQuotes`)
- **Mouse Stutter Prevention**: Waits for mouse to "settle" before starting next movement cycle
- **Movement Animation**: Smooth cursor movement with configurable speed
- **Auto-Resume Delay**: Configurable cooldown after user input before resuming automation
- **Diagnostics System**: File-based logging to `$env:TEMP\mjig_diag\` with `-Diag` flag

#### New P/Invoke Types
- `mJiggAPI.POINT` - Coordinate struct
- `mJiggAPI.RECT` - Rectangle struct
- `mJiggAPI.COORD` - Console coordinate struct
- `mJiggAPI.CONSOLE_SCREEN_BUFFER_INFO` - Console buffer info
- `mJiggAPI.MOUSE_EVENT_RECORD` - Mouse event data
- `mJiggAPI.INPUT_RECORD` - Input record union
- `mJiggAPI.SMALL_RECT` - Small rectangle struct
- `mJiggAPI.Keyboard` - Keyboard APIs (GetAsyncKeyState, keybd_event) *(GetAsyncKeyState later moved to Mouse class -- see latest)*
- `mJiggAPI.Mouse` - Mouse/Window APIs (GetCursorPos, SetCursorPos, FindWindow, EnumWindows, etc.)
- `mJiggAPI.MouseHook` - Mouse wheel hook (WH_MOUSE_LL)

#### New Documentation
- `CHANGELOG.md` - Structured change tracking across commits
- `resources/AGENT.md` - Deep codebase context for AI agents
- `README.md` - Rewritten with full parameter table, usage examples, and architecture notes

### Changed

#### Parameters
- `-endTime` renamed to `-EndTime`, default changed from `"2400"` to `"0"` (no end time)
- `-Output` default changed from `"full"` to `"min"`
- Added `ValidateSet` for `-Output`: `"min"`, `"full"`, `"hidden"`, `"dib"`

#### Code Structure
- Moved from simple inline code to modular helper functions
- Parameters now copied to `$script:` variables for runtime modification
- Configuration section removed (settings now exposed as parameters)
- Variable naming standardized to PascalCase (`$lastPos` → `$LastPos`)
- P/Invoke types moved to `mJiggAPI` namespace with full struct definitions

#### UI
- Header now shows app icon (🐀) and view mode indicator
- Menu bar with emoji icons and colored hotkeys
- Interactive dialogs with drop shadows and themed colors
- Log entries use component-based structure for dynamic truncation

### Removed
- "Ideas & Notes" comment block
- Hardcoded configuration variables (`$defualtEndTime`, `$defualtEndMaxVariance`, `$intervalSeconds`, `$intervalVariance`)
- Simple `Keyboard` class (replaced by `mJiggAPI.Keyboard`)
- Direct cursor position access (replaced by helper functions)

### Fixed
- Encoding issues with box-drawing characters (now use `[char]` casts)
- Mouse stutter when movement cycle starts while user is moving mouse
- Console buffer size issues during window resize

---

## [8014293] - 2026-02-10

### Commit Message
"a bit broken but with a bunch of updates"

*This commit represents the baseline. Changes documented in [3f27144] above are relative to this commit.*

---

## [06f12d6] - 2026-01-22

### Commit Message
"major feature changes and bug fixes"

*Details not available - this was the state before 8014293.*

---

## Format Guidelines

When adding to this changelog:

1. **Latest Section**: Always add new changes under `[Latest] - Unreleased`
2. **On Commit**: Move `[Latest]` content to a new versioned section with commit hash and date
3. **Categories**: Use Added, Changed, Removed, Fixed, Deprecated, Security
4. **Be Specific**: Include function names, parameter names, line numbers where helpful
5. **Group Related**: Group related changes under descriptive subheadings
