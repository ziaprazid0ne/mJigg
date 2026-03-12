# mJig Code Context for AI Agents

This document provides deep context for AI agents working on the mJig codebase.

> **LINTER ERRORS**: Every linter error and warning MUST be fixed. After ANY edit, check lints on every file you touched. NEVER dismiss errors as "false positives", "pre-existing", "expected", or "safe to ignore". If the linter reports it, fix it. No exceptions.

> **IMPORTANT FOR AI AGENTS**: When modifying mJig source files, you must also update this `AGENTS.md` file and `README.md` to reflect any changes. This includes:
> - New or modified parameters
> - New or renamed functions
> - New files added to the `Private/` tree
> - New features or behaviors
> - New theme colors or UI components
> - Changes to hotkeys or interactive controls
> - New gotchas or patterns discovered during development
>
> Keeping documentation in sync prevents knowledge drift and ensures future AI agents have accurate context.

> **COMMIT WORKFLOW**: When the user says they are ready to commit (e.g. "I have everything staged", "please commit"), follow this process:
> 1. Run `git status` and `git log --oneline -5` to see staged files and recent commit style.
> 2. Write a commit message: first line is a concise summary of the biggest feature changes. Body is a bulleted list of key changes. End with "See CHANGELOG.md for full details."
> 3. Write the message to a temp file (`_commit_msg.txt`) and use `git commit -F _commit_msg.txt` (PowerShell does not support heredoc in git commands). Delete the temp file after.
> 4. Verify with `git status` that the working tree is clean.
> 5. **After the commit is confirmed**, prep `CHANGELOG.md` for the next commit:
>    - Move the current `[Latest] - Unreleased` content into a new versioned section with the commit hash and today's date.
>    - Replace `[Latest] - Unreleased` with a fresh empty section referencing the new commit.
>    - Do NOT stage or commit this changelog prep -- it becomes the starting point for the next round of changes.
>
> The user expects this full workflow every time. Do not skip the changelog prep step.

---

## Architecture Overview

The module is a multi-file PowerShell module implementing a console-based TUI mouse jiggler. It uses Win32 API calls via P/Invoke for low-level mouse/keyboard interaction. Every invocation automatically runs inside a fresh, isolated runspace provisioned by the module itself (see Module Runspace Provisioner below).

### Multi-File Structure

The codebase is split across ~39 files under `Start-mJig/Private/`. The skeleton `Start-mJig.psm1` (~3,000 lines) contains the `Start-mJig` function entry point, parameter block, Module Runspace Provisioner, variable initialization, and the main loop. All helper functions and large config sections are dot-sourced from individual `.ps1` files **inside** the `Start-mJig` function body, preserving PowerShell's scope chain so nested functions can access `$script:` and parent-scope variables without refactoring.

**Build pipeline:** `Start-mJig/Build/Build-Module.ps1` recombines all dot-sourced files into a single monolithic `.psm1` in `dist/`. GitHub Actions (`.github/workflows/build.yml`) runs this on `v*` tag push and creates a release. The `dist/` folder is git-ignored.

**Development vs release:** During development, `Import-Module .\Start-mJig` loads the skeleton which dot-sources individual files at runtime. For releases, the build script produces a single-file `.psm1` that is functionally identical.

### IPC Background Worker Architecture

By default, `Start-mJig` spawns a hidden background worker process that performs the actual mouse jiggling, then the calling terminal becomes a viewer connected to the worker via a named pipe with a SHA256-derived hex name (no 'mJig' string in the pipe name). This allows the worker to persist independently of the terminal.

**Behavior matrix:**
- **`Start-mJig`** (no running instance): Spawns hidden worker, enters viewer mode
- **`Start-mJig`** (instance running): Connects to existing worker as a viewer
- **`Start-mJig -Headless`** (no running instance): Spawns hidden worker, exits immediately
- **`Start-mJig -Headless`** (instance running): Exits immediately
- **`Start-mJig -Inline`**: Legacy single-process mode, no IPC
- **`Start-mJig -_WorkerMode`** (internal): Headless worker entry point

**IPC protocol:** JSON lines over `NamedPipeServerStream` / `NamedPipeClientStream`. All messages are encrypted with AES-256-CBC (per-message random IV) via `Protect-PipeMessage` / `Unprotect-PipeMessage`. The first message from the viewer is an auth handshake containing the `$script:PipeAuthToken`; the worker validates it before accepting the connection. Worker sends `welcome`, `state` (every 500ms), `log`, and `stopped` messages. Viewer sends `settings`, `endtime`, `output`, `title`, and `quit` commands. State messages include `mouseInputDetected`, `keyboardInputDetected`, `keyboardInferred`, `userInputDetected`, `cooldownActive`, `cooldownRemaining`, and `epoch` so the viewer can display live input detection and cooldown status and discard stale state messages.

