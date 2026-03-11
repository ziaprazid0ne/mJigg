# mJig 🐀

A feature-rich PowerShell mouse jiggler with a console-based TUI, designed to keep your system active with natural-looking mouse movements and intelligent user input detection.

## Features

- **Smart Mouse Movement**: Randomized cursor movements with configurable distance, speed, and variance
- **User Input Detection**: Automatically pauses when you're actively using mouse/keyboard
- **Auto-Resume Delay**: Configurable cooldown timer after user input before resuming automation
- **Scheduled Stop Time**: Set a specific end time with optional variance for natural patterns
- **Multiple View Modes**: Full, minimal, or incognito (hidden) interface
- **Interactive Dialogs**: Modify settings on-the-fly without restarting via the consolidated Settings dialog
- **Mouse Stutter Prevention**: Waits for mouse to settle before starting next movement cycle
- **Startup Screen**: Loading and initialization-complete screens on startup; auto-continues after 7 seconds if parameters were passed, otherwise waits for a keypress
- **Unified Window Resize Handling**: Centered logo with playful quotes during resize from any screen (startup, main loop, hidden mode); stays open while the mouse button is held so the UI never dismisses mid-drag
- **Themeable UI**: Centralized color variables including configurable border padding (`BorderPadV` / `BorderPadH`) and layered group/row background colors for the header and footer chrome
- **Info / About Dialog**: Version info and GitHub update check accessible via `?`, `/`, or clicking the mJig logo in the header
- **Stats Box**: Real-time display of detected input categories (Mouse, Keyboard, mouse buttons, Scroll/Other) and movement statistics
- **Polished Click Interactions**: Buttons highlight on press (mouse down), fire on release (mouse up); dragging off before releasing cancels the click
- **Per-Button Color Theming**: Each button carries its own normal and onclick color set; pressed-state colors are resolved per-button at render time
- **Popup Indicator**: The button that opened a dialog stays highlighted for the full lifetime of that dialog; toggle-action buttons restore instantly
- **Flicker-Free Rendering**: VT100/ANSI escape sequence rendering with atomic single-write frame output

## Requirements

- PowerShell 7+ (the hidden background worker requires `pwsh.exe`)
- Windows OS (uses Win32 API for mouse/keyboard interaction)

## Installation

1. Download the `Start-mJig` folder (contains `Start-mJig.psm1` and `Start-mJig.psd1`)
2. Ensure PowerShell execution policy allows scripts:
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

## Usage

### Basic Usage

```powershell
# Import the module (do this once per session)
Import-Module C:\Projects\mJig\Start-mJig\Start-mJig.psm1

# Run with defaults (no end time, minimal view)
Start-mJig

# Run with full interface
Start-mJig -Output full

# Run until 5:30 PM
Start-mJig -EndTime 1730

# Run hidden in background
Start-mJig -Output hidden

# Debugging one-liner: isolated session with full output and debug mode
$mJig = "C:\Projects\mJig\Start-mJig\Start-mJig.psm1"
powershell -NoProfile -Command "Import-Module '$mJig'; Start-mJig -Output full -DebugMode"
```

> **Note:** mJig automatically runs inside its own isolated, controlled runspace — separate from your session's profile, aliases, and loaded modules. No manual session management is needed.

### Background Worker Mode (Default)

By default, `Start-mJig` spawns a hidden background worker process that performs the actual jiggling. Your terminal becomes a viewer that displays the worker's status. This means:

- **Closing the terminal does not stop mJig** — the background worker continues running
- **Reconnect from any terminal** — run `Start-mJig` again to connect a new viewer to the running worker
- **Use `-Inline`** to run in legacy single-process mode where closing the terminal stops mJig

