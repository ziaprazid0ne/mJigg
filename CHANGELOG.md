# mJig Changelog

All notable changes to `start-mjig.ps1` are documented in this file.

---

## [Latest] - Unreleased

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