**Key functions:**
- `Start-WorkerLoop` — headless jiggling loop with pipe server; accepts one viewer at a time. Resilient pipe reconnection: all `BeginWaitForConnection` calls are wrapped in try/catch; if the call fails (e.g. broken pipe after abrupt viewer death), the `NamedPipeServerStream` is disposed and recreated from scratch. All `NamedPipeServerStream` instances use 64KB (65536) in/out buffer sizes to prevent pipe saturation during viewer dialog interactions.
- `Connect-WorkerPipe` — connection-only function; returns pipe client/reader/writer or `$null` on failure. The welcome handshake uses a synchronous `ReadLine()` (not `Read-PipeMessage`'s async path) to avoid racing async and sync reads on the same stream. If the connection fails, `Show-DiagnosticFiles` is called before returning when `-Diag` is enabled.
- `Send-PipeMessage` / `Read-PipeMessage` — JSON-line IPC helpers. `Read-PipeMessage` uses asynchronous `ReadLineAsync()` with a `[ref]$PendingTask` parameter to prevent blocking on named pipes when no data is available. Each caller maintains its own pending task variable (`$_workerReadTask` / `$_viewerReadTask`).
- `Send-PipeMessageNonBlocking` — async write variant using `FlushAsync()` with a `[ref]$PendingFlush` pattern. If a previous flush hasn't completed (viewer not draining, e.g. during a dialog), the message is skipped instead of blocking the worker. Used for periodic `state` and `log` messages. Critical messages (`welcome`, `stopped`, log replay) use synchronous `Send-PipeMessage`. The `$_pendingWriteFlush` variable is reset at all disconnect/reconnect paths and on new viewer connect.
- `New-SecurePipeServer` — creates `NamedPipeServerStream` with `PipeSecurity` ACL restricting access to the current user. Includes a try/catch fallback: if `PipeSecurity` is unavailable (e.g., missing `System.IO.Pipes.AccessControl` on some .NET runtimes), falls back to creating the pipe without ACL.
- `Protect-PipeMessage` / `Unprotect-PipeMessage` — AES-256-CBC encryption/decryption with per-message random IV
- `Get-SessionIdentifier` — SHA256-based session identifier derivation; produces pipe name, encryption key, and auth token from a single hash

**Worker process spawning:** Uses `Invoke-CimMethod -ClassName Win32_Process -MethodName Create` (WMI) to spawn the worker outside the terminal's job object, ensuring the worker survives when the viewer terminal tab is closed. Falls back to `Start-Process` if WMI is unavailable. The executable path is determined dynamically via `[System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName` to match the running PowerShell version (pwsh.exe on PS 7, powershell.exe on 5.1). The worker command is passed via `-EncodedCommand` (Base64-encoded script block) instead of `-Command` to avoid shell escaping issues.

**Worker input detection bootstrap:** `GetLastInputInfo` and mouse position tracking in the worker are guarded with `if ($null -ne $workerLastAutomatedMouseMovement)`. This skips input detection until the first automated movement completes, preventing a permanent "User input skip" deadlock where the null filter timestamps cause every system tick to be classified as user input.

**Settings epoch guard (stale state message prevention):**
After a viewer dialog closes, the viewer sends new settings to the worker and returns to the main loop. The pipe buffer may contain stale `state` messages (sent before the worker processed the new settings) that would overwrite the viewer's local variables with pre-change values. The epoch guard prevents this:
- Viewer increments `$_settingsEpoch` before each settings/endtime/output send, and includes `epoch` in the message.
- Worker captures `$_workerSettingsEpoch` from incoming commands and includes it in every outgoing `state` message.
- Viewer state handlers check `if ($msg.epoch -lt $_settingsEpoch) { break }` to skip stale state messages. Log and stopped messages are always processed regardless of epoch.
- The epoch is incremented at all 6 viewer send sites: `s` hotkey settings (3 messages), `m` hotkey movement settings, `t` hotkey endtime, `v`/`o` output toggle, incognito toggle, and the PendingReopenSettings path.

**Viewer main loop integration (`$_isViewerMode`):**
When the viewer connects (via `Connect-WorkerPipe`), it sets `$_isViewerMode = $true` and falls through into the existing main loop. The main loop checks `$_isViewerMode` at key points:
- **IPC reading**: At the top of each iteration and inside each 50ms wait tick, reads `state`, `log`, and `stopped` messages from the worker pipe. Updates `$script:*` variables, `$LogArray`, `$mouseInputDetected`, `$keyboardInputDetected`, `$script:PreviousIntervalKeys`, `$cooldownActive`, `$secondsRemaining`, and `$SkipUpdate` directly from the worker's state messages.
- **Skips**: Interval calculation (uses fixed 500ms/10 ticks), movement-specific per-tick checks (keyboard state, mouse position, GetLastInputInfo), post-wait mouse settle, movement execution, log building, and end-time check.
- **Keeps**: Full rendering via `Draw-MainFrame`, resize detection, console input handling (PeekConsoleInput for clicks, ReadKey for hotkeys), all dialog invocations, and stats box display (populated from IPC state).
- **IPC forwarding**: After dialog results (quit, time, movement, output, settings, title), the viewer increments `$_settingsEpoch` and sends the changes (with `epoch`) back to the worker via the pipe. The `title` message carries `windowTitle` (string) and `titleEmoji` (int codepoint) so the worker's notifications match the viewer's current title preset. During dialogs, the viewer's main loop is suspended (dialog has its own input loop), so IPC messages from the worker accumulate in the 64KB pipe buffer. The worker uses `Send-PipeMessageNonBlocking` to avoid blocking when the buffer fills. After the dialog closes, the viewer returns to the main loop and drains the backed-up messages. The **settings epoch guard** causes the viewer to skip any `state` message whose `epoch` is less than its own `$_settingsEpoch`, preventing stale pre-change values from overwriting the viewer's local variables.

### High-Level Flow

```
1. Import-Module Start-mJig  (loads module, defines Start-mJig function)
2. Caller invokes Start-mJig [...params...]
3. Module Runspace Provisioner fires (if not already inside the module runspace):
   a. Create InitialSessionState::CreateDefault2() — no profile, no PSModulePath modules
   b. Create Runspace with current $Host (preserves console TUI access), ApartmentState=STA
   c. Import-Module into the new runspace; call Start-mJig -_InModuleRunspace $true + forwarded params
   d. Invoke() blocks; finally disposes runspace on exit
4. Inside the provisioned runspace, $_InModuleRunspace=$true skips the provisioner
5. Mutex check:
   a. Mutex NOT acquired + not -_WorkerMode → set $_viewerReconnect flag (viewer reconnect path)
   b. Mutex acquired → continue initialization
6. Console setup (skipped for -_WorkerMode; startup screen skipped for viewer reconnect)
7. Load assemblies (System.Windows.Forms), define P/Invoke types
8. Initialize variables, theme colors, parse end time
9. Define helper functions (including IPC helpers, Start-WorkerLoop, Connect-WorkerPipe)
10. IPC Mode Branching:
    a. -_WorkerMode → write worker-startup diag checkpoints [1]-[5] (if -Diag), Start-WorkerLoop
       (headless IPC server + jiggling loop), wrapped in try/catch that logs [FATAL] to both
       worker-startup.txt and worker-ipc.txt, then return
    b. $_viewerReconnect → Connect-WorkerPipe, set $_isViewerMode = $true, fall through to main loop
       (if connection fails and -Diag, calls Show-DiagnosticFiles then returns)
    c. -Inline not set + mutex acquired → Spawn hidden worker via WMI (Invoke-CimMethod Win32_Process),
       Connect-WorkerPipe (15s timeout), set $_isViewerMode = $true, fall through to main loop
       (if connection fails and -Diag, calls Show-DiagnosticFiles then returns)
    d. -Inline + mutex acquired → fall through to main loop (inline mode, $_isViewerMode = $false)
11. Show-StartupScreen / Show-StartupComplete (inline mode only)
12. Initialize $oldWindowSize / $OldBufferSize to current state
13. Enter main processing loop (dual-mode: inline OR viewer)
    ├── Viewer IPC: read state/log/stopped messages from worker (viewer mode only)
    ├── Wait for interval (inline: calculated; viewer: fixed 500ms)
    ├── Per-tick: read IPC messages (viewer) / check keyboard/mouse state (inline)
    ├── Check for user input / hotkeys + forward to worker (viewer)
    ├── Detect window resize → Invoke-ResizeHandler → Draw-MainFrame (both modes)
    ├── Wait for mouse to settle (inline only)
    ├── Perform automated mouse movement (inline only)
    ├── Send simulated keypress (inline only)
    ├── Render UI (header, logs, stats, menu) — SAME CODE, both modes
    └── Check end time (inline only; viewer uses IPC 'stopped' message)
14. Cleanup: pipe disposal (viewer mode) → Show-DiagnosticFiles prompt (if -Diag) → mutex release → provisioner's finally block disposes the runspace
```

### Code Structure Map

```
Start-mJig/
├── Start-mJig.psd1                             Module manifest (unchanged)
├── Start-mJig.psm1                             Skeleton (~3,000 lines)
│   └── Start-mJig function
│       ├── Parameters
│       ├── Module Runspace Provisioner
│       ├── Initialization Variables + box-drawing chars
│       ├── . Private\Config\Initialize-Theme.ps1
│       ├── . Private\Startup\Show-StartupScreen.ps1
│       ├── . Private\Startup\Show-StartupComplete.ps1
│       ├── . Private\Startup\Get-LatestVersionInfo.ps1
│       ├── . Private\Helpers\Invoke-ResizeHandler.ps1
│       ├── Mutex check + Console setup
│       ├── . Private\Config\Initialize-PInvoke.ps1
│       ├── End Time Calculation
│       ├── . Private\Helpers\Get-SmoothMovementPath.ps1
│       ├── . Private\Helpers\Get-DirectionArrow.ps1
│       ├── . Private\Rendering\*.ps1           (11 files)
│       ├── . Private\Dialogs\Show-TimeChangeDialog.ps1
│       ├── . Private\Helpers\Restore-ConsoleInputMode.ps1
│       ├── . Private\Helpers\Send-ResizeExitWakeKey.ps1
│       ├── . Private\Helpers\Show-DiagnosticFiles.ps1
│       ├── . Private\Rendering\Draw-ResizeLogo.ps1
│       ├── . Private\Rendering\Draw-MainFrame.ps1
│       ├── . Private\Helpers\*.ps1             (remaining helpers)
│       ├── . Private\IPC\*.ps1                 (5 files)
│       ├── . Private\Helpers\Get-Padding.ps1
│       ├── . Private\Rendering\Write-Section*.ps1 + Write-SimpleField*.ps1
│       ├── . Private\Dialogs\*.ps1             (remaining 4 dialogs)
│       ├── IPC Mode Branching
│       ├── Main Loop (:process while)
│       │   ├── Global Hotkey Polling (standalone only; worker handles in viewer mode)
│       │   ├── Viewer IPC read + state update (incl. togglePause/stopped from worker)
│       │   ├── Wait Loop (50ms ticks)
│       │   ├── Mouse Settle Detection (inline only)
│       │   ├── Movement Execution (inline only)
│       │   ├── UI Rendering → Draw-MainFrame
│       │   └── End Time Check (inline only)
│       └── Cleanup (pipe, Show-DiagnosticFiles if -Diag, mutex, runspace)
│
├── Private/
│   ├── Config/
│   │   ├── Initialize-Theme.ps1                Theme color variables (~230 lines)
│   │   └── Initialize-PInvoke.ps1              C# P/Invoke types + Add-Type (~440 lines)
│   ├── Startup/
│   │   ├── Show-StartupScreen.ps1              Pre-VT100 "Initializing…" screen
│   │   ├── Show-StartupComplete.ps1            "Init Complete" box (nested: drawCompleteScreen, getSize, drainWakeKeys)
│   │   └── Get-LatestVersionInfo.ps1           GitHub release check (cached)
│   ├── Rendering/
│   │   ├── Write-Buffer.ps1                    Queue positioned, colored text segments
│   │   ├── Flush-Buffer.ps1                    Build VT100 string + atomic [Console]::Write()
│   │   ├── Clear-Buffer.ps1                    Discard queued segments
│   │   ├── Write-ButtonImmediate.ps1           Instant button redraw (click feedback)
│   │   ├── Write-HotkeyLabel.ps1              Hotkey-parsed label renderer (split + highlight)
│   │   ├── Draw-DialogShadow.ps1               Offset shadow effect
│   │   ├── Clear-DialogShadow.ps1              Remove shadow
│   │   ├── Draw-ResizeLogo.ps1                 Resize splash logo
│   │   ├── Draw-MainFrame.ps1                  Full main UI renderer (~940 lines)
│   │   ├── Write-SectionLine.ps1               Section divider row
│   │   ├── Write-SimpleDialogRow.ps1           Dialog content row
│   │   └── Write-SimpleFieldRow.ps1            Dialog input field row
│   ├── Dialogs/
│   │   ├── Show-TimeChangeDialog.ps1           End time editor (~680 lines)
│   │   ├── Show-MovementModifyDialog.ps1       Movement parameter editor (~765 lines)
│   │   ├── Show-QuitConfirmationDialog.ps1     Quit confirmation (~460 lines)
│   │   ├── Show-SettingsDialog.ps1             Settings slide-up (~490 lines)
│   │   ├── Show-InfoDialog.ps1                 About & version (~300 lines)
│   │   └── Show-OptionsDialog.ps1              Options sub-dialog
│   ├── IPC/
│   │   ├── Send-PipeMessage.ps1                Synchronous JSON-line write
│   │   ├── Read-PipeMessage.ps1                Async ReadLineAsync reader
│   │   ├── Send-PipeMessageNonBlocking.ps1     FlushAsync writer (skips on backpressure)
│   │   ├── Start-WorkerLoop.ps1                Headless IPC server + jiggling loop (~500 lines)
│   │   ├── Connect-WorkerPipe.ps1              Pipe connection + welcome handshake
│   │   ├── New-SecurePipeServer.ps1            ACL-restricted named pipe server creation
│   │   └── Protect-PipeMessage.ps1             AES-256-CBC encrypt/decrypt helpers
│   └── Helpers/
│       ├── Get-SessionIdentifier.ps1           SHA256-based session identifier derivation
│       ├── Get-SmoothMovementPath.ps1          Ease-in-out-cubic path generator
│       ├── Get-DirectionArrow.ps1              Movement direction arrow emoji
│       ├── Get-CachedMethod.ps1                Reflection method cache
│       ├── Get-MousePosition.ps1               Cursor position via GetCursorPos
│       ├── Test-MouseMoved.ps1                 Position change detection
│       ├── Get-TimeSinceMs.ps1                 Millisecond elapsed time
│       ├── Get-ValueWithVariance.ps1           Random variance helper
│       ├── Set-CoordinateBounds.ps1            Click region bounds helper
│       ├── Get-Padding.ps1                     Padding string generator
│       ├── Invoke-ResizeHandler.ps1            Blocking resize handler
│       ├── Restore-ConsoleInputMode.ps1        Re-enable ENABLE_MOUSE_INPUT
│       ├── Send-ResizeExitWakeKey.ps1          Inject VK_RMENU wake event
│       ├── Show-DiagnosticFiles.ps1            Post-exit diag file dump (countdown prompt)
│       ├── Add-DebugLogEntry.ps1               Standardized debug log entry creation
│       ├── Get-DialogButtonLayout.ps1          Dialog button width calculations
│       ├── Get-DialogMouseClick.ps1            Dialog mouse click detection via PeekConsoleInput
│       ├── Read-DialogKeyInput.ps1             Dialog key-up event reader
│       ├── Invoke-DialogExitCleanup.ps1        Dialog close cleanup (shadow, area, cursor, state)
│       ├── Invoke-PostDialogCleanup.ps1        Post-dialog redraw flag setup (no clear-host; see §3a)
│       ├── Invoke-CursorMovement.ps1           Shared cursor animation loop with drift detection
│       ├── Show-Notification.ps1               Windows toast notification via NotifyIcon + Dispose-Notification
│       └── Test-GlobalHotkey.ps1               Global hotkey polling (Shift+M+P / Shift+M+Q) via GetAsyncKeyState
│
└── Build/
    └── Build-Module.ps1                        Combines all files into single .psm1
```

---

## Key Concepts

### 1. Script-Scoped Variables

Parameters are copied to `$script:` variables because PowerShell parameters are read-only:

```powershell
$script:IntervalSeconds = $IntervalSeconds
$script:MoveSpeed = $MoveSpeed
$script:TravelDistance = $TravelDistance
```

These can be modified at runtime via the Modify Movement dialog. When accessing these in nested functions, always use the `$script:` prefix.

**Common script-scoped variables:**
- `$script:IntervalSeconds`, `$script:IntervalVariance` - Timing
- `$script:MoveSpeed`, `$script:MoveVariance` - Animation speed
- `$script:TravelDistance`, `$script:TravelVariance` - Movement distance
- `$script:AutoResumeDelaySeconds` - User input cooldown
- `$script:Output` - Current output mode (`"min"` / `"full"` / `"hidden"`); synced from/to local `$Output` at settings dialog close and on incognito/output-toggle hotkeys
- `$script:DebugMode` - Current debug mode flag (`[bool]`); synced from/to local `$DebugMode` at settings dialog close
- `$script:BorderPadV` - Blank-row border thickness above/below header+footer chrome groups (min 1)
- `$script:BorderPadH` - Blank-column border thickness left/right of every chrome row (min 1)
- `$script:HeaderBg`, `$script:FooterBg` - Group background colors for 3-row header / footer blocks
- `$script:HeaderRowBg`, `$script:MenuRowBg` - Per-row background colors (inset by `$_bpH`, do not bleed into padding)
- `$script:DiagEnabled` - Diagnostics flag
- `$script:DiagFolder` - Path to `_diag/` folder (set when `-Diag` enabled)
- `$script:StartupDiagFile` / `$script:SettleDiagFile` / `$script:InputDiagFile` / `$script:IpcDiagFile` / `$script:NotifyDiagFile` - Per-subsystem diag file paths (set when `-Diag` enabled)
- `$script:LoopIteration` - Main loop counter
- `$script:MenuItemsBounds` - `System.Collections.Generic.List[hashtable]` for click detection bounds; each entry carries `displayText`, `format`, `fg`, `bg`, `hotkeyFg`, `onClickFg`, `onClickBg`, `onClickHotkeyFg`. Use `.Clear()` and `.Add()` — never `= @()` or `+=`.
- `$script:MenuClickHotkey` - Menu item hotkey triggered by mouse click
- `$script:ConsoleClickCoords` - Character cell X/Y from last PeekConsoleInput left-click event
- `$script:PressedMenuButton` - Hotkey of the menu button currently held down (LMB pressed); cleared when pressed state is restored
- `$script:ButtonClickedAt` - `[DateTime]` timestamp of a confirmed click (UP over button); used alongside `PendingDialogCheck`
- `$script:PendingDialogCheck` - `$true` after a confirmed click; render loop clears it on the first execution after the action, immediately restoring the button color unless a dialog is open
- `$script:LButtonWasDown` - Tracks previous LMB state from console `PeekConsoleInput` events for UP-transition detection
- `$script:RenderQueue` - `System.Collections.Generic.List[hashtable]` used by buffered rendering (`Write-Buffer`/`Flush-Buffer`)
- `$script:ESC` - `[char]27` for VT100 escape sequences
- `$script:CursorVisible` - Boolean tracking cursor visibility state for VT100 sequences
- `$script:AnsiFG` / `$script:AnsiBG` - ConsoleColor-to-ANSI SGR code lookup hashtables
- `$script:LastMouseMovementTime` - Stutter prevention timing
- `$script:ResizeQuotes` - Playful quotes array
- `$script:CurrentResizeQuote` - Currently displayed quote
- `$script:PipeName` - Named pipe identifier for IPC (SHA256-derived hex name, no 'mJig' string)
- `$script:SessionId` - Hashtable with `PipeName`, `AesKey`, `AuthToken` derived from SHA256
- `$script:PipeEncryptionKey` - AES-256 key (bytes 8–23 of session hash)
- `$script:PipeAuthToken` - Auth handshake token (bytes 24–31 of session hash)
- `$script:NotificationsEnabled` - Toggle for toast notifications (default `$true`)
- `$script:TitlePresets` - Array of hashtables `@{ Name = "..."; Emoji = 0x... }` — each built-in title disguise has an associated emoji codepoint
- `$script:TitlePresetIndex` - Current index in the preset cycle
- `$script:TitleEmoji` - Current title's emoji codepoint (int); used by the header, notification tray icon, and IPC sync
- `$script:MouseAPI` / `$script:KeyboardAPI` / `$script:ToastAPI` - Runtime type references for randomized P/Invoke namespace
- `$script:PointType` / `$script:LastInputType` / `$script:InputRecordType` / `$script:CSBIType` - String type names for `New-Object`
- `$script:_ApiNamespace` - Randomized namespace string (e.g. `"ns_a3f7c019b2e84d01"`)
- `$script:LogReplayBuffer` - `Queue[hashtable]` (capacity 30) in worker mode; replayed to viewer on connect
- `$_isViewerMode` - `$true` when running as a viewer connected to a background worker; controls main loop dual-mode behavior (local, not `$script:`)
- `$_viewerPipeClient` / `$_viewerPipeReader` / `$_viewerPipeWriter` - Pipe objects for viewer IPC (local)
- `$_viewerStopped` / `$_viewerStopReason` - Viewer stop state; reason is `'endtime'`, `'quit'`, `'disconnected'`, or `'pipe_error'`
- `$_workerReadTask` / `$_viewerReadTask` - Pending `ReadLineAsync()` tasks for non-blocking pipe reads (local; passed as `[ref]` to `Read-PipeMessage`)
- `$_pendingWriteFlush` - Pending `FlushAsync()` task for non-blocking state/log writes in worker (local; passed as `[ref]` to `Send-PipeMessageNonBlocking`). Reset on every viewer connect/disconnect.
- `$_writeSkipCount` - Counter for consecutive state messages skipped due to pending flush (worker; used for diagnostic logging)
- `$_settingsEpoch` - Incrementing counter on the viewer side; bumped before every settings/endtime/output send. State messages with `epoch < $_settingsEpoch` are discarded to prevent stale values from overwriting dialog changes.
- `$_workerSettingsEpoch` - Worker-side mirror of the viewer's epoch; captured from incoming `settings`, `endtime`, and `output` commands and included in all outgoing `state` messages.

### 2. P/Invoke (Platform Invoke)

The script defines Win32 API types in a C# code block via `Add-Type`. The `mJiggAPI` namespace is **randomized at startup** (e.g. `ns_a3f7c019b2e84d01`) to avoid type conflicts across sessions. The old `[mJiggAPI.Mouse]::` syntax is no longer used directly. Instead, types are accessed via script-scoped variables:

- `$script:MouseAPI` — runtime type reference for the Mouse class (replaces `[mJiggAPI.Mouse]`)
- `$script:KeyboardAPI` — runtime type reference for the Keyboard class (replaces `[mJiggAPI.Keyboard]`)
- `$script:ToastAPI` — runtime type reference for the Toast class (WinRT COM interop for toast notifications)
- `$script:PointType` — string type name for `New-Object` (replaces `mJiggAPI.POINT`)
- `$script:LastInputType` — string type name for `New-Object` (replaces `mJiggAPI.LASTINPUTINFO`)
- `$script:InputRecordType` — string type name for `New-Object` (replaces `mJiggAPI.INPUT_RECORD`)
- `$script:CSBIType` — string type name for `New-Object` (replaces `mJiggAPI.CONSOLE_SCREEN_BUFFER_INFO`)
- `$script:_ApiNamespace` — the randomized namespace string (e.g. `"ns_a3f7c019b2e84d01"`)

```powershell
# Mouse position
$point = New-Object $script:PointType
$script:MouseAPI::GetCursorPos([ref]$point)
$script:MouseAPI::SetCursorPos($x, $y)

# Mouse button state (only used for 0x01-0x06 mouse buttons)
$state = $script:MouseAPI::GetAsyncKeyState($keyCode)

# Simulate keypress
$script:KeyboardAPI::keybd_event($VK_RMENU, 0, 0, 0)  # Key down
$script:KeyboardAPI::keybd_event($VK_RMENU, 0, $KEYEVENTF_KEYUP, 0)  # Key up

# System-wide input detection (keyboard, mouse, scroll -- passive, no scanning)
$lii = New-Object $script:LastInputType
$lii.cbSize = [uint32][System.Runtime.InteropServices.Marshal]::SizeOf($lii)  # pass INSTANCE, not type
$script:MouseAPI::GetLastInputInfo([ref]$lii)

# Window detection
$handle = $script:MouseAPI::GetForegroundWindow()
$consoleHandle = $script:MouseAPI::GetConsoleWindow()
```

> **`Marshal.SizeOf` gotcha on .NET Core:** Never pass `($script:LastInputType -as [type])` to `[Marshal]::SizeOf()`. PowerShell resolves the generic `SizeOf<T>(T instance)` overload instead of `SizeOf(Type type)`, causing a `MethodInvocationException`. Always pass an already-created struct instance: `[Marshal]::SizeOf($lii)`.

**Key structs** (accessed via `$script:*Type` string variables with `New-Object`):
- `POINT` (`$script:PointType`) - X/Y coordinates
- `COORD` - Console coordinates (short X, short Y)
- `LASTINPUTINFO` (`$script:LastInputType`) - System idle time tracking (cbSize, dwTime)
- `KEY_EVENT_RECORD` - Console keyboard event (bKeyDown, wVirtualKeyCode, etc.)
- `MOUSE_EVENT_RECORD` - Console mouse event (dwMousePosition, dwEventFlags, etc.)
- `INPUT_RECORD` (`$script:InputRecordType`) - Console input union (EventType + MouseEvent/KeyEvent overlay at offset 4)

**Key APIs:**
- `GetCursorPos` / `SetCursorPos` - Mouse position read/write
- `GetAsyncKeyState` - Mouse button state only (VK 0x01-0x06); also used for Shift/Ctrl modifier checks
- `keybd_event` - Simulate key presses
- `GetLastInputInfo` - Passive system-wide last input timestamp (detects all input: keyboard, mouse, scroll)
- `PeekConsoleInput` / `ReadConsoleInput` - Console input buffer access for scroll and keyboard event detection
- `GetConsoleMode` / `SetConsoleMode` - Console input mode management; used by `Restore-ConsoleInputMode` to re-enable `ENABLE_MOUSE_INPUT` after `[Console]::Clear()` / `clear-host` operations strip it
- `FindWindow` / `EnumWindows` - Window handle lookup
- `GetForegroundWindow` - Currently active window
- `GetConsoleWindow` - This script's console window

### 2b. WinRT Toast API (COM Interop)

The Toast API provides native WinRT toast notifications from PowerShell 7 via raw COM interop — no subprocess, no WinRT projection. It lives in the same `Add-Type` block alongside Mouse and Keyboard and shares the randomized namespace.

**How it works:** The API manually manages WinRT activation using `combase.dll` P/Invoke functions (`WindowsCreateString`, `RoActivateInstance`, `RoGetActivationFactory`). COM interfaces are declared with `[ComImport]` + `InterfaceIsIUnknown`, with 3 manual `IInspectable` vtable stubs (`GetIids`, `GetRuntimeClassName`, `GetTrustLevel`) preceding each interface's real methods. All HSTRING parameters use raw `IntPtr` (not `UnmanagedType.HString`, which is broken in .NET 6+ P/Invoke). COM object parameters use `UnmanagedType.IUnknown`.

```powershell
# Single static method — build the XML, pass an AUMID, done
$script:ToastAPI::ShowToast($toastXml, $aumid)
```

**COM interfaces defined (vtable order matters!):**
- `IXmlDocumentIO` (`6CD0E74E-...`) — `LoadXml(IntPtr hstring)`
- `IToastNotificationFactory` (`04124B20-...`) — `CreateToastNotification(object xmlDoc)`
- `IToastNotificationManagerStatics` (`50AC103F-...`) — `CreateToastNotifier()`, `CreateToastNotifierWithId(IntPtr hstring)`, `GetTemplateContent(int)`
- `IToastNotifier` (`75927B93-...`) — `Show(object toast)`

> **Vtable order is critical.** The method order in the `[ComImport]` interface declaration must exactly match the WinRT IDL. For `IToastNotificationManagerStatics` the order is `CreateToastNotifier`, `CreateToastNotifierWithId`, `GetTemplateContent` — NOT alphabetical. Getting this wrong causes `AccessViolationException` (0xC0000005).

> **HString gotcha on .NET 6+:** `UnmanagedType.HString` and `UnmanagedType.IInspectable` compile but fail at runtime for P/Invoke parameters ("Invalid managed/unmanaged type combination"). Use `WindowsCreateString`/`WindowsDeleteString` from `combase.dll` to manually create/destroy HSTRINGs, and `Marshal.GetObjectForIUnknown` + `Marshal.Release` for IInspectable pointers.

**Emoji rendering** (`Toast.RenderEmojiToPng`):
The Toast class also provides `RenderEmojiToPng(string emoji, string outputPath, int size)` which renders emoji to a tightly-cropped PNG with transparent background using WPF's `FormattedText` + `DrawingVisual` + `RenderTargetBitmap` (backed by DirectWrite). The `Add-Type` call references `PresentationCore.dll` and `WindowsBase.dll` (resolved dynamically from the PowerShell runtime directory). Output is monochrome (WPF software renderer doesn't support COLR/CPAL color font tables) but auto-cropped to the glyph bounds with no wasted space.