```powershell
# Default: spawns background worker + viewer
Start-mJig

# Legacy mode: single process, dies with terminal
Start-mJig -Inline
```

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-Output` | string | `"min"` | View mode: `full`, `min`, or `hidden` |
| `-EndTime` | string | `"0"` | Stop time in 24hr format (e.g., `1730` for 5:30 PM). `0` = no end time |
| `-EndVariance` | int | `0` | Random variance in minutes for end time |
| `-IntervalSeconds` | double | `2` | Base interval between movement cycles |
| `-IntervalVariance` | double | `2` | Random variance for interval timing |
| `-MoveSpeed` | double | `0.5` | Movement animation duration in seconds |
| `-MoveVariance` | double | `0.2` | Random variance for movement speed |
| `-TravelDistance` | double | `100` | Base cursor travel distance in pixels |
| `-TravelVariance` | double | `5` | Random variance for travel distance |
| `-AutoResumeDelaySeconds` | double | `0` | Cooldown after user input before resuming |
| `-Title` | string | `""` | Custom window title override (e.g., `"Windows Update"`) |
| `-Headless` | switch | `$false` | Fire-and-forget: spawn worker then exit (no TUI) |
| `-Inline` | switch | `$false` | Run without background worker (legacy single-process mode) |
| `-DebugMode` | switch | `$false` | Enable debug logging |
| `-Diag` | switch | `$false` | Enable diagnostic file output |

### Interactive Controls

While running, use these keyboard shortcuts:

| Key | Action |
|-----|--------|
| `q` | Open quit confirmation dialog |
| `s` | Open Settings dialog (end time, movement, output mode, debug toggle) |
| `t` | Set/change end time (also accessible via Settings) |
| `m` | Open movement settings (also accessible via Settings) |
| `o` | Toggle between full/min output view |
| `i` | Toggle incognito (hidden) mode |
| `?` or `/` | Open Info/About dialog |
| `Shift+M+P` | Toggle manual pause/resume (global hotkey, works from any window) |
| `Shift+M+Q` | Immediate quit (global hotkey, no confirmation dialog) |

You can also click menu buttons with your mouse. Buttons respond visually on press (onclick highlight color) and fire the action on release. Dragging the mouse off a button before releasing cancels the action. When a button opens a dialog, it stays highlighted for the duration of that dialog to indicate which menu is active. Clicking the mJig logo in the header opens the Info dialog.

### Dialogs

**Settings** (`s` key) — slide-up dialog above the menu bar:
- `end_(t)ime` — open end-time picker
- `mouse_(m)ovement` — open movement settings
- `(o)ptions` — open Options sub-dialog (output, debug, notifications, window title)
- `(t)heme` — placeholder (coming soon)

**Options** (via Settings → Options):
- `(o)utput: Full/Min` — inline toggle between full and minimal view
- `(d)ebug: On/Off` — inline toggle for debug mode
- `(n)otifications: On/Off` — enable/disable Windows toast notifications
- `(w)indow Title` — cycle through preset window title disguises

**Modify Movement Settings** (`m` key or via Settings):
- Interval timing and variance
- Travel distance and variance
- Movement speed and variance
- Auto-resume delay timer

**Set End Time** (`t` key or via Settings):
- Enter time in HHmm format (e.g., 1730 for 5:30 PM)

**Quit Confirmation** (`q` key):
- Displays runtime statistics before exiting

**Info / About** (`?` or `/` key, or click the mJig logo):
- Current version, GitHub link, and configuration summary

## View Modes

### Full Mode
- Header with logo, current/end times, view indicator
- Activity log with timestamped entries
- Stats box showing detected inputs
- Interactive menu bar with icons

### Minimal Mode
- Header with essential info
- Menu bar only (no log or stats)

### Hidden / Incognito Mode
- Minimal display: status line and clickable `(i)` button in bottom-right corner
- Only `i` (exit incognito) and `q` (quit) are processed; all other hotkeys blocked
- Click `(i)` or press `i` to return to the previous view
- Perfect for background operation

## Configuration

Movement and timing can be adjusted via:
1. Command-line parameters at startup
2. The "Modify Movement" dialog during runtime (`m` key)

### Theme Customization

Colors and layout are defined as `$script:` variables in the Theme Colors section (around line 134). Groups include:

- **Menu bar** — normal state (`MenuButtonBg`, `MenuButtonText`, `MenuButtonHotkey`) and pressed/onclick state (`MenuButtonOnClickBg`, `MenuButtonOnClickFg`, `MenuButtonOnClickHotkey`)
- **Chrome padding** — `$script:BorderPadV` (blank rows above/below, min 1) and `$script:BorderPadH` (blank columns left/right, min 1) control the space around the main content area
- **Header group bg** — `$script:HeaderBg` colors the 3-row strip at the top (blank + header row + separator); only the innermost padding column on each side carries this color
- **Footer group bg** — `$script:FooterBg` colors the 3-row strip at the bottom (separator + menu row + blank); same transparency rules
- **Row backgrounds** — `$script:HeaderRowBg` and `$script:MenuRowBg` color only the content row within each group, inset by `BorderPadH` so they do not bleed into the side padding
- **Stats box** — `StatsBox*` colors
- **Dialogs** — `QuitDialog*`, `SettingsDialog*`, `TimeDialog*`, `MoveDialog*`
- **Resize screen** — `Resize*`
- **General UI** — `Text*`

## How It Works

1. **Movement Cycle**: At each interval, the script:
   - Checks if user is actively moving the mouse
   - Waits for mouse to "settle" (stop moving) if needed
   - Moves cursor a random distance in a random direction
   - Sends a simulated Right Alt keypress (non-intrusive)

2. **Input Detection**: Monitors user activity using multiple mechanisms:
   - `PeekConsoleInput` for keyboard and scroll wheel events (console-focused)
   - `GetLastInputInfo` for system-wide activity detection (passive)
   - `GetAsyncKeyState` for mouse button clicks (VK 0x01-0x06)
   - Position polling for mouse movement

3. **Stutter Prevention**: Before each movement cycle, verifies the mouse has been stationary for a brief period to avoid interfering with user actions

## Diagnostics

Enable with `-Diag` flag. Creates log files in `_diag/` relative to the module directory (`Start-mJig\_diag\`):
- `startup.txt` - Initialization diagnostics
- `settle.txt` - Mouse settle detection logs
- `input.txt` - Input detection logs (PeekConsoleInput + GetLastInputInfo)
- `welcome.txt` - Welcome-screen resize diagnostics (**always written** even without `-Diag`)
- `ipc.txt` - Viewer-side IPC diagnostics (dialog open/close, pipe send/receive, epoch tracking)
- `worker-startup.txt` - Worker process initialization trace (checkpoints [1]-[8], `[FATAL]` on crash)
- `worker-ipc.txt` - Worker-side IPC diagnostics (viewer connect/disconnect, command receipt, state send/skip events)

The `-Diag` flag is automatically forwarded to the background worker process when it is spawned.

After quitting (or if the viewer fails to connect to the worker), a 15-second countdown prompt offers to print all diagnostic files directly to the console. Each file is displayed in a distinct color and limited to 100 rows; files exceeding the limit show a truncation notice with the full file path.

## Scheduling Tasks

### Headless Mode

Use `-Headless` for fire-and-forget execution. In headless mode, mJig spawns the background worker and exits immediately (no TUI). If a worker is already running, it exits silently.

Headless mode is also auto-detected when the console window is hidden (e.g., from a scheduled task with `-WindowStyle Hidden`).

### Time-Based Schedule (Mon-Fri at 8:00 AM)

**PowerShell one-liner:**

```powershell
$action = New-ScheduledTaskAction -Execute 'pwsh.exe' -Argument '-NoProfile -WindowStyle Hidden -EncodedCommand <base64>'
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday,Tuesday,Wednesday,Thursday,Friday -At 8am
Register-ScheduledTask -TaskName 'SystemHealthCheck' -Action $action -Trigger $trigger -RunLevel Limited
```

### Login Trigger

```powershell
$action = New-ScheduledTaskAction -Execute 'pwsh.exe' -Argument '-NoProfile -WindowStyle Hidden -EncodedCommand <base64>'
$trigger = New-ScheduledTaskTrigger -AtLogOn
Register-ScheduledTask -TaskName 'SystemHealthCheck' -Action $action -Trigger $trigger -RunLevel Limited
```

### Generating the EncodedCommand

```powershell
$cmd = "Import-Module 'C:\Path\To\Start-mJig\Start-mJig.psm1'; Start-mJig -Headless -EndTime 1730"
$encoded = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($cmd))
# Use $encoded as the -EncodedCommand argument above
```

### Stealth Best Practices

- Use `-Headless` for fire-and-forget (no visible window)
- Use `-Title "Windows Update"` to disguise the window title
- Use `-EncodedCommand` in the task action (arguments appear as opaque Base64)
- Give the scheduled task a generic name (e.g., "SystemHealthCheck")
- Pipe and mutex names are automatically randomized per boot session

## License

Shield: [![CC BY-ND 4.0][cc-by-nd-shield]][cc-by-nd]

This work is licensed under a
[Creative Commons Attribution-NoDerivs 4.0 International License][cc-by-nd].

[![CC BY-ND 4.0][cc-by-nd-image]][cc-by-nd]

[cc-by-nd]: https://creativecommons.org/licenses/by-nd/4.0/
[cc-by-nd-image]: https://licensebuttons.net/l/by-nd/4.0/88x31.png
[cc-by-nd-shield]: https://img.shields.io/badge/License-CC%20BY--ND%204.0-lightgrey.svg
