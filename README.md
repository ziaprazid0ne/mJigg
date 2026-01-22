# mJig 🐭

A stealthy, robust, schedulable PowerShell mouse jiggler with advanced features for keeping your system active.

## Overview

mJig is an intelligent mouse jiggling tool that prevents your computer from going idle by:
- Moving the mouse cursor randomly at configurable intervals
- Sending keyboard input (Right Alt key) for applications that monitor keyboard activity
- Detecting user input and pausing automated movements when you're actively using your computer
- Running on a schedule with automatic stop times

## Features

- **Smart Input Detection**: Automatically pauses when you move the mouse or type, resuming when idle
- **Schedulable**: Set a specific end time or use the default with random variance
- **Multiple Output Modes**: Full, minimal, or hidden interface
- **Interactive Controls**: Hotkeys to toggle settings without stopping the script
- **Randomized Timing**: Variable intervals to appear more natural
- **Runtime Tracking**: Displays how long the script has been running
- **Window Resize Handling**: Automatically adjusts to console window size changes

## Requirements

- Windows PowerShell 5.1 or PowerShell 7+
- .NET Framework (for Windows Forms)

## Installation

1. Download the `start-mjig.ps1` script
2. Ensure PowerShell execution policy allows script execution:
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

## Usage

### Basic Usage

Run the script with default settings:
```powershell
.\start-mjig.ps1
```

This will:
- Use the default end time (6:07 PM with ±15 minute variance)
- Display full output mode
- Run until the scheduled end time

### Parameters

#### `-endTime` (Optional)
Specify when the script should stop in 4-digit 24-hour format.

**Examples:**
```powershell
# Stop at 5:30 PM
.\start-mjig.ps1 -endTime 1730

# Stop at 9:15 AM
.\start-mjig.ps1 -endTime 0915

# Stop at midnight
.\start-mjig.ps1 -endTime 0000
```

**Note:** If you don't specify `-endTime` or use `2400`, the script uses a default end time of 1807 (6:07 PM) with a random variance of ±15 minutes to avoid predictable patterns.

#### `-Output` (Optional)
Control the display mode of the interface.

**Options:**
- `full` (default): Shows full interface with detailed log entries
- `min`: Minimal interface with header and controls only (no log entries)
- `hidden`: Completely hidden interface (runs silently)

**Examples:**
```powershell
# Full output (default)
.\start-mjig.ps1 -Output full

# Minimal output
.\start-mjig.ps1 -Output min

# Hidden mode
.\start-mjig.ps1 -Output hidden
```

### Combined Examples

```powershell
# Run until 5:00 PM with minimal output
.\start-mjig.ps1 -endTime 1700 -Output min

# Run until 11:30 PM in hidden mode
.\start-mjig.ps1 -endTime 2330 -Output hidden

# Run with default end time and full output
.\start-mjig.ps1 -endTime 2400 -Output full
```

## Interactive Controls

While the script is running, you can use these hotkeys:

| Key | Action |
|-----|--------|
| `q` | Quit the script (shows runtime statistics) |
| `t` | Toggle between full and minimal output modes |
| `h` | Toggle between visible and hidden output modes |

**Note:** These hotkeys work in all output modes, including hidden mode.

## How It Works

### Movement Pattern
- Base interval: 10 seconds between movements
- Variance: ±2 seconds (randomized to appear natural)
- Movement range: Random movement up to 300 pixels in any direction from current position
- Keyboard input: Sends Right Alt key press (modifier key that won't interfere with applications)

### Smart Detection
The script monitors for:
- **Keyboard input**: Detects any key presses system-wide
- **Mouse movement**: Detects when you manually move the mouse
- **User activity**: When detected, skips the automated movement to avoid interfering with your work

### Scheduling
- If the specified end time has already passed today, the script schedules for tomorrow
- Default end time includes random variance (±15 minutes) to avoid predictable patterns
- Script automatically stops when the end time is reached

## Configuration

You can modify these settings in the script's configuration section (lines 62-66):

```powershell
$defualtEndTime = 1807              # Default end time (4-digit 24-hour format)
$defualtEndMaxVariance = 15          # Variance in minutes for default end time
$intervalSeconds = 10               # Base interval between movements (seconds)
$intervalVariance = 2               # Maximum variance in seconds for intervals
```

## Output Modes Explained

### Full Mode (`-Output full`)
- Displays header with end time and current time
- Shows detailed log entries with:
  - Timestamp
  - Movement status
  - Coordinates
  - Wait intervals
  - User input detection
- Interactive menu at the bottom
- Best for monitoring and debugging

### Minimal Mode (`-Output min`)
- Displays header with end time and current time
- Shows interactive menu
- No log entries (cleaner interface)
- Good for when you want to see status but not detailed logs

### Hidden Mode (`-Output hidden`)
- No visible output
- Runs completely silently
- All hotkeys still work
- Perfect for background operation

## Log Entry Format

When in full mode, log entries show:
```
[Timestamp] - [Status] [Coordinates] [Debug Info]
```

**Examples:**
```
01/20/2025 14:30:15 - Coordinates updated x1234/y567 [Wait: 11s]
01/20/2025 14:30:26 - Input detected, skipping update [Wait: 9s] [KB:YES]
```

## Tips

1. **For Work**: Use hidden mode to run silently in the background
2. **For Testing**: Use full mode to see detailed activity logs
3. **For Monitoring**: Use minimal mode for a clean status display
4. **Scheduling**: Set end times slightly before you actually need to stop (the script will continue until that time)
5. **Natural Behavior**: The randomized intervals and variance make the activity appear more human-like

## Troubleshooting

### Script won't run
- Check PowerShell execution policy: `Get-ExecutionPolicy`
- If restricted, run: `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`

### Mouse movements too frequent/infrequent
- Adjust `$intervalSeconds` and `$intervalVariance` in the configuration section

### Script stops too early/late
- Check your `-endTime` parameter format (must be 4 digits, 24-hour format)
- Verify the time hasn't already passed today (it will schedule for tomorrow)

### Keyboard detection issues
- The script uses Right Alt key which shouldn't interfere with most applications
- If issues occur, the script will continue with mouse movement only

## Notes

- The script uses Right Alt (VK_RMENU) for keyboard input simulation, which is a modifier key that won't type characters or trigger shortcuts
- Mouse movements are randomized in both direction and distance (up to 300 pixels)
- The script automatically handles console window resizing
- All timing includes randomization to appear more natural and less detectable

## License

This script is provided as-is for personal use.