**Ephemeral AUMID registration:**
Each toast uses a unique AUMID (`svc_<PipeName>_<PID>_<seq>`) registered ephemerally in `HKCU:\Software\Classes\AppUserModelId\`. The PID ensures uniqueness across sessions (Windows caches AUMID metadata persistently; reusing the same string would show stale DisplayNames). The `<seq>` is an incrementing `$script:_NotifyAumidSeq` counter ensuring uniqueness within a session. The registry key is created in `try`, the toast is fired, a 50ms sleep gives the toast system time to read the registry, then the key is removed in `finally`. On the very first notification call each session, all stale `svc_<PipeName>_*` keys are enumerated and deleted to clean up leftovers from crashed sessions. `Dispose-Notification` includes a safety-net sweep of all keys for the current PID.

**Fallback chain in `Show-Notification`:**
1. `$script:ToastAPI::ShowToast()` — native COM (instant, no process spawn), with ephemeral AUMID
2. `powershell.exe` subprocess — delegates to Windows PowerShell 5.1's built-in WinRT support, same ephemeral AUMID (with 500ms delay before cleanup for async subprocess)
3. `NotifyIcon.ShowBalloonTip()` — basic balloon notification (last resort)

### 3. Console TUI Rendering (VT100 Buffered)

All rendering goes through a buffered rendering system backed by VT100/ANSI escape sequences. Code calls `Write-Buffer` to queue positioned, colored text segments, then `Flush-Buffer` builds a single string with embedded VT100 escape codes and outputs the entire frame with one `[Console]::Write()` call.

```powershell
# Queue segments at specific positions with colors
Write-Buffer -X $col -Y $row -Text $text -FG $fgColor -BG $bgColor

# Queue sequential segments (continue from last position)
Write-Buffer -Text "more text" -FG $color

# Flush all queued segments to console (single atomic write)
Flush-Buffer

# Atomic clear screen + redraw (no visible blank flash)
Flush-Buffer -ClearFirst
```

**VT100 setup** (console mode block, ~line 458):
- `ENABLE_VIRTUAL_TERMINAL_PROCESSING` (0x0004) enabled on stdout handle via `SetConsoleMode`
- `[Console]::OutputEncoding` set to `[System.Text.Encoding]::UTF8` for correct emoji rendering

**ANSI color tables** (`$script:AnsiFG`, `$script:AnsiBG`, ~line 1464):
- Map all 16 `[ConsoleColor]` enum values to ANSI SGR codes (FG: 30-37/90-97, BG: 40-47/100-107)
- Segments with `$null` FG/BG use ANSI codes 39/49 (terminal default colors) instead of explicit color codes

**Buffer infrastructure** (`$script:RenderQueue`, `Write-Buffer`, `Flush-Buffer`, `Clear-Buffer`):
- `$script:RenderQueue` - `System.Collections.Generic.List[hashtable]` holding `@{ X; Y; Text; FG; BG }` segments
- `Write-Buffer` - Adds a segment. `X`/`Y` of `-1` = continue from last position. `FG`/`BG` of `$null` = use terminal default color (ANSI 39/49). `-Wide` switch appends a trailing space for 2-column emoji background fill. `-NoWrap` switch emits `ESC[?7l` before the segment and `ESC[?7h` after, disabling ANSI auto-wrap so writing to the last character of the last row does not trigger a console scroll.
- `Flush-Buffer` - Builds a `StringBuilder` with VT100 sequences: `ESC[?25l` (hide cursor), `ESC[row;colH` (positioning), `ESC[fg;bgm` (colors, only emitted on change), segment text, optional `ESC[?7l`/`ESC[?7h` wrapping for NoWrap segments, `ESC[0m` (reset), optional `ESC[?25h` (show cursor if `$script:CursorVisible` is true). Single `[Console]::Write()` outputs the entire frame atomically. `-ClearFirst` switch prepends `ESC[2J` (clear visible area) + `ESC[3J` (clear scrollback buffer) for atomic screen clear+redraw with no stale frames in scrollback.
- `Clear-Buffer` - Discards all queued segments without writing.

**Cursor visibility** is tracked via `$script:CursorVisible` (boolean) and controlled with VT100 sequences (`ESC[?25l` / `ESC[?25h`) instead of `[Console]::CursorVisible`. The cursor is hidden during flush and conditionally shown at the end based on the tracked state (e.g., shown during dialog text input, hidden otherwise).

**Frame boundaries** (where `Flush-Buffer` is called):
1. After initial dialog draw (shadow + borders + fields + buttons)
2. After dialog field redraw (2 affected rows on navigation/click)
3. After dialog input value change (character typed, backspace, validation error)
4. After dialog resize handler atomic redraw (`Draw-MainFrame -Force -NoFlush` + optional parent callback + dialog redraw + single `Flush-Buffer -ClearFirst`)
5. After dialog cleanup (clear shadow + clear area)
6. After full main UI render (`Draw-MainFrame`: header + separator + logs + stats + separator + menu)
7. After resize logo draw (`Draw-ResizeLogo -ClearFirst` on first draw)

### 3a. Buffer-Before-Clear Rendering Rule (ARCHITECTURAL INVARIANT)

**Never clear the screen unless the render buffer already contains everything that needs to appear next.**

Every screen clear must be immediately followed by a flush of the complete next frame -- main frame, any open dialogs, shadows, menus in their current visual state -- all in a single `[Console]::Write()` call. `Flush-Buffer -ClearFirst` achieves this by embedding `ESC[2J` at the start of the VT100 string, so clear + redraw happen in one atomic write with zero visible blank gap.

```powershell
# Buffer everything that needs to be on screen FIRST, then flush atomically
Draw-MainFrame -Force:$true -Date $date -NoFlush
Flush-Buffer -ClearFirst   # ESC[2J + full frame in one [Console]::Write()
```

**The rule:** before calling `Flush-Buffer -ClearFirst`, you must have already buffered the **entire** next screen state -- the main frame plus any dialogs/menus that should be visible on top. If a dialog should be open after the flush, its content must be in the buffer before the flush happens.

**When flushes occur:**
- **Forced main frame redraw** (`$forceRedraw`): `Draw-MainFrame -Force -NoFlush` + `Flush-Buffer -ClearFirst`. Used after dialog close, mode change, or buffer resize.
- **Settings reopen after sub-dialog** (`PendingReopenSettings`): Main frame is buffered with `-NoFlush`, then `Show-SettingsDialog -DeferFlush` adds the settings dialog to the same buffer, then `Flush-Buffer -ClearFirst` inside Settings paints everything atomically.
- **Dialog-internal resize**: `Draw-MainFrame -Force -NoFlush` + optional parent callback + dialog redraw + single `Flush-Buffer -ClearFirst`.
- **Resize logo animation**: `Draw-ResizeLogo -ClearFirst` flushes rapidly during the resize loop. Each flush is a complete frame. This is the one place where repeated rapid flushes are intentional.
- **Dialog-internal redraws** (toggling a value, typing in a field): Plain `Flush-Buffer` (no clear) since only a small region changed.
- **Normal main loop renders**: `Draw-MainFrame -Date $date` (flushes internally, no clear needed).

**The `-DeferFlush` pattern** (layered draws): When a dialog must reopen on top of a freshly redrawn main frame, the caller buffers the main frame with `Draw-MainFrame -Force -NoFlush` and passes `-DeferFlush` to the dialog. The dialog adds its content (padding, borders, buttons) to the existing buffer, then calls `Flush-Buffer -ClearFirst` before entering its input loop. Result: clear + main frame + dialog all appear in one atomic write.

**What does NOT use `Flush-Buffer -ClearFirst`:**
- `Clear-Host` in quit/exit paths — these clear for a goodbye message before the process exits, not for frame transitions.
- `Clear-Host` at startup — one-time clear before the render buffer is initialized.
- `[Console]::Clear()` inside `Invoke-ResizeHandler` mid-loop (artifact cleanup during active resize animation, line 28) — this is inside the resize logo loop, not on exit; the exit path returns without clearing and the caller handles the atomic flush.

**Key rule:** `Invoke-PostDialogCleanup` does **not** call `clear-host` or `[Console]::Clear()`. It only sets `$SkipUpdate`, `$forceRedraw`, and refreshes `$oldWindowSize`/`$OldBufferSize`. The actual screen clearing is handled centrally via `Flush-Buffer -ClearFirst`. This ensures a single, consistent code path for all screen transitions.

**`Invoke-ResizeHandler` exit behavior:** The handler does NOT clear the screen on exit. The resize logo stays visible until the caller's `Flush-Buffer -ClearFirst` atomically replaces it with the full next frame. The only `[Console]::Clear()` inside the handler is the periodic artifact cleanup (every 50 draws) during the active resize animation loop.

**What stays as direct writes:**
- Debug/diagnostic logging to files (`Out-File`)
- One-off `Write-Host` calls during initialization/startup (before main loop)
- `[Console]::SetCursorPosition` for positioning the text input cursor in dialogs (after Flush-Buffer)
- Direct `[Console]::Write()` of VT100 cursor show/hide sequences during dialog text input state changes

**Box-drawing characters** are stored as variables to avoid encoding issues:

```powershell
$script:BoxTopLeft = [char]0x250C      # ┌
$script:BoxTopRight = [char]0x2510     # ┐
$script:BoxBottomLeft = [char]0x2514   # └
$script:BoxBottomRight = [char]0x2518  # ┘
$script:BoxHorizontal = [char]0x2500   # ─
$script:BoxVertical = [char]0x2502     # │
$script:BoxVerticalRight = [char]0x251C # ├
$script:BoxVerticalLeft = [char]0x2524  # ┤
```

### 4. Theme System

All colors are centralized as `$script:` variables (lines 214-289):

```powershell
# Menu Bar (normal state)
$script:MenuButtonBg = "DarkBlue"
$script:MenuButtonText = "White"
$script:MenuButtonHotkey = "Green"
$script:MenuButtonSeparatorFg = "White"
# Menu Bar (pressed / onclick state)
$script:MenuButtonOnClickBg        = "DarkCyan"
$script:MenuButtonOnClickFg        = "Black"
$script:MenuButtonOnClickHotkey    = "Black"
$script:MenuButtonOnClickSeparatorFg      = "Black"      # onclick counterpart for MenuButtonSeparatorFg
# Menu button icon prefix
$script:MenuButtonShowIcon         = $true    # Show/hide emoji + separator before label
$script:MenuButtonSeparator        = "|"      # Separator char between icon and label
# Menu button bracket wrapping (e.g. "[👁 |toggle_(v)iew]")
$script:MenuButtonShowBrackets     = $false
$script:MenuButtonBracketFg        = "DarkCyan"
$script:MenuButtonBracketBg        = "DarkBlue"
$script:MenuButtonOnClickBracketFg = "Black"
$script:MenuButtonOnClickBracketBg = "DarkCyan"
# Dialog button icon prefix (Quit, Time, Move dialogs)
$script:DialogButtonShowIcon       = $true   # Show/hide emoji + separator on dialog buttons
$script:DialogButtonSeparator      = "|"     # Separator char between icon and label
# Dialog button bracket wrapping (e.g. "[✅ |(u)pdate]")
$script:DialogButtonShowBrackets   = $false
$script:DialogButtonBracketFg      = "White"
$script:DialogButtonBracketBg      = $null   # null = terminal default (transparent)
# Show/hide () around hotkey letters — menu bar and header buttons
$script:MenuButtonShowHotkeyParens   = $true   # When $false the letter is still highlighted
# Show/hide () around hotkey letters — all dialog box buttons
$script:DialogButtonShowHotkeyParens = $true   # Independent of the menu bar setting

# Dialogs
$script:SettingsDialogBg           = "DarkBlue"
$script:SettingsDialogBorder       = "White"
$script:SettingsDialogTitle        = "Yellow"
$script:SettingsDialogText         = "White"
$script:SettingsDialogButtonBg     = "Blue"
$script:SettingsDialogButtonText   = "White"
$script:SettingsDialogButtonHotkey = "Yellow"
# Menu Bar: Settings Button
$script:SettingsButtonBg                 = $script:MenuButtonBg
$script:SettingsButtonText               = $script:MenuButtonText
$script:SettingsButtonHotkey             = $script:MenuButtonHotkey
$script:SettingsButtonSeparatorFg        = $script:MenuButtonSeparatorFg
$script:SettingsButtonBracketFg          = $script:MenuButtonBracketFg
$script:SettingsButtonBracketBg          = $script:MenuButtonBracketBg
$script:SettingsButtonOnClickBg          = $script:SettingsDialogBg
$script:SettingsButtonOnClickFg          = $script:SettingsDialogText
$script:SettingsButtonOnClickHotkey      = $script:SettingsDialogTitle
$script:SettingsButtonOnClickSeparatorFg = $script:SettingsDialogText
$script:SettingsButtonOnClickBracketFg   = $script:SettingsDialogBorder
$script:SettingsButtonOnClickBracketBg   = $script:SettingsDialogBg
# Quit
$script:QuitDialogBg = "DarkMagenta"
$script:QuitDialogShadow = "DarkMagenta"
$script:QuitDialogBorder = "White"
$script:QuitDialogTitle = "Yellow"
# ... etc
```

**Color categories:**
| Prefix | Component |
|--------|-----------|
| `MenuButton*` | Bottom menu bar (normal + `OnClick*` pressed state) |
| `MenuButtonOnClickSeparatorFg` | Onclick separator color (was inheriting from `MenuButtonOnClickFg`) |
| `MenuButtonShowIcon` / `MenuButtonSeparator` | Main menu icon prefix visibility and separator char |
| `MenuButtonShowBrackets` / `MenuButtonBracketFg` / `MenuButtonBracketBg` | Main menu button bracket wrapping and normal-state bracket colors |
| `MenuButtonOnClickBracketFg` / `MenuButtonOnClickBracketBg` | Pressed-state bracket colors for main menu buttons |
| `DialogButtonShowIcon` / `DialogButtonSeparator` | Dialog button icon prefix visibility and separator char |
| `DialogButtonShowBrackets` / `DialogButtonBracketFg` / `DialogButtonBracketBg` | Dialog button bracket wrapping and bracket colors (`BracketBg = $null` = transparent) |
| `MenuButtonShowHotkeyParens` | Hides/shows `()` around hotkey letters on menu bar buttons; letter remains highlighted |
| `DialogButtonShowHotkeyParens` | Hides/shows `()` around hotkey letters on all dialog box buttons; independent of the menu bar setting |
| `Header*` | Top header line |
| `HeaderBg` | Background for the 3-row header group (top blank + header row + top separator); outer `$_bpH-1` cols transparent |
| `HeaderRowBg` | Background applied **only** to the header content row, inset by `$_bpH` so it doesn't bleed into padding |
| `FooterBg` | Background for the 3-row footer group (bottom separator + menu row + bottom blank); same transparency rules |
| `MenuRowBg` | Background applied **only** to the menu bar content row, with the same inset |
| `BorderPadV` | Blank-row count above/below chrome (min 1); only innermost row gets `HeaderBg`/`FooterBg`, extras are transparent |
| `BorderPadH` | Blank-column count left/right of every chrome row (min 1); only innermost column gets group bg |
| `StatsBox*` | Right-side stats panel |
| `QuitDialog*` / `QuitButton*` | Quit confirmation dialog and dedicated quit menu button colors |
| `SettingsDialog*` | Settings mini-dialog (slide-up; time, movement, output toggle, debug toggle) |
| `SettingsButton*` | Dedicated colors for the `(s)ettings` menu bar button; `OnClick*` defaults match `SettingsDialog*` |
| `TimeDialog*` | Set end time dialog |
| `MoveDialog*` | Modify movement dialog |
| `Resize*` | Window resize splash screen |
| `Text*` | General purpose colors |

### 4a. Chrome Layout System (BorderPad, group bg, row bg)

The chrome (header + footer strip) is rendered using a layered background model controlled by two variables:

- **`$script:BorderPadV`** (`$_bpV`) — number of blank rows above and below the chrome group. Row count: `$Rows = $HostHeight - 4 - 2 * $_bpV`.
- **`$script:BorderPadH`** (`$_bpH`) — number of blank columns on each side of every chrome row.

**Horizontal layout per chrome row (left side):**
```
[transparent: $_bpH-1 cols] [group-bg: 1 col at X=$_bpH-1] [inner row-bg: 2 cols] [content ...]
```
**Right side (mirror):**
```
[... content] [inner row-bg: 2 cols] [group-bg: 1 col at X=$HostWidth-$_bpH] [transparent: $_bpH-1 cols]
```

The transparency is achieved by writing spaces with **no BG** (`$null` → ANSI 49 default background). This is implemented as the **last writes** in the render queue for each row (the inset overwrites), so they always win over any content that happened to land there.

**Rows affected:**
| Row type | Group bg var | Row bg var |
|----------|-------------|-----------|
| Top blank | `$_hBg` (HeaderBg) | — (whole row is group bg inside) |
| Header content | `$_hBg` | `$_hrBg` (HeaderRowBg) |
| Top separator | `$_hBg` | — |
| Bottom separator | `$_fBg` (FooterBg) | — |
| Menu content | `$_fBg` | `$_mrBg` (MenuRowBg) |
| Bottom blank | `$_fBg` | — |

**Content start/end X:**
- Header and menu content start at `X = $_bpH + 2` (group-bg col + 2 inner padding).
- Log rows start at `X = Max(0, $_bpH - 2)` (flush with the group-bg col; no inner padding for logs; clamped to 0 to prevent negative X which skips VT100 positioning). Width is clamped to `Min(logWidth + 2, HostWidth - logStartX)` to prevent line wrapping.
- Stats separator at `X = $_bpH + $logWidth + 1`.

**`$_bpV = 1` footer blank**: Uses `Write-Buffer -NoWrap` on the last segment to prevent console scroll when writing to `Y = $HostHeight - 1`. When `$_bpH > 1`, the row is split into three segments (transparent left, group-bg centre, transparent right with NoWrap) to achieve both transparency and full background coverage.

### 4b. Button Click System

Menu buttons use a multi-phase click model:

**Phase 1 — Mouse DOWN** (`PeekConsoleInput` handler):
- Detect which `$script:MenuItemsBounds` entry is under the cursor
- Set `$script:PressedMenuButton = $btn.hotkey`
- Immediately call `Write-ButtonImmediate` with `onClickFg`/`onClickBg`/`onClickHotkeyFg` + `Flush-Buffer` — gives instant visual feedback without waiting for the next frame

**Phase 2 — Mouse UP over same button** (confirmed click):
- Set `$script:ConsoleClickCoords` to trigger the action
- Set `$script:ButtonClickedAt = Get-Date` and `$script:PendingDialogCheck = $true`
- Leave `$script:PressedMenuButton` set — render loop handles restoration

**Phase 2 — Mouse UP outside button** (cancelled click):
- `Start-Sleep 100ms` brief delay, then `Write-ButtonImmediate` with normal colors
- Clear `$script:PressedMenuButton` immediately

**Phase 3 — Render loop restoration** (top of menu bar render, checks `$script:PendingDialogCheck`):
- `$script:DialogButtonBounds -eq $null` (no dialog open) → clears `$script:PressedMenuButton` immediately — handles toggles (o, i) and instant actions
- `$script:DialogButtonBounds -ne $null` (dialog open) → skips; button stays pressed while dialog is open

**Popup persistence**: Dialog-opening actions (q, t, m) call `Show-*Dialog` synchronously, blocking the main loop. The button stays visually highlighted (from Phase 1) throughout because no main render runs during the dialog. When the dialog closes, `DialogButtonBounds` is cleared and the next render's `PendingDialogCheck` fires the restore.

**`Write-ButtonImmediate` function** (near `Flush-Buffer` definition):
- Params: `$btn` (bounds entry), `$fg`, `$bg`, `$hotkeyFg`
- Reads `$btn.displayText` and `$btn.format` to render full button text with emoji/pipe splitting
- Calls `Flush-Buffer` at the end for immediate console output

**`$script:MenuItemsBounds` entry schema:**
```
startX, endX, y        — click hit area
hotkey                 — single character hotkey
index                  — position in menuItems array
displayText            — current format text string (for Write-ButtonImmediate)
format                 — menuFormat int (0=emoji|pipe, 1=noIcons, 2=short)
fg, bg, hotkeyFg       — normal render colors
onClickFg, onClickBg, onClickHotkeyFg  — pressed-state colors
```

### 5. Mouse Stutter Prevention

The "settle" logic prevents the next movement cycle from starting while the user is moving the mouse. This is critical for user experience:

```powershell
# Settle detection loop (simplified)
$stableChecks = 0
$requiredStableChecks = 3  # ~75ms of stability
while ($true) {
    Start-Sleep -Milliseconds 25
    $currentPos = Get-MousePosition
    
    if ($currentPos.X -eq $lastPos.X -and $currentPos.Y -eq $lastPos.Y) {
        $stableChecks++
        if ($stableChecks -ge $requiredStableChecks) {
            break  # Mouse has settled
        }
    } else {
        $stableChecks = 0  # Reset - mouse still moving
    }
    $lastPos = $currentPos
}
```

Input detection during the wait loop uses `PeekConsoleInput` for keyboard, scroll, and mouse click events (with exact character cell coordinates for click-to-button mapping), `GetLastInputInfo` for system-wide activity, `Test-MouseMoved` for cursor position changes, and a focused `GetAsyncKeyState` loop over mouse buttons only (VK 0x01-0x06) for general input detection. No keyboard scanning (`GetAsyncKeyState` over key codes) is performed.

### 6. Window Resize Handling

There are two resize handler paths: a **self-contained `handleResize`** for the welcome screen, and the **`Invoke-ResizeHandler`** function for everything after initialization.

#### Size detection: use `GetConsoleScreenBufferInfo` directly

`$Host.UI.RawUI.WindowSize` and `[Console]::WindowWidth` both go through managed wrapper code that can return stale values. The welcome screen's `getSize` and `handleResize` use `[mJiggAPI.Mouse]::GetConsoleScreenBufferInfo` (the raw Win32 P/Invoke on the **stdout** handle, `GetStdHandle(-11)`) and read `srWindow.Right - srWindow.Left + 1` / `srWindow.Bottom - srWindow.Top + 1` directly. This is the lowest-level path possible and always returns the current terminal dimensions.

```powershell
$csbi = New-Object mJiggAPI.CONSOLE_SCREEN_BUFFER_INFO
$hOut = [mJiggAPI.Mouse]::GetStdHandle(-11)   # STD_OUTPUT_HANDLE
if ([mJiggAPI.Mouse]::GetConsoleScreenBufferInfo($hOut, [ref]$csbi)) {
    $w = [int]($csbi.srWindow.Right  - $csbi.srWindow.Left + 1)
    $h = [int]($csbi.srWindow.Bottom - $csbi.srWindow.Top  + 1)
}
```

#### Welcome screen: `handleResize` (nested inside `Show-StartupComplete`)

Self-contained; does **not** call `Invoke-ResizeHandler` or `Send-ResizeExitWakeKey`.

Before the outer polling loop starts, `Restore-ConsoleInputMode` and `Send-ResizeExitWakeKey` are called once to prime Windows Terminal's input routing (same mechanism used after main-loop resizes). `drainWakeKeys` is then called to consume the injected events before real keypress detection begins.

1. Read initial size via `getSize` (direct CSBI call)
2. Draw logo (or clear on error)
3. 10ms poll loop: `GetConsoleScreenBufferInfo` directly → detect change → redraw logo
4. Stability: 1500ms with no size change AND LMB released → break
5. `[Console]::Clear()`, `Restore-ConsoleInputMode`, `drainWakeKeys`, redraw welcome box

#### `drainWakeKeys` (nested inside `Show-StartupComplete`)

Drains the **entire** console input buffer and returns `$true` if any genuine keypress was found.

Critical rules (each learned from a diagnosed bug):
- **`IncludeKeyDown,IncludeKeyUp`** — `IncludeKeyDown` alone causes `ReadKey` to block indefinitely on KeyUp events, freezing the polling loop.
- **Drain the whole buffer, never return early** — if a stale KeyUp (e.g. the Enter used to run the script) causes an early return, the synthetic wake key events are left behind in the buffer and counted as real keypresses on the next tick.
- **Filter `VK_MENU` (18) as well as `VK_RMENU` (165)** — `Send-ResizeExitWakeKey` injects `VK_RMENU` (0xA5), but the Windows console input layer reports it as `VK_MENU` (18) in `INPUT_RECORD` keyboard events. See gotcha below.
- **Filter all modifier VKs** — Shift (16), Ctrl (17), Alt (18), and their L/R variants (160–165) are never "press any key".
- **Only count `KeyDown=true` as a real keypress** — stale KeyUp events from any previous key are discarded.

```powershell
$_wakeVKs = @(16, 17, 18, 160, 161, 162, 163, 164, 165)
function drainWakeKeys {
    $_real = $false
    try {
        while ($Host.UI.RawUI.KeyAvailable) {
            $k = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown,IncludeKeyUp,AllowCtrlC")
            if ($k.KeyDown -and $k.VirtualKeyCode -notin $_wakeVKs) { $_real = $true }
        }
    } catch {}
    return $_real
}
```

#### Main loop & dialog: `Invoke-ResizeHandler`

Called from: the main wait loop resize check, the per-iteration outside-wait-loop resize check, **and all five dialog resize checks** (Time, Movement, Quit, Settings, Info). Not called from the welcome screen.

**Parameters:** `-PreviousScreenState` (string, defaults to `$script:CurrentScreenState`). Stored in `$script:LastResizePreviousState`.

1. **Enter**: Reset `$script:CurrentResizeQuote` and `$script:ResizeLogoLockedHeight`
2. **Initial draw**: `Draw-ResizeLogo -ClearFirst` (normal mode) or `[Console]::Clear()` (hidden mode)
3. **1ms poll loop**:
   - Read `$psw.WindowSize` on every iteration (main loop already calls PeekConsoleInput externally)
   - If size changed: update pending size, reset stability timer, redraw logo (or nothing in hidden mode)
   - Every 50 redraws: `[Console]::Clear()` + `Restore-ConsoleInputMode` to prevent artifact buildup
   - Check stability: if elapsed time >= `$script:ResizeThrottleMs` (100ms) AND LMB not held → exit
4. **Exit**: `Restore-ConsoleInputMode`, `Send-ResizeExitWakeKey`, `return $pendingSize` (no screen clear — the resize logo stays visible until the caller's `Flush-Buffer -ClearFirst` atomically replaces it)

**Centralized resize flow** (after extraction of `Draw-MainFrame`):
```
Resize detected → Invoke-ResizeHandler (logo shown, blocks until stable)
  → Caller updates HostWidth/HostHeight from returned stableSize
  → Draw-MainFrame -Force -NoFlush (queues main UI, does not flush)
  → If sub-dialog with parent: invoke ParentRedrawCallback (queues parent dialog offfocus)
  → Dialog re-centers and redraws on top (queues dialog)
  → Single Flush-Buffer -ClearFirst (atomic paint of all layers)
```

```powershell
# Main loop call pattern:
$stableSize = Invoke-ResizeHandler
$oldWindowSize = $stableSize
$HostWidth     = $stableSize.Width
$HostHeight    = $stableSize.Height

# Dialog call pattern (top-level dialog — Settings, Quit, Info):
$stableSize = Invoke-ResizeHandler -PreviousScreenState "dialog-settings"
$HostWidthRef.Value  = $stableSize.Width
$HostHeightRef.Value = $stableSize.Height
Draw-MainFrame -Force -NoFlush
# ... re-center and queue dialog redraw ...
Flush-Buffer -ClearFirst

# Sub-dialog call pattern (TimeChange/MovementModify opened from Settings):
$stableSize = Invoke-ResizeHandler -PreviousScreenState "dialog-time"
$HostWidthRef.Value  = $stableSize.Width
$HostHeightRef.Value = $stableSize.Height
Draw-MainFrame -Force -NoFlush
if ($null -ne $ParentRedrawCallback) {
    & $ParentRedrawCallback $currentHostWidth $currentHostHeight
}
# ... re-center and queue sub-dialog redraw ...
Flush-Buffer -ClearFirst
```

#### `Draw-MainFrame` function

Extracted rendering function (~2953) that draws the complete main UI: header, separator, log rows, stats box, bottom separator, menu bar, and footer. Callable from any context.

**Parameters:**
- `-ClearFirst`: passes through to `Flush-Buffer -ClearFirst`
- `-Force`: overrides `$skipConsoleUpdate` (always render)
- `-NoFlush`: queues segments but skips final `Flush-Buffer` (for layering dialog on top)

**Scope:** Defined inside `Start-mJig`, reads parent-scope variables (`$Output`, `$HostWidth`, `$HostHeight`, `$LogArray`, `$script:PreviousIntervalKeys`, etc.) via PowerShell's scope chain. Computes its own `$_bpV`, `$_bpH`, `$_hBg`, `$_hrBg`, `$_fBg`, `$_mrBg`, `$Rows`, and refreshes `$date` internally. Performs safety trim/pad on `$LogArray` to match `$Rows`.

**Screen state tracking:** Sets `$script:CurrentScreenState` to `"main"` or `"hidden"` based on `$Output`. Dialogs set it to `"dialog-*"` on entry and restore it on exit.

**Parent chain redraw pattern:** Sub-dialogs (`Show-TimeChangeDialog`, `Show-MovementModifyDialog`) accept an optional `[scriptblock]$ParentRedrawCallback` parameter. When a resize occurs inside a sub-dialog opened from Settings, the resize handler calls `Draw-MainFrame -Force -NoFlush` → `& $ParentRedrawCallback $w $h` (queues Settings in offfocus mode) → queues sub-dialog redraw → `Flush-Buffer -ClearFirst`. This ensures the full visual stack (main frame → Settings offfocus → sub-dialog) is painted atomically in a single flush, eliminating the flash caused by the previous double-flush pattern. `Show-SettingsDialog` creates the callback scriptblock before invoking each sub-dialog; the callback reads `$script:SettingsButtonStartX` and `$script:MenuBarY` (updated by `Draw-MainFrame`) to position the offfocus Settings dialog correctly at the new screen size. The callback also shadows `$dialogWidth`, `$dialogHeight`, and `$dialogLines` from saved `$_stgDialog*` variables to prevent PowerShell scope-chain shadowing (the sub-dialog's own `$dialogWidth`/`$dialogHeight` would otherwise be found first).

**Sub-dialog host refs:** `Show-SettingsDialog` passes `$HostWidthRef`/`$HostHeightRef` directly to sub-dialogs (not `[ref]$currentHostWidth` local intermediaries). This ensures that when a sub-dialog's resize handler updates the refs and calls `Draw-MainFrame`, the function reads the correct updated dimensions from the main loop's scope chain.

**LMB gate**: After the stability timer expires, the exit is deferred if `GetAsyncKeyState(0x01) -band 0x8000` is set (mouse button still held). The timer is **not** reset by mouse state — only new size changes reset it.

**`$oldWindowSize` initialization and sync**: Both `$oldWindowSize` and `$OldBufferSize` are set to the current live values immediately before the `:process while ($true)` main loop starts (prevents the first-iteration `$null` comparison from triggering a spurious resize screen on every startup). They are also synced to the current window state at every dialog exit path in the wait loop (Settings, Movement, Time, Quit, Info — both NeedsRedraw and normal close paths). This prevents the main loop from detecting a false resize mismatch after a dialog that internally handled a resize via `Invoke-ResizeHandler`.

**`Draw-ResizeLogo` function:**
- Accepts `-ClearFirst` switch (passed through to `Flush-Buffer`)
- Calculates center position for logo
- Draws box with dynamic padding (42% of available space)
- Locks height during resize to absorb ±1 transient row fluctuations (Windows Terminal reflow)
- Queues all segments via `Write-Buffer`, then `Flush-Buffer -ClearFirst` at the end
- Shows random quote 2 lines below logo

### 7. Dialog System

Dialogs are modal functions that take control of input and rendering:

**Structure:**
1. Save cursor visibility state
2. Calculate dialog position (centered)
3. Draw drop shadow
4. Draw dialog box with borders
5. Enter input loop
6. Handle keypresses (Enter, Escape, Tab, arrows, etc.)
7. Handle window resize (`Invoke-ResizeHandler` → `Draw-MainFrame` → redraw dialog)
8. Return result hashtable
9. Clear shadow and dialog area
10. Restore cursor visibility

**Dialog helper functions** (all write through `Write-Buffer`, do NOT call `Flush-Buffer` themselves -- the caller decides when to flush):

```powershell
# Draw a row with borders and background
Write-SimpleDialogRow -x $x -y $y -width $w -content "Hello" -contentColor White -backgroundColor $bg

# Draw an input field row
Write-SimpleFieldRow -x $x -y $y -width $w -label "Value:" -longestLabel $ll -fieldValue $val -fieldWidth 4 -fieldIndex 0 -currentFieldIndex $cur -backgroundColor $bg

# Draw offset shadow effect
Draw-DialogShadow -dialogX $x -dialogY $y -dialogWidth $w -dialogHeight $h -shadowColor DarkGray
```

**Result format:**
```powershell
return @{
    Result = $userInput      # The data (or $null if cancelled)
    NeedsRedraw = $true      # Whether main UI needs full refresh
}
```

### 8. Incognito Mode

Incognito mode (`$Output = "hidden"`) suppresses all UI rendering except a minimal status line and a small `(i)` toggle button positioned at the bottom-right. It is toggled by the `(i)ncognito` menu button or the `i` hotkey.

**Restricted hotkeys in incognito mode**: Only `q` (quit) and `i` (exit incognito) are processed. All other hotkeys (`o`, `s`, `m`, `?`, `/`, etc.) are silently ignored. The `o` (output cycle) handler is explicitly guarded with `$Output -ne "hidden"` so it cannot be used to exit incognito mode.

**Hidden-view render** (inside `elseif ($Output -eq "hidden")`):
- Draws a one-line status: `HH:mm:ss | running...` at row 0
- Draws `(i)` button using `$script:MenuButtonText`/`Bg`/`Hotkey` colors, positioned at `($newW - 4, $newH - 2)`
- Registers a single entry in `$script:MenuItemsBounds` with `hotkey = "i"`
- Clears `$script:ModeButtonBounds`, `$script:ModeLabelBounds`, `$script:HeaderEndTimeBounds`, `$script:HeaderCurrentTimeBounds`, `$script:HeaderLogoBounds` since those regions aren't rendered

**Entering incognito**: `$PreviousView = $Output; $Output = "hidden"; $script:MenuItemsBounds.Clear()`
**Exiting incognito**: `$Output = $PreviousView` (or `"min"` if `$PreviousView` is null); `$PreviousView = $null`

### 8a. Settings Dialog

`Show-SettingsDialog` is a slide-up mini-dialog that appears above the `(s)ettings` menu button. It is the consolidated entry point for time, movement, output mode, and debug mode configuration. Accepts `[switch]$DeferFlush` — when set, the initial draw uses `Flush-Buffer -ClearFirst` instead of `Flush-Buffer`, allowing the caller to pre-buffer the main frame so everything flushes atomically in one write.

**Layout (15 rows, height = 14):**
```
0: top border    1: title    2: divider    3: blank
4: [⏳|(t)ime]   5: blank    6: [🛠|(m)ovement]    7: blank
8: [⚙|(o)ptions]  (opens sub-dialog)   9: blank
10: [🎨|(t)heme]   (placeholder, no-op) 11: blank
12: [💻|output: Full/Min]  (inline toggle)   13: blank   14: bottom border
```

**Key behaviors:**
- **Slide-up animation**: Animates from behind the separator/menu bar. Can be skipped via `[bool]$SkipAnimation = $false` parameter.
- **Onfocus / offfocus**: While a sub-dialog (time or movement) is open, the dialog dims; returns to onfocus on sub-dialog close.
- **Sub-dialog background cleanup**: When time or movement sub-dialog closes, `Show-SettingsDialog` breaks out with `ReopenSettings = $true`. The caller sets `$script:PendingReopenSettings = $true`. On the next `$forceRedraw`, the main loop buffers the main frame with `Draw-MainFrame -Force -NoFlush`, then calls `Show-SettingsDialog -SkipAnimation -DeferFlush`. Settings adds its content to the existing buffer and calls `Flush-Buffer -ClearFirst` — one atomic write paints main frame + settings with no visible blank gap.
- **Inline output toggle** (`o`): Cycles `$script:Output` between `"full"` and `"min"` immediately, redraws the row, stays in the settings loop. No sub-dialog or screen repaint needed.
- **Inline debug toggle** (`d`): Toggles `$script:DebugMode`, redraws the row, stays in the settings loop.
- **Re-click to close**: Clicking the `(s)ettings` menu button while settings is visible closes the dialog.
- **Returns**: `@{ NeedsRedraw = $bool; ReopenSettings = $bool }`

**Output / debug rows use full inner-row click detection** — `$outputButtonStartX/EndX` and `$debugButtonStartX/EndX` span the entire inner width (`$dialogX + 1` to `$dialogX + $dialogWidth - 2`). Pads are computed dynamically at render time based on current `$script:Output` / `$script:DebugMode`.

**Sync after dialog closes**: Both call sites (`s`-hotkey handler and `$script:PendingReopenSettings` reopen path) sync `$Output = $script:Output` and `$DebugMode = $script:DebugMode` after `Show-SettingsDialog` returns.

**Theme variables** (all in the `# Dialogs: Settings` block):
- `SettingsDialog{Bg,Border,Title,Text,ButtonBg,ButtonText,ButtonHotkey}` — onfocus colors
- `SettingsDialogOffFocus{Bg,Border,Title,Text,ButtonBg,ButtonText,ButtonHotkey}` — offfocus (sub-dialog open)
- `SettingsButton{Bg,Text,Hotkey,SeparatorFg,BracketFg,BracketBg}` — normal menu button colors
- `SettingsButtonOnClick{Bg,Fg,Hotkey,SeparatorFg,BracketFg,BracketBg}` — pressed/open state (defaults match dialog colors)

### 8b. Options Dialog

`Show-OptionsDialog` is a sub-dialog opened from the Settings dialog via the `(o)ptions` button. It provides advanced configuration options.

**Layout:**
```
0: top border    1: title ("Options")    2: divider    3: blank
4: [🔍|(d)ebug: On/Off]       (inline checkbox)    5: blank
6: [🔔|(n)otifications: On/Off]  (inline checkbox)  7: blank
8: bottom border
```

**Key behaviors:**
- **Opened from Settings**: When the user presses `o` in the Settings dialog, Settings enters offfocus mode and `Show-OptionsDialog` is invoked.
- **Inline debug toggle** (`d`): Toggles `$script:DebugMode`, redraws the row, stays in the options loop.
- **Inline notifications toggle** (`n`): Toggles `$script:NotificationsEnabled`, redraws the row, stays in the options loop.
- **Close**: Escape or clicking outside closes the dialog and returns to Settings.
- **Returns**: `@{ NeedsRedraw = $bool; ReopenSettings = $bool }`

### 9. Menu Item Bounds Tracking & Click Detection

For mouse click detection, menu items track their console coordinates:

```powershell
$script:MenuItemsBounds.Clear()
$null = $script:MenuItemsBounds.Add(@{
    startX = $itemStartX      # Left edge X coordinate
    endX = $itemEndX          # Right edge X coordinate  
    y = $menuY                # Row number
    hotkey = "t"              # Associated hotkey
    index = $i                # Item index
}
```

**Click detection uses `PeekConsoleInput` MOUSE_EVENT records.** The console input buffer provides native `MOUSE_EVENT` records with exact character cell coordinates (`dwMousePosition.X/Y`), eliminating all pixel-to-character conversion math. This is the same buffer used for keyboard and scroll detection.

Click detection in the main loop's PeekConsoleInput block:

```powershell
$script:ConsoleClickCoords = $null
# Inside the existing PeekConsoleInput loop:
if ($peekBuffer[$e].EventType -eq 0x0002) {  # MOUSE_EVENT
    $mouseFlags = $peekBuffer[$e].MouseEvent.dwEventFlags
    $mouseButtons = $peekBuffer[$e].MouseEvent.dwButtonState
    if ($mouseFlags -eq 0 -and ($mouseButtons -band 0x0001) -ne 0) {  # Left button press
        $script:ConsoleClickCoords = @{
            X = $peekBuffer[$e].MouseEvent.dwMousePosition.X
            Y = $peekBuffer[$e].MouseEvent.dwMousePosition.Y
        }
    }
}
# After the peek loop, consume click events via ReadConsoleInput
# Then match against dialog buttons and menu items:
if ($null -ne $script:ConsoleClickCoords) {
    $clickX = $script:ConsoleClickCoords.X
    $clickY = $script:ConsoleClickCoords.Y
    # Exact character cell comparisons:
    if ($clickY -eq $bounds.buttonRowY -and $clickX -ge $bounds.startX -and $clickX -le $bounds.endX) { ... }
}
```

**Hit-testing uses exact character cell matching** — no tolerance, no pixel math, no expanded bounding boxes. Button and menu item bounds map to the exact visible characters (emoji+pipe+text). The `PeekConsoleInput` approach inherently handles focus (events only appear when the console is focused) and provides coordinates that match the console's own rendering.

Dialog button click detection (in Show-TimeChangeDialog, Show-MovementModifyDialog, and Show-QuitConfirmationDialog) uses the same `PeekConsoleInput` pattern within each dialog's own input loop. Each dialog peeks for MOUSE_EVENT left button press records, consumes them via `ReadConsoleInput`, then matches against `$buttonRowY`, `$updateButtonStartX/$updateButtonEndX`, and `$cancelButtonStartX/$cancelButtonEndX` (all mapped to visible characters only).

Show-MovementModifyDialog also supports **field click selection**: after button checks, clicks within the dialog area are matched against field Y offsets (`@(4, 5, 7, 8, 10, 11, 13)` relative to `$dialogY`). A matched field click switches `$currentField`, redraws only the two affected rows (previous and new selection), and repositions the cursor.

**Important**: All three dialogs must clear `$script:DialogButtonBounds = $null` and `$script:DialogButtonClick = $null` in their cleanup code. The main loop's menu click detection is guarded by `$null -eq $script:DialogButtonBounds` — stale bounds will block all menu item clicks.

### 10. Emoji Handling

Emojis display as 2 columns in the console but have string length of 1. With buffered rendering, emoji positions are computed statically (assuming 2 display cells) rather than reading `$Host.UI.RawUI.CursorPosition.X` after writing:

```powershell
$emojiX = $itemStartX
$pipeX = $emojiX + 2  # Emoji takes 2 display columns
Write-Buffer -X $emojiX -Y $menuY -Text $emoji -FG $iconColor -BG $bg
Write-Buffer -X $pipeX -Y $menuY -Text "|" -FG $pipeColor -BG $bg
```

**Common emojis used:**
```powershell
$emojiHourglass = [char]::ConvertFromUtf32(0x23F3)   # ⏳
$emojiEye = [char]::ConvertFromUtf32(0x1F441)        # 👁️
$emojiLock = [char]::ConvertFromUtf32(0x1F512)       # 🔒
$emojiGear = [char]::ConvertFromUtf32(0x1F6E0)       # 🛠
$emojiRedX = [char]::ConvertFromUtf32(0x274C)        # ❌
$emojiMouse = [char]::ConvertFromUtf32(0x1F400)      # 🐀
```

### 11. Log Array Structure

`$LogArray` is a `System.Collections.Generic.List[object]` that always contains exactly `$Rows` entries (one per visible log row). It is maintained as a ring buffer: each new log entry calls `$LogArray.RemoveAt(0)` (evicts oldest) then `$null = $LogArray.Add(...)` (appends newest). **Never use `= @()` or `+=` on `$LogArray`** — those convert the List to a plain array. Always use `$null = $LogArray.Add(...)` with no guard condition. If the List is accidentally converted to an array, the render-cycle guard at the top of the log section automatically re-wraps it.

**Debug log entries** (inside `if ($DebugMode)` blocks) follow the same pattern — just call `$null = $LogArray.Add(...)` directly. The render loop trims `$LogArray` to `$Rows` entries before each frame, so overflow is handled automatically. Do **not** add a guard like `if ($LogArray -is [Array]) { $LogArray = @() }` — the `List[object]` is never an `[Array]`, so such a check always fires and wipes the log.

Log entries use a component-based structure for dynamic truncation:

```powershell
$null = $LogArray.Add([PSCustomObject]@{
    logRow = $true
    components = @(
        @{ 
            priority = 1              # Lower = more important
            text = "full text"        # Displayed when space allows
            shortText = "short"       # Displayed when truncated
        },
        @{ 
            priority = 2
            text = " - detailed message"
            shortText = " - msg"
        }
    )
})
```

Priority determines display order when truncating. Components with lower priority numbers are shown first.

### 12. Input Detection and State Tracking

Input detection uses four complementary mechanisms, each providing evidence for a specific input type:

1. **`PeekConsoleInput`** (keyboard + scroll + mouse clicks) - Peeks at the console input buffer for event records. Detects `KEY_EVENT` (EventType 0x0001) for keyboard, `MOUSE_EVENT` with scroll flag (EventType 0x0002, dwEventFlags 0x0004) for scroll wheel, and `MOUSE_EVENT` with left button press (dwEventFlags 0, dwButtonState & 0x0001) for click detection. Keyboard events are only **peeked** (not consumed) so the menu hotkey handler can still read them. Scroll and click events are consumed to prevent buffer buildup. The simulated Right Alt key (VK 0xA5) is filtered out. Only works when console is focused.

2. **`GetAsyncKeyState`** (mouse buttons only) - Focused loop over VK codes 0x01-0x06 for general input detection (pausing the jiggler). Not used for click-to-button mapping — that is handled entirely by PeekConsoleInput MOUSE_EVENT records.

3. **`GetLastInputInfo`** (system-wide catch-all) - Passive API returning the timestamp of the last user input of any type. Used to set `$script:userInputDetected = $true` (pauses the jiggler). Also infers **mouse movement** when activity is detected but no keyboard, scroll, or click evidence was found by the other mechanisms.

4. **`Test-MouseMoved`** (position polling) - Compares cursor position against previous check with a pixel threshold. Provides direct evidence of mouse movement.

**Classification logic (evidence-based, inference by elimination):**
- **Mouse clicks**: `PeekConsoleInput` MOUSE_EVENT left button press → direct evidence (with cell coords for button mapping); `GetAsyncKeyState` VK 0x01-0x06 → general detection for jiggler pause
- **Scroll**: `PeekConsoleInput` MOUSE_EVENT with scroll flag → direct evidence (focused only)
- **Keyboard**: `PeekConsoleInput` KEY_EVENT records (excluding VK 0xA5) → direct evidence (focused only)
- **Mouse movement**: `Test-MouseMoved` position change → direct evidence; OR `GetLastInputInfo` activity with no keyboard/scroll/click evidence → inference by elimination
- **Keyboard/Other** (worker inference): `GetLastInputInfo` activity detected + mouse did NOT move → inferred as keyboard or other non-mouse input. Cannot distinguish keyboard from scroll when console is not focused (no passive Win32 API exposes device type without global input interception).

**Worker vs viewer detection and merge:**

The worker (headless background process) has no console input buffer, so it cannot use `PeekConsoleInput`. It detects:
- **Mouse movement**: `Test-MouseMoved` (direct) or `GetLastInputInfo` inference by elimination
- **Keyboard/Other**: `GetLastInputInfo` activity when mouse did NOT move (inference — could be keyboard, scroll, or any other HID input)

The worker sends `keyboardInferred = $true` alongside `keyboardInputDetected = $true` in state messages so the viewer can distinguish worker-inferred from viewer-detected keyboard activity.

The viewer OR-merges worker detections with its own local detections (preserving both). It does NOT overwrite local state with worker state. The viewer also feeds `$msg.mouseInputDetected` into `$intervalMouseInputs` so worker-detected mouse movement appears in the final display.

**Display label logic:** The final `$PreviousIntervalKeys` assembly uses "Keyboard" when the viewer locally confirmed a KEY_EVENT via `PeekConsoleInput` (`$_keyboardLocallyDetected`), and "Keyboard/Other" when only the worker inferred it (`$_keyboardInferred` without `$_keyboardLocallyDetected`).

```powershell
# Mouse button state (0x01-0x06 only)
$state = [mJiggAPI.Mouse]::GetAsyncKeyState($keyCode)
$isCurrentlyPressed = ($state -band 0x8000) -ne 0
$wasJustPressed = ($state -band 0x0001) -ne 0
```

**State tracking variables:**
- `$script:previousKeyStates` - Hashtable of previous mouse button states (for edge detection, VK 0x01-0x06 only)
- `$script:LastSimulatedKeyPress` - Timestamp of last simulated press (for filtering)
- `$keyboardInputDetected` - Boolean, set by `PeekConsoleInput` KEY_EVENT records or worker state message
- `$mouseInputDetected` - Boolean, set by mouse movement (Test-MouseMoved or GetLastInputInfo inference) or button clicks
- `$scrollDetectedInInterval` - Boolean, set by `PeekConsoleInput` scroll events, persists across wait loop iterations
- `$_keyboardInferred` - Boolean, set from worker state message `keyboardInferred` field. Indicates keyboard detection was inferred (not direct evidence).
- `$_keyboardLocallyDetected` - Boolean, set when `PeekConsoleInput` finds a KEY_EVENT. Indicates definitive keyboard evidence (console was focused).
- `$script:userInputDetected` - Boolean, set by any detection mechanism, triggers jiggler pause
- `$intervalMouseInputs` - `System.Collections.Generic.HashSet[string]` — cleared at the start of each main-loop iteration via `.Clear()`. Use `$null = $intervalMouseInputs.Add("Mouse")` etc. — **never `+=`** (would convert to plain array). Worker mouse detections are also fed into this set via the OR-merge in viewer state handlers.

### 13. Movement Animation

Mouse movement is animated over time for a natural appearance. The path is generated by `Get-SmoothMovementPath` which produces points with ease-in-out-cubic easing and optional curved paths:

```powershell
# Calculate path and animate
$movementPath = Get-SmoothMovementPath -startX $pos.X -startY $pos.Y -endX $x -endY $y ...
$movementPoints = $movementPath.Points
$timePerPoint = $movementPath.TotalTimeMs / ($movementPoints.Count - 1)

for ($i = 1; $i -lt $movementPoints.Count; $i++) {
    [System.Windows.Forms.Cursor]::Position = New-Object System.Drawing.Point ($point.X, $point.Y)
    Start-Sleep -Milliseconds $sleepTime

    # Abort if user moved mouse during animation (drift > 3px from placed position)
    $actualPos = Get-MousePosition
    if ([Math]::Abs($actualPos.X - $point.X) -gt 3 -or [Math]::Abs($actualPos.Y - $point.Y) -gt 3) {
        $movementAborted = $true
        break
    }
}
```

**User input during animation**: After each `SetCursorPos` + sleep, the loop reads the actual cursor position and compares it to where the cursor was just placed. If the position has drifted by more than 3 pixels in either axis, the user is moving the mouse and the animation aborts immediately. On abort: `$script:userInputDetected` and `$mouseInputDetected` are set, the simulated keypress is skipped, and the auto-resume delay timer is started (if configured).

### 14. Global Hotkeys & Windows Notifications

**Global hotkeys** are detected via `GetAsyncKeyState` polling (already declared as `[mJiggAPI.Mouse]::GetAsyncKeyState()`). They work from any process, including the hidden headless worker, with no message pump required.

**Hotkey combos:**
- **Shift+M+P** — Toggle manual pause/resume. Sets `$script:ManualPause` (standalone) or `$manualPause` (worker). When paused, movement is skipped but the main loop continues running.
- **Shift+M+Q** — Immediate quit with no confirmation dialog. Sends `{ type = 'quit' }` / `{ type = 'stopped'; reason = 'quit' }` as appropriate.

**Detection** (`Test-GlobalHotkey` in `Private/Helpers/Test-GlobalHotkey.ps1`):
- Polls Shift (0x10) and M (0x4D) first; if either is released, resets the debounce flag and returns `$null`.
- If Shift+M are held and debounce is not active, checks P (0x50) and Q (0x51).
- Returns `'togglePause'` or `'quit'`; sets `$script:_HotkeyDebounce = $true` to prevent repeated firing while keys are held.
- Debounce resets when Shift+M is released.

**Polling locations:**
- **Standalone** (no worker): once per `:process` iteration, before the wait loop.
- **Worker** (always, regardless of viewer connection): once per 50ms tick inside the wait loop, before `GetLastInputInfo`. When a viewer is connected, the worker sends `{ type = 'togglePause'; paused = $bool; logMsg = $hashtable }` or `{ type = 'stopped'; reason = 'quit' }` via pipe so the viewer can update its UI state.
- **Viewer mode**: does NOT poll hotkeys — the worker's 50ms tick loop provides much faster detection than the viewer's multi-second main loop. The viewer receives hotkey state changes from the worker via pipe messages (`'togglePause'` and `'stopped'`).

**Windows toast notifications** (`Show-Notification` / `Dispose-Notification` in `Private/Helpers/Show-Notification.ps1`):
- Primary path uses the native `$script:ToastAPI::ShowToast()` COM interop with an ephemeral custom AUMID (see section 2b). A 50ms sleep after `ShowToast` keeps the registry key alive long enough for the toast system to read it.
- **Per-action icons:** The `-Action` parameter (mandatory, ValidateSet) selects an action-specific emoji for the toast `appLogoOverride` image. Action icons are rendered once and cached in `$script:_ActionIconCache` as `mjig_notify_<action>.png` in temp. The system tray `NotifyIcon` still uses the title emoji (`$script:TitleEmoji`).
- Action-to-emoji mapping: `started` = U+1F680 (rocket), `paused` = U+23F8 (pause), `resumed` = U+25B6 (play), `quit` = U+1F6D1 (stop sign), `disconnected` = U+1F50C (plug), `endtime` = U+23F0 (alarm clock).
- **Ephemeral AUMID per-toast:** Each toast uses a unique AUMID (`svc_<PipeName>_<PID>_<seq>`) — PID prevents stale cached DisplayNames across sessions, seq prevents within-session collisions. On first call, all stale `svc_<PipeName>_*` keys are wiped from the registry. A 50ms sleep after `ShowToast` keeps the key alive long enough for the toast system to read it before the `finally` block deletes it.
- The `NotifyIcon` is lazily created on first use for the system tray icon.
- `Dispose-Notification` removes the tray icon, cleans up cached action icon PNGs and tray icon PNG, and performs safety-net registry cleanup for all `svc_<PipeName>_<PID>_1..N` keys. Called in both viewer cleanup and worker finally block.
- State variables: `$script:_NotifyAumidSeq` (incrementing AUMID counter), `$script:_ActionIconCache` (hashtable of action -> PNG path), `$script:_NotifyIconEmoji` (last rendered tray icon codepoint).
- Diagnostic logging: when `-Diag` is enabled, all notification entries, successes, and failures are logged to `$script:NotifyDiagFile` (`_diag/notify.txt`). Tags: `[ENTRY]`, `[RENDER-TRAY]`, `[RENDER-ACTION]`, `[TIER1-OK]`, `[TIER1-COM]`, `[TIER1-SKIP]`, `[TIER2-OK]`, `[TIER2-PS51]`, `[TIER3-BALLOON]`, `[ERROR]`.

**Header pause/resume button:** The header right side now shows a ⏸ (running) or ▶ (paused) symbol instead of the old `(o)utput` button. Clicking the symbol toggles `$script:ManualPause` and triggers the same logic as `Shift+M+P` (notification, log entry, pipe message to worker in viewer mode). The adjacent "Full"/"Min" label is now clickable and toggles output mode (replacing the removed `o` keyboard hotkey). The `o` hotkey is kept in the Settings dialog.

**Click bounds:**
- `$script:ModeButtonBounds` — tracks the ⏸/▶ pause button (2 display chars)
- `$script:ModeLabelBounds` — tracks the "Full"/"Min" label click region

**Notification events:**
| Event | Source | `-Action` | Body text |
|---|---|---|---|
| Pause (Shift+M+P or header click) | Standalone or Worker | `paused` | "Paused" |
| Resume (Shift+M+P or header click) | Standalone or Worker | `resumed` | "Resumed" |
| Quit (Shift+M+Q) | Standalone: viewer / Worker: worker | `quit` | "mJig stopped" / "Worker quit" |
| Worker initialized | Worker | `started` | "Worker started (PID: ...)" |
| Viewer disconnected | Worker | `disconnected` | "Viewer disconnected" |
| End time reached | Worker | `endtime` | "End time reached -- worker quit" |

**Script-scoped variables:**
- `$script:ManualPause` — `[bool]` manual pause flag (standalone/viewer)
- `$script:_HotkeyDebounce` — `[bool]` prevents repeated hotkey firing
- `$script:_NotifyIcon` — `[System.Windows.Forms.NotifyIcon]` lazily created, disposed on exit
- `$script:_ActionIconCache` — hashtable mapping action name to cached PNG path (per-action toast icons)
- `$script:_NotifyAumidSeq` — incrementing counter for unique per-toast AUMID strings
- `$script:PauseEmoji` / `$script:PlayEmoji` — cached ⏸/▶ characters (avoid recomputation)
- `$script:ModeLabelBounds` — click region for "Full"/"Min" label

---

## Performance Guidelines

### Hot-Path Allocation Rules

The following objects are pre-allocated before the main `:process` loop and must be **cleared/reused, never recreated**:

| Variable | Type | Per-iteration reset |
|---|---|---|
| `$intervalMouseInputs` | `HashSet[string]` | `.Clear()` |
| `$pressedMenuKeys` | `hashtable` | `.Clear()` |
| `$_waitPeekBuffer` | `INPUT_RECORD[]` (32) | Reused as-is |
| `$lii` | `LASTINPUTINFO` | Reused; `cbSize` set once |
| `$script:MenuItemsBounds` | `List[hashtable]` | `.Clear()` then `.Add()` |

**Never use `+=` on `$intervalMouseInputs`** — it converts the HashSet to a plain array. Use `$null = $intervalMouseInputs.Add(...)`.

**`$date = Get-Date`** is refreshed at the top of every 50ms `:waitLoop` tick. Use `$date.ToString("HH:mm:ss")` for log entry timestamps inside the main loop instead of calling `(Get-Date)` again.

**`TimeZoneInfo.ClearCachedData()`** is rate-limited to once per hour via `$lastTzCacheClear`. Do not add additional calls in the hot path.

---

## Common Modification Patterns

### File Placement Rule (mandatory for all plans)

All new functions must be placed in their own `.ps1` file under the appropriate `Private/` subdirectory and dot-sourced in `Start-mJig.psm1`. Never inline new functions directly into the main `.psm1`. This constraint must be acknowledged in every plan that adds new code.

After adding any new files:
1. Add a dot-source line (`. "$PSScriptRoot\Private\...\NewFunction.ps1"`) in the appropriate section of `Start-mJig.psm1`
2. Update this `AGENTS.md` (Code Structure Map + Quick Reference table)
3. Ensure `Build/Build-Module.ps1` picks up the new file (it recombines all dot-sourced files into a single `.psm1` in `dist/`)

### Adding a New Theme Color

1. Add variable in Theme Colors section (~line 214):
```powershell
$script:NewComponentColor = "Cyan"
$script:NewComponentBg = "DarkBlue"
```

2. Use in code:
```powershell
Write-Buffer -Text "text" -FG $script:NewComponentColor -BG $script:NewComponentBg
```

3. Update `resources/AGENTS.md` color categories table.

### Icon/Separator Theme Variables

Menu buttons and dialog buttons support toggling the emoji icon prefix and its separator character via two independent variable pairs:

- `$script:MenuButtonShowIcon` / `$script:MenuButtonSeparator` — controls the `"👁 |"` prefix on all main menu bar buttons (including quit; the incognito-mode `(i)` button is text-only and unaffected)
- `$script:DialogButtonShowIcon` / `$script:DialogButtonSeparator` — controls the `"✅ |"` / `"❌ |"` prefix on action buttons inside the Quit, Time, and Move dialogs

**How they are consumed:**
- `$menuIconWidth = if ($script:MenuButtonShowIcon) { 2 + $script:MenuButtonSeparator.Length } else { 0 }` is computed once at the top of the menu width calculation block and reused for all format-0 items, `$quitWidth`, `$itemDisplayWidth`, and the render loop.
- Each dialog computes `$dlgIconWidth` (or `$_dlgIW` / `$_moveDlgIW` inside scriptblocks) with the same pattern and uses it for both rendering positions and click-detection bounds.
- Button click bounds (`$script:DialogButtonBounds`) are always computed using `$dlgIconWidth` so click detection stays accurate regardless of the setting.

### Bracket Wrapping Theme Variables

Menu buttons and dialog buttons optionally wrap their full content in `[ ]` brackets with independent color control:

**Main menu buttons:**
- `$script:MenuButtonShowBrackets` (`$false`) — when `$true`, renders `[` before and `]` after the full button content (including icon)
- `$script:MenuButtonBracketFg` / `$script:MenuButtonBracketBg` — normal-state bracket colors
- `$script:MenuButtonOnClickBracketFg` / `$script:MenuButtonOnClickBracketBg` — pressed-state bracket colors
- `$script:MenuButtonOnClickSeparatorFg` — dedicated onclick color for the `|` separator (previously inherited from `MenuButtonOnClickFg`)

**Dialog buttons (Quit, Time, Move):**
- `$script:DialogButtonShowBrackets` (`$false`) — when `$true`, renders `[` before and `]` after each dialog action button
- `$script:DialogButtonBracketFg` / `$script:DialogButtonBracketBg` — bracket colors (`$null` BG = terminal default, transparent over dialog background)

**How brackets affect layout:**
- `$menuBracketWidth = if ($script:MenuButtonShowBrackets) { 2 } else { 0 }` is computed alongside `$menuIconWidth` and added to `$format0Width`, `$quitWidth`, and `$itemDisplayWidth`.
- Each dialog computes `$dlgBracketWidth` (or `$_dlgBW` / `$_moveDlgBW`) and applies it to `$bottomLinePadding`/`$buttonPadding`, `$btn2X`, and all four click-bound variables.
- In render code, a local `$contentX` offset (`$btnXX + 1` when brackets are on) is used so icon/text always render at the correct column regardless of bracket state.
- `$script:MenuItemsBounds` entries now include `pipeFg`, `bracketFg`, `bracketBg`, `onClickPipeFg`, `onClickBracketFg`, `onClickBracketBg` fields so `Write-ButtonImmediate` can restore exact colors on drag-off.

### Adding a New Parameter

1. Add to param block (~line 122):
```powershell
[Parameter(Mandatory = $false)]
[int]$NewParam = 10
```

2. Copy to script scope (~line 156):
```powershell
$script:NewParam = $NewParam
```

3. Update README.md parameters table.

### Adding a New Dialog

1. Create function following pattern of `Show-TimeChangeDialog`
2. Key elements:
   - Save `$savedCursorVisible = $script:CursorVisible`
   - Calculate centered position
   - Queue all rendering via `Write-Buffer` (borders, content, fields, buttons)
   - Call `Draw-DialogShadow` (also uses `Write-Buffer`)
   - Call `Flush-Buffer` after the complete dialog is queued
   - Input loop with resize detection (`Invoke-ResizeHandler` → `Draw-MainFrame -Force -NoFlush` → optional `& $ParentRedrawCallback` → queue dialog redraw → `Flush-Buffer -ClearFirst`)
   - On field/input redraws: queue affected rows via `Write-Buffer`, then `Flush-Buffer`
   - Cursor visibility: `$script:CursorVisible = $true; [Console]::Write("$($script:ESC)[?25h")` to show, `$script:CursorVisible = $false; [Console]::Write("$($script:ESC)[?25l")` to hide
   - Call `Clear-DialogShadow` + queue clear area via `Write-Buffer`, then `Flush-Buffer`
   - Restore `$script:CursorVisible = $savedCursorVisible` and write appropriate VT100 sequence
   - Return `@{ Result = $data; NeedsRedraw = $bool }`
   - **Do NOT call `clear-host` inside the dialog.** The caller uses `Invoke-PostDialogCleanup` (which sets `$forceRedraw = $true`), and the main render loop's centralized render→clear→flush pattern (§3a) handles screen clearing

3. Add hotkey handler in wait loop (~line 5400)
4. Update README.md interactive controls

### Adding a Menu Item

1. Add to `$menuItemsList` array (~line 7092):
```powershell
@{
    full = "$emojiNew|new_(x)feature"
    noIcons = "new_(x)feature"
    short = "(x)new"
}
```

2. Add hotkey handler in wait loop input processing
3. Update README.md interactive controls

### Adding a New Box-Drawing Character

1. Define at top of initialization (~line 210):
```powershell
$script:BoxNewChar = [char]0xXXXX  # Character name
```

2. Never use literal box characters in code - always use variables

### Modifying Movement Behavior

Key locations:
- `$script:IntervalSeconds` - Wait time between cycles
- `$script:TravelDistance` - Pixels to move
- `$script:MoveSpeed` - Animation duration
- Movement calculation: ~line 5900
- Animation loop: ~line 5950

---

## Important Gotchas

### LogArray Type Guard Bug (CRITICAL)

**Never** add a type-check guard before appending to `$LogArray`. The pattern below is **WRONG** and will wipe the entire log on every call:

```powershell
# WRONG — $LogArray is a List[object], NOT an [Array], so the guard always fires
if ($null -eq $LogArray -or -not ($LogArray -is [Array])) { $LogArray = @() }
$LogArray += [PSCustomObject]@{ ... }   # Also wrong: += converts List to plain array
```

**Correct pattern:**
```powershell
$null = $LogArray.Add([PSCustomObject]@{
    logRow = $true
    components = @(
        @{ priority = 1; text = ...; shortText = ... },
        @{ priority = 2; text = ...; shortText = ... }
    )
})
```

No guard is needed. The render loop trims `$LogArray` to `$Rows` entries before each frame.

### Encoding Issues (CRITICAL)

Box-drawing characters can corrupt if file encoding changes. **Always use `[char]` casts:**

```powershell
# SAFE - generates character at runtime
$char = [char]0x250C  # ┌

# RISKY - can corrupt to â"Œ if encoding changes
$char = "┌"
```

If you see `â"Œ` or similar garbage, the file encoding has been corrupted. Fix by:
1. Re-saving with UTF-8 BOM encoding
2. Better: Convert all literal box chars to `[char]` casts

### Resize Detection: Use `GetConsoleScreenBufferInfo` Directly (CRITICAL)

`$Host.UI.RawUI.WindowSize` and `[Console]::WindowWidth` both go through managed wrappers that can return stale values. For reliable resize detection in a polling loop, call `GetConsoleScreenBufferInfo` on the **stdout** handle directly and read `srWindow`:

```powershell
# CORRECT - direct Win32, always current
$csbi = New-Object mJiggAPI.CONSOLE_SCREEN_BUFFER_INFO
$hOut = [mJiggAPI.Mouse]::GetStdHandle(-11)   # STD_OUTPUT_HANDLE (-11)
if ([mJiggAPI.Mouse]::GetConsoleScreenBufferInfo($hOut, [ref]$csbi)) {
    $w = [int]($csbi.srWindow.Right  - $csbi.srWindow.Left + 1)
    $h = [int]($csbi.srWindow.Bottom - $csbi.srWindow.Top  + 1)
}
```

Note: use `GetStdHandle(-11)` (stdout) for `GetConsoleScreenBufferInfo`, not `-10` (stdin).

### `VK_RMENU` (165) Appears as `VK_MENU` (18) in Console Input Records (CRITICAL)

`Send-ResizeExitWakeKey` injects `VK_RMENU` (0xA5 = 165) via `keybd_event`. However, the Windows console input layer reports this in `INPUT_RECORD` keyboard events with `wVirtualKeyCode = 18` (`VK_MENU`), **not** 165. Any code that filters wake keys by checking `VirtualKeyCode -eq 165` will miss them entirely. Always filter both 18 and 165 (and all other modifier VKs 16, 160–165) when reading from the console input buffer.

### `ReadKey("IncludeKeyDown")` Blocks Indefinitely on KeyUp Events

`$Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")` waits for a KeyDown event and **skips** KeyUp events — meaning if a KeyUp event is at the front of the buffer, `ReadKey` hangs waiting for the next KeyDown. `KeyAvailable` returns `$true` for both KeyDown and KeyUp, so calling `ReadKey("IncludeKeyDown")` after a truthy `KeyAvailable` check can freeze the entire polling loop indefinitely.

**Always use `"NoEcho,IncludeKeyDown,IncludeKeyUp,AllowCtrlC"`** when draining the input buffer. Filter KeyDown/KeyUp in code after the read.

### Console Buffer vs Window Size

```powershell
$Host.UI.RawUI.WindowSize   # Visible area (use this for UI layout)
$Host.UI.RawUI.BufferSize   # Total scrollable area (larger)
```

Always use `WindowSize` for calculating UI positions and widths.

### Script Scope vs Local Scope

Variables modified in nested functions need `$script:` prefix to persist:

```powershell
# WRONG - creates local variable, doesn't modify script state
function Update-Setting {
    $IntervalSeconds = 5  # Local only!
}

# CORRECT - modifies script-scoped variable
function Update-Setting {
    $script:IntervalSeconds = 5  # Persists!
}
```

### Scope-Chain Shadowing in Scriptblock Callbacks (CRITICAL)

When a scriptblock is invoked with `&` from inside a nested function, it runs in a child scope of the **caller's** scope — NOT where it was defined. If the caller has a variable with the same name as one the scriptblock expects (e.g. `$dialogWidth`), the caller's value shadows the intended one.

**Example**: `$settingsParentRedraw` is defined in `Show-SettingsDialog` (where `$dialogWidth = 26`), but invoked from inside `Show-MovementModifyDialog` (where `$dialogWidth = 30`). The callback sees `30`, not `26`.

**Fix pattern**: Save the needed values with unique prefixed names in the defining scope, then shadow the conflicting names as local variables at the top of the callback:

```powershell
# In Show-SettingsDialog, after $dialogWidth etc. are set:
$_stgDialogWidth  = $dialogWidth
$_stgDialogHeight = $dialogHeight
$_stgDialogLines  = $dialogLines

# In the callback:
$settingsParentRedraw = {
    param($w, $h)
    $dialogWidth  = $_stgDialogWidth    # shadows sub-dialog's $dialogWidth
    $dialogHeight = $_stgDialogHeight
    $dialogLines  = $_stgDialogLines
    # ... rest of callback uses correct Settings values ...
}
```

The `$_stg*` names don't exist in any sub-dialog, so they resolve correctly via the scope chain (sub-dialog → Settings → main loop). The local `$dialogWidth` in the callback then shadows the sub-dialog's value for `& $drawSettingsDialog` which runs in a child scope of the callback.

### GetAsyncKeyState Return Values

```powershell
$state = [mJiggAPI.Mouse]::GetAsyncKeyState($keyCode)

# Bit 15 (0x8000) - Key is currently down
$isPressed = ($state -band 0x8000) -ne 0

# Bit 0 (0x0001) - Key was pressed since last GetAsyncKeyState call
$wasPressed = ($state -band 0x0001) -ne 0
```

Note: The "was pressed" bit is consumed on read, so only check it once per call. Only used for mouse buttons (0x01-0x06) and specific modifier keys (Shift, Ctrl).

### `[Console]::Clear()` and `clear-host` Strip `ENABLE_MOUSE_INPUT` (CRITICAL)

In Windows Terminal, calling `[Console]::Clear()` or `clear-host` resets the console input mode, stripping the `ENABLE_MOUSE_INPUT` flag. This causes `PeekConsoleInput` to stop reporting `MOUSE_EVENT` records entirely — mouse clicks become invisible to the application while `GetAsyncKeyState` (hardware-level) still works.

**Always call `Restore-ConsoleInputMode` after any `[Console]::Clear()` or `clear-host`**. The function reads the current mode via `GetConsoleMode`, ORs in `ENABLE_MOUSE_INPUT` (0x0010), and writes it back via `SetConsoleMode`. Current call sites: pre-main-loop clear, `Invoke-ResizeHandler` exit/hidden-mode, and once at the wait loop entry point (catches all dialog exit `clear-host` calls via the centralized render→clear→flush pattern — see §3a).

**Never call `clear-host` before the frame buffer is populated.** Use the render→clear→flush pattern (§3a) to ensure the screen is never visibly blank.

### Type Reloading Limitations

PowerShell cannot unload types once loaded via `Add-Type`. If you modify the C# type definitions, users must restart their PowerShell session. The script checks for existing types and skips reload if they exist.

### Simulated Key Press Filtering

When checking `GetLastInputInfo`, filter out the script's own simulated key presses and automated mouse movements:

```powershell
$recentSimulated = ($null -ne $LastSimulatedKeyPress) -and ((Get-TimeSinceMs -startTime $LastSimulatedKeyPress) -lt 500)
$recentAutoMove = ($null -ne $LastAutomatedMouseMovement) -and ((Get-TimeSinceMs -startTime $LastAutomatedMouseMovement) -lt 500)
```

The script simulates Right Alt (VK_RMENU = 0xA5) via `keybd_event`. After the simulated keypress, the console input buffer is flushed to prevent stale simulated events from being detected as user keyboard input by `PeekConsoleInput`. The `PeekConsoleInput` keyboard scan also explicitly filters out VK 0xA5.

### Emoji Display Width Variations

Some emojis render as 1 column, others as 2. With buffered rendering, emoji positions are computed statically (assuming 2 display cells) and explicit X positions are used after each emoji:

```powershell
$emojiX = $startX
Write-Buffer -X $emojiX -Y $row -Text $emoji -FG $color -BG $bg
Write-Buffer -X ($emojiX + 2) -Y $row -Text "|rest" -FG $color -BG $bg
```

### Windows Terminal Color Override

Windows Terminal has a setting "Automatically adjust lightness of indistinguishable text" that can override foreground colors. This cannot be controlled from PowerShell - users must disable it in Windows Terminal settings if they encounter color issues.

---

## State Machine Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         MAIN LOOP                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐   │
│  │  WAIT    │───►│  SETTLE  │───►│  MOVE    │───►│  RENDER  │   │
│  │  LOOP    │    │  CHECK   │    │  CURSOR  │    │  UI      │   │
│  └────┬─────┘    └──────────┘    └──────────┘    └────┬─────┘   │
│       │                                               │         │
│       │  ┌──────────────────────────────────────┐     │         │
│       └──┤  Hotkey / Click / Resize Detection   ├─────┘         │
│          └──────────────────────────────────────┘               │
│                          │                                      │
│          ┌───────────────┼───────────────┐                      │
│          ▼               ▼               ▼                      │
│    ┌──────────┐    ┌──────────┐    ┌──────────┐                 │
│    │  QUIT    │    │  TIME    │    │  MOVE    │                 │
│    │  DIALOG  │    │  DIALOG  │    │  DIALOG  │                 │
│    └──────────┘    └──────────┘    └──────────┘                 │
│                                                                 │
│    ┌──────────────────────────────────────────────────────┐     │
│    │               RESIZE HANDLING LOOP                   │     │
│    │  (Clear screen → Draw logo → Wait for completion)    │     │
│    └──────────────────────────────────────────────────────┘     │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Testing Tips

1. **Debug Mode**: Run with `-DebugMode` for verbose console logging during initialization
2. **Diagnostics**: Run with `-Diag` for file-based logs in `_diag/` (relative to script location). After quitting, a 15-second countdown prompt offers to print all diagnostic files to the console (each file in a different color, limited to 100 rows per file)
3. **Settle Detection**: Test by moving mouse during interval countdown - movement should be deferred
4. **Resize Handling**: Drag window edges to test logo centering and quote display
5. **Dialog Rendering**: Test dialogs at various window sizes (they should stay centered)
6. **Click Detection**: Test clicking menu items vs clicking elsewhere
7. **Encoding**: After any file modification, verify box characters render correctly

---

## File Locations

| File | Purpose |
|------|---------|
| `Start-mJig/Start-mJig.psm1` | Module skeleton — `Start-mJig` function, provisioner, init, main loop (~3,000 lines) |
| `Start-mJig/Start-mJig.psd1` | Module manifest — version, GUID, exports, `RequiredAssemblies` |
| `Start-mJig/Private/Config/` | Theme colors (`Initialize-Theme.ps1`) and P/Invoke types (`Initialize-PInvoke.ps1`) |
| `Start-mJig/Private/Startup/` | `Show-StartupScreen.ps1`, `Show-StartupComplete.ps1`, `Get-LatestVersionInfo.ps1` |
| `Start-mJig/Private/Rendering/` | Buffered rendering functions (11 files: `Write-Buffer`, `Flush-Buffer`, `Draw-MainFrame`, etc.) |
| `Start-mJig/Private/Dialogs/` | All 5 dialog functions (`Show-TimeChangeDialog`, `Show-MovementModifyDialog`, etc.) |
| `Start-mJig/Private/IPC/` | IPC helpers + worker loop (5 files: `Send-PipeMessage`, `Start-WorkerLoop`, etc.) |
| `Start-mJig/Private/Helpers/` | Utility functions (19 files: `Get-MousePosition`, `Invoke-ResizeHandler`, `Show-DiagnosticFiles`, `Add-DebugLogEntry`, `Get-DialogButtonLayout`, `Get-DialogMouseClick`, `Read-DialogKeyInput`, `Invoke-DialogExitCleanup`, `Invoke-PostDialogCleanup`, etc.) |
| `Start-mJig/Build/Build-Module.ps1` | Build script — combines skeleton + Private/ files into single `.psm1` in `dist/` |
| `.github/workflows/build.yml` | GitHub Actions — runs build on `v*` tag push, creates release |
| `README.md` | User documentation |
| `resources/AGENTS.md` | AI agent context (this file) |
| `resources/test-logs.ps1` | Temporary test script for log rendering (git-ignored) |
| `CHANGELOG.md` | Change tracking across commits |
| `.gitignore` | Excludes `_diag/`, backup files, `resources/*.ps1`, and `dist/` from git |
| `_diag/startup.txt` | Initialization diagnostics (created with `-Diag`) |
| `_diag/settle.txt` | Mouse settle detection logs (created with `-Diag`) |
| `_diag/input.txt` | PeekConsoleInput + GetLastInputInfo input detection logs (created with `-Diag`) |
| `_diag/ipc.txt` | Viewer-side IPC diagnostics: dialog open/close, pipe send attempts, main loop re-entry (created with `-Diag`) |
| `_diag/notify.txt` | Toast notification diagnostics: emoji render failures, COM interop errors (TIER1-COM), PS 5.1 subprocess errors (TIER2-PS51), balloon fallback (TIER3-BALLOON), and outer catch errors (created with `-Diag`) |
| `_diag/worker-startup.txt` | Worker process initialization trace: checkpoints [1]-[8] covering process start, session derivation, mutex, P/Invoke load, pipe creation. Includes `[FATAL]` with exception and stack trace if worker crashes (created with `-Diag`, forwarded to worker via spawn command) |
| `_diag/worker-ipc.txt` | Worker-side IPC diagnostics: viewer connect/disconnect, command recv, state send/skip counts. Also receives `[FATAL]` entries from the worker crash handler (created with `-Diag`, forwarded to worker via spawn command) |
| `_diag/welcome.txt` | Welcome screen resize detection diagnostics (**always written**, no `-Diag` flag needed) |

The `_diag/` folder is relative to `$PSScriptRoot` (i.e. `Start-mJig\_diag\`). `welcome.txt` is always written regardless of `-Diag`; all other diag files require the `-Diag` flag. `-Diag` is automatically forwarded to the worker process when spawned. All diag files are git-ignored.

**Post-exit diagnostic dump:** When `-Diag` is enabled, `Show-DiagnosticFiles` runs after the main loop exits (all exit paths: quit confirmation, end time reached, pipe connection failure). It lists available diagnostic files with line counts, then prompts `Print diagnostics to console? [Y/N]` with a 15-second countdown that auto-skips. If the user presses Y, each file is printed in a distinct color (startup=Cyan, settle=Yellow, input=Green, ipc=Magenta, notify=Blue, worker-startup=DarkYellow, worker-ipc=DarkCyan), limited to 100 rows per file. Files exceeding 100 rows show a truncation message with the full file path.

> **TEMPORARY TEST SCRIPTS**: When an agent creates a throwaway `.ps1` script to test or experiment with something (e.g. testing rendering logic, validating a calculation), place it in `resources/`. All `resources/*.ps1` files are git-ignored. Do NOT place temp scripts in the project root or elsewhere. Note: `_diag/` is separate — it is for runtime diagnostic output produced by the script itself (via `-Diag` or always-on), not for agent-authored test scripts.

**When reviewing diagnostic output with the user**, always provide a ready-to-run command to print the relevant diag file. The user expects this every time. Use:

```powershell
# Run these from the project root (c:\Projects\mJig)
Get-Content ".\_diag\input.txt"
Get-Content ".\_diag\startup.txt"
Get-Content ".\_diag\settle.txt"
Get-Content ".\_diag\ipc.txt"              # viewer IPC: dialog open/close, pipe sends
Get-Content ".\_diag\notify.txt"           # toast notification: render/COM/PS51/balloon errors
Get-Content ".\_diag\worker-startup.txt"   # worker init trace: checkpoints [1]-[8], [FATAL] on crash
Get-Content ".\_diag\worker-ipc.txt"       # worker IPC: connect/disconnect, recv, state send/skip
Get-Content ".\_diag\welcome.txt"          # always present, no -Diag flag needed
# Or full paths:
Get-Content "c:\Projects\mJig\_diag\welcome.txt"
```

### Module Runspace Provisioner

The provisioner is a ~30-line block at the top of `Start-mJig` (immediately after `param()`). It runs on every call from the user's session and is skipped on re-entry inside the provisioned runspace.

**How it works:**
- Checks `$_InModuleRunspace` — a `[switch]` parameter with `[Parameter(DontShow = $true)]`
- If not set: creates `InitialSessionState::CreateDefault2()`, opens a new `Runspace` with `$Host` passthrough and `ApartmentState = STA`, imports `Start-mJig.psm1` into it, calls `Start-mJig` again with `-_InModuleRunspace $true` plus all `$PSBoundParameters` forwarded via `AddParameter()`
- `Invoke()` blocks synchronously until mJig exits; `finally` block disposes the runspace
- If set (`$_InModuleRunspace` is `$true`): provisioner is skipped entirely, execution falls through to the normal program body

**Internal variable naming convention:** All provisioner-local variables use the `$_` prefix (e.g. `$_modPath`, `$_iss`, `$_rs`, `$_ps`, `$_kvp`) to avoid any collision with the program's own variable namespace below the provisioner block.

**What `CreateDefault2()` provides vs. what it excludes:**
- Provides: all built-in cmdlets (`Write-Host`, `Start-Sleep`, `Add-Type`, `Get-Date`, `Out-File`, `New-Object`, etc.)
- Excludes: `$PROFILE` execution, PSModulePath auto-imports, user aliases, user functions, user variables
- `System.Windows.Forms` is listed in `Start-mJig.psd1`'s `RequiredAssemblies` so it is pre-loaded before the module runs

**Error stream handling (line ~148):**
Non-terminating errors from the child runspace are accumulated in `$_ps.Streams.Error` during the entire session. In normal mode these are silently suppressed. In `-DebugMode` they are deduplicated by message+line number and shown as a compact summary after exit. This prevents the wall of hundreds of identical errors (e.g., null-reference errors from rendering edge cases) that would otherwise dump on quit.

**Exit flow:** All exit paths (quit confirmation via mouse click or keyboard `q`, and end time reached) use `break process` to exit the `:process` main loop and fall through to the cleanup section: viewer pipe disposal → `Show-DiagnosticFiles` prompt (if `-Diag`) → mutex release. If the viewer fails to connect to the worker (pipe timeout), the early-return paths also call `Show-DiagnosticFiles` before exiting when `-Diag` is enabled. The provisioner's `finally` block then disposes the runspace and restores console state. The `-DebugMode` error summary prints after the cleanup section completes.

**Why `$Host` must be passed to `CreateRunspace`:**
- Without it the runspace gets a default automation host with no console
- Passing the caller's `$Host` gives the provisioned runspace access to `$Host.UI.RawUI.ReadKey`, `WindowSize`, `KeyAvailable`, and all VT100/`[Console]::Write()` output — everything the TUI depends on

**`$_InModuleRunspace` is never user-facing:**
- `DontShow = $true` on `[Parameter()]` hides it from tab-completion and `Get-Help`
- Leading `_` signals internal/private by convention
- It is only ever passed by the provisioner's own `AddParameter('_InModuleRunspace', $true)` call

No external dependencies - the script is fully self-contained.

---

## Quick Reference: Function Locations

Functions are in individual `.ps1` files under `Start-mJig/Private/`. The skeleton `Start-mJig.psm1` contains params, provisioner, init, and the main loop.

| Component | Location |
|-----------|----------|
| Parameters | `Start-mJig.psm1` (top of function) |
| Module Runspace Provisioner | `Start-mJig.psm1` |
| Initialization Variables | `Start-mJig.psm1` |
| Theme Colors | `Private/Config/Initialize-Theme.ps1` |
| P/Invoke Types (mJiggAPI) | `Private/Config/Initialize-PInvoke.ps1` |
| Show-StartupScreen | `Private/Startup/Show-StartupScreen.ps1` |
| Show-StartupComplete | `Private/Startup/Show-StartupComplete.ps1` |
| Get-LatestVersionInfo | `Private/Startup/Get-LatestVersionInfo.ps1` |
| Invoke-ResizeHandler | `Private/Helpers/Invoke-ResizeHandler.ps1` |
| Get-SmoothMovementPath | `Private/Helpers/Get-SmoothMovementPath.ps1` |
| Get-DirectionArrow | `Private/Helpers/Get-DirectionArrow.ps1` |
| Write-Buffer / Flush-Buffer / Clear-Buffer | `Private/Rendering/` |
| Write-ButtonImmediate | `Private/Rendering/Write-ButtonImmediate.ps1` |
| Write-HotkeyLabel | `Private/Rendering/Write-HotkeyLabel.ps1` |
| Draw-DialogShadow / Clear-DialogShadow | `Private/Rendering/` |
| Draw-ResizeLogo | `Private/Rendering/Draw-ResizeLogo.ps1` |
| Draw-MainFrame | `Private/Rendering/Draw-MainFrame.ps1` |
| Write-SectionLine / Write-SimpleDialogRow / Write-SimpleFieldRow | `Private/Rendering/` |
| Get-MousePosition / Test-MouseMoved | `Private/Helpers/` |
| Get-TimeSinceMs / Get-ValueWithVariance | `Private/Helpers/` |
| Get-CachedMethod / Set-CoordinateBounds / Get-Padding | `Private/Helpers/` |
| Restore-ConsoleInputMode / Send-ResizeExitWakeKey | `Private/Helpers/` |
| Add-DebugLogEntry | `Private/Helpers/Add-DebugLogEntry.ps1` |
| Get-DialogButtonLayout | `Private/Helpers/Get-DialogButtonLayout.ps1` |
| Get-DialogMouseClick | `Private/Helpers/Get-DialogMouseClick.ps1` |
| Read-DialogKeyInput | `Private/Helpers/Read-DialogKeyInput.ps1` |
| Invoke-DialogExitCleanup | `Private/Helpers/Invoke-DialogExitCleanup.ps1` |
| Invoke-PostDialogCleanup (no clear-host; see §3a) | `Private/Helpers/Invoke-PostDialogCleanup.ps1` |
| Invoke-CursorMovement | `Private/Helpers/Invoke-CursorMovement.ps1` |
| Show-Notification / Dispose-Notification | `Private/Helpers/Show-Notification.ps1` |
| Test-GlobalHotkey | `Private/Helpers/Test-GlobalHotkey.ps1` |
| Show-DiagnosticFiles | `Private/Helpers/Show-DiagnosticFiles.ps1` |
| Send-PipeMessage / Read-PipeMessage / Send-PipeMessageNonBlocking | `Private/IPC/` |
| Start-WorkerLoop | `Private/IPC/Start-WorkerLoop.ps1` |
| Connect-WorkerPipe | `Private/IPC/Connect-WorkerPipe.ps1` |
| New-SecurePipeServer | `Private/IPC/New-SecurePipeServer.ps1` |
| Protect-PipeMessage / Unprotect-PipeMessage | `Private/IPC/Protect-PipeMessage.ps1` |
| Get-SessionIdentifier | `Private/Helpers/Get-SessionIdentifier.ps1` |
| Show-TimeChangeDialog | `Private/Dialogs/Show-TimeChangeDialog.ps1` |
| Show-MovementModifyDialog | `Private/Dialogs/Show-MovementModifyDialog.ps1` |
| Show-QuitConfirmationDialog | `Private/Dialogs/Show-QuitConfirmationDialog.ps1` |
| Show-SettingsDialog | `Private/Dialogs/Show-SettingsDialog.ps1` |
| Show-OptionsDialog | `Private/Dialogs/Show-OptionsDialog.ps1` |
| Show-InfoDialog | `Private/Dialogs/Show-InfoDialog.ps1` |
| Mutex check / Console setup | `Start-mJig.psm1` |
| End Time Calculation | `Start-mJig.psm1` |
| IPC Mode Branching | `Start-mJig.psm1` |
| Main Loop (:process while) | `Start-mJig.psm1` |
| Build Script | `Build/Build-Module.ps1` |

*Note: All paths are relative to `Start-mJig/`. Last verified: 2026-03-08.*
