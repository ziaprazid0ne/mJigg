function Start-mJig {

	#############################################################
	## mJig - An overly complex powershell mouse jiggling tool ##
	#############################################################

	<#    _                       __
		/   \                  /      \
	   '      \              /          \
	  |       |Oo          o|            |
	  `    \  |OOOo......oOO|   /        |
	   `    \\OOOOOOOOOOOOOOO\//        /
		 \ _o\OOOOOOOOOOOOOOOO//. ___ /
	 ______OOOOOOOOOOOOOOOOOOOOOOOo.___
	  --- OO'* `OOOOOOOOOO'*  `OOOOO--
		  OO.   OOOOOOOOO'    .OOOOO o
		  `OOOooOOOOOOOOOooooOOOOOO'OOOo
		.OO "OOOOOOOOOOOOOOOOOOOO"OOOOOOOo
	__ OOOOOO`OOOOOOOOOOOOOOOO"OOOOOOOOOOOOo
	___OOOOOOOO_"OOOOOOOOOOO"_OOOOOOOOOOOOOOOO
	 OOOOO^OOOO0`(____)/"OOOOOOOOOOOOO^OOOOOO
	 OOOOO OO000/00||00\000000OOOOOOOO OOOOOO
	 OOOOO O0000000000000000 ppppoooooOOOOOO
	 `OOOOO 0000000000000000 QQQQ "OOOOOOO"
	  o"OOOO 000000000000000oooooOOoooooooO'
	  OOo"OOOO.00000000000000000OOOOOOOO'
	 OOOOOO QQQQ 0000000000000000000OOOOOOO
	OOOOOO00eeee00000000000000000000OOOOOOOO.
	OOOOOOOO000000000000000000000000OOOOOOOOOO
	OOOOOOOOO00000000000000000000000OOOOOOOOOO
	`OOOOOOOOO000000000000000000000OOOOOOOOOOO
	 "OOOOOOOO0000000000000000000OOOOOOOOOOO'
	   "OOOOOOO00000000000000000OOOOOOOOOO"
	.ooooOOOOOOOo"OOOOOOO000000000000OOOOOOOOOOO"
	.OOO"""""""""".oOOOOOOOOOOOOOOOOOOOOOOOOOOOOo
	OOO         QQQQO"'                     `"QQQQ
	OOO
	`OOo.
	`"OOOOOOOOOOOOoooooooo#>

	param(
		[Parameter(Mandatory = $false)] 
		[ValidateSet("min", "full", "hidden")]
		[string]$Output = "min",
		[Parameter(Mandatory = $false)]
		[switch]$DebugMode,
		[Parameter(Mandatory = $false)]
		[switch]$Diag,
		[Parameter(Mandatory = $false)] 
		[string]$EndTime = "0",  # 0 = no end time, otherwise 4-digit 24 hour format (e.g., 1807 = 6:07 PM)
		[Parameter(Mandatory = $false)]
		[int]$EndVariance = 0,  # Variance in minutes to randomly add/subtract from EndTime to avoid overly consistent end times. Only applies if EndTime is specified (not 0).
		[Parameter(Mandatory = $false)]
		[double]$IntervalSeconds = 2,  # sets the base interval time between refreshes
		[Parameter(Mandatory = $false)]
		[double]$IntervalVariance = 2,  # Sets the maximum random plus and minus variance in seconds each refresh
		[Parameter(Mandatory = $false)]
		[double]$MoveSpeed = 0.5,  # Base movement speed in seconds (time to complete movement)
		[Parameter(Mandatory = $false)]
		[double]$MoveVariance = 0.2,  # Maximum random variance in movement speed (in seconds)
		[Parameter(Mandatory = $false)]
		[double]$TravelDistance = 100,  # Base travel distance in pixels
		[Parameter(Mandatory = $false)]
		[double]$TravelVariance = 5,  # Maximum random variance in travel distance (in pixels)
		[Parameter(Mandatory = $false)]
		[double]$AutoResumeDelaySeconds = 0  # Timer in seconds that resets on user input detection. When > 0, coordinate updates and simulated key presses are skipped.
	)

	############
	## Preparing ##
	############ 

	# Initialize script-scoped variables from parameters (so they can be modified)
	# Parameters are read-only, so we use script-scoped variables that shadow them
	$script:IntervalSeconds = $IntervalSeconds
	$script:IntervalVariance = $IntervalVariance
	$script:MoveSpeed = $MoveSpeed
	$script:MoveVariance = $MoveVariance
	$script:TravelDistance = $TravelDistance
	$script:TravelVariance = $TravelVariance
	$script:AutoResumeDelaySeconds = $AutoResumeDelaySeconds
	$script:EndVariance = $EndVariance
	$script:Output = $Output
	$script:DebugMode = [bool]$DebugMode

	# Initialize Variables
	$LastPos = $null
	$OldBufferSize = $null
	$OldWindowSize = $null
	$Rows = 0
	$SkipUpdate = $false
	$script:PendingForceRedraw = $false
	$PreviousView = $null  # Store the view before hiding to restore it later
	$PosUpdate = $false
	$LogArray = @()
	$HostWidth = 0
	$HostHeight = 0
	$OutputLine = 0
	$LastMovementTime = $null
	$LastMovementDurationMs = 0  # Track duration of last movement in milliseconds
	$LastSimulatedKeyPress = $null  # Track when we last sent a simulated key press
	$LastAutomatedMouseMovement = $null  # Track when we last performed automated mouse movement
	$LastUserInputTime = $null  # Track when user input was last detected (for auto-resume delay timer)

	$PreviousIntervalKeys = @()  # Track keys pressed in previous interval for display
	$LastResizeDetection = $null  # Track when we last detected a resize
	$PendingResize = $null  # Track pending resize to throttle redraws
	$ResizeThrottleMs = 1500  # Wait 2000ms after window stops resizing before processing resize
	$ResizeClearedScreen = $false  # Track if we've cleared the screen at the start of a resize
	$LastResizeLogoTime = $null  # Track when we last drew the resize logo
	$script:LoopIteration = 0  # Track loop iterations for diagnostics
	$script:lastInputCheckTime = $null  # Track when we last logged input check (for debug mode)
	$script:DialogButtonClick = $null  # Track dialog button clicks detected from main loop ("Update" or "Cancel")
	
	# Performance: Cache for reflection method lookups
	$script:MethodCache = @{}
	
	# Note: Screen bounds are cached later after System.Windows.Forms is loaded
	$script:ScreenWidth = $null
	$script:ScreenHeight = $null
	$script:DialogButtonBounds = $null  # Store dialog button bounds when dialog is open {buttonRowY, updateStartX, updateEndX, cancelStartX, cancelEndX}
	$script:LastClickLogTime = $null  # Track when we last logged a click to prevent duplicate logs
	$script:WindowTitle = "mJig - mJigg"  # Fixed window title (same for all instances to enable duplicate detection)
	$script:MenuClickHotkey = $null  # Menu item hotkey triggered by mouse click
	$script:ModeButtonBounds           = $null  # Header mode button click bounds {y, startX, endX}
	$script:HeaderEndTimeBounds        = $null  # Header "End⏳/..." hidden click region {y, startX, endX}
	$script:HeaderCurrentTimeBounds    = $null  # Header "Current⏳/..." hidden click region {y, startX, endX}
	$script:HeaderLogoBounds           = $null  # Header "mJig(🐀)" logo click region {y, startX, endX}
	$script:Version                    = "1.0.0"  # Current application version
	$script:VersionCheckCache          = $null  # Cached result of GitHub release check {latest, url, isNewer, error}
	$script:PressedMenuButton  = $null   # hotkey of the menu button currently held down (LMB pressed, not yet released)
	$script:ButtonClickedAt   = $null   # timestamp of confirmed click (LMB UP over button); used to time color restoration
	$script:PendingDialogCheck = $false  # set on confirmed click; render loop uses it to decide whether to clear pressed state
	$script:LButtonWasDown    = $false   # tracks previous LMB state from console events for UP-transition detection
	$script:RenderQueue = New-Object 'System.Collections.Generic.List[hashtable]'
	
	# Box-drawing characters (using Unicode code points to avoid encoding issues)
	$script:BoxTopLeft = [char]0x250C      # ┌
	$script:BoxTopRight = [char]0x2510     # ┐
	$script:BoxBottomLeft = [char]0x2514   # └
	$script:BoxBottomRight = [char]0x2518  # ┘
	$script:BoxHorizontal = [char]0x2500   # ─
	$script:BoxVertical = [char]0x2502     # │
	$script:BoxVerticalRight = [char]0x251C # ├
	$script:BoxVerticalLeft = [char]0x2524  # ┤
	
	# ============================================================================
	# Theme Colors
	# ============================================================================
	#
	# All visual theme variables live here. When YAML theme import is implemented,
	# each section maps to a top-level YAML key as documented below.
	#
	# YAML key              PS variable prefix
	# ─────────────────     ──────────────────────────
	# general.*             Text*
	# mainDisplay.header.*  Header*
	# mainDisplay.statsBox.*StatsBox*
	# menuBar.*             MenuButton*
	#   .onClick.*          MenuButtonOnClick*
	#   .icon.*             MenuButtonShowIcon / MenuButtonSeparator
	#   .brackets.*         MenuButtonShowBrackets / MenuButtonBracket* / MenuButtonOnClickBracket*
	# dialogs.button.*      DialogButton*
	# dialogs.quit.*        QuitDialog*
	# dialogs.time.*        TimeDialog*
	# dialogs.move.*        MoveDialog*
	# resize.*              Resize*
	#
	# ============================================================================

	# --- General ----------------------------------------------------------------
	# Semantic text colors reused across all components. YAML: general.*
	$script:TextDefault   = "White"
	$script:TextMuted     = "DarkGray"
	$script:TextHighlight = "Cyan"
	$script:TextSuccess   = "Green"
	$script:TextWarning   = "Yellow"
	$script:TextError     = "Red"

	# --- Main Display: Header ---------------------------------------------------
	# Top status/info bar. YAML: mainDisplay.header.*
	$script:HeaderAppName    = "Magenta"
	$script:HeaderIcon       = "White"
	$script:HeaderStatus     = "Green"
	$script:HeaderPaused     = "Yellow"
	$script:HeaderTimeLabel  = "Yellow"
	$script:HeaderTimeValue  = "Green"
	$script:HeaderViewTag    = "Magenta"
	$script:HeaderSeparator  = "White"
	# Background applied to the 3-row header group (blank + header + separator).
	# $null = terminal default (transparent). YAML: mainDisplay.header.bg
	$script:HeaderBg         = "DarkBlue"
	# Background applied only to the header content row (not the blank or separator).
	# YAML: mainDisplay.header.rowBg
	$script:HeaderRowBg      = "DarkCyan"
	# Background applied to the 3-row footer group (separator + menu + blank).
	# $null = terminal default (transparent). YAML: mainDisplay.footer.bg
	$script:FooterBg         = "DarkBlue"
	# Background applied only to the menu bar row (not the separator or blank).
	# YAML: mainDisplay.footer.rowBg
	$script:MenuRowBg        = "DarkCyan"
	# Blank-line/column border around the chrome. Minimum 1.
	# Only the innermost row/column on each side receives the Header/FooterBg; extras stay transparent.
	# YAML: mainDisplay.borderPadV (top/bottom rows)
	$script:BorderPadV       = 1
	# YAML: mainDisplay.borderPadH (left/right columns)
	$script:BorderPadH       = 1

	# --- Main Display: Stats Box ------------------------------------------------
	# Right-side stats panel. YAML: mainDisplay.statsBox.*
	$script:StatsBoxBorder    = "Cyan"
	$script:StatsBoxTitle     = "Cyan"
	$script:StatsBoxLabel     = "White"
	$script:StatsBoxValue     = "Yellow"
	$script:StatsBoxValueGood = "Green"
	$script:StatsBoxValueBad  = "Red"

	# --- Menu Bar: Normal State -------------------------------------------------
	# Bottom menu bar button colors. YAML: menuBar.*
	$script:MenuButtonBg          = "DarkBlue"
	$script:MenuButtonText        = "White"
	$script:MenuButtonHotkey      = "Green"
	$script:MenuButtonSeparatorFg = "White"

	# --- Menu Bar: Pressed / OnClick State -------------------------------------
	# Applied while the user holds LMB on a button. YAML: menuBar.onClick.*
	$script:MenuButtonOnClickBg          = "DarkCyan"
	$script:MenuButtonOnClickFg          = "Black"
	$script:MenuButtonOnClickHotkey      = "Black"
	$script:MenuButtonOnClickSeparatorFg = "Black"

	# --- Menu Bar: Icon Prefix -------------------------------------------------
	# The emoji + separator rendered before the button label (e.g. "👁 |").
	# YAML: menuBar.icon.*
	$script:MenuButtonShowIcon  = $true   # Show/hide the icon prefix
	$script:MenuButtonSeparator = "|"     # Character between icon and label

	# --- Menu Bar: Bracket Wrapping --------------------------------------------
	# Optional [ ] wrapping around the full button (e.g. "[👁 |toggle_(v)iew]").
	# YAML: menuBar.brackets.*
	$script:MenuButtonShowBrackets     = $true
	$script:MenuButtonBracketFg        = "DarkCyan"
	$script:MenuButtonBracketBg        = "DarkBlue"
	$script:MenuButtonOnClickBracketFg = "Black"
	$script:MenuButtonOnClickBracketBg = "DarkCyan"

	# --- Global: Hotkey Parentheses --------------------------------------------
	# Controls whether () appear around hotkey letters. Each group is independent
	# so a theme can hide parens on menu buttons but keep them on dialogs (or vice versa).
	# The letter is still highlighted in its hotkey color when parens are hidden.
	# YAML: menuBar.hotkeyParens / dialogs.hotkeyParens
	$script:MenuButtonShowHotkeyParens   = $false   # Menu bar buttons + header mode button
	$script:DialogButtonShowHotkeyParens = $false    # All dialog box buttons

	# --- Dialogs: Shared Button Settings ---------------------------------------
	# Icon prefix and bracket wrapping applied to action buttons in all dialogs.
	# YAML: dialogs.button.*
	$script:DialogButtonShowIcon     = $true
	$script:DialogButtonSeparator    = "|"
	$script:DialogButtonShowBrackets = $false
	$script:DialogButtonBracketFg    = "White"
	$script:DialogButtonBracketBg    = $null   # null = transparent (inherits dialog BG)

	# --- Dialogs: Quit ---------------------------------------------------------
	# YAML: dialogs.quit.*
	$script:QuitDialogBg           = "DarkMagenta"
	$script:QuitDialogShadow       = "DarkMagenta"
	$script:QuitDialogBorder       = "White"
	$script:QuitDialogTitle        = "Yellow"
	$script:QuitDialogText         = "White"
	$script:QuitDialogButtonBg     = "Magenta"
	$script:QuitDialogButtonText   = "White"
	$script:QuitDialogButtonHotkey = "Yellow"

	# --- Menu Bar: Quit Button -------------------------------------------------
	# Overrides the shared menu button colors specifically for the quit button.
	# Defaults inherit from the standard MenuButton* variables.
	# YAML: menuBar.quitButton.*
	$script:QuitButtonBg               = $script:MenuButtonBg
	$script:QuitButtonText             = $script:MenuButtonText
	$script:QuitButtonHotkey           = $script:MenuButtonHotkey
	$script:QuitButtonSeparatorFg      = $script:MenuButtonSeparatorFg
	$script:QuitButtonBracketFg        = $script:MenuButtonBracketFg
	$script:QuitButtonBracketBg        = $script:MenuButtonBracketBg
	$script:QuitButtonOnClickBg        = $script:QuitDialogBg
	$script:QuitButtonOnClickFg        = $script:QuitDialogText
	$script:QuitButtonOnClickHotkey    = $script:QuitDialogTitle
	$script:QuitButtonOnClickSeparatorFg  = $script:QuitDialogText
	$script:QuitButtonOnClickBracketFg    = $script:QuitDialogBorder
	$script:QuitButtonOnClickBracketBg    = $script:QuitDialogBg

	# --- Dialogs: Settings --------------------------------------------------------
	# Colors for the settings mini-popup that appears above the Settings menu button.
	# OnFocus = normal/active state.  OffFocus = dimmed state while a sub-dialog is open.
	# YAML: dialogs.settings.*
	$script:SettingsDialogBg           = "DarkBlue"
	$script:SettingsDialogBorder       = "White"
	$script:SettingsDialogTitle        = "Yellow"
	$script:SettingsDialogText         = "White"
	$script:SettingsDialogButtonBg     = "Blue"
	$script:SettingsDialogButtonText   = "White"
	$script:SettingsDialogButtonHotkey = "Yellow"
	# Off-focus: used while a sub-dialog launched from settings is open
	# YAML: dialogs.settings.offFocus.*
	$script:SettingsDialogOffFocusBg           = "DarkGray"
	$script:SettingsDialogOffFocusBorder       = "Gray"
	$script:SettingsDialogOffFocusTitle        = "DarkYellow"
	$script:SettingsDialogOffFocusText         = "Gray"
	$script:SettingsDialogOffFocusButtonBg     = "DarkGray"
	$script:SettingsDialogOffFocusButtonText   = "Gray"
	$script:SettingsDialogOffFocusButtonHotkey = "DarkYellow"

	# --- Menu Bar: Settings Button ------------------------------------------------
	# Overrides shared menu button colors for the settings button.
	# OnClick defaults match the settings dialog so the button highlights when open.
	# YAML: menuBar.settingsButton.*
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

	# --- Dialogs: Set End Time -------------------------------------------------
	# YAML: dialogs.time.*
	$script:TimeDialogBg           = "DarkBlue"
	$script:TimeDialogShadow       = "DarkBlue"
	$script:TimeDialogBorder       = "White"
	$script:TimeDialogTitle        = "Yellow"
	$script:TimeDialogText         = "White"
	$script:TimeDialogButtonBg     = "Blue"
	$script:TimeDialogButtonText   = "White"
	$script:TimeDialogButtonHotkey = "Yellow"
	$script:TimeDialogFieldBg      = "Blue"
	$script:TimeDialogFieldText    = "White"

	# --- Dialogs: Modify Movement ----------------------------------------------
	# YAML: dialogs.move.*
	$script:MoveDialogBg            = "DarkBlue"
	$script:MoveDialogShadow        = "DarkBlue"
	$script:MoveDialogBorder        = "White"
	$script:MoveDialogTitle         = "Yellow"
	$script:MoveDialogSectionTitle  = "Yellow"
	$script:MoveDialogText          = "White"
	$script:MoveDialogButtonBg      = "Blue"
	$script:MoveDialogButtonText    = "White"
	$script:MoveDialogButtonHotkey  = "Yellow"
	$script:MoveDialogFieldBg       = "Blue"
	$script:MoveDialogFieldText     = "White"

	# --- Dialogs: Info / About -------------------------------------------------
	# YAML: dialogs.info.*
	$script:InfoDialogBg           = "DarkBlue"
	$script:InfoDialogShadow       = "DarkBlue"
	$script:InfoDialogBorder       = "White"
	$script:InfoDialogTitle        = "Yellow"
	$script:InfoDialogText         = "White"
	$script:InfoDialogValue        = "Cyan"
	$script:InfoDialogValueGood    = "Green"
	$script:InfoDialogValueWarn    = "Yellow"
	$script:InfoDialogValueMuted   = "DarkGray"
	$script:InfoDialogSectionTitle = "Yellow"
	$script:InfoDialogButtonBg     = "Blue"
	$script:InfoDialogButtonText   = "White"
	$script:InfoDialogButtonHotkey = "Yellow"

	# --- Resize Screen ---------------------------------------------------------
	# YAML: resize.*
	$script:ResizeBoxBorder  = "White"
	$script:ResizeLogoName   = "Magenta"
	$script:ResizeLogoIcon   = "White"
	$script:ResizeQuoteText  = "White"
	
	# ============================================================================
	# Startup / Initializing Screen
	# ============================================================================

	# Shown immediately at startup — VT100 not yet enabled so Write-Host is used.
	function Show-StartupScreen {
		[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
		try { [Console]::Clear() } catch {}

		$sw    = try { $Host.UI.RawUI.WindowSize.Width  } catch { 80 }
		$sh    = try { $Host.UI.RawUI.WindowSize.Height } catch { 24 }
		$boxW  = [Math]::Min(58, $sw - 4)
		$pad   = " " * [Math]::Max(0, [Math]::Floor(($sw - $boxW) / 2))
		$inner = $boxW - 2
		$hLine = [string]$script:BoxHorizontal
		$top   = $script:BoxTopLeft  + ($hLine * ($boxW - 2)) + $script:BoxTopRight
		$div   = $script:BoxVerticalRight + ($hLine * ($boxW - 2)) + $script:BoxVerticalLeft
		$bot   = $script:BoxBottomLeft + ($hLine * ($boxW - 2)) + $script:BoxBottomRight
		$blank = $script:BoxVertical + (" " * $inner) + $script:BoxVertical

		$vertGap = [Math]::Max(0, [Math]::Floor($sh / 2) - 5)
		for ($i = 0; $i -lt $vertGap; $i++) { Write-Host "" }

		Write-Host "$pad$top"  -ForegroundColor Cyan
		Write-Host "$pad$($script:BoxVertical)$("  mJig  |  Initializing".PadRight($inner))$($script:BoxVertical)" -ForegroundColor Cyan
		Write-Host "$pad$div"  -ForegroundColor Cyan
		Write-Host "$pad$blank" -ForegroundColor Cyan
		Write-Host "$pad$($script:BoxVertical)$("  Initializing...".PadRight($inner))$($script:BoxVertical)" -ForegroundColor White
		Write-Host "$pad$blank" -ForegroundColor Cyan
		Write-Host "$pad$bot"  -ForegroundColor Cyan
	}

	# Shown after initialization completes. By this point VT100 and UTF-8 are set up.
	function Show-StartupComplete {
		param([bool]$HasParams)

		$endTimeDisplay    = if ($EndTime -and $EndTime -ne "0") { $EndTime } else { "none" }
		$autoResumeDisplay = if ($script:AutoResumeDelaySeconds -gt 0) { "$($script:AutoResumeDelaySeconds)s" } else { "off" }

		function drawCompleteScreen {
			param([string]$PromptText)

			$sw    = try { $Host.UI.RawUI.WindowSize.Width  } catch { 80 }
			$sh    = try { $Host.UI.RawUI.WindowSize.Height } catch { 24 }
			$boxW  = [Math]::Min(58, $sw - 4)
			$pad   = " " * [Math]::Max(0, [Math]::Floor(($sw - $boxW) / 2))
			$inner = $boxW - 2
			$hLine = [string]$script:BoxHorizontal
			$top   = $script:BoxTopLeft  + ($hLine * ($boxW - 2)) + $script:BoxTopRight
			$div   = $script:BoxVerticalRight + ($hLine * ($boxW - 2)) + $script:BoxVerticalLeft
			$bot   = $script:BoxBottomLeft + ($hLine * ($boxW - 2)) + $script:BoxBottomRight
			$blank = $script:BoxVertical + (" " * $inner) + $script:BoxVertical

			$vertGap = [Math]::Max(0, [Math]::Floor($sh / 2) - 10)
			try { [Console]::Clear() } catch {}
			for ($i = 0; $i -lt $vertGap; $i++) { Write-Host "" }

			Write-Host "$pad$top"  -ForegroundColor Cyan
			Write-Host "$pad$($script:BoxVertical)$("  mJig  |  Initialization Complete".PadRight($inner))$($script:BoxVertical)" -ForegroundColor Cyan
			Write-Host "$pad$div"  -ForegroundColor Cyan
			Write-Host "$pad$blank" -ForegroundColor Cyan
			Write-Host "$pad$($script:BoxVertical)$("  Initialization complete".PadRight($inner))$($script:BoxVertical)" -ForegroundColor Green
			Write-Host "$pad$($script:BoxVertical)$("  Version:     $($script:Version)".PadRight($inner))$($script:BoxVertical)" -ForegroundColor White
			Write-Host "$pad$blank" -ForegroundColor Cyan
			Write-Host "$pad$($script:BoxVertical)$("  Output:      $Output".PadRight($inner))$($script:BoxVertical)"  -ForegroundColor White
			Write-Host "$pad$($script:BoxVertical)$("  Interval:    $($script:IntervalSeconds)s  (variance: +-$($script:IntervalVariance)s)".PadRight($inner))$($script:BoxVertical)" -ForegroundColor White
			Write-Host "$pad$($script:BoxVertical)$("  Distance:    $($script:TravelDistance)px  (variance: +-$($script:TravelVariance)px)".PadRight($inner))$($script:BoxVertical)" -ForegroundColor White
			Write-Host "$pad$($script:BoxVertical)$("  Move speed:  $($script:MoveSpeed)s  (variance: +-$($script:MoveVariance)s)".PadRight($inner))$($script:BoxVertical)" -ForegroundColor White
			Write-Host "$pad$($script:BoxVertical)$("  End time:    $endTimeDisplay".PadRight($inner))$($script:BoxVertical)" -ForegroundColor White
			Write-Host "$pad$($script:BoxVertical)$("  Auto-resume: $autoResumeDisplay".PadRight($inner))$($script:BoxVertical)" -ForegroundColor White
			Write-Host "$pad$blank" -ForegroundColor Cyan
			Write-Host "$pad$div"   -ForegroundColor Cyan
			Write-Host "$pad$blank" -ForegroundColor Cyan
			Write-Host "$pad$($script:BoxVertical)$("  $PromptText".PadRight($inner))$($script:BoxVertical)" -ForegroundColor Yellow
			Write-Host "$pad$blank" -ForegroundColor Cyan
			Write-Host "$pad$bot"   -ForegroundColor Cyan
		}

		function getSize { @{ W = $Host.UI.RawUI.WindowSize.Width; H = $Host.UI.RawUI.WindowSize.Height } }

	# Shared helper: wait for any non-modifier key-UP via PeekConsoleInput (5ms poll).
	# Returns when a qualifying key-up is detected; flushes all buffered events so the
	# main loop starts with a clean input queue.  Falls back to KeyAvailable if the
	# Win32 API is unavailable.
	$modifierVKs = @(0x10, 0x11, 0x12, 0xA0, 0xA1, 0xA2, 0xA3, 0xA4, 0xA5, 0x5B, 0x5C)
	$waitForKeyUp = {
		$hIn = [mJiggAPI.Mouse]::GetStdHandle(-10)
		$peekBuf  = New-Object 'mJiggAPI.INPUT_RECORD[]' 32
		$peekEvts = [uint32]0
		$detected = $false
		while (-not $detected) {
			Start-Sleep -Milliseconds 5
			try {
				if ([mJiggAPI.Mouse]::PeekConsoleInput($hIn, $peekBuf, 32, [ref]$peekEvts) -and $peekEvts -gt 0) {
					for ($e = 0; $e -lt [int]$peekEvts; $e++) {
						if ($peekBuf[$e].EventType -eq 0x0001 -and $peekBuf[$e].KeyEvent.bKeyDown -eq 0 -and
						    $peekBuf[$e].KeyEvent.wVirtualKeyCode -notin $modifierVKs) {
							$detected = $true; break
						}
					}
					if ($detected) {
						$flushBuf = New-Object 'mJiggAPI.INPUT_RECORD[]' $peekEvts
						$flushed  = [uint32]0
						[mJiggAPI.Mouse]::ReadConsoleInput($hIn, $flushBuf, $peekEvts, [ref]$flushed) | Out-Null
					}
				}
			} catch {
				# Fallback: accept any buffered key
				if ($Host.UI.RawUI.KeyAvailable) {
					try { $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown,IncludeKeyUp,AllowCtrlC") } catch {}
					$detected = $true
				}
			}
		}
	}

	if (-not $HasParams) {
		# Wait for key-up; check for resize every 50ms while polling
		drawCompleteScreen "Press any key to continue..."
		$lastSize   = getSize
		$hIn        = [mJiggAPI.Mouse]::GetStdHandle(-10)
		$peekBuf    = New-Object 'mJiggAPI.INPUT_RECORD[]' 32
		$peekEvts   = [uint32]0
		# Drain events buffered before the prompt appeared (e.g. Enter key-up from launch)
		try { $Host.UI.RawUI.FlushInputBuffer() } catch {}
		$detected   = $false
		$resizeTick = 0
		while (-not $detected) {
			Start-Sleep -Milliseconds 5
			$resizeTick++
			if ($resizeTick -ge 10) {
				$resizeTick = 0
				$curSize = getSize
				if ($curSize.W -ne $lastSize.W -or $curSize.H -ne $lastSize.H) {
					$null = Invoke-ResizeHandler
					drawCompleteScreen "Press any key to continue..."
					$lastSize = getSize
				}
			}
			try {
				if ([mJiggAPI.Mouse]::PeekConsoleInput($hIn, $peekBuf, 32, [ref]$peekEvts) -and $peekEvts -gt 0) {
					for ($e = 0; $e -lt [int]$peekEvts; $e++) {
						if ($peekBuf[$e].EventType -eq 0x0001 -and $peekBuf[$e].KeyEvent.bKeyDown -eq 0 -and
						    $peekBuf[$e].KeyEvent.wVirtualKeyCode -notin $modifierVKs) {
							$detected = $true; break
						}
					}
					if ($detected) {
						$flushBuf = New-Object 'mJiggAPI.INPUT_RECORD[]' $peekEvts
						$flushed  = [uint32]0
						[mJiggAPI.Mouse]::ReadConsoleInput($hIn, $flushBuf, $peekEvts, [ref]$flushed) | Out-Null
					}
				}
			} catch {
				if ($Host.UI.RawUI.KeyAvailable) {
					try { $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown,IncludeKeyUp,AllowCtrlC") } catch {}
					$detected = $true
				}
			}
		}
	} else {
		# Countdown: 7 seconds, 1s per tick, key-up skips immediately
		$lastSize = getSize
		$hIn      = [mJiggAPI.Mouse]::GetStdHandle(-10)
		$peekBuf  = New-Object 'mJiggAPI.INPUT_RECORD[]' 32
		$peekEvts = [uint32]0
		# Drain events buffered before the prompt appeared (e.g. Enter key-up from launch)
		try { $Host.UI.RawUI.FlushInputBuffer() } catch {}
		$detected = $false
		for ($i = 7; $i -gt 0 -and -not $detected; $i--) {
			$secs = if ($i -eq 1) { "second" } else { "seconds" }
			drawCompleteScreen "Starting in $i $secs...  (any key to skip)"
			$lastSize  = getSize
			$secStart  = [DateTime]::UtcNow
			$resizeTick = 0
			while (-not $detected -and ([DateTime]::UtcNow - $secStart).TotalMilliseconds -lt 1000) {
				Start-Sleep -Milliseconds 5
				$resizeTick++
				if ($resizeTick -ge 10) {
					$resizeTick = 0
					$curSize = getSize
					if ($curSize.W -ne $lastSize.W -or $curSize.H -ne $lastSize.H) {
						$null = Invoke-ResizeHandler
						drawCompleteScreen "Starting in $i $secs...  (any key to skip)"
						$lastSize = getSize
					}
				}
				try {
					if ([mJiggAPI.Mouse]::PeekConsoleInput($hIn, $peekBuf, 32, [ref]$peekEvts) -and $peekEvts -gt 0) {
						for ($e = 0; $e -lt [int]$peekEvts; $e++) {
							if ($peekBuf[$e].EventType -eq 0x0001 -and $peekBuf[$e].KeyEvent.bKeyDown -eq 0 -and
							    $peekBuf[$e].KeyEvent.wVirtualKeyCode -notin $modifierVKs) {
								$detected = $true; break
							}
						}
						if ($detected) {
							$flushBuf = New-Object 'mJiggAPI.INPUT_RECORD[]' $peekEvts
							$flushed  = [uint32]0
							[mJiggAPI.Mouse]::ReadConsoleInput($hIn, $flushBuf, $peekEvts, [ref]$flushed) | Out-Null
						}
					}
				} catch {
					if ($Host.UI.RawUI.KeyAvailable) {
						try { $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown,IncludeKeyUp,AllowCtrlC") } catch {}
						$detected = $true
					}
				}
			}
		}
	}
	}

	# Fetches the latest release info from GitHub. Returns a hashtable with
	# {latest, url, isNewer, error}. Result is cached in $script:VersionCheckCache
	# so subsequent calls are instant. Pass -Force to bypass the cache.
	function Get-LatestVersionInfo {
		param([switch]$Force)
		if (-not $Force -and $null -ne $script:VersionCheckCache) {
			return $script:VersionCheckCache
		}
		try {
			$response   = Invoke-RestMethod -Uri "https://api.github.com/repos/ziaprazid0ne/mJig/releases/latest" -TimeoutSec 5 -UseBasicParsing
			$latestTag  = $response.tag_name -replace '^v', ''
			$isNewer    = $false
			try { $isNewer = ([version]$latestTag -gt [version]$script:Version) } catch {}
			$result = @{ latest = $latestTag; url = $response.html_url; isNewer = $isNewer; error = $null }
		} catch {
			$result = @{ latest = $null; url = $null; isNewer = $false; error = "Could not connect" }
		}
		$script:VersionCheckCache = $result
		return $result
	}

	# Unified resize handler — blocks until the window is stable and LMB is released.
	# Draws the resize logo in normal mode, or a blank screen in hidden mode.
	# Returns the final stable [System.Management.Automation.Host.Size] object.
	# Can be called from any context after initialization (startup screen, main loop, etc.).
	function Invoke-ResizeHandler {
		$psw       = (Get-Host).UI.RawUI
		$drawCount = 0
		$script:CurrentResizeQuote     = $null
		$script:ResizeLogoLockedHeight = $null
		$pendingSize  = $psw.WindowSize
		$lastDetected = Get-Date

		if ($Output -eq "hidden") {
			[Console]::Clear()
		} else {
			Draw-ResizeLogo -ClearFirst -WindowSize $pendingSize
		}

		while ($true) {
			Start-Sleep -Milliseconds 1
			$newSize   = $psw.WindowSize
			$isNewSize = ($newSize.Width -ne $pendingSize.Width -or $newSize.Height -ne $pendingSize.Height)

			if ($isNewSize) {
				$pendingSize  = $newSize
				$lastDetected = Get-Date
				if ($Output -ne "hidden") {
					$drawCount++
					if ($drawCount % 50 -eq 0) { [Console]::Clear(); Restore-ConsoleInputMode }
					Draw-ResizeLogo -ClearFirst -WindowSize $newSize
				}
			}

			# Stability + LMB gate: only exit once size is stable AND mouse is released
			$elapsed = ((Get-Date) - $lastDetected).TotalMilliseconds
			if ($elapsed -ge $ResizeThrottleMs) {
				$lmbHeld = ([mJiggAPI.Mouse]::GetAsyncKeyState(0x01) -band 0x8000) -ne 0
				if (-not $lmbHeld) {
					[Console]::Clear()
					Restore-ConsoleInputMode
					Send-ResizeExitWakeKey
					return $pendingSize
				}
			}
		}
	}

	# Function to find window handle using EnumWindows (like Get-ProcessWindow.ps1)
	function Find-WindowHandle {
		param(
			[int]$ProcessId = $PID
		)
		
		$foundHandle = [IntPtr]::Zero
		
		# First, try to find by window title (most reliable for our case)
		try {
			$hasFindWindow = [mJiggAPI.Mouse].GetMethod("FindWindow") -ne $null
			if ($hasFindWindow -and $null -ne $script:WindowTitle) {
				# Try exact title match
				$handle = [mJiggAPI.Mouse]::FindWindow($null, $script:WindowTitle)
				if ($handle -eq [IntPtr]::Zero -and $DebugMode) {
					# Try with DEBUGMODE suffix
					$handle = [mJiggAPI.Mouse]::FindWindow($null, "$script:WindowTitle - DEBUGMODE")
				}
				if ($handle -ne [IntPtr]::Zero) {
					# Verify it belongs to our process
					$hasGetWindowThreadProcessId = [mJiggAPI.Mouse].GetMethod("GetWindowThreadProcessId") -ne $null
					if ($hasGetWindowThreadProcessId) {
						$windowProcessId = 0
						[mJiggAPI.Mouse]::GetWindowThreadProcessId($handle, [ref]$windowProcessId) | Out-Null
						if ($windowProcessId -eq $ProcessId -or $windowProcessId -eq $PID) {
							return $handle
						}
					} else {
						# Can't verify, but return it anyway
						return $handle
					}
				}
			}
		} catch {
			# FindWindow by title failed
		}
		
		# Use the C# EnumWindows-based method (fallback)
		try {
			$hasFindWindowByProcessId = [mJiggAPI.Mouse].GetMethod("FindWindowByProcessId") -ne $null
			if ($hasFindWindowByProcessId) {
				$foundHandle = [mJiggAPI.Mouse]::FindWindowByProcessId($ProcessId)
				if ($foundHandle -ne [IntPtr]::Zero) {
					return $foundHandle
				}
			}
		} catch {
			# FindWindowByProcessId failed or not available
		}
		
		# Fallback: Try parent process if current process has no window
		try {
			$currentProcess = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
			if ($null -ne $currentProcess -and $null -ne $currentProcess.Parent) {
				$parentId = $currentProcess.Parent.Id
				$hasFindWindowByProcessId = [mJiggAPI.Mouse].GetMethod("FindWindowByProcessId") -ne $null
				if ($hasFindWindowByProcessId) {
					$foundHandle = [mJiggAPI.Mouse]::FindWindowByProcessId($parentId)
					if ($foundHandle -ne [IntPtr]::Zero) {
						return $foundHandle
					}
				}
			}
		} catch {
			# Parent process lookup failed
		}
		
		return [IntPtr]::Zero
	}

	# Prep the Host Console
	# Set window title FIRST so we can be found by duplicate detection
	try {
		$Host.UI.RawUI.WindowTitle = if ($DebugMode) { "$script:WindowTitle - DEBUGMODE" } else { $script:WindowTitle }
		if ($DebugMode) {
			Write-Host "[DEBUG] Set window title: $($Host.UI.RawUI.WindowTitle)" -ForegroundColor $script:TextHighlight
		}
	} catch {
		if ($DebugMode) {
			Write-Host "  [WARN] Failed to set window title: $($_.Exception.Message)" -ForegroundColor $script:TextWarning
		}
	}
	
	# Check for duplicate windows - FAIL if another instance is running
	if ($DebugMode) {
		Write-Host "[DEBUG] Checking for duplicate mJig instances..." -ForegroundColor $script:TextHighlight
	}
	
	$duplicateFound = $false
	$duplicateProcessId = 0
	$duplicateProcessName = "Unknown"
	
	# Search for any windows with our window title (excluding our own PID)
	try {
		$hasFindWindowByTitlePattern = [mJiggAPI.Mouse].GetMethod("FindWindowByTitlePattern") -ne $null
		if ($hasFindWindowByTitlePattern) {
			# Search for windows with our exact title, excluding our own PID
			$duplicateHandle = [mJiggAPI.Mouse]::FindWindowByTitlePattern($script:WindowTitle, $PID)
			if ($duplicateHandle -eq [IntPtr]::Zero -and $DebugMode) {
				# Try with DEBUGMODE suffix
				$duplicateHandle = [mJiggAPI.Mouse]::FindWindowByTitlePattern("$script:WindowTitle - DEBUGMODE", $PID)
			}
			
			if ($duplicateHandle -ne [IntPtr]::Zero) {
				# Found a window with matching title - verify the process is actually running
				$hasGetWindowThreadProcessId = [mJiggAPI.Mouse].GetMethod("GetWindowThreadProcessId") -ne $null
				if ($hasGetWindowThreadProcessId) {
					$windowProcessId = 0
					[mJiggAPI.Mouse]::GetWindowThreadProcessId($duplicateHandle, [ref]$windowProcessId) | Out-Null
					if ($windowProcessId -ne 0) {
						# Verify the process actually exists and is running
						try {
							$otherProcess = Get-Process -Id $windowProcessId -ErrorAction Stop
							if ($null -ne $otherProcess) {
								# Process exists - this is a real duplicate
								$duplicateFound = $true
								$duplicateProcessId = $windowProcessId
								$duplicateProcessName = $otherProcess.ProcessName
							}
						} catch {
							# Process doesn't exist - window handle is stale, ignore it
							if ($DebugMode) {
								Write-Host "  [INFO] Found window handle for PID $windowProcessId but process doesn't exist (stale handle)" -ForegroundColor Gray
							}
						}
					}
				}
			}
		} else {
			# Fallback: Try FindWindow with exact title match
			$hasFindWindow = [mJiggAPI.Mouse].GetMethod("FindWindow") -ne $null
			if ($hasFindWindow) {
				$testHandle = [mJiggAPI.Mouse]::FindWindow($null, $script:WindowTitle)
				if ($testHandle -eq [IntPtr]::Zero -and $DebugMode) {
					$testHandle = [mJiggAPI.Mouse]::FindWindow($null, "$script:WindowTitle - DEBUGMODE")
				}
				if ($testHandle -ne [IntPtr]::Zero) {
					$hasGetWindowThreadProcessId = [mJiggAPI.Mouse].GetMethod("GetWindowThreadProcessId") -ne $null
					if ($hasGetWindowThreadProcessId) {
						$windowProcessId = 0
						[mJiggAPI.Mouse]::GetWindowThreadProcessId($testHandle, [ref]$windowProcessId) | Out-Null
						if ($windowProcessId -ne 0 -and $windowProcessId -ne $PID) {
							# Verify the process actually exists and is running
							try {
								$otherProcess = Get-Process -Id $windowProcessId -ErrorAction Stop
								if ($null -ne $otherProcess) {
									# Process exists - this is a real duplicate
									$duplicateFound = $true
									$duplicateProcessId = $windowProcessId
									$duplicateProcessName = $otherProcess.ProcessName
								}
							} catch {
								# Process doesn't exist - window handle is stale, ignore it
								if ($DebugMode) {
									Write-Host "  [INFO] Found window handle for PID $windowProcessId but process doesn't exist (stale handle)" -ForegroundColor Gray
								}
							}
						}
					}
				}
			}
		}
	} catch {
		if ($DebugMode) {
			Write-Host "  [WARN] Could not check for duplicates: $($_.Exception.Message)" -ForegroundColor $script:TextWarning
		}
	}
	
	# If duplicate found, exit with error
	if ($duplicateFound) {
		Write-Host ""
		Write-Host "ERROR: Another instance of mJig is already running!" -ForegroundColor $script:TextError
		Write-Host "  Process ID: $duplicateProcessId" -ForegroundColor $script:TextError
		Write-Host "  Process Name: $duplicateProcessName" -ForegroundColor $script:TextError
		Write-Host "  Window Title: $script:WindowTitle" -ForegroundColor $script:TextError
		Write-Host ""
		Write-Host "Please close the other instance before starting a new one." -ForegroundColor $script:TextWarning
		Write-Host ""
		exit 1
	} else {
		if ($DebugMode) {
			Write-Host "  [OK] No duplicate instances found" -ForegroundColor $script:TextSuccess
		}
	}
	
	# Show initializing screen (or plain clear for DebugMode)
	if ($Output -ne "hidden") {
		if (-not $DebugMode) {
			Show-StartupScreen
		} else {
			try { Clear-Host } catch {}
		}
	}
	
	if ($DebugMode) {
		Write-Host "Initialization Debug" -ForegroundColor $script:HeaderAppName
		Write-Host ""
		Write-Host "[DEBUG] Initializing console..." -ForegroundColor $script:TextHighlight
		# Window title already set above, just log it
		Write-Host "[DEBUG] Window title: $($Host.UI.RawUI.WindowTitle)" -ForegroundColor $script:TextHighlight
		Write-Host "[DEBUG] DebugMode is ENABLED - click detection will be logged" -ForegroundColor $script:TextWarning
		Write-Host ""
	}
	try {
		$signature = @'
[DllImport("kernel32.dll", SetLastError = true)]
public static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);
[DllImport("kernel32.dll", SetLastError = true)]
public static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);
[DllImport("kernel32.dll", SetLastError = true)]
public static extern IntPtr GetStdHandle(int nStdHandle);
'@
		$type = Add-Type -MemberDefinition $signature -Name Win32Utils -Namespace Console -PassThru -ErrorAction SilentlyContinue
		if ($type) {
			$STD_INPUT_HANDLE = -10
			$hConsole = $type::GetStdHandle($STD_INPUT_HANDLE)
			$mode = 0
			if ($type::GetConsoleMode($hConsole, [ref]$mode)) {
				$ENABLE_QUICK_EDIT_MODE = 0x0040
				$ENABLE_MOUSE_INPUT = 0x0010
				$ENABLE_EXTENDED_FLAGS = 0x0080
				# Disable Quick Edit Mode but enable Mouse Input
				$newMode = ($mode -band (-bnot $ENABLE_QUICK_EDIT_MODE)) -bor $ENABLE_MOUSE_INPUT
				if ($type::SetConsoleMode($hConsole, $newMode)) {
					if ($DebugMode) {
						Write-Host "  [OK] Quick Edit Mode disabled, Mouse Input enabled" -ForegroundColor $script:TextSuccess
					}
				} else {
					if ($DebugMode) {
						Write-Host "  [WARN] Failed to set console mode (SetConsoleMode failed)" -ForegroundColor $script:TextWarning
					}
				}
			} else {
				if ($DebugMode) {
					Write-Host "  [WARN] Failed to disable Quick Edit Mode (GetConsoleMode failed)" -ForegroundColor $script:TextWarning
				}
			}
		} else {
			if ($DebugMode) {
				Write-Host "  [WARN] Failed to disable Quick Edit Mode (could not load Win32 API)" -ForegroundColor $script:TextWarning
			}
		}
	} catch {
		if ($DebugMode) {
			Write-Host "  [WARN] Failed to disable Quick Edit Mode: $($_.Exception.Message)" -ForegroundColor $script:TextWarning
		}
	}
	
	# Enable VT100 processing on stdout for ANSI escape sequence rendering
	try {
		if ($type) {
			$STD_OUTPUT_HANDLE = -11
			$hStdOut = $type::GetStdHandle($STD_OUTPUT_HANDLE)
			$outMode = 0
			if ($type::GetConsoleMode($hStdOut, [ref]$outMode)) {
				$ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004
				$newOutMode = $outMode -bor $ENABLE_VIRTUAL_TERMINAL_PROCESSING
				if ($type::SetConsoleMode($hStdOut, $newOutMode)) {
					if ($DebugMode) {
						Write-Host "  [OK] VT100 processing enabled on stdout" -ForegroundColor $script:TextSuccess
					}
				} else {
					if ($DebugMode) {
						Write-Host "  [WARN] Failed to enable VT100 processing" -ForegroundColor $script:TextWarning
					}
				}
			}
		}
		[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
		if ($DebugMode) {
			Write-Host "  [OK] Console output encoding set to UTF-8" -ForegroundColor $script:TextSuccess
		}
	} catch {
		if ($DebugMode) {
			Write-Host "  [WARN] VT100/UTF-8 setup: $($_.Exception.Message)" -ForegroundColor $script:TextWarning
		}
	}
	
	try {
		[Console]::Write("$([char]27)[?25l")
		$script:CursorVisible = $false
		if ($DebugMode) {
			Write-Host "  [OK] Console cursor hidden" -ForegroundColor $script:TextSuccess
		}
	} catch {
		if ($DebugMode) {
			Write-Host "  [FAIL] Failed to hide cursor: $($_.Exception.Message)" -ForegroundColor $script:TextError
		}
	}
	
	# Capture Initial Buffer & Window Sizes (needed even for hidden mode)
	if ($DebugMode) {
		Write-Host "[DEBUG] Capturing console dimensions..." -ForegroundColor $script:TextHighlight
	}
	try {
		$pshost = Get-Host
		$pswindow = $pshost.UI.RawUI
		$newWindowSize = $pswindow.WindowSize
		$newBufferSize = $pswindow.BufferSize
		if ($DebugMode) {
			Write-Host "  [OK] Got console dimensions" -ForegroundColor $script:TextSuccess
			Write-Host "    Window Size: $($newWindowSize.Width)x$($newWindowSize.Height)" -ForegroundColor Gray
			Write-Host "    Buffer Size: $($newBufferSize.Width)x$($newBufferSize.Height)" -ForegroundColor Gray
		}
	} catch {
		if ($DebugMode) {
			Write-Host "  [FAIL] Failed to get console dimensions: $($_.Exception.Message)" -ForegroundColor $script:TextError
		}
		throw  # Re-throw as this is critical
	}
	# Set vertical buffer to match window height, but let horizontal buffer be managed by PowerShell (for text zoom)
	try {
		$pswindow.BufferSize = New-Object System.Management.Automation.Host.Size($newBufferSize.Width, $newWindowSize.Height)
		$newBufferSize = $pswindow.BufferSize
		if ($DebugMode) {
			Write-Host "  [OK] Set buffer height to match window height" -ForegroundColor $script:TextSuccess
		}
	} catch {
		# If setting buffer size fails, continue with current buffer size
		if ($DebugMode) {
			Write-Host "  [WARN] Failed to set buffer size: $($_.Exception.Message)" -ForegroundColor $script:TextWarning
			Write-Host "    Continuing with current buffer size" -ForegroundColor Gray
		}
		$newBufferSize = $pswindow.BufferSize
	}
	$OldBufferSize = $newBufferSize
	$OldWindowSize = $newWindowSize
	$HostWidth = $newWindowSize.Width
	$HostHeight = $newWindowSize.Height
	if ($DebugMode) {
		Write-Host "    Final host dimensions: ${HostWidth}x${HostHeight}" -ForegroundColor Gray
	}

	# Initialize the Output Array
	if ($DebugMode) {
		Write-Host "[DEBUG] Initializing output array..." -ForegroundColor $script:TextHighlight
	}
	try {
		if ($Output -ne "hidden") {
			$LogArray = @()
			if ($DebugMode) {
				Write-Host "  [OK] Output mode: $Output" -ForegroundColor $script:TextSuccess
			}
		} else {
			if ($DebugMode) {
				Write-Host "  [OK] Output mode: hidden (no log array)" -ForegroundColor $script:TextSuccess
			}
		}
	} catch {
		if ($DebugMode) {
			Write-Host "  [FAIL] Failed to initialize output array: $($_.Exception.Message)" -ForegroundColor $script:TextError
		}
		throw  # Re-throw as this is critical
	}

	###############################
	## Calculating the End Times ##
	###############################
	
	if ($DebugMode) {
		Write-Host "[DEBUG] Calculating end times..." -ForegroundColor $script:TextHighlight
	}
	
	# Convert EndTime to string and parse
	# Handle: "0" = none, "00" or "0000" = midnight (0000), 2-digit = hour on the hour, 4-digit = HHmm
	try {
		$endTimeTrimmed = $EndTime.Trim()
		
		# Check if it's "0" (single digit) - means no end time
		if ($endTimeTrimmed -eq "0") {
			$endTimeInt = -1
			$endTimeStr = ""
			if ($DebugMode) {
				Write-Host "  [OK] No end time specified - script will run indefinitely" -ForegroundColor $script:TextSuccess
			}
		} elseif ($endTimeTrimmed.Length -eq 2) {
			# 2-digit input = hour on the hour (e.g., "12" = 1200, "00" = 0000)
			$hours = [int]$endTimeTrimmed
			if ($hours -ge 0 -and $hours -le 23) {
				$endTimeInt = $hours * 100  # Convert to HHmm format (e.g., 12 -> 1200)
				$endTimeStr = $endTimeInt.ToString().PadLeft(4, '0')
				if ($DebugMode) {
					Write-Host "  [OK] Parsed end time: $endTimeStr (hour on the hour)" -ForegroundColor $script:TextSuccess
				}
			} else {
				Write-Host "Error: Invalid hour format. Hours must be 00-23. Got: $EndTime" -ForegroundColor $script:TextError
				throw "Invalid hour format: $EndTime"
			}
		} elseif ($endTimeTrimmed.Length -eq 4) {
			# 4-digit input = HHmm format
			$endTimeInt = [int]$endTimeTrimmed
			$hours = [int]$endTimeTrimmed.Substring(0, 2)
			$minutes = [int]$endTimeTrimmed.Substring(2, 2)
			
			# Validate HHmm format
			if ($hours -ge 0 -and $hours -le 23 -and $minutes -ge 0 -and $minutes -le 59) {
				$endTimeStr = $endTimeTrimmed
				if ($DebugMode) {
					Write-Host "  [OK] Parsed end time: $endTimeStr" -ForegroundColor $script:TextSuccess
				}
			} else {
				if ($hours -gt 23) {
					Write-Host "Error: Invalid time format. Hours must be 00-23. Got: $EndTime" -ForegroundColor $script:TextError
				} elseif ($minutes -gt 59) {
					Write-Host "Error: Invalid time format. Minutes must be 00-59. Got: $EndTime" -ForegroundColor $script:TextError
				} else {
					Write-Host "Error: Invalid time format. Expected HHmm format (0000-2359). Got: $EndTime" -ForegroundColor $script:TextError
				}
				throw "Invalid time format: $EndTime"
			}
		} else {
			Write-Host "Error: Invalid time format. Expected '0' (none), 2-digit hour (00-23), or 4-digit HHmm (0000-2359). Got: $EndTime" -ForegroundColor $script:TextError
			throw "Invalid time format: $EndTime"
		}
	} catch {
		if ($DebugMode) {
			Write-Host "  [FAIL] Failed to parse endTime: $($_.Exception.Message)" -ForegroundColor $script:TextError
		}
		if ($_.Exception.Message -notmatch "Invalid time format") {
			Write-Host "Error: Invalid EndTime format: $EndTime" -ForegroundColor $script:TextError
		}
		throw
	}
	
	# Time format has already been validated in the try-catch block above
	# Proceed with initialization
		# Diagnostics - initialize folder and file paths
		$script:DiagEnabled = $Diag
		if ($script:DiagEnabled) {
			$script:DiagFolder = Join-Path $PSScriptRoot "_diag"
			if (-not (Test-Path $script:DiagFolder)) {
				New-Item -ItemType Directory -Path $script:DiagFolder -Force | Out-Null
			}
			$script:StartupDiagFile = Join-Path $script:DiagFolder "startup.txt"
			$script:SettleDiagFile = Join-Path $script:DiagFolder "settle.txt"
			$script:InputDiagFile = Join-Path $script:DiagFolder "input.txt"
			
			$diagTimestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
			"=== mJig Startup Diag: $diagTimestamp ===" | Out-File $script:StartupDiagFile
			"$(Get-Date -Format 'HH:mm:ss.fff') - CHECKPOINT 1: Starting initialization" | Out-File $script:StartupDiagFile -Append
			"  Diag enabled, folder: $script:DiagFolder" | Out-File $script:StartupDiagFile -Append
			"=== mJig Settle Diag: $diagTimestamp ===" | Out-File $script:SettleDiagFile
			"$(Get-Date -Format 'HH:mm:ss.fff') - Settle diagnostics started" | Out-File $script:SettleDiagFile -Append
			"=== mJig Input Diag: $diagTimestamp ===" | Out-File $script:InputDiagFile
			"$(Get-Date -Format 'HH:mm:ss.fff') - Input diagnostics started (PeekConsoleInput + GetLastInputInfo)" | Out-File $script:InputDiagFile -Append
		}
		
		if ($DebugMode) {
			Write-Host "[DEBUG] Loading System.Windows.Forms assembly..." -ForegroundColor $script:TextHighlight
		}
		try {
			Add-Type -AssemblyName System.Windows.Forms
			if ($DebugMode) {
				Write-Host "  [OK] System.Windows.Forms loaded" -ForegroundColor $script:TextSuccess
			}
			# Cache screen bounds now that the assembly is loaded
			$script:ScreenWidth = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width
			$script:ScreenHeight = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height
			if ($DebugMode) {
				Write-Host "  [OK] Screen bounds cached: $($script:ScreenWidth) x $($script:ScreenHeight)" -ForegroundColor $script:TextSuccess
			}
		} catch {
			if ($DebugMode) {
				Write-Host "  [FAIL] Failed to load System.Windows.Forms: $($_.Exception.Message)" -ForegroundColor $script:TextError
			}
			throw  # Re-throw as this is critical
		}
		
		# Add Windows API for system-wide keyboard detection and key sending
		if ($DebugMode) {
			Write-Host "[DEBUG] Loading Windows API types..." -ForegroundColor $script:TextHighlight
		}
		# Check if types already exist and have the required methods
		$typesNeedReload = $false
		try {
			# Use a safer method to check if types exist without throwing errors
			$existingKeyboard = $null
			$existingMouse = $null
			
			# Try to get the types using Get-Type or by checking if they're loaded
			$allTypes = [System.AppDomain]::CurrentDomain.GetAssemblies() | ForEach-Object { $_.GetTypes() } | Where-Object { $_.Namespace -eq 'mJiggAPI' }
			
			foreach ($type in $allTypes) {
				if ($type.Name -eq 'Keyboard') { $existingKeyboard = $type }
				if ($type.Name -eq 'Mouse') { $existingMouse = $type }
			}
			
			if ($null -ne $existingMouse) {
				$hasGetCursorPos = $existingMouse.GetMethod("GetCursorPos") -ne $null
				$hasGetForegroundWindow = $existingMouse.GetMethod("GetForegroundWindow") -ne $null
				$hasFindWindow = $existingMouse.GetMethod("FindWindow") -ne $null
				$hasFindWindowByProcessId = $existingMouse.GetMethod("FindWindowByProcessId") -ne $null
				$hasFindWindowByTitlePattern = $existingMouse.GetMethod("FindWindowByTitlePattern") -ne $null
				if (-not $hasGetCursorPos -or -not $hasGetForegroundWindow -or -not $hasFindWindow -or -not $hasFindWindowByProcessId -or -not $hasFindWindowByTitlePattern) {
					# Type exists but missing required methods - need to reload
					# Note: PowerShell cannot remove types once loaded, so Add-Type will fail silently
					# User may need to restart PowerShell session to get updated types
					$typesNeedReload = $true
					if ($DebugMode) {
						Write-Host "  [WARN] Existing types found but missing required methods" -ForegroundColor $script:TextWarning
						Write-Host "  [WARN] Missing: GetCursorPos=$(-not $hasGetCursorPos), GetForegroundWindow=$(-not $hasGetForegroundWindow), FindWindow=$(-not $hasFindWindow), FindWindowByProcessId=$(-not $hasFindWindowByProcessId), FindWindowByTitlePattern=$(-not $hasFindWindowByTitlePattern)" -ForegroundColor $script:TextWarning
						Write-Host "  [WARN] Attempting reload (may fail if types already exist - restart PowerShell if needed)" -ForegroundColor $script:TextWarning
					}
				} else {
					# Types exist and have required methods - skip reload
					if ($DebugMode) {
						Write-Host "  [INFO] Types already loaded from previous run (with required methods)" -ForegroundColor Gray
					}
				}
			} else {
				# Types don't exist - need to load
				$typesNeedReload = $true
			}
		} catch {
			# Types don't exist or can't be accessed - need to load
			$typesNeedReload = $true
			if ($DebugMode) {
				Write-Host "  [INFO] Types not found, will load them: $($_.Exception.Message)" -ForegroundColor Gray
			}
		}
		
		# Only attempt to add types if they don't exist or are incomplete
		if ($typesNeedReload) {
			try {
				# Try to add the types - use ErrorAction Stop to catch failures
				$typeDefinition = @"
using System;
using System.Runtime.InteropServices;
namespace mJiggAPI {
	// Define POINT struct for P/Invoke (avoids dependency on System.Drawing.Primitives)
	[StructLayout(LayoutKind.Sequential)]
	public struct POINT {
		public int X;
		public int Y;
		
		public POINT(int x, int y) {
			X = x;
			Y = y;
		}
	}
	
	[StructLayout(LayoutKind.Sequential)]
	public struct CONSOLE_SCREEN_BUFFER_INFO {
		public COORD dwSize;
		public COORD dwCursorPosition;
		public short wAttributes;
		public SMALL_RECT srWindow;
		public COORD dwMaximumWindowSize;
	}
	
	[StructLayout(LayoutKind.Sequential)]
	public struct MOUSE_EVENT_RECORD {
		public COORD dwMousePosition;
		public uint dwButtonState;
		public uint dwControlKeyState;
		public uint dwEventFlags;
	}
	
	[StructLayout(LayoutKind.Sequential)]
	public struct KEY_EVENT_RECORD {
		public int bKeyDown;
		public ushort wRepeatCount;
		public ushort wVirtualKeyCode;
		public ushort wVirtualScanCode;
		public char UnicodeChar;
		public uint dwControlKeyState;
	}
	
	[StructLayout(LayoutKind.Explicit)]
	public struct INPUT_RECORD {
		[FieldOffset(0)]
		public ushort EventType;
		[FieldOffset(4)]
		public MOUSE_EVENT_RECORD MouseEvent;
		[FieldOffset(4)]
		public KEY_EVENT_RECORD KeyEvent;
	}
	
	[StructLayout(LayoutKind.Sequential)]
	public struct COORD {
		public short X;
		public short Y;
	}
	
	[StructLayout(LayoutKind.Sequential)]
	public struct SMALL_RECT {
		public short Left;
		public short Top;
		public short Right;
		public short Bottom;
	}
	
	[StructLayout(LayoutKind.Sequential)]
	public struct LASTINPUTINFO {
		public uint cbSize;
		public uint dwTime;
	}
	
	public class Keyboard {
		[DllImport("user32.dll", CharSet = CharSet.Auto, CallingConvention = CallingConvention.StdCall)]
		public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, int dwExtraInfo);
		
		public const uint KEYEVENTF_KEYUP = 0x0002;
		public const int VK_RMENU = 0xA5;  // Right Alt key (modifier, won't type anything)
	}
	
	public class Mouse {
		[DllImport("user32.dll")]
		public static extern short GetAsyncKeyState(int vKey);
		
		[DllImport("user32.dll")]
		public static extern int GetSystemMetrics(int nIndex);
		
		[DllImport("user32.dll")]
		[return: MarshalAs(UnmanagedType.Bool)]
		public static extern bool GetCursorPos(out POINT lpPoint);
		
		[DllImport("kernel32.dll")]
		public static extern IntPtr GetConsoleWindow();
		
		[DllImport("kernel32.dll")]
		public static extern IntPtr GetStdHandle(int nStdHandle);
		
		[DllImport("user32.dll")]
		public static extern IntPtr GetForegroundWindow();
		
		[DllImport("user32.dll")]
		public static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);
		
		[DllImport("kernel32.dll")]
		public static extern ulong GetTickCount64();
		
		[DllImport("kernel32.dll")]
		public static extern bool GetConsoleScreenBufferInfo(IntPtr hConsoleOutput, out CONSOLE_SCREEN_BUFFER_INFO lpConsoleScreenBufferInfo);
		
		[DllImport("kernel32.dll", SetLastError = true)]
		public static extern bool ReadConsoleInput(IntPtr hConsoleInput, [Out] INPUT_RECORD[] lpBuffer, uint nLength, out uint lpNumberOfEventsRead);
		
		[DllImport("kernel32.dll", SetLastError = true)]
		public static extern uint PeekConsoleInput(IntPtr hConsoleInput, [Out] INPUT_RECORD[] lpBuffer, uint nLength, out uint lpNumberOfEventsRead);
		
		// Window finding APIs
		[DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
		public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);
		
		[DllImport("user32.dll")]
		[return: MarshalAs(UnmanagedType.Bool)]
		public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
		
		public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
		
		[DllImport("user32.dll", SetLastError = true)]
		public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
		
		[DllImport("user32.dll", CharSet = CharSet.Auto)]
		public static extern int GetWindowText(IntPtr hWnd, System.Text.StringBuilder lpString, int nMaxCount);
		
		[DllImport("user32.dll", CharSet = CharSet.Auto)]
		public static extern int GetClassName(IntPtr hWnd, System.Text.StringBuilder lpClassName, int nMaxCount);
		
		// Static storage for EnumWindows callback
		private static IntPtr foundWindowHandle = IntPtr.Zero;
		private static int targetProcessId = 0;
		
		// Callback for EnumWindows to find window by process ID
		private static bool EnumWindowsCallback(IntPtr hWnd, IntPtr lParam) {
			if (hWnd == IntPtr.Zero) return true;
			
			try {
				uint windowProcessId = 0;
				GetWindowThreadProcessId(hWnd, out windowProcessId);
				if (windowProcessId == targetProcessId) {
					foundWindowHandle = hWnd;
					return false; // Stop enumeration
				}
			} catch { }
			return true; // Continue enumeration
		}
		
		// Public method to find window handle by process ID
		public static IntPtr FindWindowByProcessId(int processId) {
			foundWindowHandle = IntPtr.Zero;
			targetProcessId = processId;
			try {
				EnumWindows(new EnumWindowsProc(EnumWindowsCallback), IntPtr.Zero);
			} catch { }
			return foundWindowHandle;
		}
		
		// Static storage for title-based search
		private static IntPtr foundWindowHandleByTitle = IntPtr.Zero;
		private static string targetTitlePattern = string.Empty;
		private static int excludeProcessId = 0;
		
		// Callback for EnumWindows to find window by title pattern
		private static bool EnumWindowsCallbackByTitle(IntPtr hWnd, IntPtr lParam) {
			if (hWnd == IntPtr.Zero) return true;
			
			try {
				uint windowProcessId = 0;
				GetWindowThreadProcessId(hWnd, out windowProcessId);
				
				// Skip if this is the process we want to exclude
				if (excludeProcessId != 0 && windowProcessId == excludeProcessId) {
					return true;
				}
				
				// Get window title
				System.Text.StringBuilder sb = new System.Text.StringBuilder(256);
				int length = GetWindowText(hWnd, sb, sb.Capacity);
				string windowTitle = sb.ToString();
				
				// Check if title matches pattern (starts with pattern)
				if (!string.IsNullOrEmpty(windowTitle) && windowTitle.StartsWith(targetTitlePattern, System.StringComparison.OrdinalIgnoreCase)) {
					foundWindowHandleByTitle = hWnd;
					return false; // Stop enumeration
				}
			} catch { }
			return true; // Continue enumeration
		}
		
		// Public method to find window handle by title pattern (excluding a specific process ID)
		public static IntPtr FindWindowByTitlePattern(string titlePattern, int excludePid) {
			foundWindowHandleByTitle = IntPtr.Zero;
			targetTitlePattern = titlePattern ?? string.Empty;
			excludeProcessId = excludePid;
			try {
				EnumWindows(new EnumWindowsProc(EnumWindowsCallbackByTitle), IntPtr.Zero);
			} catch { }
			return foundWindowHandleByTitle;
		}
		
		// Mouse button virtual key codes
		public const int VK_LBUTTON = 0x01;
		public const int VK_RBUTTON = 0x02;
		public const int VK_MBUTTON = 0x04;
		public const int VK_XBUTTON1 = 0x05;
		public const int VK_XBUTTON2 = 0x06;
		
		// Console input event constants
		public const ushort MOUSE_EVENT = 2;
		public const uint MOUSE_LEFT_BUTTON_DOWN = 0x0001;
		public const uint MOUSE_LEFT_BUTTON_UP = 0x0002;
		public const uint DOUBLE_CLICK = 0x0002;
		
	}
}
"@
				
				# Add-Type with explicit error handling and assembly references
				# Note: We use our own POINT struct, so we don't need System.Drawing.dll
				$addTypeResult = $null
				$addTypeError = $null
				try {
					if ($DebugMode) {
						Write-Host "  [DEBUG] Attempting to add types..." -ForegroundColor $script:TextHighlight
					}
					$addTypeResult = Add-Type -TypeDefinition $typeDefinition -ReferencedAssemblies @("System.dll") -ErrorAction Stop
					if ($DebugMode) {
						Write-Host "  [OK] Add-Type completed successfully" -ForegroundColor $script:TextSuccess
					}
				} catch {
					$addTypeError = $_
					# If Add-Type fails, it might be because types already exist
					# Check if the error is about duplicate types
					if ($_.Exception.Message -like "*already exists*" -or $_.Exception.Message -like "*duplicate*" -or $_.Exception.Message -like "*Cannot add type*") {
						if ($DebugMode) {
							Write-Host "  [INFO] Types may already exist: $($_.Exception.Message)" -ForegroundColor $script:TextWarning
						}
					} else {
						# Some other error occurred - log it
						if ($DebugMode) {
							Write-Host "  [WARN] Add-Type error: $($_.Exception.Message)" -ForegroundColor $script:TextWarning
							if ($_.Exception.InnerException) {
								Write-Host "  [WARN] Inner exception: $($_.Exception.InnerException.Message)" -ForegroundColor $script:TextWarning
							}
						}
						# Don't throw yet - we'll check if types exist anyway
					}
				}
				
				# Always verify types were loaded, regardless of Add-Type result
				# Try both reflection and direct type access
				$loadedKeyboard = $null
				$loadedMouse = $null
				
				# First try direct type access (most reliable)
				try {
					$testType = [mJiggAPI.Keyboard]
					$loadedKeyboard = $testType
				} catch {
					# Type not accessible directly, try reflection
				}
				
				try {
					$testType = [mJiggAPI.Mouse]
					$loadedMouse = $testType
				} catch {
					# Type not accessible directly, try reflection
				}
				
				# If direct access failed, try reflection
				if ($null -eq $loadedKeyboard -or $null -eq $loadedMouse) {
					try {
						$allTypes = [System.AppDomain]::CurrentDomain.GetAssemblies() | ForEach-Object { $_.GetTypes() } | Where-Object { $_.Namespace -eq 'mJiggAPI' }
						foreach ($type in $allTypes) {
							if ($type.Name -eq 'Keyboard' -and $null -eq $loadedKeyboard) { $loadedKeyboard = $type }
							if ($type.Name -eq 'Mouse' -and $null -eq $loadedMouse) { $loadedMouse = $type }
						}
					} catch {
						if ($DebugMode) {
							Write-Host "  [WARN] Error checking for loaded types: $($_.Exception.Message)" -ForegroundColor $script:TextWarning
						}
					}
				}
				
				# Check if we have both types
				if ($null -ne $loadedKeyboard -and $null -ne $loadedMouse) {
					if ($DebugMode) {
						Write-Host "  [OK] All types verified: Keyboard, Mouse" -ForegroundColor $script:TextSuccess
					}
				} else {
					# Types weren't loaded - check if they already exist from previous check
					if ($null -ne $existingKeyboard -and $null -ne $existingMouse) {
						if ($DebugMode) {
							Write-Host "  [INFO] Types already exist from previous run" -ForegroundColor Gray
						}
					} else {
						# Types don't exist and failed to load - try to find them anywhere
						if ($DebugMode) {
							Write-Host "  [DEBUG] Searching all assemblies for mJiggAPI types..." -ForegroundColor $script:TextHighlight
							try {
								$allAssemblies = [System.AppDomain]::CurrentDomain.GetAssemblies()
								foreach ($assembly in $allAssemblies) {
									try {
										$types = $assembly.GetTypes() | Where-Object { $_.Name -in @('Keyboard', 'Mouse') }
										if ($types) {
											Write-Host "    Found types in $($assembly.FullName): $($types | ForEach-Object { $_.FullName } | Join-String -Separator ', ')" -ForegroundColor Gray
										}
									} catch {
										# Some assemblies can't be inspected
									}
								}
							} catch {
								Write-Host "    Error searching assemblies: $($_.Exception.Message)" -ForegroundColor $script:TextWarning
							}
						}
						
						# Types don't exist and failed to load
						$missingTypes = @()
						if ($null -eq $loadedKeyboard) { $missingTypes += "Keyboard" }
						if ($null -eq $loadedMouse) { $missingTypes += "Mouse" }
						$errorMsg = "Failed to load required mJiggAPI types: $($missingTypes -join ', ')"
						if ($addTypeError) {
							$errorMsg += "`nAdd-Type error: $($addTypeError.Exception.Message)"
						}
						if ($DebugMode) {
							Write-Host "  [FAIL] $errorMsg" -ForegroundColor $script:TextError
						}
						throw $errorMsg
					}
				}
			} catch {
				# Final fallback - check if types exist anyway
				$finalKeyboard = $null
				$finalMouse = $null
				try {
					$allTypes = [System.AppDomain]::CurrentDomain.GetAssemblies() | ForEach-Object { $_.GetTypes() } | Where-Object { $_.Namespace -eq 'mJiggAPI' }
					foreach ($type in $allTypes) {
						if ($type.Name -eq 'Keyboard') { $finalKeyboard = $type }
						if ($type.Name -eq 'Mouse') { $finalMouse = $type }
					}
				} catch {
					# Ignore errors when checking for existing types
				}
				
				if ($null -ne $finalKeyboard -and $null -ne $finalMouse) {
					if ($DebugMode) {
						Write-Host "  [INFO] Types found after error recovery" -ForegroundColor Gray
					}
				} else {
					if ($DebugMode) {
						Write-Host "  [FAIL] Add-Type failed and types don't exist: $($_.Exception.Message)" -ForegroundColor $script:TextError
						Write-Host "  [INFO] This may require restarting PowerShell to reload types" -ForegroundColor $script:TextWarning
					}
					throw "Failed to load required mJiggAPI types: $($_.Exception.Message)"
				}
			}
		}
		
		# Verify types loaded correctly
		if ($script:DiagEnabled) { "$(Get-Date -Format 'HH:mm:ss.fff') - CHECKPOINT 2: Types loaded, verifying" | Out-File $script:StartupDiagFile -Append }
		try {
			$testKey = [mJiggAPI.Mouse]::GetAsyncKeyState(0x01)
			$testPoint = New-Object mJiggAPI.POINT
			$hasGetCursorPos = [mJiggAPI.Mouse].GetMethod("GetCursorPos") -ne $null
			if ($hasGetCursorPos) {
				$testMouse = [mJiggAPI.Mouse]::GetCursorPos([ref]$testPoint)
			}
			if ($DebugMode) {
				Write-Host "  [OK] Windows API types loaded successfully" -ForegroundColor $script:TextSuccess
			}
		} catch {
			if ($DebugMode) {
				Write-Host "  [FAIL] Could not verify keyboard/mouse API: $($_.Exception.Message)" -ForegroundColor $script:TextError
			}
			Write-Host "Warning: Could not verify keyboard/mouse API. Some features may be disabled." -ForegroundColor $script:TextWarning
		}
		
		# Apply variance to end time if variance is set and end time is specified (not -1)
		if ($endTimeInt -ne -1 -and $script:EndVariance -gt 0) {
			try {
				$ras = Get-Random -Maximum 3 -Minimum 1
				if ($ras -eq 1) {
					$variance = -(Get-Random -Maximum $script:EndVariance)
					$endTimeInt = $endTimeInt + $variance
				} else {
					$variance = (Get-Random -Maximum $script:EndVariance)
					$endTimeInt = $endTimeInt + $variance
				}
				# Ensure time stays within valid range (0-2359)
				if ($endTimeInt -lt 0) {
					$endTimeInt = 0
				} elseif ($endTimeInt -gt 2359) {
					$endTimeInt = 2359
				}
				$endTimeStr = $endTimeInt.ToString().PadLeft(4, '0')
				if ($DebugMode) {
					Write-Host "  [OK] Applied variance: $variance minutes, final end time: $endTimeStr" -ForegroundColor $script:TextSuccess
				}
			} catch {
				if ($DebugMode) {
					Write-Host "  [FAIL] Failed to apply variance: $($_.Exception.Message)" -ForegroundColor $script:TextError
				}
			}
		}
		
		# Calculate end date/time only if end time is set (not -1)
		if ($endTimeInt -ne -1) {
			try {
				$currentTime = Get-Date -Format "HHmm"
				if ($DebugMode) {
					Write-Host "  [OK] Current time: $currentTime" -ForegroundColor $script:TextSuccess
				}
			} catch {
				if ($DebugMode) {
					Write-Host "  [FAIL] Failed to get current time: $($_.Exception.Message)" -ForegroundColor $script:TextError
				}
				throw
			}
			try {
				if ($endTimeInt -le [int]$currentTime) {
					$tommorow = (Get-Date).AddDays(1)
					$endDate = Get-Date $tommorow -Format "MMdd"
					if ($DebugMode) {
						Write-Host "  [OK] End time is today, using tomorrow's date: $endDate" -ForegroundColor $script:TextSuccess
					}
				} else {
					$endDate = Get-Date -Format "MMdd"
					if ($DebugMode) {
						Write-Host "  [OK] End time is today, using today's date: $endDate" -ForegroundColor $script:TextSuccess
					}
				}
				$end = "$endDate$endTimeStr"
				$time = $false
				if ($DebugMode) {
					Write-Host "  [OK] Final end datetime: $end" -ForegroundColor $script:TextSuccess
				}
			} catch {
				if ($DebugMode) {
					Write-Host "  [FAIL] Failed to calculate end datetime: $($_.Exception.Message)" -ForegroundColor $script:TextError
				}
				throw
			}
		} else {
			# No end time - set end to empty and time to false
			$end = ""
			$time = $false
			if ($DebugMode) {
				Write-Host "  [OK] No end time - script will run indefinitely" -ForegroundColor $script:TextSuccess
			}
		}

		# Initialize lastPos for mouse detection
		if ($DebugMode) {
			Write-Host "[DEBUG] Initializing mouse position tracking..." -ForegroundColor $script:TextHighlight
		}
		try {
			if ($null -eq $LastPos) {
				# Use direct Windows API call for better performance (avoids .NET stutter)
				$point = New-Object mJiggAPI.POINT
				$hasGetCursorPos = [mJiggAPI.Mouse].GetMethod("GetCursorPos") -ne $null
				if ($hasGetCursorPos) {
					if ([mJiggAPI.Mouse]::GetCursorPos([ref]$point)) {
						# Convert POINT to System.Drawing.Point for compatibility with rest of code
						$LastPos = New-Object System.Drawing.Point($point.X, $point.Y)
					} else {
						throw "GetCursorPos API call failed"
					}
				} else {
					throw "GetCursorPos method not available"
				}
				if ($DebugMode) {
					Write-Host "  [OK] Initial mouse position: $($LastPos.X), $($LastPos.Y)" -ForegroundColor $script:TextSuccess
				}
			} else {
				if ($DebugMode) {
					Write-Host "  [OK] Mouse position already set: $($LastPos.X), $($LastPos.Y)" -ForegroundColor $script:TextSuccess
				}
			}
		} catch {
			if ($DebugMode) {
				Write-Host "  [FAIL] Failed to get mouse position: $($_.Exception.Message)" -ForegroundColor $script:TextError
			}
			# Don't throw - mouse position tracking is optional
		}

		# Track start time for runtime calculation
		$ScriptStartTime = Get-Date

		# Function to calculate smooth movement path with acceleration/deceleration
		# Returns an array of points and the total movement time in milliseconds
		function Get-SmoothMovementPath {
			param(
				[int]$startX,
				[int]$startY,
				[int]$endX,
				[int]$endY,
				[double]$baseSpeedSeconds,
				[double]$varianceSeconds
			)
			
			# Calculate distance
			$deltaX = $endX - $startX
			$deltaY = $endY - $startY
			$distance = [Math]::Sqrt($deltaX * $deltaX + $deltaY * $deltaY)
			
			# If distance is very small, return single point
			if ($distance -lt 1) {
				return @{
					Points = @([PSCustomObject]@{ X = $endX; Y = $endY })
					TotalTimeMs = 0
				}
			}
			
			# Calculate movement time with variance (in milliseconds)
			$baseSpeedMs = $baseSpeedSeconds * 1000
			$varianceMs = $varianceSeconds * 1000
			$varianceAmountMs = Get-Random -Minimum 0 -Maximum ($varianceMs + 1)
			$ras = Get-Random -Maximum 2 -Minimum 0
			if ($ras -eq 0) {
				$movementTimeMs = ($baseSpeedMs - $varianceAmountMs)
			} else {
				$movementTimeMs = ($baseSpeedMs + $varianceAmountMs)
			}
			
			# Ensure minimum movement time of 50ms
			if ($movementTimeMs -lt 50) {
				$movementTimeMs = 50
			}
			
		# Generate one point per 5ms of movement time so the execution loop can advance
		# at a constant 5ms interval. Acceleration/deceleration is expressed by point
		# spacing along the curve (easing places points close together when the virtual
		# speed is low, and far apart when it is high) rather than by varying the sleep
		# duration. Duplicate pixel coordinates are fine - the cursor simply dwells there
		# for one 5ms tick. t is always increasing so the cursor never moves backwards.
		$numPoints = [Math]::Max(2, [Math]::Ceiling($movementTimeMs / 5))
		$numPoints = [Math]::Min($numPoints, 2000)  # safety cap (~10 seconds at 5ms/step)
			
		# Perpendicular unit vector (left of travel direction) used for lateral arc offsets
		$perpendicularX = 0.0
		$perpendicularY = 0.0
		if ($distance -gt 0) {
			$perpendicularX = -$deltaY / $distance
			$perpendicularY =  $deltaX / $distance
		}

		# Start arc — window [0, 0.3], peaks at t=0.15: curve develops quickly after departure.
		# Amplitude 1-10% of distance (was 5-20%), and only present ~50% of the time so it
		# ranges naturally from nonexistent to subtle.
		$startArcAmount = 0.0
		$startArcSign   = 1
		if ((Get-Random -Minimum 0 -Maximum 100) -ge 50) {
			$startArcAmount = $distance * (Get-Random -Minimum 1 -Maximum 11) / 100  # 1-10%
			$startArcSign   = if ((Get-Random -Maximum 2) -eq 0) { 1 } else { -1 }
		}

		# Body curve — subtle background curve over the remaining 70% of travel [0.3, 1].
		# Randomly U-shaped (half-sine: bows one way and returns) or S-shaped (full-sine:
		# crosses sides at the midpoint). Amplitude 3-10% of distance keeps it natural.
		$bodyCurveAmount = 0.0
		$bodyCurveSign   = 1
		$bodyCurveType   = 0  # 0 = U-shape (half-sine), 1 = S-shape (full-sine)
		if ((Get-Random -Minimum 0 -Maximum 100) -ge 40) {  # 60% chance
			$bodyCurveAmount = $distance * (Get-Random -Minimum 3 -Maximum 11) / 100  # 3-10%
			$bodyCurveSign   = if ((Get-Random -Maximum 2) -eq 0) { 1 } else { -1 }
			$bodyCurveType   = Get-Random -Maximum 2  # 0 = U, 1 = S
		}

		# Generate points with acceleration/deceleration curve and optional path curve
		# Use ease-in-out-cubic: accelerates in first half, decelerates in second half
		$points = @()
		for ($i = 0; $i -le $numPoints; $i++) {
			# Normalized progress (0 to 1)
			$t = $i / $numPoints
			
			# Ease-in-out-cubic function: accelerates then decelerates
			# f(t) = t < 0.5 ? 4t³ : 1 - pow(-2t + 2, 3)/2
			if ($t -lt 0.5) {
				$easedT = 4 * $t * $t * $t
			} else {
				$easedT = 1 - [Math]::Pow(-2 * $t + 2, 3) / 2
			}
			
			# Calculate base position along straight path
			$baseX = $startX + $deltaX * $easedT
			$baseY = $startY + $deltaY * $easedT
			
			# Start arc: window [0, 0.3] → peaks at t=0.15
			if ($startArcAmount -gt 0 -and $t -le 0.3) {
				$lateralOffset = $startArcSign * $startArcAmount * [Math]::Sin([Math]::PI * $t / 0.3)
				$baseX += $perpendicularX * $lateralOffset
				$baseY += $perpendicularY * $lateralOffset
			}

			# Body curve: window [0.3, 1] — both shapes use squared-sine envelopes so the
			# derivative is zero at both window boundaries (smooth departure AND smooth landing).
			#   U-shape: sin(π·bodyT)²                     — always same side, peaks at t=0.65
			#   S-shape: sin(2π·bodyT) · sin(π·bodyT)      — crosses sides at t=0.65
			# Neither shape produces a hook; both glide naturally into the endpoint.
			if ($bodyCurveAmount -gt 0 -and $t -ge 0.3) {
				$bodyT   = ($t - 0.3) / 0.7  # normalise to [0,1] over the body segment
				$sinBase = [Math]::Sin([Math]::PI * $bodyT)
				$bodyArc = if ($bodyCurveType -eq 0) {
					$bodyCurveAmount * $sinBase * $sinBase                            # U-shape
				} else {
					$bodyCurveAmount * [Math]::Sin(2 * [Math]::PI * $bodyT) * $sinBase  # S-shape
				}
				$baseX += $perpendicularX * $bodyCurveSign * $bodyArc
				$baseY += $perpendicularY * $bodyCurveSign * $bodyArc
			}
			
			# Round to integer pixel coordinates
			$x = [Math]::Round($baseX)
			$y = [Math]::Round($baseY)
			
			$points += [PSCustomObject]@{
				X = $x
				Y = $y
			}
		}
			
			return @{
				Points = $points
				TotalTimeMs = [Math]::Round($movementTimeMs)
			}
		}

		# Function to get direction arrow emoji based on movement delta
		# Options: "arrows" (emoji arrows), "text" (N/S/E/W/NE/etc), "simple" (←→↑↓↗↖↘↙)
		function Get-DirectionArrow {
			param(
				[int]$deltaX,
				[int]$deltaY,
				[string]$style = "simple"  # "arrows", "text", or "simple"
			)
			
			# Define emoji arrows using ConvertFromUtf32 for cross-version compatibility
			$arrowRight = [char]::ConvertFromUtf32(0x27A1)  # ➡
			$arrowLeft = [char]::ConvertFromUtf32(0x2B05)   # ⬅
			$arrowDown = [char]::ConvertFromUtf32(0x2B07)   # ⬇
			$arrowUp = [char]::ConvertFromUtf32(0x2B06)     # ⬆
			$arrowSE = [char]::ConvertFromUtf32(0x2198)     # ↘
			$arrowNE = [char]::ConvertFromUtf32(0x2197)     # ↗
			$arrowSW = [char]::ConvertFromUtf32(0x2199)     # ↙
			$arrowNW = [char]::ConvertFromUtf32(0x2196)     # ↖
			
			# Simple arrows (BMP characters, work with [char])
			$simpleRight = [char]0x2192  # →
			$simpleLeft = [char]0x2190   # ←
			$simpleDown = [char]0x2193   # ↓
			$simpleUp = [char]0x2191     # ↑
			$simpleSE = [char]0x2198     # ↘
			$simpleNE = [char]0x2197     # ↗
			$simpleSW = [char]0x2199     # ↙
			$simpleNW = [char]0x2196     # ↖
			
			# Calculate angle and determine primary direction
			# Use a threshold to determine if movement is primarily horizontal, vertical, or diagonal
			$absX = [Math]::Abs($deltaX)
			$absY = [Math]::Abs($deltaY)
			
			# If movement is very small, return no arrow
			if ($absX -lt 5 -and $absY -lt 5) {
				return ""
			}
			
			# Determine if movement is primarily horizontal or vertical
			# If one axis is significantly larger, use cardinal direction
			# Otherwise use diagonal direction
			if ($absX -gt $absY * 2) {
				# Primarily horizontal
				if ($style -eq "text") {
					if ($deltaX -gt 0) { return "E" } else { return "W" }
				} elseif ($style -eq "arrows") {
					if ($deltaX -gt 0) { return $arrowRight } else { return $arrowLeft }
				} else {
					# simple style
					if ($deltaX -gt 0) { return $simpleRight } else { return $simpleLeft }
				}
			} elseif ($absY -gt $absX * 2) {
				# Primarily vertical
				if ($style -eq "text") {
					if ($deltaY -gt 0) { return "S" } else { return "N" }
				} elseif ($style -eq "arrows") {
					if ($deltaY -gt 0) { return $arrowDown } else { return $arrowUp }
				} else {
					# simple style
					if ($deltaY -gt 0) { return $simpleDown } else { return $simpleUp }
				}
			} else {
				# Diagonal movement
				if ($style -eq "text") {
					if ($deltaX -gt 0 -and $deltaY -gt 0) {
						return "SE"
					} elseif ($deltaX -gt 0 -and $deltaY -lt 0) {
						return "NE"
					} elseif ($deltaX -lt 0 -and $deltaY -gt 0) {
						return "SW"
					} else {
						return "NW"
					}
				} elseif ($style -eq "arrows") {
					if ($deltaX -gt 0 -and $deltaY -gt 0) {
						return $arrowSE
					} elseif ($deltaX -gt 0 -and $deltaY -lt 0) {
						return $arrowNE
					} elseif ($deltaX -lt 0 -and $deltaY -gt 0) {
						return $arrowSW
					} else {
						return $arrowNW
					}
				} else {
					# simple style
					if ($deltaX -gt 0 -and $deltaY -gt 0) {
						return $simpleSE
					} elseif ($deltaX -gt 0 -and $deltaY -lt 0) {
						return $simpleNE
					} elseif ($deltaX -lt 0 -and $deltaY -gt 0) {
						return $simpleSW
					} else {
						return $simpleNW
					}
				}
			}
		}

		if ($script:DiagEnabled) { "$(Get-Date -Format 'HH:mm:ss.fff') - CHECKPOINT 3: About to define helper functions" | Out-File $script:StartupDiagFile -Append }

		# ============================================
		# Buffered Rendering Functions
		# ============================================

		$script:ESC = [char]27
		$script:CursorVisible = $false
		$script:AnsiFG = @{
			[ConsoleColor]::Black = 30; [ConsoleColor]::DarkBlue = 34; [ConsoleColor]::DarkGreen = 32; [ConsoleColor]::DarkCyan = 36
			[ConsoleColor]::DarkRed = 31; [ConsoleColor]::DarkMagenta = 35; [ConsoleColor]::DarkYellow = 33; [ConsoleColor]::Gray = 37
			[ConsoleColor]::DarkGray = 90; [ConsoleColor]::Blue = 94; [ConsoleColor]::Green = 92; [ConsoleColor]::Cyan = 96
			[ConsoleColor]::Red = 91; [ConsoleColor]::Magenta = 95; [ConsoleColor]::Yellow = 93; [ConsoleColor]::White = 97
		}
		$script:AnsiBG = @{
			[ConsoleColor]::Black = 40; [ConsoleColor]::DarkBlue = 44; [ConsoleColor]::DarkGreen = 42; [ConsoleColor]::DarkCyan = 46
			[ConsoleColor]::DarkRed = 41; [ConsoleColor]::DarkMagenta = 45; [ConsoleColor]::DarkYellow = 43; [ConsoleColor]::Gray = 47
			[ConsoleColor]::DarkGray = 100; [ConsoleColor]::Blue = 104; [ConsoleColor]::Green = 102; [ConsoleColor]::Cyan = 106
			[ConsoleColor]::Red = 101; [ConsoleColor]::Magenta = 105; [ConsoleColor]::Yellow = 103; [ConsoleColor]::White = 107
		}

	function Write-Buffer {
		param(
			[int]$X = -1,
			[int]$Y = -1,
			[string]$Text,
			[object]$FG = $null,
			[object]$BG = $null,
			[switch]$Wide,
			[switch]$NoWrap  # Disable auto-wrap for this segment (use for last row to avoid scroll)
		)
		if ($Wide -and $null -ne $BG) { $Text = $Text + " " }
		$script:RenderQueue.Add(@{ X = $X; Y = $Y; Text = $Text; FG = $FG; BG = $BG; NoWrap = $NoWrap.IsPresent })
		}

		function Flush-Buffer {
			param([switch]$ClearFirst)
			if ($script:RenderQueue.Count -eq 0) { return }
			$csi = "$($script:ESC)["
			$sb = New-Object System.Text.StringBuilder (8192)
			[void]$sb.Append("${csi}?25l")
			if ($ClearFirst) { [void]$sb.Append("${csi}2J") }
			$lastFGCode = -1
			$lastBGCode = -1
		foreach ($seg in $script:RenderQueue) {
			$fgCode = if ($null -ne $seg.FG) { $script:AnsiFG[[ConsoleColor]$seg.FG] } else { 39 }
			$bgCode = if ($null -ne $seg.BG) { $script:AnsiBG[[ConsoleColor]$seg.BG] } else { 49 }
			if ($seg.NoWrap) { [void]$sb.Append("${csi}?7l") }  # disable auto-wrap
			if ($seg.X -ge 0 -and $seg.Y -ge 0) {
				[void]$sb.Append("${csi}$($seg.Y + 1);$($seg.X + 1)H")
			}
			if ($fgCode -ne $lastFGCode -or $bgCode -ne $lastBGCode) {
				[void]$sb.Append("${csi}${fgCode};${bgCode}m")
				$lastFGCode = $fgCode
				$lastBGCode = $bgCode
			}
			[void]$sb.Append($seg.Text)
			if ($seg.NoWrap) { [void]$sb.Append("${csi}?7h") }  # re-enable auto-wrap
		}
			[void]$sb.Append("${csi}0m")
			if ($script:CursorVisible) { [void]$sb.Append("${csi}?25h") }
			[Console]::Write($sb.ToString())
			$script:RenderQueue.Clear()
		}

		function Clear-Buffer {
			$script:RenderQueue.Clear()
		}

		# Immediately renders a single menu button with the given colors and flushes to console.
		# Used for instant press/release visual feedback without waiting for the next full frame.
		# Requires the bounds entry to include displayText (string) and format (int: 0=emoji, 1/2=text).
		function Write-ButtonImmediate {
			param($btn, $fg, $bg, $hotkeyFg, $pipeFg = $null, $bracketFg = $null, $bracketBg = $null)
			$text   = $btn.displayText
			$startX = $btn.startX
			$y      = $btn.y
			$rPipeFg    = if ($null -ne $pipeFg)    { $pipeFg }    else { $script:MenuButtonSeparatorFg }
			$rBracketFg = if ($null -ne $bracketFg) { $bracketFg } else { $script:MenuButtonBracketFg }
			$rBracketBg = if ($null -ne $bracketBg) { $bracketBg } else { $script:MenuButtonBracketBg }
			# ? help button: single character rendered entirely in hotkey color, with optional brackets
			if ($btn.isHelpButton -eq $true) {
				$hContentX = $startX
				if ($script:MenuButtonShowBrackets) {
					Write-Buffer -X $hContentX -Y $y -Text "[" -FG $rBracketFg -BG $rBracketBg
					$hContentX += 1
				}
				Write-Buffer -X $hContentX -Y $y -Text "?" -FG $hotkeyFg -BG $bg
				if ($script:MenuButtonShowBrackets) {
					Write-Buffer -Text "]" -FG $rBracketFg -BG $rBracketBg
				}
				Flush-Buffer
				return
			}
			if ($btn.format -eq 0) {
				# Emoji format: "emoji|label (k) text"
				$parts = $text -split "\|", 2
				if ($parts.Count -eq 2) {
					$contentX = $startX
					if ($script:MenuButtonShowBrackets) {
						Write-Buffer -X $contentX -Y $y -Text "[" -FG $rBracketFg -BG $rBracketBg
						$contentX += 1
					}
					if ($script:MenuButtonShowIcon) {
						Write-Buffer -X $contentX -Y $y -Text $parts[0] -BG $bg -Wide
						$sepX = $contentX + 2
						Write-Buffer -X $sepX -Y $y -Text $script:MenuButtonSeparator -FG $rPipeFg -BG $bg
					} else {
						Write-Buffer -X $contentX -Y $y -Text "" -BG $bg
					}
				$textParts = $parts[1] -split "([()])"
				for ($j = 0; $j -lt $textParts.Count; $j++) {
					$part = $textParts[$j]
					if ($part -eq "(" -and $j+2 -lt $textParts.Count -and $textParts[$j+1] -match '^[a-z]$' -and $textParts[$j+2] -eq ")") {
						if ($script:MenuButtonShowHotkeyParens) { Write-Buffer -Text "(" -FG $fg -BG $bg }
						Write-Buffer -Text $textParts[$j+1] -FG $hotkeyFg -BG $bg
						if ($script:MenuButtonShowHotkeyParens) { Write-Buffer -Text ")" -FG $fg -BG $bg }
						$j += 2
					} elseif ($part -ne "") {
						Write-Buffer -Text $part -FG $fg -BG $bg
					}
				}
				if ($script:MenuButtonShowBrackets) {
					Write-Buffer -Text "]" -FG $rBracketFg -BG $rBracketBg
				}
			}
		} else {
			# Text-only formats (noIcons / short)
			Write-Buffer -X $startX -Y $y -Text "" -BG $bg
			$textParts = $text -split "([()])"
			for ($j = 0; $j -lt $textParts.Count; $j++) {
				$part = $textParts[$j]
				if ($part -eq "(" -and $j+2 -lt $textParts.Count -and $textParts[$j+1] -match '^[a-z]$' -and $textParts[$j+2] -eq ")") {
					if ($script:MenuButtonShowHotkeyParens) { Write-Buffer -Text "(" -FG $fg -BG $bg }
					Write-Buffer -Text $textParts[$j+1] -FG $hotkeyFg -BG $bg
					if ($script:MenuButtonShowHotkeyParens) { Write-Buffer -Text ")" -FG $fg -BG $bg }
					$j += 2
				} elseif ($part -ne "") {
					Write-Buffer -Text $part -FG $fg -BG $bg
				}
			}
		}
			Flush-Buffer
		}

		# Function to draw drop shadow for dialog boxes
		function Draw-DialogShadow {
			param(
				[int]$dialogX,
				[int]$dialogY,
				[int]$dialogWidth,
				[int]$dialogHeight,
				[string]$shadowColor = "DarkGray"
			)
			
			$shadowChar = [char]0x2591  # ░ light shade character
			
			for ($i = 1; $i -le $dialogHeight; $i++) {
				Write-Buffer -X ($dialogX + $dialogWidth) -Y ($dialogY + $i) -Text "$shadowChar" -FG $shadowColor
			}
			for ($i = 1; $i -le $dialogWidth; $i++) {
				Write-Buffer -X ($dialogX + $i) -Y ($dialogY + $dialogHeight + 1) -Text "$shadowChar" -FG $shadowColor
			}
			Write-Buffer -X ($dialogX + $dialogWidth) -Y ($dialogY + $dialogHeight + 1) -Text "$shadowChar" -FG $shadowColor
		}
		
		# Function to clear drop shadow for dialog boxes
		function Clear-DialogShadow {
			param(
				[int]$dialogX,
				[int]$dialogY,
				[int]$dialogWidth,
				[int]$dialogHeight
			)
			
			for ($i = 1; $i -le $dialogHeight; $i++) {
				Write-Buffer -X ($dialogX + $dialogWidth) -Y ($dialogY + $i) -Text " "
			}
			for ($i = 1; $i -le $dialogWidth; $i++) {
				Write-Buffer -X ($dialogX + $i) -Y ($dialogY + $dialogHeight + 1) -Text " "
			}
			Write-Buffer -X ($dialogX + $dialogWidth) -Y ($dialogY + $dialogHeight + 1) -Text " "
		}

		# Function to show popup dialog for changing end time
		function Show-TimeChangeDialog {
			param(
				[int]$currentEndTime,
				[ref]$HostWidthRef,
				[ref]$HostHeightRef
			)
			
			# Get current host dimensions from references
			$currentHostWidth = $HostWidthRef.Value
			$currentHostHeight = $HostHeightRef.Value
			
			# Dialog dimensions (reduced width)
			$dialogWidth = 35
			$dialogHeight = 7
			$dialogX = [math]::Max(0, [math]::Floor(($currentHostWidth - $dialogWidth) / 2))
			$dialogY = [math]::Max(0, [math]::Floor(($currentHostHeight - $dialogHeight) / 2))
			
			$savedCursorVisible = $script:CursorVisible
			$script:CursorVisible = $true
			[Console]::Write("$($script:ESC)[?25h")
			
		$checkmark = [char]::ConvertFromUtf32(0x2705)  # ✅ green checkmark
		$redX = [char]::ConvertFromUtf32(0x274C)  # ❌ red X
$dlgIconWidth    = if ($script:DialogButtonShowIcon)     { 2 + $script:DialogButtonSeparator.Length } else { 0 }
$dlgBracketWidth = if ($script:DialogButtonShowBrackets) { 2 } else { 0 }
$dlgParenAdj     = if ($script:DialogButtonShowHotkeyParens) { 0 } else { -2 }
# Button line: border+space(2) + btn1(bracketW+iconW+"(a)pply"=7) + gap(2) + btn2(bracketW+iconW+"(c)ancel"=8) = 19 + 2*iconWidth + 2*bracketWidth
$bottomLinePadding = $dialogWidth - (19 + 2 * $dlgParenAdj + 2 * $dlgIconWidth + 2 * $dlgBracketWidth) - 1
			
			# Build all lines to be exactly 35 characters using Get-Padding helper
			$line0 = "$($script:BoxTopLeft)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxTopRight)"  # 35 chars
			$line1Text = "$($script:BoxVertical)  Change End Time"
			$line1Padding = Get-Padding -usedWidth ($line1Text.Length + 1) -totalWidth $dialogWidth
			$line1 = $line1Text + (" " * $line1Padding) + "$($script:BoxVertical)"
			
			$line2 = "$($script:BoxVertical)" + (" " * 33) + "$($script:BoxVertical)"  # 35 chars
			
			$line3Text = "$($script:BoxVertical)  Enter new time (HHmm format):"
			$line3Padding = Get-Padding -usedWidth ($line3Text.Length + 1) -totalWidth $dialogWidth
			$line3 = $line3Text + (" " * $line3Padding) + "$($script:BoxVertical)"
			
			# Line 4 will be drawn separately with highlighted field
			$line4Text = "$($script:BoxVertical)  "
			$line4Padding = Get-Padding -usedWidth ($line4Text.Length + 1 + 6) -totalWidth $dialogWidth  # +6 for "[    ]"
			$line4 = $line4Text + (" " * $line4Padding) + "$($script:BoxVertical)"
			
			$line5 = "$($script:BoxVertical)" + (" " * 33) + "$($script:BoxVertical)"  # 35 chars
			
			$line7 = "$($script:BoxBottomLeft)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxBottomRight)"  # 35 chars
			
			$dialogLines = @(
				$line0,
				$line1,
				$line2,
				$line3,
				$line4,
				$line5,
				$null,  # Bottom line will be written separately with colors
				$line7
			)
			
			# Draw dialog background (clear area) with themed background
			for ($i = 0; $i -lt $dialogHeight; $i++) {
				Write-Buffer -X $dialogX -Y ($dialogY + $i) -Text (" " * $dialogWidth) -BG $script:TimeDialogBg
			}
			
			# Draw dialog box with themed background
			for ($i = 0; $i -lt $dialogLines.Count; $i++) {
				if ($i -eq 1) {
					Write-Buffer -X $dialogX -Y ($dialogY + $i) -Text "$($script:BoxVertical)  " -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
					Write-Buffer -Text "Change End Time" -FG $script:TimeDialogTitle -BG $script:TimeDialogBg
					$titleUsedWidth = 3 + "Change End Time".Length
					$titlePadding = Get-Padding -usedWidth ($titleUsedWidth + 1) -totalWidth $dialogWidth
					Write-Buffer -Text (" " * $titlePadding) -BG $script:TimeDialogBg
					Write-Buffer -Text "$($script:BoxVertical)" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
				} elseif ($i -eq 4) {
					$initialTimeDisplay = if ($currentEndTime -ne -1 -and $currentEndTime -ne 0) { 
						$currentEndTime.ToString().PadLeft(4, '0') 
					} else { 
						"" 
					}
					$fieldDisplay = $initialTimeDisplay.PadRight(4)
					Write-Buffer -X $dialogX -Y ($dialogY + $i) -Text "$($script:BoxVertical)  " -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
					Write-Buffer -Text "[" -FG $script:TimeDialogText -BG $script:TimeDialogBg
					Write-Buffer -Text $fieldDisplay -FG $script:TimeDialogFieldText -BG $script:TimeDialogFieldBg
					Write-Buffer -Text "]" -FG $script:TimeDialogText -BG $script:TimeDialogBg
					$fieldUsedWidth = 3 + 6
					$fieldPadding = Get-Padding -usedWidth ($fieldUsedWidth + 1) -totalWidth $dialogWidth
					Write-Buffer -Text (" " * $fieldPadding) -BG $script:TimeDialogBg
					Write-Buffer -Text "$($script:BoxVertical)" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
			} elseif ($i -eq 6) {
			$btn1X = $dialogX + 2
		$btn2X = $btn1X + $dlgBracketWidth + $dlgIconWidth + 7 + $dlgParenAdj + 2  # bracket + icon + "(a)pply"(7) + gap(2)
		Write-Buffer -X $dialogX -Y ($dialogY + $i) -Text "$($script:BoxVertical) " -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
		if ($script:DialogButtonShowBrackets) {
			Write-Buffer -X $btn1X -Y ($dialogY + $i) -Text "[" -FG $script:DialogButtonBracketFg -BG $script:DialogButtonBracketBg
		}
		$btn1ContentX = $btn1X + [int]$script:DialogButtonShowBrackets
		if ($script:DialogButtonShowIcon) {
			Write-Buffer -X $btn1ContentX -Y ($dialogY + $i) -Text $checkmark -FG $script:TextSuccess -BG $script:TimeDialogButtonBg -Wide
			Write-Buffer -X ($btn1ContentX + 2) -Y ($dialogY + $i) -Text $script:DialogButtonSeparator -FG $script:TimeDialogButtonText -BG $script:TimeDialogButtonBg
		} else {
			Write-Buffer -X $btn1ContentX -Y ($dialogY + $i) -Text "" -BG $script:TimeDialogButtonBg
		}
		$_rp = if ($script:DialogButtonShowHotkeyParens) { ")" } else { "" }
		if ($script:DialogButtonShowHotkeyParens) { Write-Buffer -Text "(" -FG $script:TimeDialogButtonText -BG $script:TimeDialogButtonBg }
	Write-Buffer -Text "a" -FG $script:TimeDialogButtonHotkey -BG $script:TimeDialogButtonBg
	Write-Buffer -Text "${_rp}pply" -FG $script:TimeDialogButtonText -BG $script:TimeDialogButtonBg
		if ($script:DialogButtonShowBrackets) { Write-Buffer -Text "]" -FG $script:DialogButtonBracketFg -BG $script:DialogButtonBracketBg }
		Write-Buffer -Text "  " -BG $script:TimeDialogBg
		if ($script:DialogButtonShowBrackets) {
			Write-Buffer -X $btn2X -Y ($dialogY + $i) -Text "[" -FG $script:DialogButtonBracketFg -BG $script:DialogButtonBracketBg
		}
		$btn2ContentX = $btn2X + [int]$script:DialogButtonShowBrackets
		if ($script:DialogButtonShowIcon) {
			Write-Buffer -X $btn2ContentX -Y ($dialogY + $i) -Text $redX -FG $script:TextError -BG $script:TimeDialogButtonBg -Wide
			Write-Buffer -X ($btn2ContentX + 2) -Y ($dialogY + $i) -Text $script:DialogButtonSeparator -FG $script:TimeDialogButtonText -BG $script:TimeDialogButtonBg
		} else {
			Write-Buffer -X $btn2ContentX -Y ($dialogY + $i) -Text "" -BG $script:TimeDialogButtonBg
		}
		if ($script:DialogButtonShowHotkeyParens) { Write-Buffer -Text "(" -FG $script:TimeDialogButtonText -BG $script:TimeDialogButtonBg }
		Write-Buffer -Text "c" -FG $script:TimeDialogButtonHotkey -BG $script:TimeDialogButtonBg
		Write-Buffer -Text "${_rp}ancel" -FG $script:TimeDialogButtonText -BG $script:TimeDialogButtonBg
		if ($script:DialogButtonShowBrackets) { Write-Buffer -Text "]" -FG $script:DialogButtonBracketFg -BG $script:DialogButtonBracketBg }
		Write-Buffer -Text (" " * $bottomLinePadding) -BG $script:TimeDialogBg
		Write-Buffer -Text "$($script:BoxVertical)" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
	} else {
		Write-Buffer -X $dialogX -Y ($dialogY + $i) -Text $dialogLines[$i] -FG $script:TimeDialogText -BG $script:TimeDialogBg
	}
}

# Draw drop shadow
Draw-DialogShadow -dialogX $dialogX -dialogY $dialogY -dialogWidth $dialogWidth -dialogHeight $dialogHeight -shadowColor $script:TimeDialogShadow
	Flush-Buffer
	
	# Calculate button bounds for click detection (visible characters only)
	# Button row is at dialogY + 6 (line 6)
	$buttonRowY = $dialogY + 6
$updateButtonStartX = $dialogX + 2
$updateButtonEndX   = $dialogX + 2 + $dlgBracketWidth + $dlgIconWidth + 7 + $dlgParenAdj - 1   # bracket + icon + "(a)pply"(7) - 1 inclusive
$cancelButtonStartX = $dialogX + 2 + $dlgBracketWidth + $dlgIconWidth + 7 + $dlgParenAdj + 2   # after btn1 + gap(2)
$cancelButtonEndX   = $cancelButtonStartX + $dlgBracketWidth + $dlgIconWidth + 8 + $dlgParenAdj - 1  # bracket + icon + "(c)ancel"(8) - 1 inclusive
		
		# Store button bounds in script scope for main loop click detection
		$script:DialogButtonBounds = @{
			buttonRowY = $buttonRowY
			updateStartX = $updateButtonStartX
			updateEndX = $updateButtonEndX
			cancelStartX = $cancelButtonStartX
			cancelEndX = $cancelButtonEndX
		}
		$script:DialogButtonClick = $null  # Clear any previous click  # 20 + 2 (emoji) + 1 (pipe) + 8 (text) - 1 (inclusive)
			
			# Position cursor in input field (inside the brackets, after "$($script:BoxVertical)  [")
			# Line 4 is "$($script:BoxVertical)  [" + 4 spaces + "]", so input starts at position 4
			$inputX = $dialogX + 4
			$inputY = $dialogY + 4
			$script:CursorVisible = $false
			[Console]::Write("$($script:ESC)[?25l")
			
			# Get input
			# Initialize with current end time if it exists (convert to 4-digit string)
			if ($currentEndTime -ne -1 -and $currentEndTime -ne 0) {
				$timeInput = $currentEndTime.ToString().PadLeft(4, '0')
			} else {
				$timeInput = ""
			}
			$result = $null
			$needsRedraw = $false
			$errorMessage = ""
			$isFirstChar = $true  # Track if this is the first character typed
			
			# Don't draw initial input value - cursor is hidden until first character is typed
			# Position cursor at the input field after initial draw (even if hidden, so it's ready when shown)
			[Console]::SetCursorPosition($inputX + $timeInput.Length, $inputY)
			
			# Debug: Log that dialog input loop has started
			if ($DebugMode) {
				if ($null -eq $LogArray -or -not ($LogArray -is [Array])) {
					$LogArray = @()
				}
				$LogArray += [PSCustomObject]@{
					logRow = $true
					components = @(
						@{
							priority = 1
							text = (Get-Date).ToString("HH:mm:ss")
							shortText = (Get-Date).ToString("HH:mm:ss")
						},
						@{
							priority = 2
							text = " - [DEBUG] Time dialog input loop started, button row Y: $buttonRowY"
							shortText = " - [DEBUG] Dialog started"
						}
					)
				}
			}
			
			:inputLoop do {
				# Check for window resize and update references
				$pshost = Get-Host
				$pswindow = $pshost.UI.RawUI
				$newWindowSize = $pswindow.WindowSize
				if ($newWindowSize.Width -ne $currentHostWidth -or $newWindowSize.Height -ne $currentHostHeight) {
					# Window was resized - update references and flag for main UI redraw
					# Don't force buffer size - let PowerShell manage it (allows text zoom to work)
					$HostWidthRef.Value = $newWindowSize.Width
					$HostHeightRef.Value = $newWindowSize.Height
					$currentHostWidth = $newWindowSize.Width
					$currentHostHeight = $newWindowSize.Height
					$needsRedraw = $true
					
					# Reposition dialog
					$dialogX = [math]::Max(0, [math]::Floor(($currentHostWidth - $dialogWidth) / 2))
					$dialogY = [math]::Max(0, [math]::Floor(($currentHostHeight - $dialogHeight) / 2))
					$inputX = $dialogX + 4
					$inputY = $dialogY + 4
					
				# Recalculate button bounds after repositioning
			$buttonRowY = $dialogY + 6
		$updateButtonStartX = $dialogX + 2
		$updateButtonEndX   = $dialogX + 2 + $dlgBracketWidth + $dlgIconWidth + 7 - 1
		$cancelButtonStartX = $dialogX + 2 + $dlgBracketWidth + $dlgIconWidth + 7 + 2
		$cancelButtonEndX   = $cancelButtonStartX + $dlgBracketWidth + $dlgIconWidth + 8 - 1
		
		# Update button bounds in script scope
		$script:DialogButtonBounds = @{
			buttonRowY = $buttonRowY
			updateStartX = $updateButtonStartX
			updateEndX = $updateButtonEndX
			cancelStartX = $cancelButtonStartX
			cancelEndX = $cancelButtonEndX
		}
		
		for ($i = 0; $i -lt $dialogLines.Count; $i++) {
			if ($i -eq 1) {
				Write-Buffer -X $dialogX -Y ($dialogY + $i) -Text "$($script:BoxVertical)  " -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
				Write-Buffer -Text "Change End Time" -FG $script:TimeDialogTitle -BG $script:TimeDialogBg
					$titleUsedWidth = 3 + "Change End Time".Length
					$titlePadding = Get-Padding -usedWidth ($titleUsedWidth + 1) -totalWidth $dialogWidth
					Write-Buffer -Text (" " * $titlePadding) -BG $script:TimeDialogBg
					Write-Buffer -Text "$($script:BoxVertical)" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
				} elseif ($i -eq 4) {
					$fieldDisplay = $timeInput.PadRight(4)
					Write-Buffer -X $dialogX -Y ($dialogY + $i) -Text "$($script:BoxVertical)  " -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
					Write-Buffer -Text "[" -FG $script:TimeDialogText -BG $script:TimeDialogBg
					Write-Buffer -Text $fieldDisplay -FG $script:TimeDialogFieldText -BG $script:TimeDialogFieldBg
					Write-Buffer -Text "]" -FG $script:TimeDialogText -BG $script:TimeDialogBg
					$fieldUsedWidth = 3 + 6
					$fieldPadding = Get-Padding -usedWidth ($fieldUsedWidth + 1) -totalWidth $dialogWidth
					Write-Buffer -Text (" " * $fieldPadding) -BG $script:TimeDialogBg
					Write-Buffer -Text "$($script:BoxVertical)" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
				} elseif ($i -eq 6) {
				$btn1X = $dialogX + 2
				$btn2X = $btn1X + $dlgBracketWidth + $dlgIconWidth + 7 + $dlgParenAdj + 2
				Write-Buffer -X $dialogX -Y ($dialogY + $i) -Text "$($script:BoxVertical) " -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
				if ($script:DialogButtonShowBrackets) {
					Write-Buffer -X $btn1X -Y ($dialogY + $i) -Text "[" -FG $script:DialogButtonBracketFg -BG $script:DialogButtonBracketBg
				}
				$btn1ContentX = $btn1X + [int]$script:DialogButtonShowBrackets
				if ($script:DialogButtonShowIcon) {
					Write-Buffer -X $btn1ContentX -Y ($dialogY + $i) -Text $checkmark -FG $script:TextSuccess -BG $script:TimeDialogButtonBg -Wide
					Write-Buffer -X ($btn1ContentX + 2) -Y ($dialogY + $i) -Text $script:DialogButtonSeparator -FG $script:TimeDialogButtonText -BG $script:TimeDialogButtonBg
				} else {
					Write-Buffer -X $btn1ContentX -Y ($dialogY + $i) -Text "" -BG $script:TimeDialogButtonBg
				}
				$_rp = if ($script:DialogButtonShowHotkeyParens) { ")" } else { "" }
				if ($script:DialogButtonShowHotkeyParens) { Write-Buffer -Text "(" -FG $script:TimeDialogButtonText -BG $script:TimeDialogButtonBg }
	Write-Buffer -Text "a" -FG $script:TimeDialogButtonHotkey -BG $script:TimeDialogButtonBg
	Write-Buffer -Text "${_rp}pply" -FG $script:TimeDialogButtonText -BG $script:TimeDialogButtonBg
				if ($script:DialogButtonShowBrackets) { Write-Buffer -Text "]" -FG $script:DialogButtonBracketFg -BG $script:DialogButtonBracketBg }
				Write-Buffer -Text "  " -BG $script:TimeDialogBg
				if ($script:DialogButtonShowBrackets) {
					Write-Buffer -X $btn2X -Y ($dialogY + $i) -Text "[" -FG $script:DialogButtonBracketFg -BG $script:DialogButtonBracketBg
				}
				$btn2ContentX = $btn2X + [int]$script:DialogButtonShowBrackets
				if ($script:DialogButtonShowIcon) {
					Write-Buffer -X $btn2ContentX -Y ($dialogY + $i) -Text $redX -FG $script:TextError -BG $script:TimeDialogButtonBg -Wide
					Write-Buffer -X ($btn2ContentX + 2) -Y ($dialogY + $i) -Text $script:DialogButtonSeparator -FG $script:TimeDialogButtonText -BG $script:TimeDialogButtonBg
				} else {
					Write-Buffer -X $btn2ContentX -Y ($dialogY + $i) -Text "" -BG $script:TimeDialogButtonBg
				}
				if ($script:DialogButtonShowHotkeyParens) { Write-Buffer -Text "(" -FG $script:TimeDialogButtonText -BG $script:TimeDialogButtonBg }
				Write-Buffer -Text "c" -FG $script:TimeDialogButtonHotkey -BG $script:TimeDialogButtonBg
				Write-Buffer -Text "${_rp}ancel" -FG $script:TimeDialogButtonText -BG $script:TimeDialogButtonBg
				if ($script:DialogButtonShowBrackets) { Write-Buffer -Text "]" -FG $script:DialogButtonBracketFg -BG $script:DialogButtonBracketBg }
				Write-Buffer -Text (" " * $bottomLinePadding) -BG $script:TimeDialogBg
				Write-Buffer -Text "$($script:BoxVertical)" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
			} else {
				Write-Buffer -X $dialogX -Y ($dialogY + $i) -Text $dialogLines[$i] -FG $script:TimeDialogText -BG $script:TimeDialogBg
			}
		}
					
					Draw-DialogShadow -dialogX $dialogX -dialogY $dialogY -dialogWidth $dialogWidth -dialogHeight $dialogHeight -shadowColor $script:TimeDialogShadow
					
					$fieldDisplay = $timeInput.PadRight(4)
					Write-Buffer -X $dialogX -Y $inputY -Text "$($script:BoxVertical)  " -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
					Write-Buffer -Text "[" -FG $script:TimeDialogText -BG $script:TimeDialogBg
					Write-Buffer -Text $fieldDisplay -FG $script:TimeDialogFieldText -BG $script:TimeDialogFieldBg
					Write-Buffer -Text "]" -FG $script:TimeDialogText -BG $script:TimeDialogBg
					$fieldUsedWidth = 3 + 6
					$fieldPadding = Get-Padding -usedWidth ($fieldUsedWidth + 1) -totalWidth $dialogWidth
					Write-Buffer -Text (" " * $fieldPadding) -BG $script:TimeDialogBg
					Write-Buffer -Text "$($script:BoxVertical)" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
					if ($errorMessage -ne "") {
						Write-Buffer -X $dialogX -Y ($dialogY + 5) -Text "$($script:BoxVertical)  " -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
						Write-Buffer -Text $errorMessage -FG $script:TextError -BG $script:TimeDialogBg
						$errorLineUsedWidth = 3 + $errorMessage.Length
						$errorLinePadding = Get-Padding -usedWidth ($errorLineUsedWidth + 1) -totalWidth $dialogWidth
						Write-Buffer -Text (" " * $errorLinePadding) -BG $script:TimeDialogBg
						Write-Buffer -Text "$($script:BoxVertical)" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
					} else {
						Write-Buffer -X $dialogX -Y ($dialogY + 5) -Text "$($script:BoxVertical)" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
						Write-Buffer -Text (" " * ($dialogWidth - 2)) -BG $script:TimeDialogBg
						Write-Buffer -Text "$($script:BoxVertical)" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
					}
					Flush-Buffer -ClearFirst
					[Console]::SetCursorPosition($inputX + $timeInput.Length, $inputY)
				}
				
				# Check for mouse button clicks on dialog buttons via console input buffer
				$keyProcessed = $false
				$keyInfo = $null
				$key = $null
				$char = $null
				
				try {
					$peekBuf = New-Object 'mJiggAPI.INPUT_RECORD[]' 16
					$peekEvts = [uint32]0
					$hIn = [mJiggAPI.Mouse]::GetStdHandle(-10)
					if ([mJiggAPI.Mouse]::PeekConsoleInput($hIn, $peekBuf, 16, [ref]$peekEvts) -and $peekEvts -gt 0) {
						$lastClickIdx = -1
						$clickX = -1; $clickY = -1
						for ($e = 0; $e -lt $peekEvts; $e++) {
							if ($peekBuf[$e].EventType -eq 0x0002 -and $peekBuf[$e].MouseEvent.dwEventFlags -eq 0 -and ($peekBuf[$e].MouseEvent.dwButtonState -band 0x0001) -ne 0) {
								$clickX = $peekBuf[$e].MouseEvent.dwMousePosition.X
								$clickY = $peekBuf[$e].MouseEvent.dwMousePosition.Y
								$lastClickIdx = $e
							}
						}
						if ($lastClickIdx -ge 0) {
							$consumeCount = [uint32]($lastClickIdx + 1)
							$flushBuf = New-Object 'mJiggAPI.INPUT_RECORD[]' $consumeCount
							$flushed = [uint32]0
							[mJiggAPI.Mouse]::ReadConsoleInput($hIn, $flushBuf, $consumeCount, [ref]$flushed) | Out-Null
							
					# Click outside dialog bounds → cancel
					if ($clickX -lt $dialogX -or $clickX -ge ($dialogX + $dialogWidth) -or $clickY -lt $dialogY -or $clickY -gt ($dialogY + $dialogHeight)) {
						$char = "c"; $keyProcessed = $true
					} elseif ($clickY -eq $buttonRowY -and $clickX -ge $updateButtonStartX -and $clickX -le $updateButtonEndX) {
						$char = "a"; $keyProcessed = $true
					} elseif ($clickY -eq $buttonRowY -and $clickX -ge $cancelButtonStartX -and $clickX -le $cancelButtonEndX) {
						$char = "c"; $keyProcessed = $true
					}
					if ($DebugMode) {
						$clickTarget = if ($keyProcessed) { "button:$char" } else { "none" }
						if ($null -eq $LogArray -or -not ($LogArray -is [Array])) { $LogArray = @() }
						$LogArray += [PSCustomObject]@{
							logRow = $true
							components = @(
								@{ priority = 1; text = (Get-Date).ToString("HH:mm:ss"); shortText = (Get-Date).ToString("HH:mm:ss") },
								@{ priority = 2; text = " - [DEBUG] Time dialog click at ($clickX,$clickY), target: $clickTarget"; shortText = " - [DEBUG] Click ($clickX,$clickY) -> $clickTarget" }
							)
						}
					}
						}
					}
				} catch { }
				
				# Check for dialog button clicks detected by main loop
				if (-not $keyProcessed -and $null -ne $script:DialogButtonClick) {
					$buttonClick = $script:DialogButtonClick
					$script:DialogButtonClick = $null
				if ($buttonClick -eq "Apply") { $char = "a"; $keyProcessed = $true }
				elseif ($buttonClick -eq "Cancel") { $char = "c"; $keyProcessed = $true }
			}
			
			# Wait for key input (non-blocking check)
			if (-not $keyProcessed) {
				while ($Host.UI.RawUI.KeyAvailable -and -not $keyProcessed) {
					$keyInfo = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyup,AllowCtrlC")
						$isKeyDown = $false
						if ($null -ne $keyInfo.KeyDown) {
							$isKeyDown = $keyInfo.KeyDown
						}
						
						# Only process key UP events (skip key down)
						if (-not $isKeyDown) {
							$key = $keyInfo.Key
							$char = $keyInfo.Character
							$keyProcessed = $true
						}
					}
				}
				
				if (-not $keyProcessed) {
					# No key available, sleep briefly and check for resize again
					Start-Sleep -Milliseconds 50
					continue
				}
				
			if ($char -eq "a" -or $char -eq "A" -or $key -eq "Enter" -or $char -eq [char]13 -or $char -eq [char]10) {
				# Apply - allow blank input to clear end time (Enter key also works as hidden function)
					# Debug: Log time dialog update
					if ($DebugMode) {
						if ($null -eq $LogArray -or -not ($LogArray -is [Array])) {
							$LogArray = @()
						}
						$updateValue = if ($timeInput.Length -eq 0) { "cleared" } else { $timeInput }
						$LogArray += [PSCustomObject]@{
							logRow = $true
							components = @(
								@{
									priority = 1
									text = (Get-Date).ToString("HH:mm:ss")
									shortText = (Get-Date).ToString("HH:mm:ss")
								},
								@{
									priority = 2
									text = " - [DEBUG] Time dialog: Update clicked (value: $updateValue)"
									shortText = " - [DEBUG] Time: Update"
								}
							)
						}
					}
					if ($timeInput.Length -eq 0) {
						# Blank input - clear end time (use -1 as special value)
						$result = -1
						break
					} elseif ($timeInput.Length -eq 1 -and $timeInput -eq "0") {
						# Single "0" = no end time
						$result = -1
						break
					} elseif ($timeInput.Length -eq 2) {
						# 2 digits entered - treat as hours, auto-fill minutes as 00
						try {
							$hours = [int]$timeInput
							if ($hours -ge 0 -and $hours -le 23) {
								# Valid hours - pad with "00" for minutes
								$timeInput = $timeInput.PadRight(4, '0')
								$newTime = [int]$timeInput
								$result = $newTime
								break
							} else {
								# Invalid hours - show error
								$errorMessage = "Hours out of range (00-23)"
								# Redraw input field with highlight - redraw entire line 4
								$fieldDisplay = $timeInput.PadRight(4)
								Write-Buffer -X $dialogX -Y $inputY -Text "$($script:BoxVertical)  " -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
								Write-Buffer -Text "[" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
								Write-Buffer -Text $fieldDisplay -FG $script:TimeDialogFieldText -BG $script:TimeDialogFieldBg
								Write-Buffer -Text "]" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
								$fieldUsedWidth = 3 + 6
								$fieldPadding = Get-Padding -usedWidth ($fieldUsedWidth + 1) -totalWidth $dialogWidth
								Write-Buffer -Text (" " * $fieldPadding) -BG $script:TimeDialogBg
								Write-Buffer -Text "$($script:BoxVertical)" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
								Write-Buffer -X $dialogX -Y ($dialogY + 5) -Text "$($script:BoxVertical)  " -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
								Write-Buffer -Text $errorMessage -FG $script:TextError -BG $script:TimeDialogBg
								$errorLineUsedWidth = 3 + $errorMessage.Length
								$errorLinePadding = Get-Padding -usedWidth ($errorLineUsedWidth + 1) -totalWidth $dialogWidth
								Write-Buffer -Text (" " * $errorLinePadding) -BG $script:TimeDialogBg
								Write-Buffer -Text "$($script:BoxVertical)" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
								Flush-Buffer
								[Console]::SetCursorPosition($inputX + 1 + $timeInput.Length, $inputY)
							}
						} catch {
							# Invalid input - show error
							$errorMessage = "Invalid hours"
							# Redraw input field with highlight - redraw entire line 4
							$fieldDisplay = $timeInput.PadRight(4)
							Write-Buffer -X $dialogX -Y $inputY -Text "$($script:BoxVertical)  " -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
							Write-Buffer -Text "[" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
							Write-Buffer -Text $fieldDisplay -FG $script:TimeDialogFieldText -BG $script:TimeDialogFieldBg
							Write-Buffer -Text "]" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
							$fieldUsedWidth = 3 + 6
							$fieldPadding = Get-Padding -usedWidth ($fieldUsedWidth + 1) -totalWidth $dialogWidth
							Write-Buffer -Text (" " * $fieldPadding) -BG $script:TimeDialogBg
							Write-Buffer -Text "$($script:BoxVertical)" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
							Write-Buffer -X $dialogX -Y ($dialogY + 5) -Text "$($script:BoxVertical)  " -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
							Write-Buffer -Text $errorMessage -FG $script:TextError -BG $script:TimeDialogBg
							$errorLineUsedWidth = 3 + $errorMessage.Length
							$errorLinePadding = Get-Padding -usedWidth ($errorLineUsedWidth + 1) -totalWidth $dialogWidth
							Write-Buffer -Text (" " * $errorLinePadding) -BG $script:TimeDialogBg
							Write-Buffer -Text "$($script:BoxVertical)" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
							Flush-Buffer
							[Console]::SetCursorPosition($inputX + 1 + $timeInput.Length, $inputY)
						}
					} elseif ($timeInput.Length -eq 4) {
						try {
							$newTime = [int]$timeInput
							# Validate time format: HHmm where HH is 00-23 and mm is 00-59
							$hours = [int]$timeInput.Substring(0, 2)
							$minutes = [int]$timeInput.Substring(2, 2)
							
							# "0000" is midnight (12:00 AM), not "no end time"
							if ($newTime -ge 0 -and $newTime -le 2359 -and $hours -le 23 -and $minutes -le 59) {
								$result = $newTime
								break
							} else {
								# Invalid time - show error
								if ($hours -gt 23) {
									$errorMessage = "Hours out of range (00-23)"
								} elseif ($minutes -gt 59) {
									$errorMessage = "Minutes out of range (00-59)"
								} else {
									$errorMessage = "Time out of range (0000-2359)"
								}
								# Redraw input field with highlight - redraw entire line 4
								$fieldDisplay = $timeInput.PadRight(4)
								Write-Buffer -X $dialogX -Y $inputY -Text "$($script:BoxVertical)  " -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
								Write-Buffer -Text "[" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
								Write-Buffer -Text $fieldDisplay -FG $script:TimeDialogFieldText -BG $script:TimeDialogFieldBg
								Write-Buffer -Text "]" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
								$fieldUsedWidth = 3 + 6
								$fieldPadding = Get-Padding -usedWidth ($fieldUsedWidth + 1) -totalWidth $dialogWidth
								Write-Buffer -Text (" " * $fieldPadding) -BG $script:TimeDialogBg
								Write-Buffer -Text "$($script:BoxVertical)" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
								Write-Buffer -X $dialogX -Y ($dialogY + 5) -Text "$($script:BoxVertical)  " -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
								Write-Buffer -Text $errorMessage -FG $script:TextError -BG $script:TimeDialogBg
								$errorLineUsedWidth = 3 + $errorMessage.Length
								$errorLinePadding = Get-Padding -usedWidth ($errorLineUsedWidth + 1) -totalWidth $dialogWidth
								Write-Buffer -Text (" " * $errorLinePadding) -BG $script:TimeDialogBg
								Write-Buffer -Text "$($script:BoxVertical)" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
								Flush-Buffer
								[Console]::SetCursorPosition($inputX + 1 + $timeInput.Length, $inputY)
							}
						} catch {
							# Invalid input - show error (shouldn't normally happen with numeric-only input)
							$errorMessage = "Number out of range"
							# Redraw input field with highlight - redraw entire line 4
							$fieldDisplay = $timeInput.PadRight(4)
							Write-Buffer -X $dialogX -Y $inputY -Text "$($script:BoxVertical)  " -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
							Write-Buffer -Text "[" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
							Write-Buffer -Text $fieldDisplay -FG $script:TimeDialogFieldText -BG $script:TimeDialogFieldBg
							Write-Buffer -Text "]" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
							$fieldUsedWidth = 3 + 6
							$fieldPadding = Get-Padding -usedWidth ($fieldUsedWidth + 1) -totalWidth $dialogWidth
							Write-Buffer -Text (" " * $fieldPadding) -BG $script:TimeDialogBg
							Write-Buffer -Text "$($script:BoxVertical)" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
							Write-Buffer -X $dialogX -Y ($dialogY + 5) -Text "$($script:BoxVertical)  " -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
							Write-Buffer -Text $errorMessage -FG $script:TextError -BG $script:TimeDialogBg
							$errorLineUsedWidth = 3 + $errorMessage.Length
							$errorLinePadding = Get-Padding -usedWidth ($errorLineUsedWidth + 1) -totalWidth $dialogWidth
							Write-Buffer -Text (" " * $errorLinePadding) -BG $script:TimeDialogBg
							Write-Buffer -Text "$($script:BoxVertical)" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
							Flush-Buffer
							[Console]::SetCursorPosition($inputX + 1 + $timeInput.Length, $inputY)
						}
					} else {
						# Not 4 digits yet - show error
						$errorMessage = "Enter 4 digits (HHmm format)"
						# Redraw input field with highlight - redraw entire line 4
						$fieldDisplay = $timeInput.PadRight(4)
						Write-Buffer -X $dialogX -Y $inputY -Text "$($script:BoxVertical)  " -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
						Write-Buffer -Text "[" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
						Write-Buffer -Text $fieldDisplay -FG $script:TimeDialogFieldText -BG $script:TimeDialogFieldBg
						Write-Buffer -Text "]" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
						$fieldUsedWidth = 3 + 6
						$fieldPadding = Get-Padding -usedWidth ($fieldUsedWidth + 1) -totalWidth $dialogWidth
						Write-Buffer -Text (" " * $fieldPadding) -BG $script:TimeDialogBg
						Write-Buffer -Text "$($script:BoxVertical)" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
						Write-Buffer -X $dialogX -Y ($dialogY + 5) -Text "$($script:BoxVertical)  " -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
						Write-Buffer -Text $errorMessage -FG $script:TextError -BG $script:TimeDialogBg
						$errorLineUsedWidth = 3 + $errorMessage.Length
						$errorLinePadding = Get-Padding -usedWidth ($errorLineUsedWidth + 1) -totalWidth $dialogWidth
						Write-Buffer -Text (" " * $errorLinePadding) -BG $script:TimeDialogBg
						Write-Buffer -Text "$($script:BoxVertical)" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
						Flush-Buffer
						[Console]::SetCursorPosition($inputX + 1 + $timeInput.Length, $inputY)
					}
				} elseif ($char -eq "c" -or $char -eq "C" -or $char -eq "t" -or $char -eq "T" -or $key -eq "Escape" -or ($null -ne $keyInfo -and $keyInfo.VirtualKeyCode -eq 27)) {
					# Cancel (Escape key and 't' key also work as hidden functions)
					# Debug: Log time dialog cancel
					if ($DebugMode) {
						if ($null -eq $LogArray -or -not ($LogArray -is [Array])) {
							$LogArray = @()
						}
						$LogArray += [PSCustomObject]@{
							logRow = $true
							components = @(
								@{
									priority = 1
									text = (Get-Date).ToString("HH:mm:ss")
									shortText = (Get-Date).ToString("HH:mm:ss")
								},
								@{
									priority = 2
									text = " - [DEBUG] Time dialog: Cancel clicked"
									shortText = " - [DEBUG] Time: Cancel"
								}
							)
						}
					}
					$result = $null
					$needsRedraw = $false  # No redraw needed on cancel
					break
				} elseif ($key -eq "Backspace" -or $char -eq [char]8 -or ($null -ne $keyInfo -and $keyInfo.VirtualKeyCode -eq 8)) {
					# Backspace - handle multiple ways to ensure it works
					# Ensure value is a string (in case it was somehow set as a char)
					$timeInput = $timeInput.ToString()
					if ($timeInput.Length -gt 0) {
						$timeInput = $timeInput.Substring(0, $timeInput.Length - 1)
						# If field is now empty, reset the input tracking so next char will clear again
						if ($timeInput.Length -eq 0) {
							$isFirstChar = $true
							$script:CursorVisible = $false; [Console]::Write("$($script:ESC)[?25l")
						}
						$errorMessage = ""  # Clear error when editing
						# Redraw input with highlight - redraw entire line 4 to ensure clean overwrite
						$fieldDisplay = $timeInput.PadRight(4)
						Write-Buffer -X $dialogX -Y $inputY -Text "$($script:BoxVertical)  " -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
						Write-Buffer -Text "[" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
						Write-Buffer -Text $fieldDisplay -FG $script:TimeDialogFieldText -BG $script:TimeDialogFieldBg
						Write-Buffer -Text "]" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
						$fieldUsedWidth = 3 + 6
						$fieldPadding = Get-Padding -usedWidth ($fieldUsedWidth + 1) -totalWidth $dialogWidth
						Write-Buffer -Text (" " * $fieldPadding) -BG $script:TimeDialogBg
						Write-Buffer -Text "$($script:BoxVertical)" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
						Write-Buffer -X $dialogX -Y ($dialogY + 5) -Text "$($script:BoxVertical)" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
						Write-Buffer -Text (" " * 33) -BG $script:TimeDialogBg
						Write-Buffer -Text "$($script:BoxVertical)" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
						Flush-Buffer
						# Position cursor at end of input (only if field has content, after opening bracket)
						if ($timeInput.Length -gt 0) {
							[Console]::SetCursorPosition($inputX + $timeInput.Length, $inputY)
						}
					}
				} elseif ($char -match "[0-9]") {
					# Numeric input
					# If this is the first character typed, clear the field first and show cursor
					if ($isFirstChar) {
						$timeInput = $char.ToString()  # Convert char to string
						$isFirstChar = $false
						$script:CursorVisible = $true; [Console]::Write("$($script:ESC)[?25h")
					} elseif ($timeInput.Length -lt 4) {
						$timeInput += $char.ToString()  # Convert char to string
					}
					$errorMessage = ""  # Clear error when typing
					# Redraw input field with highlight - redraw entire line 4 to ensure clean overwrite
					$fieldDisplay = $timeInput.PadRight(4)
					Write-Buffer -X $dialogX -Y $inputY -Text "$($script:BoxVertical)  " -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
					Write-Buffer -Text "[" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
					Write-Buffer -Text $fieldDisplay -FG $script:TimeDialogFieldText -BG $script:TimeDialogFieldBg
					Write-Buffer -Text "]" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
					$fieldUsedWidth = 3 + 6
					$fieldPadding = Get-Padding -usedWidth ($fieldUsedWidth + 1) -totalWidth $dialogWidth
					Write-Buffer -Text (" " * $fieldPadding) -BG $script:TimeDialogBg
					Write-Buffer -Text "$($script:BoxVertical)" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
					Write-Buffer -X $dialogX -Y ($dialogY + 5) -Text "$($script:BoxVertical)" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
					Write-Buffer -Text (" " * 33) -BG $script:TimeDialogBg
					Write-Buffer -Text "$($script:BoxVertical)" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
					Flush-Buffer
					[Console]::SetCursorPosition($inputX + $timeInput.Length, $inputY)
				}
				
				# Clear any remaining keys in buffer after processing
				try {
					while ($Host.UI.RawUI.KeyAvailable) {
						$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown,AllowCtrlC")
					}
				} catch {
					# Silently ignore - buffer might not be clearable
				}
			} until ($false)
			
			Clear-DialogShadow -dialogX $dialogX -dialogY $dialogY -dialogWidth $dialogWidth -dialogHeight $dialogHeight
			for ($i = 0; $i -lt $dialogHeight; $i++) {
				Write-Buffer -X $dialogX -Y ($dialogY + $i) -Text (" " * $dialogWidth)
			}
			Flush-Buffer
			
			$script:CursorVisible = $savedCursorVisible
			if ($script:CursorVisible) { [Console]::Write("$($script:ESC)[?25h") } else { [Console]::Write("$($script:ESC)[?25l") }
			
			$script:DialogButtonBounds = $null
			$script:DialogButtonClick = $null
			
			return @{
				Result = $result
				NeedsRedraw = $needsRedraw
			}
		}

		# ============================================
		# Performance Helper Functions
		# ============================================
		
		# Playful quotes for resize screen
		$script:ResizeQuotes = @(
			"Jiggling since the dawn of idle timeouts..."
			"A mouse in motion stays employed"
			"Wiggle wiggle wiggle"
			"Like jello, but for your cursor"
			"Making mice dance since 2024"
			"The early mouse gets the jiggle"
			"Shake it like a Polaroid picture"
			"Keep calm and jiggle on"
			"This mouse has moves"
			"Cursor cardio in progress"
			"Staying active so you don't have to"
			"Mice just wanna have fun"
			"Jiggle physics: enabled"
			"Not all who wander are lost, some are jiggling"
			"Professional mouse motivator"
			"Your mouse's personal trainer"
			"Wiggling through the workday"
		)
		$script:CurrentResizeQuote = $null
		
	# Restores ENABLE_MOUSE_INPUT on the console's stdin handle.
	# [Console]::Clear() can cause Windows Terminal to reset the console input mode,
	# stripping ENABLE_MOUSE_INPUT and silently dropping all subsequent mouse events.
	# Call this after every [Console]::Clear() that occurs outside of normal rendering.
	function Restore-ConsoleInputMode {
		try {
			$hConsole = [mJiggAPI.Mouse]::GetStdHandle(-10)  # STD_INPUT_HANDLE
			$mode = [uint32]0
			if ([mJiggAPI.Mouse]::GetConsoleMode($hConsole, [ref]$mode)) {
				$ENABLE_QUICK_EDIT_MODE = 0x0040
				$ENABLE_MOUSE_INPUT     = 0x0010
				$newMode = ($mode -band (-bnot $ENABLE_QUICK_EDIT_MODE)) -bor $ENABLE_MOUSE_INPUT
				[mJiggAPI.Mouse]::SetConsoleMode($hConsole, $newMode) | Out-Null
			}
		} catch { }
	}

	# After a drag-resize Windows Terminal briefly holds mouse-event routing for its own
	# resize UI and doesn't forward mouse clicks to the console app. Injecting a system-level
	# keyboard event (via keybd_event, not WriteConsoleInput) signals to Windows Terminal that
	# focus is back in the console app, restoring normal mouse-event delivery.
	# VK_RMENU (Right Alt, 0xA5) is a pure modifier key - no printable character, no hotkey risk.
	function Send-ResizeExitWakeKey {
		try {
			$vkCode = [byte]0xA5  # VK_RMENU (Right Alt)
			[mJiggAPI.Keyboard]::keybd_event($vkCode, [byte]0, [uint32]0, [int]0)        # key down
			Start-Sleep -Milliseconds 10
			[mJiggAPI.Keyboard]::keybd_event($vkCode, [byte]0, [uint32]0x0002, [int]0)   # key up
		} catch { }
	}

	# Helper function: Draw centered logo during window resize using buffered output
	function Draw-ResizeLogo {
			param(
				[switch]$ClearFirst,
				[object]$WindowSize = $null
			)
			try {
				$rawUI = $Host.UI.RawUI
				$winSize = if ($null -ne $WindowSize) { $WindowSize } else { $rawUI.WindowSize }
				$winWidth = $winSize.Width
				$winHeight = $winSize.Height

			# Lock height during resize: WindowSize.Height can transiently fluctuate by ±1 row
			# when only the width is being changed (Windows Terminal reflow). Lock the height
			# at resize-start and only update it if it changes by more than 1 row, so small
			# transient fluctuations never affect the vertical center calculation.
			if ($null -ne $WindowSize) {
				if ($null -eq $script:ResizeLogoLockedHeight) {
					$script:ResizeLogoLockedHeight = $winHeight
				} elseif ([math]::Abs($winHeight - $script:ResizeLogoLockedHeight) -gt 1) {
					$script:ResizeLogoLockedHeight = $winHeight
				}
				# else: change is ≤1 row — treat as transient, hold the locked value
				$winHeight = $script:ResizeLogoLockedHeight
			}
				
				# Only draw if window is large enough
				if ($winWidth -lt 16 -or $winHeight -lt 14) {
					return
				}
				
				# Select a random quote if we don't have one yet
				if ($null -eq $script:CurrentResizeQuote) {
					$script:CurrentResizeQuote = $script:ResizeQuotes | Get-Random
				}
				
				# Box-drawing characters
				$boxTL = [char]0x250C      # ┌
				$boxTR = [char]0x2510      # ┐
				$boxBL = [char]0x2514      # └
				$boxBR = [char]0x2518      # ┘
				$boxH = [char]0x2500       # ─
				$boxV = [char]0x2502       # │
				
				# Logo display width: mJig( (5) + emoji (2) + ) (1) = 8
				$logoDisplayWidth = 8
				
				# Calculate center position for logo
				$centerX = [math]::Floor(($winWidth - $logoDisplayWidth) / 2)
				$centerY = [math]::Floor($winHeight / 2)
				
				# Box dimensions: scale with screen size while maintaining minimum padding
				$minPadding = 3
				# Calculate available space around logo
				$availableH = [math]::Min($centerX - 1, $winWidth - $centerX - $logoDisplayWidth - 1)
				$availableV = [math]::Min($centerY - 1, $winHeight - $centerY - 2)
				# Use 42% of available space as padding, with minimum
				$boxPaddingH = [math]::Max($minPadding * 2, [math]::Floor($availableH * 0.42))
				$boxPaddingV = [math]::Max($minPadding, [math]::Floor($availableV * 0.42))
				$boxLeft = $centerX - $boxPaddingH - 1
				$boxRight = $centerX + $logoDisplayWidth + $boxPaddingH
				$boxTop = $centerY - $boxPaddingV - 1
				$boxBottom = $centerY + $boxPaddingV + 1
				$boxInnerWidth = $boxRight - $boxLeft - 1
				
				# Build horizontal line string once
				$hLine = [string]::new($boxH, $boxInnerWidth)
				
				Write-Buffer -X $boxLeft -Y $boxTop -Text "$boxTL$hLine$boxTR"
				for ($y = $boxTop + 1; $y -lt $boxBottom; $y++) {
					Write-Buffer -X $boxLeft -Y $y -Text "$boxV"
					Write-Buffer -X $boxRight -Y $y -Text "$boxV"
				}
				Write-Buffer -X $boxLeft -Y $boxBottom -Text "$boxBL$hLine$boxBR"
				
				$emojiX = $centerX + 5
				Write-Buffer -X $centerX -Y $centerY -Text "mJig(" -FG $script:ResizeLogoName
				Write-Buffer -X $emojiX -Y $centerY -Text ([char]::ConvertFromUtf32(0x1F400)) -FG $script:ResizeLogoIcon
				Write-Buffer -X ($emojiX + 2) -Y $centerY -Text ")" -FG $script:ResizeLogoName
				
				$quoteY = $centerY + 2
				if ($quoteY -lt $boxBottom -and $null -ne $script:CurrentResizeQuote) {
					$quote = $script:CurrentResizeQuote
					$maxQuoteWidth = $boxInnerWidth - 2
					if ($quote.Length -gt $maxQuoteWidth) {
						$quote = $quote.Substring(0, $maxQuoteWidth - 3) + "..."
					}
					$quoteX = [math]::Floor(($winWidth - $quote.Length) / 2)
					Write-Buffer -X $quoteX -Y $quoteY -Text $quote -FG $script:ResizeQuoteText
				}
				if ($ClearFirst) { Flush-Buffer -ClearFirst } else { Flush-Buffer }
				
			} catch {
				try {
					$winSize = $Host.UI.RawUI.WindowSize
					$centerX = [math]::Max(0, [math]::Floor(($winSize.Width - 8) / 2))
					$centerY = [math]::Max(0, [math]::Floor($winSize.Height / 2))
					Write-Buffer -X $centerX -Y $centerY -Text "mJig(" -FG $script:ResizeLogoName
					Write-Buffer -Text ([char]::ConvertFromUtf32(0x1F400)) -FG $script:ResizeLogoIcon
					Write-Buffer -Text ")" -FG $script:ResizeLogoName
					if ($ClearFirst) { Flush-Buffer -ClearFirst } else { Flush-Buffer }
				} catch { }
			}
		}
		
		# Helper function: Get method safely (cached for performance)
		function Get-CachedMethod {
			param(
				$type,
				[string]$methodName
			)
			$cacheKey = "$($type.FullName).$methodName"
			if (-not $script:MethodCache.ContainsKey($cacheKey)) {
				$script:MethodCache[$cacheKey] = $type.GetMethod($methodName)
			}
			return $script:MethodCache[$cacheKey]
		}
		
		# Helper function: Get mouse position (uses cached method)
		function Get-MousePosition {
			$point = New-Object mJiggAPI.POINT
			$mouseType = [mJiggAPI.Mouse]
			$getCursorPosMethod = Get-CachedMethod -type $mouseType -methodName "GetCursorPos"
			if ($null -ne $getCursorPosMethod -and [mJiggAPI.Mouse]::GetCursorPos([ref]$point)) {
				return New-Object System.Drawing.Point($point.X, $point.Y)
			}
			return $null
		}
		
		# Helper function: Check mouse movement threshold
		function Test-MouseMoved {
			param(
				[System.Drawing.Point]$currentPos,
				[System.Drawing.Point]$lastPos,
				[int]$threshold = 2
			)
			if ($null -eq $lastPos) { return $false }
			$deltaX = [Math]::Abs($currentPos.X - $lastPos.X)
			$deltaY = [Math]::Abs($currentPos.Y - $lastPos.Y)
			return ($deltaX -gt $threshold -or $deltaY -gt $threshold)
		}
		
		# Helper function: Calculate time since (in milliseconds)
		# Returns MaxValue if startTime is null (allows safe comparison without null checks)
		function Get-TimeSinceMs {
			param($startTime)
			if ($null -eq $startTime) { return [double]::MaxValue }
			return ((Get-Date) - [DateTime]$startTime).TotalMilliseconds
		}
		
		# Helper function: Calculate value with random variance
		function Get-ValueWithVariance {
			param([double]$baseValue, [double]$variance)
			$varianceAmount = Get-Random -Minimum 0.0 -Maximum ($variance + 0.0001)
			if ((Get-Random -Maximum 2) -eq 0) {
				return $baseValue - $varianceAmount
			} else {
				return $baseValue + $varianceAmount
			}
		}
		
		# Helper function: Clamp coordinates to screen bounds
		function Set-CoordinateBounds {
			param([ref]$x, [ref]$y)
			$x.Value = [Math]::Max(0, [Math]::Min($x.Value, $script:ScreenWidth - 1))
			$y.Value = [Math]::Max(0, [Math]::Min($y.Value, $script:ScreenHeight - 1))
		}
		
		
		# ============================================
		# UI Helper Functions
		# ============================================
		
		# Helper function: Calculate padding needed to fill remaining width
		function Get-Padding {
			param(
				[int]$usedWidth,
				[int]$totalWidth
			)
			return [Math]::Max(0, $totalWidth - $usedWidth)
		}
		
		# Helper function: Draw a horizontal line in a section
		function Write-SectionLine {
			param(
				[int]$x,
				[int]$y,
				[int]$width,
				[string]$leftChar = "$($script:BoxVertical)",
				[string]$rightChar = "$($script:BoxVertical)",
				[string]$fillChar = " ",
				[System.ConsoleColor]$borderColor = [System.ConsoleColor]::White,
				[System.ConsoleColor]$fillColor = [System.ConsoleColor]::White
			)
			
			$fillWidth = $width - 2
			Write-Buffer -X $x -Y $y -Text $leftChar -FG $borderColor
			Write-Buffer -Text ($fillChar * $fillWidth) -FG $fillColor
			Write-Buffer -Text $rightChar -FG $borderColor
		}
		
		# Helper function: Draw a simple dialog row (no description box)
		function Write-SimpleDialogRow {
			param(
				[int]$x,
				[int]$y,
				[int]$width,
				[string]$content = "",
				[System.ConsoleColor]$contentColor = [System.ConsoleColor]::White,
				[System.ConsoleColor]$backgroundColor = $null
			)
			
			$borderFG = if ($null -ne $backgroundColor) { $script:MoveDialogBorder } else { $null }
			Write-Buffer -X $x -Y $y -Text "$($script:BoxVertical)" -FG $borderFG -BG $backgroundColor
			if ($content.Length -gt 0) {
				Write-Buffer -Text " " -BG $backgroundColor
				Write-Buffer -Text $content -FG $contentColor -BG $backgroundColor
				$usedWidth = 1 + 1 + $content.Length
				$padding = Get-Padding -usedWidth ($usedWidth + 1) -totalWidth $width
				Write-Buffer -Text (" " * $padding) -BG $backgroundColor
			} else {
				Write-Buffer -Text (" " * ($width - 2)) -BG $backgroundColor
			}
			Write-Buffer -Text "$($script:BoxVertical)" -FG $borderFG -BG $backgroundColor
		}
		
		# Helper function: Draw a field row with input box (no description box)
		function Write-SimpleFieldRow {
			param(
				[int]$x,
				[int]$y,
				[int]$width,
				[string]$label,
				[int]$longestLabel,
				[string]$fieldValue,
				[int]$fieldWidth,
				[int]$fieldIndex,
				[int]$currentFieldIndex,
				[System.ConsoleColor]$backgroundColor = $null
			)
			
			$labelPadding = [Math]::Max(0, $longestLabel - $label.Length)
			$labelText = "$($script:BoxVertical)  " + $label + (" " * $labelPadding)
			
			$fieldDisplay = if ([string]::IsNullOrEmpty($fieldValue)) { "" } else { $fieldValue }
			$fieldDisplay = $fieldDisplay.PadRight($fieldWidth)
			$fieldContent = "[" + $fieldDisplay + "]"
			
			$labelFG = if ($null -ne $backgroundColor) { $script:MoveDialogText } else { $null }
			$borderFG = if ($null -ne $backgroundColor) { $script:MoveDialogBorder } else { $null }
			$fieldFG = if ($fieldIndex -eq $currentFieldIndex) {
				if ($null -ne $backgroundColor) { $script:MoveDialogFieldText } else { $script:TimeDialogFieldText }
			} else {
				$script:TextHighlight
			}
			$fieldBG = if ($fieldIndex -eq $currentFieldIndex) {
				if ($null -ne $backgroundColor) { $script:MoveDialogFieldBg } else { $script:TimeDialogFieldBg }
			} else {
				$backgroundColor
			}
			
			Write-Buffer -X $x -Y $y -Text $labelText -FG $labelFG -BG $backgroundColor
			Write-Buffer -Text "[" -FG $labelFG -BG $backgroundColor
			Write-Buffer -Text $fieldDisplay -FG $fieldFG -BG $fieldBG
			Write-Buffer -Text "]" -FG $labelFG -BG $backgroundColor
			$usedWidth = $labelText.Length + $fieldContent.Length
			$remainingPadding = Get-Padding -usedWidth ($usedWidth + 1) -totalWidth $width
			Write-Buffer -Text (" " * $remainingPadding) -BG $backgroundColor
			Write-Buffer -Text "$($script:BoxVertical)" -FG $borderFG -BG $backgroundColor
		}
		
		function Show-MovementModifyDialog {
			param(
				[double]$currentIntervalSeconds,
				[double]$currentIntervalVariance,
				[double]$currentMoveSpeed,
				[double]$currentMoveVariance,
				[double]$currentTravelDistance,
				[double]$currentTravelVariance,
				[double]$currentAutoResumeDelaySeconds,
				[ref]$HostWidthRef,
				[ref]$HostHeightRef
			)
			
			# Get current host dimensions from references
			$currentHostWidth = $HostWidthRef.Value
			$currentHostHeight = $HostHeightRef.Value
			
			# Dialog dimensions - simplified (no description box)
			$dialogWidth = 30  # Width for parameters section (reduced by 20)
			$dialogHeight = 17  # Increased by 1 for new auto-resume delay field
			$dialogX = [math]::Max(0, [math]::Floor(($currentHostWidth - $dialogWidth) / 2))
			$dialogY = [math]::Max(0, [math]::Floor(($currentHostHeight - $dialogHeight) / 2))
			
			$savedCursorVisible = $script:CursorVisible
			$script:CursorVisible = $false
			[Console]::Write("$($script:ESC)[?25l")
			
			# Input field values
			$intervalSecondsInput = $currentIntervalSeconds.ToString()
			$intervalVarianceInput = $currentIntervalVariance.ToString()
			$moveSpeedInput = $currentMoveSpeed.ToString()
			$moveVarianceInput = $currentMoveVariance.ToString()
			$travelDistanceInput = $currentTravelDistance.ToString()
			$travelVarianceInput = $currentTravelVariance.ToString()
			$autoResumeDelaySecondsInput = $currentAutoResumeDelaySeconds.ToString()
			
			# Current field index (0-6)
			$currentField = 0
			$errorMessage = ""
			$lastFieldWithInput = -1  # Track which field last received input (to detect first character)
			
			# Field positions (Y coordinates relative to dialogY)
			$fieldYPositions = @(5, 6, 9, 10, 13, 14, 15)  # Y positions for each input field
			$fieldWidth = 6  # Width of input field (max 6 characters)
			# Calculate the longest label width for alignment
			$label1 = [Math]::Max("Interval (sec): ".Length, "Variance (sec): ".Length)
			$label2 = [Math]::Max("Distance (px): ".Length, "Variance (px): ".Length)
			$label3 = [Math]::Max($label1, $label2)
			$label4 = [Math]::Max($label3, "Speed (sec): ".Length)
			$longestLabel = [Math]::Max($label4, "Delay (sec): ".Length)
			$inputBoxStartX = 3 + $longestLabel  # "$($script:BoxVertical)  " + longest label = X position where all input boxes start
			
			# Draw dialog function - simplified (no description box)
			$drawDialog = {
				param($x, $y, $width, $height, $currentFieldIndex, $errorMsg, $inputBoxStartXPos, $fieldWidthValue, $intervalSec, $intervalVar, $moveSpeed, $moveVar, $travelDist, $travelDistVar, $autoResumeDelaySec)
				
				$fieldWidth = $fieldWidthValue
				
				# Calculate longest label for alignment
				$label1 = [Math]::Max("Interval (sec): ".Length, "Variance (sec): ".Length)
				$label2 = [Math]::Max("Distance (px): ".Length, "Variance (px): ".Length)
				$label3 = [Math]::Max($label1, $label2)
				$label4 = [Math]::Max($label3, "Speed (sec): ".Length)
				$longestLabel = [Math]::Max($label4, "Delay (sec): ".Length)
				
				# Define field data structure
				$fields = @(
					@{ Index = 0; Label = "Interval (sec): "; Value = $intervalSec },
					@{ Index = 1; Label = "Variance (sec): "; Value = $intervalVar },
					@{ Index = 2; Label = "Distance (px): "; Value = $travelDist },
					@{ Index = 3; Label = "Variance (px): "; Value = $travelDistVar },
					@{ Index = 4; Label = "Speed (sec): "; Value = $moveSpeed },
					@{ Index = 5; Label = "Variance (sec): "; Value = $moveVar },
					@{ Index = 6; Label = "Delay (sec): "; Value = $autoResumeDelaySec }
				)
				
			# Clear dialog area with themed background
			for ($i = 0; $i -lt $height; $i++) {
				Write-Buffer -X $x -Y ($y + $i) -Text (" " * $width) -BG $script:MoveDialogBg
			}
				
			# Top border (spans full width)
			Write-Buffer -X $x -Y $y -Text "$($script:BoxTopLeft)" -FG $script:MoveDialogBorder -BG $script:MoveDialogBg
			Write-Buffer -Text ("$($script:BoxHorizontal)" * ($width - 2)) -FG $script:MoveDialogBorder -BG $script:MoveDialogBg
			Write-Buffer -Text "$($script:BoxTopRight)" -FG $script:MoveDialogBorder -BG $script:MoveDialogBg
				
				# Title line
				Write-SimpleDialogRow -x $x -y ($y + 1) -width $width -content "Modify Movement Settings" -contentColor $script:MoveDialogTitle -backgroundColor $script:MoveDialogBg
				
				# Empty line (row 2)
				Write-SimpleDialogRow -x $x -y ($y + 2) -width $width -backgroundColor $script:MoveDialogBg
				
				# Interval section header (row 3)
				Write-SimpleDialogRow -x $x -y ($y + 3) -width $width -content "Interval:" -contentColor $script:MoveDialogSectionTitle -backgroundColor $script:MoveDialogBg
				
				# Interval fields (rows 4-5)
				Write-SimpleFieldRow -x $x -y ($y + 4) -width $width `
					-label $fields[0].Label -longestLabel $longestLabel -fieldValue $fields[0].Value `
					-fieldWidth $fieldWidth -fieldIndex $fields[0].Index -currentFieldIndex $currentFieldIndex -backgroundColor $script:MoveDialogBg
				
				Write-SimpleFieldRow -x $x -y ($y + 5) -width $width `
					-label $fields[1].Label -longestLabel $longestLabel -fieldValue $fields[1].Value `
					-fieldWidth $fieldWidth -fieldIndex $fields[1].Index -currentFieldIndex $currentFieldIndex -backgroundColor $script:MoveDialogBg
				
				# Travel Distance section header (row 6)
				Write-SimpleDialogRow -x $x -y ($y + 6) -width $width -content "Travel Distance:" -contentColor $script:MoveDialogSectionTitle -backgroundColor $script:MoveDialogBg
				
				# Travel Distance fields (rows 7-8)
				Write-SimpleFieldRow -x $x -y ($y + 7) -width $width `
					-label $fields[2].Label -longestLabel $longestLabel -fieldValue $fields[2].Value `
					-fieldWidth $fieldWidth -fieldIndex $fields[2].Index -currentFieldIndex $currentFieldIndex -backgroundColor $script:MoveDialogBg
				
				Write-SimpleFieldRow -x $x -y ($y + 8) -width $width `
					-label $fields[3].Label -longestLabel $longestLabel -fieldValue $fields[3].Value `
					-fieldWidth $fieldWidth -fieldIndex $fields[3].Index -currentFieldIndex $currentFieldIndex -backgroundColor $script:MoveDialogBg
				
				# Movement Speed section header (row 9)
				Write-SimpleDialogRow -x $x -y ($y + 9) -width $width -content "Movement Speed:" -contentColor $script:MoveDialogSectionTitle -backgroundColor $script:MoveDialogBg
				
				# Movement Speed fields (rows 10-11)
				Write-SimpleFieldRow -x $x -y ($y + 10) -width $width `
					-label $fields[4].Label -longestLabel $longestLabel -fieldValue $fields[4].Value `
					-fieldWidth $fieldWidth -fieldIndex $fields[4].Index -currentFieldIndex $currentFieldIndex -backgroundColor $script:MoveDialogBg
				
				Write-SimpleFieldRow -x $x -y ($y + 11) -width $width `
					-label $fields[5].Label -longestLabel $longestLabel -fieldValue $fields[5].Value `
					-fieldWidth $fieldWidth -fieldIndex $fields[5].Index -currentFieldIndex $currentFieldIndex -backgroundColor $script:MoveDialogBg
				
				# Auto-Resume Delay section header (row 12)
				Write-SimpleDialogRow -x $x -y ($y + 12) -width $width -content "Auto-Resume Delay:" -contentColor $script:MoveDialogSectionTitle -backgroundColor $script:MoveDialogBg
				
				# Auto-Resume Delay field (row 13)
				Write-SimpleFieldRow -x $x -y ($y + 13) -width $width `
					-label $fields[6].Label -longestLabel $longestLabel -fieldValue $fields[6].Value `
					-fieldWidth $fieldWidth -fieldIndex $fields[6].Index -currentFieldIndex $currentFieldIndex -backgroundColor $script:MoveDialogBg
				
				# Empty line (row 14)
				Write-SimpleDialogRow -x $x -y ($y + 14) -width $width -backgroundColor $script:MoveDialogBg
				
				# Error line (row 15)
				if ($errorMsg) {
					Write-SimpleDialogRow -x $x -y ($y + 15) -width $width -content $errorMsg -contentColor $script:TextError -backgroundColor $script:MoveDialogBg
				} else {
					Write-SimpleDialogRow -x $x -y ($y + 15) -width $width -backgroundColor $script:MoveDialogBg
				}
				
	# Bottom line with buttons (row 16)
	$checkmark = [char]::ConvertFromUtf32(0x2705)
	$redX = [char]::ConvertFromUtf32(0x274C)
$_dlgIW = if ($script:DialogButtonShowIcon)     { 2 + $script:DialogButtonSeparator.Length } else { 0 }
$_dlgBW = if ($script:DialogButtonShowBrackets) { 2 } else { 0 }
$_dlgPA = if ($script:DialogButtonShowHotkeyParens) { 0 } else { -2 }
$btn1X = $x + 2
$btn2X = $btn1X + $_dlgBW + $_dlgIW + 7 + $_dlgPA + 2  # bracket + icon + "(a)pply"(7) + gap(2)
# Button line: border+space(2) + btn1(bracketW+iconW+7) + gap(2) + btn2(bracketW+iconW+8) = 19 + 2*iconWidth + 2*bracketWidth
$buttonPadding = $width - (19 + 2 * $_dlgPA + 2 * $_dlgIW + 2 * $_dlgBW) - 1
Write-Buffer -X $x -Y ($y + 16) -Text "$($script:BoxVertical)" -FG $script:MoveDialogBorder -BG $script:MoveDialogBg
Write-Buffer -Text " " -BG $script:MoveDialogBg
if ($script:DialogButtonShowBrackets) {
	Write-Buffer -X $btn1X -Y ($y + 16) -Text "[" -FG $script:DialogButtonBracketFg -BG $script:DialogButtonBracketBg
}
$btn1ContentX = $btn1X + [int]$script:DialogButtonShowBrackets
if ($script:DialogButtonShowIcon) {
	Write-Buffer -X $btn1ContentX -Y ($y + 16) -Text $checkmark -FG $script:TextSuccess -BG $script:MoveDialogButtonBg -Wide
	Write-Buffer -X ($btn1ContentX + 2) -Y ($y + 16) -Text $script:DialogButtonSeparator -FG $script:MoveDialogButtonText -BG $script:MoveDialogButtonBg
} else {
	Write-Buffer -X $btn1ContentX -Y ($y + 16) -Text "" -BG $script:MoveDialogButtonBg
}
$_rp = if ($script:DialogButtonShowHotkeyParens) { ")" } else { "" }
if ($script:DialogButtonShowHotkeyParens) { Write-Buffer -Text "(" -FG $script:MoveDialogButtonText -BG $script:MoveDialogButtonBg }
Write-Buffer -Text "a" -FG $script:MoveDialogButtonHotkey -BG $script:MoveDialogButtonBg
Write-Buffer -Text "${_rp}pply" -FG $script:MoveDialogButtonText -BG $script:MoveDialogButtonBg
if ($script:DialogButtonShowBrackets) { Write-Buffer -Text "]" -FG $script:DialogButtonBracketFg -BG $script:DialogButtonBracketBg }
Write-Buffer -Text "  " -BG $script:MoveDialogBg
if ($script:DialogButtonShowBrackets) {
	Write-Buffer -X $btn2X -Y ($y + 16) -Text "[" -FG $script:DialogButtonBracketFg -BG $script:DialogButtonBracketBg
}
$btn2ContentX = $btn2X + [int]$script:DialogButtonShowBrackets
if ($script:DialogButtonShowIcon) {
	Write-Buffer -X $btn2ContentX -Y ($y + 16) -Text $redX -FG $script:TextError -BG $script:MoveDialogButtonBg -Wide
	Write-Buffer -X ($btn2ContentX + 2) -Y ($y + 16) -Text $script:DialogButtonSeparator -FG $script:MoveDialogButtonText -BG $script:MoveDialogButtonBg
} else {
	Write-Buffer -X $btn2ContentX -Y ($y + 16) -Text "" -BG $script:MoveDialogButtonBg
}
if ($script:DialogButtonShowHotkeyParens) { Write-Buffer -Text "(" -FG $script:MoveDialogButtonText -BG $script:MoveDialogButtonBg }
Write-Buffer -Text "c" -FG $script:MoveDialogButtonHotkey -BG $script:MoveDialogButtonBg
Write-Buffer -Text "${_rp}ancel" -FG $script:MoveDialogButtonText -BG $script:MoveDialogButtonBg
	if ($script:DialogButtonShowBrackets) { Write-Buffer -Text "]" -FG $script:DialogButtonBracketFg -BG $script:DialogButtonBracketBg }
	Write-Buffer -Text (" " * $buttonPadding) -BG $script:MoveDialogBg
	Write-Buffer -Text "$($script:BoxVertical)" -FG $script:MoveDialogBorder -BG $script:MoveDialogBg
				
			# Bottom border (spans full width)
			Write-Buffer -X $x -Y ($y + 17) -Text "$($script:BoxBottomLeft)" -FG $script:MoveDialogBorder -BG $script:MoveDialogBg
			Write-Buffer -Text ("$($script:BoxHorizontal)" * ($width - 2)) -FG $script:MoveDialogBorder -BG $script:MoveDialogBg
			Write-Buffer -Text "$($script:BoxBottomRight)" -FG $script:MoveDialogBorder -BG $script:MoveDialogBg
				
				# Draw drop shadow
				Draw-DialogShadow -dialogX $x -dialogY $y -dialogWidth $width -dialogHeight $height -shadowColor $script:MoveDialogShadow
			}
			
		# Initial draw
		& $drawDialog $dialogX $dialogY $dialogWidth $dialogHeight $currentField $errorMessage $inputBoxStartX $fieldWidth $intervalSecondsInput $intervalVarianceInput $moveSpeedInput $moveVarianceInput $travelDistanceInput $travelVarianceInput $autoResumeDelaySecondsInput
		Flush-Buffer
		
	# Calculate button bounds for click detection
	# Button row is at dialogY + 16 (row 16)
	$buttonRowY = $dialogY + 16
$_moveDlgIW = if ($script:DialogButtonShowIcon)     { 2 + $script:DialogButtonSeparator.Length } else { 0 }
$_moveDlgBW = if ($script:DialogButtonShowBrackets) { 2 } else { 0 }
$_moveDlgPA = if ($script:DialogButtonShowHotkeyParens) { 0 } else { -2 }
$updateButtonStartX = $dialogX + 2
$updateButtonEndX   = $dialogX + 2 + $_moveDlgBW + $_moveDlgIW + 7 + $_moveDlgPA - 1   # bracket + icon + "(a)pply"(7) - 1 inclusive
$cancelButtonStartX = $dialogX + 2 + $_moveDlgBW + $_moveDlgIW + 7 + $_moveDlgPA + 2   # after btn1 + gap(2)
$cancelButtonEndX   = $cancelButtonStartX + $_moveDlgBW + $_moveDlgIW + 8 + $_moveDlgPA - 1  # bracket + icon + "(c)ancel"(8) - 1 inclusive
			
			# Store button bounds in script scope for main loop click detection
			$script:DialogButtonBounds = @{
				buttonRowY = $buttonRowY
				updateStartX = $updateButtonStartX
				updateEndX = $updateButtonEndX
				cancelStartX = $cancelButtonStartX
				cancelEndX = $cancelButtonEndX
			}
			$script:DialogButtonClick = $null  # Clear any previous click  # 19 + 2 (emoji) + 1 (pipe) + 8 (text) - 1 (inclusive)
			
			# Position cursor at the first field after initial draw (ready for input)
			$fieldYOffsets = @(4, 5, 7, 8, 10, 11, 13)  # Y offsets for each field relative to dialogY
			$fieldY = $dialogY + $fieldYOffsets[$currentField]
			# Get the current field's input value
			$currentInputRef = switch ($currentField) {
				0 { [ref]$intervalSecondsInput }
				1 { [ref]$intervalVarianceInput }
				2 { [ref]$travelDistanceInput }
				3 { [ref]$travelVarianceInput }
				4 { [ref]$moveSpeedInput }
				5 { [ref]$moveVarianceInput }
				6 { [ref]$autoResumeDelaySecondsInput }
			}
			# Cursor X: dialogX + inputBoxStartX + 1 (for opening bracket) + length of actual value
			$cursorX = $dialogX + $inputBoxStartX + 1 + $currentInputRef.Value.Length
			[Console]::SetCursorPosition($cursorX, $fieldY)
			$result = $null
			$needsRedraw = $false
			
			# Debug: Log that dialog input loop has started
			if ($DebugMode) {
				if ($null -eq $LogArray -or -not ($LogArray -is [Array])) {
					$LogArray = @()
				}
				$LogArray += [PSCustomObject]@{
					logRow = $true
					components = @(
						@{
							priority = 1
							text = (Get-Date).ToString("HH:mm:ss")
							shortText = (Get-Date).ToString("HH:mm:ss")
						},
						@{
							priority = 2
							text = " - [DEBUG] Movement dialog input loop started, button row Y: $buttonRowY"
							shortText = " - [DEBUG] Dialog started"
						}
					)
				}
			}
			
			:inputLoop do {
				# Check for window resize
				$pshost = Get-Host
				$pswindow = $pshost.UI.RawUI
				$newWindowSize = $pswindow.WindowSize
				if ($newWindowSize.Width -ne $currentHostWidth -or $newWindowSize.Height -ne $currentHostHeight) {
					$HostWidthRef.Value = $newWindowSize.Width
					$HostHeightRef.Value = $newWindowSize.Height
					$currentHostWidth = $newWindowSize.Width
					$currentHostHeight = $newWindowSize.Height
					$needsRedraw = $true
					$dialogX = [math]::Max(0, [math]::Floor(($currentHostWidth - $dialogWidth) / 2))
					$dialogY = [math]::Max(0, [math]::Floor(($currentHostHeight - $dialogHeight) / 2))
					
			# Recalculate button bounds after repositioning
			$buttonRowY = $dialogY + 16
			$_moveDlgIW = if ($script:DialogButtonShowIcon)     { 2 + $script:DialogButtonSeparator.Length } else { 0 }
			$_moveDlgBW = if ($script:DialogButtonShowBrackets) { 2 } else { 0 }
		$updateButtonStartX = $dialogX + 2
		$updateButtonEndX   = $dialogX + 2 + $_moveDlgBW + $_moveDlgIW + 7 - 1
		$cancelButtonStartX = $dialogX + 2 + $_moveDlgBW + $_moveDlgIW + 7 + 2
		$cancelButtonEndX   = $cancelButtonStartX + $_moveDlgBW + $_moveDlgIW + 8 - 1
					
					# Update button bounds in script scope
					$script:DialogButtonBounds = @{
						buttonRowY = $buttonRowY
						updateStartX = $updateButtonStartX
						updateEndX = $updateButtonEndX
						cancelStartX = $cancelButtonStartX
						cancelEndX = $cancelButtonEndX
					}
					
				& $drawDialog $dialogX $dialogY $dialogWidth $dialogHeight $currentField $errorMessage $inputBoxStartX $fieldWidth $intervalSecondsInput $intervalVarianceInput $moveSpeedInput $moveVarianceInput $travelDistanceInput $travelVarianceInput $autoResumeDelaySecondsInput
				Flush-Buffer -ClearFirst
				# Position cursor at the active field after resize
					$fieldYOffsets = @(4, 5, 7, 8, 10, 11, 13)  # Y offsets for each field relative to dialogY
					$fieldY = $dialogY + $fieldYOffsets[$currentField]
					$currentInputRef = switch ($currentField) {
						0 { [ref]$intervalSecondsInput }
						1 { [ref]$intervalVarianceInput }
						2 { [ref]$travelDistanceInput }
						3 { [ref]$travelVarianceInput }
						4 { [ref]$moveSpeedInput }
						5 { [ref]$moveVarianceInput }
						6 { [ref]$autoResumeDelaySecondsInput }
					}
					$cursorX = $dialogX + $inputBoxStartX + 1 + $currentInputRef.Value.Length
					[Console]::SetCursorPosition($cursorX, $fieldY)
				}
				
				# Check for mouse button clicks on dialog buttons/fields via console input buffer
				$keyProcessed = $false
				$keyInfo = $null
				$key = $null
				$char = $null
				
				try {
					$peekBuf = New-Object 'mJiggAPI.INPUT_RECORD[]' 16
					$peekEvts = [uint32]0
					$hIn = [mJiggAPI.Mouse]::GetStdHandle(-10)
					if ([mJiggAPI.Mouse]::PeekConsoleInput($hIn, $peekBuf, 16, [ref]$peekEvts) -and $peekEvts -gt 0) {
						$lastClickIdx = -1
						$clickX = -1; $clickY = -1
						for ($e = 0; $e -lt $peekEvts; $e++) {
							if ($peekBuf[$e].EventType -eq 0x0002 -and $peekBuf[$e].MouseEvent.dwEventFlags -eq 0 -and ($peekBuf[$e].MouseEvent.dwButtonState -band 0x0001) -ne 0) {
								$clickX = $peekBuf[$e].MouseEvent.dwMousePosition.X
								$clickY = $peekBuf[$e].MouseEvent.dwMousePosition.Y
								$lastClickIdx = $e
							}
						}
						if ($lastClickIdx -ge 0) {
							$consumeCount = [uint32]($lastClickIdx + 1)
							$flushBuf = New-Object 'mJiggAPI.INPUT_RECORD[]' $consumeCount
							$flushed = [uint32]0
							[mJiggAPI.Mouse]::ReadConsoleInput($hIn, $flushBuf, $consumeCount, [ref]$flushed) | Out-Null
							
						$clickedField = -1
					# Click outside dialog bounds → cancel
					if ($clickX -lt $dialogX -or $clickX -ge ($dialogX + $dialogWidth) -or $clickY -lt $dialogY -or $clickY -gt ($dialogY + $dialogHeight)) {
						$char = "c"; $keyProcessed = $true
					} elseif ($clickY -eq $buttonRowY -and $clickX -ge $updateButtonStartX -and $clickX -le $updateButtonEndX) {
						$char = "a"; $keyProcessed = $true
					} elseif ($clickY -eq $buttonRowY -and $clickX -ge $cancelButtonStartX -and $clickX -le $cancelButtonEndX) {
						$char = "c"; $keyProcessed = $true
					}
					if (-not $keyProcessed -and $clickX -ge $dialogX -and $clickX -lt ($dialogX + $dialogWidth)) {
								$clickFieldYOffsets = @(4, 5, 7, 8, 10, 11, 13)
								for ($fi = 0; $fi -lt $clickFieldYOffsets.Count; $fi++) {
									$fy = $dialogY + $clickFieldYOffsets[$fi]
									if ($clickY -eq $fy) {
										$clickedField = $fi
										break
									}
								}
								if ($clickedField -ge 0 -and $clickedField -ne $currentField) {
									$previousField = $currentField
									$currentField = $clickedField
									$errorMessage = ""
									$lastFieldWithInput = -1
									
									$fieldLabels = @("Interval (sec): ", "Variance (sec): ", "Distance (px): ", "Variance (px): ", "Speed (sec): ", "Variance (sec): ", "Delay (sec): ")
									$fieldValues = @($intervalSecondsInput, $intervalVarianceInput, $travelDistanceInput, $travelVarianceInput, $moveSpeedInput, $moveVarianceInput, $autoResumeDelaySecondsInput)
									
									Write-SimpleFieldRow -x $dialogX -y ($dialogY + $clickFieldYOffsets[$previousField]) -width $dialogWidth `
										-label $fieldLabels[$previousField] -longestLabel $longestLabel -fieldValue $fieldValues[$previousField] `
										-fieldWidth $fieldWidth -fieldIndex $previousField -currentFieldIndex $currentField -backgroundColor DarkBlue
									
								Write-SimpleFieldRow -x $dialogX -y ($dialogY + $clickFieldYOffsets[$currentField]) -width $dialogWidth `
									-label $fieldLabels[$currentField] -longestLabel $longestLabel -fieldValue $fieldValues[$currentField] `
									-fieldWidth $fieldWidth -fieldIndex $currentField -currentFieldIndex $currentField -backgroundColor DarkBlue
								Flush-Buffer
								
								$fieldY = $dialogY + $clickFieldYOffsets[$currentField]
								$currentInputRef = switch ($currentField) {
										0 { [ref]$intervalSecondsInput }
										1 { [ref]$intervalVarianceInput }
										2 { [ref]$travelDistanceInput }
										3 { [ref]$travelVarianceInput }
										4 { [ref]$moveSpeedInput }
										5 { [ref]$moveVarianceInput }
										6 { [ref]$autoResumeDelaySecondsInput }
									}
									$cursorX = $dialogX + $inputBoxStartX + 1 + $currentInputRef.Value.Length
									[Console]::SetCursorPosition($cursorX, $fieldY)
									$keyProcessed = $true
								}
							}
							if ($DebugMode) {
								$clickTarget = "none"
								if ($keyProcessed -and $char) { $clickTarget = "button:$char" }
								elseif ($clickedField -ge 0) { $clickTarget = "field:$clickedField" }
								if ($null -eq $LogArray -or -not ($LogArray -is [Array])) { $LogArray = @() }
								$LogArray += [PSCustomObject]@{
									logRow = $true
									components = @(
										@{ priority = 1; text = (Get-Date).ToString("HH:mm:ss"); shortText = (Get-Date).ToString("HH:mm:ss") },
										@{ priority = 2; text = " - [DEBUG] Movement dialog click at ($clickX,$clickY), target: $clickTarget"; shortText = " - [DEBUG] Click ($clickX,$clickY) -> $clickTarget" }
									)
								}
							}
						}
					}
				} catch { }
				
				# Check for dialog button clicks detected by main loop
				if (-not $keyProcessed -and $null -ne $script:DialogButtonClick) {
					$buttonClick = $script:DialogButtonClick
					$script:DialogButtonClick = $null
				if ($buttonClick -eq "Apply") { $char = "a"; $keyProcessed = $true }
				elseif ($buttonClick -eq "Cancel") { $char = "c"; $keyProcessed = $true }
			}
			
			# Wait for key input (non-blocking check)
			if (-not $keyProcessed) {
				while ($Host.UI.RawUI.KeyAvailable -and -not $keyProcessed) {
					$keyInfo = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyUp,AllowCtrlC")
						$isKeyDown = $false
						if ($null -ne $keyInfo.KeyDown) {
							$isKeyDown = $keyInfo.KeyDown
						}
						# Process key-up events (when key is released)
						if (-not $isKeyDown) {
							$key = $keyInfo.Key
							$char = $keyInfo.Character
							$keyProcessed = $true
						}
					}
				}
				
				if (-not $keyProcessed) {
					Start-Sleep -Milliseconds 50
					continue
				}
				
				# Get current field input string reference
				$currentInputRef = switch ($currentField) {
					0 { [ref]$intervalSecondsInput }
					1 { [ref]$intervalVarianceInput }
					2 { [ref]$travelDistanceInput }      # Travel Distance (swapped)
					3 { [ref]$travelVarianceInput }  # Travel Variance (swapped)
					4 { [ref]$moveSpeedInput }           # Move Speed (swapped)
					5 { [ref]$moveVarianceInput }        # Move Variance (swapped)
					6 { [ref]$autoResumeDelaySecondsInput }  # Auto-Resume Delay
				}
				
			if ($char -eq "a" -or $char -eq "A" -or $key -eq "Enter" -or $char -eq [char]13 -or $char -eq [char]10) {
				# Apply - validate and save all values
					# Debug: Log movement dialog update
					if ($DebugMode) {
						if ($null -eq $LogArray -or -not ($LogArray -is [Array])) {
							$LogArray = @()
						}
						$LogArray += [PSCustomObject]@{
							logRow = $true
							components = @(
								@{
									priority = 1
									text = (Get-Date).ToString("HH:mm:ss")
									shortText = (Get-Date).ToString("HH:mm:ss")
								},
								@{
									priority = 2
									text = " - [DEBUG] Movement dialog: Update clicked"
									shortText = " - [DEBUG] Movement: Update"
								}
							)
						}
					}
					$errorMessage = ""
					try {
						$newIntervalSeconds = [double]$intervalSecondsInput
						$newIntervalVariance = [double]$intervalVarianceInput
						$newMoveSpeed = [double]$moveSpeedInput
						$newMoveVariance = [double]$moveVarianceInput
						$newTravelDistance = [double]$travelDistanceInput
						$newTravelVariance = [double]$travelVarianceInput
						$newAutoResumeDelaySeconds = [double]$autoResumeDelaySecondsInput
						
						# Validate ranges
						if ($newIntervalSeconds -le 0) {
							$errorMessage = "Interval must be greater than 0"
						} elseif ($newIntervalVariance -lt 0) {
							$errorMessage = "Interval variance must be >= 0"
						} elseif ($newMoveSpeed -le 0) {
							$errorMessage = "Move speed must be greater than 0"
						} elseif ($newMoveVariance -lt 0) {
							$errorMessage = "Move variance must be >= 0"
						} elseif ($newTravelDistance -le 0) {
							$errorMessage = "Travel distance must be greater than 0"
						} elseif ($newTravelVariance -lt 0) {
							$errorMessage = "Travel variance must be >= 0"
						} elseif ($newAutoResumeDelaySeconds -lt 0) {
							$errorMessage = "Auto-resume delay must be >= 0"
						}
						
						if (-not $errorMessage) {
							$result = @{
								IntervalSeconds = $newIntervalSeconds
								IntervalVariance = $newIntervalVariance
								MoveSpeed = $newMoveSpeed
								MoveVariance = $newMoveVariance
								TravelDistance = $newTravelDistance
								TravelVariance = $newTravelVariance
								AutoResumeDelaySeconds = $newAutoResumeDelaySeconds
							}
							break
						}
					} catch {
						$errorMessage = "Invalid number format"
					}
				& $drawDialog $dialogX $dialogY $dialogWidth $dialogHeight $currentField $errorMessage $inputBoxStartX $fieldWidth $intervalSecondsInput $intervalVarianceInput $moveSpeedInput $moveVarianceInput $travelDistanceInput $travelVarianceInput $autoResumeDelaySecondsInput
				Flush-Buffer
			} elseif ($char -eq "c" -or $char -eq "C" -or $char -eq "t" -or $char -eq "T" -or $key -eq "Escape" -or ($null -ne $keyInfo -and $keyInfo.VirtualKeyCode -eq 27)) {
					# Cancel
					# Debug: Log movement dialog cancel
					if ($DebugMode) {
						if ($null -eq $LogArray -or -not ($LogArray -is [Array])) {
							$LogArray = @()
						}
						$LogArray += [PSCustomObject]@{
							logRow = $true
							components = @(
								@{
									priority = 1
									text = (Get-Date).ToString("HH:mm:ss")
									shortText = (Get-Date).ToString("HH:mm:ss")
								},
								@{
									priority = 2
									text = " - [DEBUG] Movement dialog: Cancel clicked"
									shortText = " - [DEBUG] Movement: Cancel"
								}
							)
						}
					}
					$result = $null
					$needsRedraw = $false
					break
				} elseif ($char -eq "m" -or $char -eq "M") {
					# Hidden option: Close dialog with 'm' key
					$result = $null
					$needsRedraw = $false
					break
				} elseif ($key -eq "Tab" -or ($null -ne $keyInfo -and $keyInfo.VirtualKeyCode -eq 9)) {
					# Tab - check if Shift is pressed for reverse tab
					# Use Windows API to check if Shift keys are currently pressed (more reliable than ControlKeyState)
					$VK_LSHIFT = 0xA0  # Left Shift virtual key code
					$VK_RSHIFT = 0xA1  # Right Shift virtual key code
					$isShiftPressed = $false
					try {
						$shiftState = [mJiggAPI.Mouse]::GetAsyncKeyState($VK_LSHIFT) -bor [mJiggAPI.Mouse]::GetAsyncKeyState($VK_RSHIFT)
						$isShiftPressed = (($shiftState -band 0x8000) -ne 0)
					} catch {
						# Fallback to ControlKeyState if API call fails
						if ($null -ne $keyInfo.ControlKeyState) {
							$isShiftPressed = (($keyInfo.ControlKeyState -band 4) -ne 0) -or 
											   (($keyInfo.ControlKeyState -band 1) -ne 0) -or 
											   (($keyInfo.ControlKeyState -band 2) -ne 0)
						}
					}
					if ($isShiftPressed) {
						# Shift+Tab - move to previous field
						$currentField = ($currentField - 1 + 7) % 7
					} else {
						# Tab - move to next field
						$currentField = ($currentField + 1) % 7
					}
					$errorMessage = ""
					$lastFieldWithInput = -1  # Reset input tracking when switching fields
			& $drawDialog $dialogX $dialogY $dialogWidth $dialogHeight $currentField $errorMessage $inputBoxStartX $fieldWidth $intervalSecondsInput $intervalVarianceInput $moveSpeedInput $moveVarianceInput $travelDistanceInput $travelVarianceInput $autoResumeDelaySecondsInput
				Flush-Buffer
				# Position cursor at the active field after tab navigation
					$fieldYOffsets = @(4, 5, 7, 8, 10, 11, 13)  # Y offsets for each field relative to dialogY
					$fieldY = $dialogY + $fieldYOffsets[$currentField]
					$currentInputRef = switch ($currentField) {
						0 { [ref]$intervalSecondsInput }
						1 { [ref]$intervalVarianceInput }
						2 { [ref]$travelDistanceInput }
						3 { [ref]$travelVarianceInput }
						4 { [ref]$moveSpeedInput }
						5 { [ref]$moveVarianceInput }
						6 { [ref]$autoResumeDelaySecondsInput }
					}
					$cursorX = $dialogX + $inputBoxStartX + 1 + $currentInputRef.Value.Length
					[Console]::SetCursorPosition($cursorX, $fieldY)
				} elseif ($key -eq "Backspace" -or $char -eq [char]8 -or ($null -ne $keyInfo -and $keyInfo.VirtualKeyCode -eq 8)) {
					# Backspace
					# Ensure value is a string (in case it was somehow set as a char)
					$currentInputRef.Value = $currentInputRef.Value.ToString()
					if ($currentInputRef.Value.Length -gt 0) {
						$currentInputRef.Value = $currentInputRef.Value.Substring(0, $currentInputRef.Value.Length - 1)
						# If field is now empty, reset the input tracking so next char will clear again
						if ($currentInputRef.Value.Length -eq 0) {
							$lastFieldWithInput = -1
							$script:CursorVisible = $false; [Console]::Write("$($script:ESC)[?25l")
						}
						$errorMessage = ""
						# Optimized: only redraw current field instead of entire dialog
						$fieldYOffsets = @(4, 5, 7, 8, 10, 11, 13)
						$fieldLabels = @("Interval (sec): ", "Variance (sec): ", "Distance (px): ", "Variance (px): ", "Speed (sec): ", "Variance (sec): ", "Delay (sec): ")
					Write-SimpleFieldRow -x $dialogX -y ($dialogY + $fieldYOffsets[$currentField]) -width $dialogWidth `
						-label $fieldLabels[$currentField] -longestLabel $longestLabel -fieldValue $currentInputRef.Value `
						-fieldWidth $fieldWidth -fieldIndex $currentField -currentFieldIndex $currentField -backgroundColor DarkBlue
					Flush-Buffer
					# Position cursor at end of input
					$fieldY = $dialogY + $fieldYOffsets[$currentField]
					$cursorX = $dialogX + $inputBoxStartX + 1 + $currentInputRef.Value.Length
					[Console]::SetCursorPosition($cursorX, $fieldY)
				}
			} elseif ($char -match "[0-9]") {
					# Numeric input - limit to 6 characters
					# If this is the first character typed in this field, clear the field first
					$isFirstChar = ($lastFieldWithInput -ne $currentField)
					if ($isFirstChar) {
						$currentInputRef.Value = $char.ToString()  # Convert char to string
						$lastFieldWithInput = $currentField
						$script:CursorVisible = $true; [Console]::Write("$($script:ESC)[?25h")
					} elseif ($currentInputRef.Value.Length -lt 6) {
						$currentInputRef.Value += $char.ToString()  # Convert char to string
					}
					$errorMessage = ""
					# Optimized: only redraw current field instead of entire dialog
					$fieldYOffsets = @(4, 5, 7, 8, 10, 11, 13)
					$fieldLabels = @("Interval (sec): ", "Variance (sec): ", "Distance (px): ", "Variance (px): ", "Speed (sec): ", "Variance (sec): ", "Delay (sec): ")
				Write-SimpleFieldRow -x $dialogX -y ($dialogY + $fieldYOffsets[$currentField]) -width $dialogWidth `
					-label $fieldLabels[$currentField] -longestLabel $longestLabel -fieldValue $currentInputRef.Value `
					-fieldWidth $fieldWidth -fieldIndex $currentField -currentFieldIndex $currentField -backgroundColor DarkBlue
				Flush-Buffer
				# Position cursor at end of input
				$fieldY = $dialogY + $fieldYOffsets[$currentField]
				$cursorX = $dialogX + $inputBoxStartX + 1 + $currentInputRef.Value.Length
				[Console]::SetCursorPosition($cursorX, $fieldY)
			} elseif ($char -eq ".") {
					# Decimal point for all fields - limit to 6 characters (including decimal point)
					# If this is the first character typed in this field, clear the field first
					$isFirstChar = ($lastFieldWithInput -ne $currentField)
					if ($isFirstChar) {
						$currentInputRef.Value = "."  # Already a string
						$lastFieldWithInput = $currentField
						$script:CursorVisible = $true; [Console]::Write("$($script:ESC)[?25h")
					} elseif ($currentInputRef.Value -notmatch "\." -and $currentInputRef.Value.Length -lt 6) {
						$currentInputRef.Value += "."  # Already a string
					}
					$errorMessage = ""
					# Optimized: only redraw current field instead of entire dialog
					$fieldYOffsets = @(4, 5, 7, 8, 10, 11, 13)
					$fieldLabels = @("Interval (sec): ", "Variance (sec): ", "Distance (px): ", "Variance (px): ", "Speed (sec): ", "Variance (sec): ", "Delay (sec): ")
				Write-SimpleFieldRow -x $dialogX -y ($dialogY + $fieldYOffsets[$currentField]) -width $dialogWidth `
					-label $fieldLabels[$currentField] -longestLabel $longestLabel -fieldValue $currentInputRef.Value `
					-fieldWidth $fieldWidth -fieldIndex $currentField -currentFieldIndex $currentField -backgroundColor DarkBlue
				Flush-Buffer
				# Position cursor at end of input
				$fieldY = $dialogY + $fieldYOffsets[$currentField]
				$cursorX = $dialogX + $inputBoxStartX + 1 + $currentInputRef.Value.Length
				[Console]::SetCursorPosition($cursorX, $fieldY)
			} elseif ($key -eq "UpArrow" -or ($null -ne $keyInfo -and $keyInfo.VirtualKeyCode -eq 38)) {
					# UpArrow - move to previous field (reverse tab)
					$previousField = $currentField
					$currentField = ($currentField - 1 + 7) % 7
					$errorMessage = ""
					$lastFieldWithInput = -1  # Reset input tracking when switching fields
					
					# Optimized redraw: only update the two affected field rows instead of entire dialog
					$fieldYOffsets = @(4, 5, 7, 8, 10, 11, 13)  # Y offsets for each field relative to dialogY
					$fieldLabels = @("Interval (sec): ", "Variance (sec): ", "Distance (px): ", "Variance (px): ", "Speed (sec): ", "Variance (sec): ", "Delay (sec): ")
					$fieldValues = @($intervalSecondsInput, $intervalVarianceInput, $travelDistanceInput, $travelVarianceInput, $moveSpeedInput, $moveVarianceInput, $autoResumeDelaySecondsInput)
					
					# Redraw previous field (unhighlight)
					Write-SimpleFieldRow -x $dialogX -y ($dialogY + $fieldYOffsets[$previousField]) -width $dialogWidth `
						-label $fieldLabels[$previousField] -longestLabel $longestLabel -fieldValue $fieldValues[$previousField] `
						-fieldWidth $fieldWidth -fieldIndex $previousField -currentFieldIndex $currentField -backgroundColor DarkBlue
					
				# Redraw new field (highlight)
				Write-SimpleFieldRow -x $dialogX -y ($dialogY + $fieldYOffsets[$currentField]) -width $dialogWidth `
					-label $fieldLabels[$currentField] -longestLabel $longestLabel -fieldValue $fieldValues[$currentField] `
					-fieldWidth $fieldWidth -fieldIndex $currentField -currentFieldIndex $currentField -backgroundColor DarkBlue
				Flush-Buffer
				
				# Position cursor at the active field after arrow navigation
				$fieldY = $dialogY + $fieldYOffsets[$currentField]
				$currentInputRef = switch ($currentField) {
					0 { [ref]$intervalSecondsInput }
					1 { [ref]$intervalVarianceInput }
					2 { [ref]$travelDistanceInput }
					3 { [ref]$travelVarianceInput }
					4 { [ref]$moveSpeedInput }
					5 { [ref]$moveVarianceInput }
					6 { [ref]$autoResumeDelaySecondsInput }
				}
				$cursorX = $dialogX + $inputBoxStartX + 1 + $currentInputRef.Value.Length
				[Console]::SetCursorPosition($cursorX, $fieldY)
			} elseif ($key -eq "DownArrow" -or ($null -ne $keyInfo -and $keyInfo.VirtualKeyCode -eq 40)) {
					# DownArrow - move to next field (forward tab)
					$previousField = $currentField
					$currentField = ($currentField + 1) % 7
					$errorMessage = ""
					$lastFieldWithInput = -1  # Reset input tracking when switching fields
					
					# Optimized redraw: only update the two affected field rows instead of entire dialog
					$fieldYOffsets = @(4, 5, 7, 8, 10, 11, 13)  # Y offsets for each field relative to dialogY
					$fieldLabels = @("Interval (sec): ", "Variance (sec): ", "Distance (px): ", "Variance (px): ", "Speed (sec): ", "Variance (sec): ", "Delay (sec): ")
					$fieldValues = @($intervalSecondsInput, $intervalVarianceInput, $travelDistanceInput, $travelVarianceInput, $moveSpeedInput, $moveVarianceInput, $autoResumeDelaySecondsInput)
					
					# Redraw previous field (unhighlight)
					Write-SimpleFieldRow -x $dialogX -y ($dialogY + $fieldYOffsets[$previousField]) -width $dialogWidth `
						-label $fieldLabels[$previousField] -longestLabel $longestLabel -fieldValue $fieldValues[$previousField] `
						-fieldWidth $fieldWidth -fieldIndex $previousField -currentFieldIndex $currentField -backgroundColor DarkBlue
					
				# Redraw new field (highlight)
				Write-SimpleFieldRow -x $dialogX -y ($dialogY + $fieldYOffsets[$currentField]) -width $dialogWidth `
					-label $fieldLabels[$currentField] -longestLabel $longestLabel -fieldValue $fieldValues[$currentField] `
					-fieldWidth $fieldWidth -fieldIndex $currentField -currentFieldIndex $currentField -backgroundColor DarkBlue
				Flush-Buffer
				
				# Position cursor at the active field after arrow navigation
				$fieldY = $dialogY + $fieldYOffsets[$currentField]
				$currentInputRef = switch ($currentField) {
					0 { [ref]$intervalSecondsInput }
					1 { [ref]$intervalVarianceInput }
					2 { [ref]$travelDistanceInput }
					3 { [ref]$travelVarianceInput }
					4 { [ref]$moveSpeedInput }
					5 { [ref]$moveVarianceInput }
					6 { [ref]$autoResumeDelaySecondsInput }
				}
				$cursorX = $dialogX + $inputBoxStartX + 1 + $currentInputRef.Value.Length
				[Console]::SetCursorPosition($cursorX, $fieldY)
			}
			
			# Clear any remaining keys in buffer
				try {
					while ($Host.UI.RawUI.KeyAvailable) {
						$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown,AllowCtrlC")
					}
				} catch {
					# Silently ignore
				}
			} until ($false)
			
			# Clear shadow before clearing dialog area
			Clear-DialogShadow -dialogX $dialogX -dialogY $dialogY -dialogWidth $dialogWidth -dialogHeight $dialogHeight
			
		# Clear dialog area
		for ($i = 0; $i -lt $dialogHeight; $i++) {
			Write-Buffer -X $dialogX -Y ($dialogY + $i) -Text (" " * $dialogWidth)
		}
		Flush-Buffer
			
			$script:CursorVisible = $savedCursorVisible
			if ($script:CursorVisible) { [Console]::Write("$($script:ESC)[?25h") } else { [Console]::Write("$($script:ESC)[?25l") }
			
			$script:DialogButtonBounds = $null
			$script:DialogButtonClick = $null
			
			# Return result object
			return @{
				Result = $result
				NeedsRedraw = $needsRedraw
			}
		}

		# Function to show quit confirmation dialog
		function Show-QuitConfirmationDialog {
			param(
				[ref]$HostWidthRef,
				[ref]$HostHeightRef
			)
			
			# Debug: Log that dialog was opened
			if ($DebugMode) {
				# Note: LogArray is in parent scope, accessible directly
				if ($null -eq $LogArray -or -not ($LogArray -is [Array])) {
					$LogArray = @()
				}
				$LogArray += [PSCustomObject]@{
					logRow = $true
					components = @(
						@{
							priority = 1
							text = (Get-Date).ToString("HH:mm:ss")
							shortText = (Get-Date).ToString("HH:mm:ss")
						},
						@{
							priority = 2
							text = " - [DEBUG] Quit confirmation dialog opened"
							shortText = " - [DEBUG] Quit dialog opened"
						}
					)
				}
			}
			
			# Get current host dimensions from references
			$currentHostWidth = $HostWidthRef.Value
			$currentHostHeight = $HostHeightRef.Value
			
			# Dialog dimensions (same as time change dialog)
			$dialogWidth = 35
			$dialogHeight = 7
			# Right-aligned, 2 chars from right edge; bottom border sits one row above the separator line
			$dialogX = [math]::Max(0, $currentHostWidth - $dialogWidth - 2)
			$menuBarY = if ($null -ne $script:MenuBarY) { $script:MenuBarY } else { $currentHostHeight - 2 }
			$dialogY = [math]::Max(0, $menuBarY - 2 - $dialogHeight)
			
			$savedCursorVisible = $script:CursorVisible
			$script:CursorVisible = $false
			[Console]::Write("$($script:ESC)[?25l")
			
			# Draw dialog box (exactly 35 characters per line)
	$checkmark = [char]::ConvertFromUtf32(0x2705)  # ✅ green checkmark
	$redX = [char]::ConvertFromUtf32(0x274C)  # ❌ red X
$dlgIconWidth    = if ($script:DialogButtonShowIcon)     { 2 + $script:DialogButtonSeparator.Length } else { 0 }
$dlgBracketWidth = if ($script:DialogButtonShowBrackets) { 2 } else { 0 }
$dlgParenAdj     = if ($script:DialogButtonShowHotkeyParens) { 0 } else { -2 }
# Button line: border+space(2) + btn1(bracketW+iconW+"(y)es"=5) + gap(2) + btn2(bracketW+iconW+"(n)o"=4) = 13 + 2*iconWidth + 2*bracketWidth
$bottomLinePadding = $dialogWidth - (13 + 2 * $dlgParenAdj + 2 * $dlgIconWidth + 2 * $dlgBracketWidth) - 1
		
		# Build all lines to be exactly 35 characters using Get-Padding helper
		$line0 = "$($script:BoxTopLeft)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxTopRight)"  # 35 chars
			$line1Text = "$($script:BoxVertical)  Confirm Quit"
			$line1Padding = Get-Padding -usedWidth ($line1Text.Length + 1) -totalWidth $dialogWidth
			$line1 = $line1Text + (" " * $line1Padding) + "$($script:BoxVertical)"
			
			$line2 = "$($script:BoxVertical)" + (" " * 33) + "$($script:BoxVertical)"  # 35 chars
			
			$line3Text = "$($script:BoxVertical)  Are you sure you want to quit?"
			$line3Padding = Get-Padding -usedWidth ($line3Text.Length + 1) -totalWidth $dialogWidth
			$line3 = $line3Text + (" " * $line3Padding) + "$($script:BoxVertical)"
			
			$line4 = "$($script:BoxVertical)" + (" " * 33) + "$($script:BoxVertical)"  # 35 chars
			$line5 = "$($script:BoxVertical)" + (" " * 33) + "$($script:BoxVertical)"  # 35 chars
			
			$dialogLines = @(
				$line0,
				$line1,
				$line2,
				$line3,
				$line4,
				$line5,
				$null,  # Bottom line will be written separately with colors
				"$($script:BoxBottomLeft)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxBottomRight)"  # 35 chars
			)
			
		# Slide-up-from-behind animation: the box rises from behind the separator/menu bar.
		# Each step moves the box 2 rows up and draws only the rows above the separator,
		# so the menu bar acts as a mask and the box appears to emerge from behind it.
		$clipY        = $menuBarY - 1   # separator row — nothing drawn at or below this Y
		$animSteps    = $dialogHeight + 1  # steps to fully reveal the box
		$frameDelayMs = 15  # 15ms per frame — at the Windows timer floor for consistency
		for ($step = 2; $step -le ($animSteps + 1); $step += 2) {
			$s     = [math]::Min($step, $animSteps)
			$animY = $menuBarY - 1 - $s  # top of box this step (rises 2 rows each step)
			for ($r = 0; $r -lt $s -and $r -le $dialogHeight; $r++) {
					$absY = $animY + $r
					if ($absY -ge $clipY) { continue }  # safety: never draw over separator
					# Side padding (terminal default background)
					if ($dialogX -gt 0) {
						Write-Buffer -X ($dialogX - 1) -Y $absY -Text " "
					}
					if (($dialogX + $dialogWidth) -lt $currentHostWidth) {
						Write-Buffer -X ($dialogX + $dialogWidth) -Y $absY -Text " "
					}
					# Background fill
					Write-Buffer -X $dialogX -Y $absY -Text (" " * $dialogWidth) -BG $script:QuitDialogBg
					# Row content
					if ($r -eq 0) {
						Write-Buffer -X $dialogX -Y $absY -Text $line0 -FG $script:QuitDialogBorder -BG $script:QuitDialogBg
					} elseif ($r -eq $dialogHeight) {
						Write-Buffer -X $dialogX -Y $absY -Text $dialogLines[$dialogLines.Count - 1] -FG $script:QuitDialogBorder -BG $script:QuitDialogBg
					} else {
						Write-Buffer -X $dialogX                      -Y $absY -Text $script:BoxVertical -FG $script:QuitDialogBorder -BG $script:QuitDialogBg
						Write-Buffer -X ($dialogX + $dialogWidth - 1) -Y $absY -Text $script:BoxVertical -FG $script:QuitDialogBorder -BG $script:QuitDialogBg
					}
				}
			# On the last step the box is fully revealed; draw the blank top-padding row
			if ($s -eq $animSteps -and $animY -gt 0) {
				$aPadLeft  = [math]::Max(0, $dialogX - 1)
				$aPadWidth = $dialogWidth + ($dialogX - $aPadLeft) + 1
				Write-Buffer -X $aPadLeft -Y ($animY - 1) -Text (" " * $aPadWidth)
			}
			Flush-Buffer
			if ($frameDelayMs -gt 0) { Start-Sleep -Milliseconds $frameDelayMs }
		}

		# Draw blank padding (terminal default background) — top, left, right; no bottom
			if ($dialogY -gt 0) {
				$padLeft  = [math]::Max(0, $dialogX - 1)
				$padWidth = $dialogWidth + ($dialogX - $padLeft) + 1
				Write-Buffer -X $padLeft -Y ($dialogY - 1) -Text (" " * $padWidth)
			}
			for ($i = 0; $i -le $dialogHeight; $i++) {
				if ($dialogX -gt 0) {
					Write-Buffer -X ($dialogX - 1) -Y ($dialogY + $i) -Text " "
				}
				if (($dialogX + $dialogWidth) -lt $currentHostWidth) {
					Write-Buffer -X ($dialogX + $dialogWidth) -Y ($dialogY + $i) -Text " "
				}
			}

			# Draw dialog background (clear area) with magenta background
			for ($i = 0; $i -lt $dialogHeight; $i++) {
				Write-Buffer -X $dialogX -Y ($dialogY + $i) -Text (" " * $dialogWidth) -BG DarkMagenta
			}
			
			# Draw dialog box with themed background
			for ($i = 0; $i -lt $dialogLines.Count; $i++) {
				if ($i -eq 1) {
					# Title line
					Write-Buffer -X $dialogX -Y ($dialogY + $i) -Text "$($script:BoxVertical)  " -FG $script:QuitDialogBorder -BG $script:QuitDialogBg
					Write-Buffer -Text "Confirm Quit" -FG $script:QuitDialogTitle -BG $script:QuitDialogBg
					$titleUsedWidth = 3 + "Confirm Quit".Length  # "$($script:BoxVertical)  " + title
					$titlePadding = Get-Padding -usedWidth ($titleUsedWidth + 1) -totalWidth $dialogWidth
					Write-Buffer -Text (" " * $titlePadding) -BG $script:QuitDialogBg
					Write-Buffer -Text "$($script:BoxVertical)" -FG $script:QuitDialogBorder -BG $script:QuitDialogBg
			} elseif ($i -eq 6) {
			# Bottom line - write with colored icons and hotkey letters
		$btn1X = $dialogX + 2
		$btn2X = $btn1X + $dlgBracketWidth + $dlgIconWidth + 5 + $dlgParenAdj + 2  # bracket + icon + "(y)es"(5) + gap(2)
		Write-Buffer -X $dialogX -Y ($dialogY + $i) -Text "$($script:BoxVertical) " -FG $script:QuitDialogBorder -BG $script:QuitDialogBg
		if ($script:DialogButtonShowBrackets) {
			Write-Buffer -X $btn1X -Y ($dialogY + $i) -Text "[" -FG $script:DialogButtonBracketFg -BG $script:DialogButtonBracketBg
		}
		$btn1ContentX = $btn1X + [int]$script:DialogButtonShowBrackets
		if ($script:DialogButtonShowIcon) {
			Write-Buffer -X $btn1ContentX -Y ($dialogY + $i) -Text $checkmark -FG $script:TextSuccess -BG $script:QuitDialogButtonBg -Wide
			Write-Buffer -X ($btn1ContentX + 2) -Y ($dialogY + $i) -Text $script:DialogButtonSeparator -FG $script:QuitDialogButtonText -BG $script:QuitDialogButtonBg
		} else {
			Write-Buffer -X $btn1ContentX -Y ($dialogY + $i) -Text "" -BG $script:QuitDialogButtonBg
		}
		if ($script:DialogButtonShowHotkeyParens) { Write-Buffer -Text "(" -FG $script:QuitDialogButtonText -BG $script:QuitDialogButtonBg }
		Write-Buffer -Text "y" -FG $script:QuitDialogButtonHotkey -BG $script:QuitDialogButtonBg
		$_rp = if ($script:DialogButtonShowHotkeyParens) { ")" } else { "" }
		Write-Buffer -Text "${_rp}es" -FG $script:QuitDialogButtonText -BG $script:QuitDialogButtonBg
		if ($script:DialogButtonShowBrackets) { Write-Buffer -Text "]" -FG $script:DialogButtonBracketFg -BG $script:DialogButtonBracketBg }
		Write-Buffer -Text "  " -BG $script:QuitDialogBg
		if ($script:DialogButtonShowBrackets) {
			Write-Buffer -X $btn2X -Y ($dialogY + $i) -Text "[" -FG $script:DialogButtonBracketFg -BG $script:DialogButtonBracketBg
		}
		$btn2ContentX = $btn2X + [int]$script:DialogButtonShowBrackets
		if ($script:DialogButtonShowIcon) {
			Write-Buffer -X $btn2ContentX -Y ($dialogY + $i) -Text $redX -FG $script:TextError -BG $script:QuitDialogButtonBg -Wide
			Write-Buffer -X ($btn2ContentX + 2) -Y ($dialogY + $i) -Text $script:DialogButtonSeparator -FG $script:QuitDialogButtonText -BG $script:QuitDialogButtonBg
		} else {
			Write-Buffer -X $btn2ContentX -Y ($dialogY + $i) -Text "" -BG $script:QuitDialogButtonBg
		}
		if ($script:DialogButtonShowHotkeyParens) { Write-Buffer -Text "(" -FG $script:QuitDialogButtonText -BG $script:QuitDialogButtonBg }
		Write-Buffer -Text "n" -FG $script:QuitDialogButtonHotkey -BG $script:QuitDialogButtonBg
		Write-Buffer -Text "${_rp}o" -FG $script:QuitDialogButtonText -BG $script:QuitDialogButtonBg
		if ($script:DialogButtonShowBrackets) { Write-Buffer -Text "]" -FG $script:DialogButtonBracketFg -BG $script:DialogButtonBracketBg }
		Write-Buffer -Text (" " * $bottomLinePadding) -BG $script:QuitDialogBg
		Write-Buffer -Text "$($script:BoxVertical)" -FG $script:QuitDialogBorder -BG $script:QuitDialogBg
	} else {
		Write-Buffer -X $dialogX -Y ($dialogY + $i) -Text $dialogLines[$i] -FG $script:QuitDialogText -BG $script:QuitDialogBg
	}
}

Flush-Buffer

# Calculate button bounds for click detection (visible characters only)
# Button row is at dialogY + 6
$buttonRowY = $dialogY + 6
$yesButtonStartX = $dialogX + 2
$yesButtonEndX   = $dialogX + 2 + $dlgBracketWidth + $dlgIconWidth + 5 + $dlgParenAdj - 1   # bracket + icon + "(y)es"(5) - 1 inclusive
$noButtonStartX  = $dialogX + 2 + $dlgBracketWidth + $dlgIconWidth + 5 + $dlgParenAdj + 2   # after btn1 + gap(2)
$noButtonEndX    = $noButtonStartX + $dlgBracketWidth + $dlgIconWidth + 4 + $dlgParenAdj - 1 # bracket + icon + "(n)o"(4) - 1 inclusive
			
			$script:DialogButtonBounds = @{
				buttonRowY = $buttonRowY
				updateStartX = $yesButtonStartX
				updateEndX = $yesButtonEndX
				cancelStartX = $noButtonStartX
				cancelEndX = $noButtonEndX
			}
			$script:DialogButtonClick = $null
			
			# Get input
			$result = $null
			$needsRedraw = $false
			
			:inputLoop do {
				# Check for window resize and update references
				$pshost = Get-Host
				$pswindow = $pshost.UI.RawUI
				$newWindowSize = $pswindow.WindowSize
				if ($newWindowSize.Width -ne $currentHostWidth -or $newWindowSize.Height -ne $currentHostHeight) {
					# Window was resized - update references and flag for main UI redraw
					# Don't force buffer size - let PowerShell manage it (allows text zoom to work)
					$HostWidthRef.Value = $newWindowSize.Width
					$HostHeightRef.Value = $newWindowSize.Height
					$currentHostWidth = $newWindowSize.Width
					$currentHostHeight = $newWindowSize.Height
					$needsRedraw = $true
					
				# Reposition dialog: right-aligned, one row above the separator
				$dialogX = [math]::Max(0, $currentHostWidth - $dialogWidth - 2)
				$menuBarY = if ($null -ne $script:MenuBarY) { $script:MenuBarY } else { $currentHostHeight - 2 }
				$dialogY = [math]::Max(0, $menuBarY - 2 - $dialogHeight)

				# Redraw blank padding (terminal default background) — top, left, right; no bottom
				if ($dialogY -gt 0) {
					$padLeft  = [math]::Max(0, $dialogX - 1)
					$padWidth = $dialogWidth + ($dialogX - $padLeft) + 1
					Write-Buffer -X $padLeft -Y ($dialogY - 1) -Text (" " * $padWidth)
				}
				for ($i = 0; $i -le $dialogHeight; $i++) {
					if ($dialogX -gt 0) {
						Write-Buffer -X ($dialogX - 1) -Y ($dialogY + $i) -Text " "
					}
					if (($dialogX + $dialogWidth) -lt $currentHostWidth) {
						Write-Buffer -X ($dialogX + $dialogWidth) -Y ($dialogY + $i) -Text " "
					}
				}

				for ($i = 0; $i -lt $dialogLines.Count; $i++) {
						if ($i -eq 1) {
							# Title line
							Write-Buffer -X $dialogX -Y ($dialogY + $i) -Text "$($script:BoxVertical)  " -FG $script:QuitDialogBorder -BG $script:QuitDialogBg
							Write-Buffer -Text "Confirm Quit" -FG $script:QuitDialogTitle -BG $script:QuitDialogBg
							$titleUsedWidth = 3 + "Confirm Quit".Length  # "$($script:BoxVertical)  " + title
							$titlePadding = Get-Padding -usedWidth ($titleUsedWidth + 1) -totalWidth $dialogWidth
							Write-Buffer -Text (" " * $titlePadding) -BG $script:QuitDialogBg
							Write-Buffer -Text "$($script:BoxVertical)" -FG $script:QuitDialogBorder -BG $script:QuitDialogBg
					} elseif ($i -eq 6) {
					# Bottom line - write with colored icons and hotkey letters
				$btn1X = $dialogX + 2
				$btn2X = $btn1X + $dlgBracketWidth + $dlgIconWidth + 5 + $dlgParenAdj + 2  # bracket + icon + "(y)es"(5) + gap(2)
				Write-Buffer -X $dialogX -Y ($dialogY + $i) -Text "$($script:BoxVertical) " -FG $script:QuitDialogBorder -BG $script:QuitDialogBg
				if ($script:DialogButtonShowBrackets) {
					Write-Buffer -X $btn1X -Y ($dialogY + $i) -Text "[" -FG $script:DialogButtonBracketFg -BG $script:DialogButtonBracketBg
				}
				$btn1ContentX = $btn1X + [int]$script:DialogButtonShowBrackets
				if ($script:DialogButtonShowIcon) {
					Write-Buffer -X $btn1ContentX -Y ($dialogY + $i) -Text $checkmark -FG $script:TextSuccess -BG $script:QuitDialogButtonBg -Wide
					Write-Buffer -X ($btn1ContentX + 2) -Y ($dialogY + $i) -Text $script:DialogButtonSeparator -FG $script:QuitDialogButtonText -BG $script:QuitDialogButtonBg
				} else {
					Write-Buffer -X $btn1ContentX -Y ($dialogY + $i) -Text "" -BG $script:QuitDialogButtonBg
				}
				if ($script:DialogButtonShowHotkeyParens) { Write-Buffer -Text "(" -FG $script:QuitDialogButtonText -BG $script:QuitDialogButtonBg }
				Write-Buffer -Text "y" -FG $script:QuitDialogButtonHotkey -BG $script:QuitDialogButtonBg
				$_rp = if ($script:DialogButtonShowHotkeyParens) { ")" } else { "" }
				Write-Buffer -Text "${_rp}es" -FG $script:QuitDialogButtonText -BG $script:QuitDialogButtonBg
				if ($script:DialogButtonShowBrackets) { Write-Buffer -Text "]" -FG $script:DialogButtonBracketFg -BG $script:DialogButtonBracketBg }
				Write-Buffer -Text "  " -BG $script:QuitDialogBg
				if ($script:DialogButtonShowBrackets) {
					Write-Buffer -X $btn2X -Y ($dialogY + $i) -Text "[" -FG $script:DialogButtonBracketFg -BG $script:DialogButtonBracketBg
				}
				$btn2ContentX = $btn2X + [int]$script:DialogButtonShowBrackets
				if ($script:DialogButtonShowIcon) {
					Write-Buffer -X $btn2ContentX -Y ($dialogY + $i) -Text $redX -FG $script:TextError -BG $script:QuitDialogButtonBg -Wide
					Write-Buffer -X ($btn2ContentX + 2) -Y ($dialogY + $i) -Text $script:DialogButtonSeparator -FG $script:QuitDialogButtonText -BG $script:QuitDialogButtonBg
				} else {
					Write-Buffer -X $btn2ContentX -Y ($dialogY + $i) -Text "" -BG $script:QuitDialogButtonBg
				}
				if ($script:DialogButtonShowHotkeyParens) { Write-Buffer -Text "(" -FG $script:QuitDialogButtonText -BG $script:QuitDialogButtonBg }
				Write-Buffer -Text "n" -FG $script:QuitDialogButtonHotkey -BG $script:QuitDialogButtonBg
				Write-Buffer -Text "${_rp}o" -FG $script:QuitDialogButtonText -BG $script:QuitDialogButtonBg
				if ($script:DialogButtonShowBrackets) { Write-Buffer -Text "]" -FG $script:DialogButtonBracketFg -BG $script:DialogButtonBracketBg }
				Write-Buffer -Text (" " * $bottomLinePadding) -BG $script:QuitDialogBg
				Write-Buffer -Text "$($script:BoxVertical)" -FG $script:QuitDialogBorder -BG $script:QuitDialogBg
			} else {
				Write-Buffer -X $dialogX -Y ($dialogY + $i) -Text $dialogLines[$i] -FG $script:QuitDialogText -BG $script:QuitDialogBg
			}
		}
		
		Flush-Buffer -ClearFirst
		
		$buttonRowY = $dialogY + 6
		$yesButtonStartX = $dialogX + 2
		$yesButtonEndX   = $dialogX + 2 + $dlgBracketWidth + $dlgIconWidth + 5 + $dlgParenAdj - 1
		$noButtonStartX  = $dialogX + 2 + $dlgBracketWidth + $dlgIconWidth + 5 + $dlgParenAdj + 2
		$noButtonEndX    = $noButtonStartX + $dlgBracketWidth + $dlgIconWidth + 4 + $dlgParenAdj - 1
					
					$script:DialogButtonBounds = @{
						buttonRowY = $buttonRowY
						updateStartX = $yesButtonStartX
						updateEndX = $yesButtonEndX
						cancelStartX = $noButtonStartX
						cancelEndX = $noButtonEndX
					}
				}
				
				# Check for mouse button clicks on dialog buttons via console input buffer
				$keyProcessed = $false
				$keyInfo = $null
				$key = $null
				$char = $null
				
				try {
					$peekBuf = New-Object 'mJiggAPI.INPUT_RECORD[]' 16
					$peekEvts = [uint32]0
					$hIn = [mJiggAPI.Mouse]::GetStdHandle(-10)
					if ([mJiggAPI.Mouse]::PeekConsoleInput($hIn, $peekBuf, 16, [ref]$peekEvts) -and $peekEvts -gt 0) {
						$lastClickIdx = -1
						$clickX = -1; $clickY = -1
						for ($e = 0; $e -lt $peekEvts; $e++) {
							if ($peekBuf[$e].EventType -eq 0x0002 -and $peekBuf[$e].MouseEvent.dwEventFlags -eq 0 -and ($peekBuf[$e].MouseEvent.dwButtonState -band 0x0001) -ne 0) {
								$clickX = $peekBuf[$e].MouseEvent.dwMousePosition.X
								$clickY = $peekBuf[$e].MouseEvent.dwMousePosition.Y
								$lastClickIdx = $e
							}
						}
						if ($lastClickIdx -ge 0) {
							$consumeCount = [uint32]($lastClickIdx + 1)
							$flushBuf = New-Object 'mJiggAPI.INPUT_RECORD[]' $consumeCount
							$flushed = [uint32]0
							[mJiggAPI.Mouse]::ReadConsoleInput($hIn, $flushBuf, $consumeCount, [ref]$flushed) | Out-Null
							
						# Click outside dialog bounds → cancel
						if ($clickX -lt $dialogX -or $clickX -ge ($dialogX + $dialogWidth) -or $clickY -lt $dialogY -or $clickY -gt ($dialogY + $dialogHeight)) {
							$char = "n"; $keyProcessed = $true
						} elseif ($clickY -eq $buttonRowY -and $clickX -ge $yesButtonStartX -and $clickX -le $yesButtonEndX) {
							$char = "y"; $keyProcessed = $true
						} elseif ($clickY -eq $buttonRowY -and $clickX -ge $noButtonStartX -and $clickX -le $noButtonEndX) {
							$char = "n"; $keyProcessed = $true
						}
						if ($DebugMode) {
								$clickTarget = if ($keyProcessed) { "button:$char" } else { "none" }
								if ($null -eq $LogArray -or -not ($LogArray -is [Array])) { $LogArray = @() }
								$LogArray += [PSCustomObject]@{
									logRow = $true
									components = @(
										@{ priority = 1; text = (Get-Date).ToString("HH:mm:ss"); shortText = (Get-Date).ToString("HH:mm:ss") },
										@{ priority = 2; text = " - [DEBUG] Quit dialog click at ($clickX,$clickY), target: $clickTarget"; shortText = " - [DEBUG] Click ($clickX,$clickY) -> $clickTarget" }
									)
								}
							}
						}
					}
				} catch { }
				
				# Check for dialog button clicks detected by main loop
				if (-not $keyProcessed -and $null -ne $script:DialogButtonClick) {
					$buttonClick = $script:DialogButtonClick
					$script:DialogButtonClick = $null
					if ($buttonClick -eq "Update") { $char = "y"; $keyProcessed = $true }
					elseif ($buttonClick -eq "Cancel") { $char = "n"; $keyProcessed = $true }
				}
				
				# Wait for key input (non-blocking check)
				if (-not $keyProcessed) {
					while ($Host.UI.RawUI.KeyAvailable -and -not $keyProcessed) {
						$keyInfo = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyup,AllowCtrlC")
						$isKeyDown = $false
						if ($null -ne $keyInfo.KeyDown) {
							$isKeyDown = $keyInfo.KeyDown
						}
						
						# Only process key UP events (skip key down)
						if (-not $isKeyDown) {
							$key = $keyInfo.Key
							$char = $keyInfo.Character
							$keyProcessed = $true
						}
					}
				}
				
				if (-not $keyProcessed) {
					# No key available, sleep briefly and check for resize again
					Start-Sleep -Milliseconds 50
					continue
				}
				
				if ($char -eq "y" -or $char -eq "Y" -or $key -eq "Enter" -or $char -eq [char]13 -or $char -eq [char]10) {
					# Yes - confirm quit (Enter key also works as hidden function)
					# Debug: Log quit confirmation
					if ($DebugMode) {
						if ($null -eq $LogArray -or -not ($LogArray -is [Array])) {
							$LogArray = @()
						}
						$LogArray += [PSCustomObject]@{
							logRow = $true
							components = @(
								@{
									priority = 1
									text = (Get-Date).ToString("HH:mm:ss")
									shortText = (Get-Date).ToString("HH:mm:ss")
								},
								@{
									priority = 2
									text = " - [DEBUG] Quit dialog: Confirmed"
									shortText = " - [DEBUG] Quit: Yes"
								}
							)
						}
					}
					$result = $true
					break
				} elseif ($char -eq "n" -or $char -eq "N" -or $char -eq "q" -or $char -eq "Q" -or $key -eq "Escape" -or ($null -ne $keyInfo -and $keyInfo.VirtualKeyCode -eq 27)) {
					# No - cancel quit (Escape key and 'q' key also work as hidden functions)
					# Debug: Log quit cancellation
					if ($DebugMode) {
						if ($null -eq $LogArray -or -not ($LogArray -is [Array])) {
							$LogArray = @()
						}
						$LogArray += [PSCustomObject]@{
							logRow = $true
							components = @(
								@{
									priority = 1
									text = (Get-Date).ToString("HH:mm:ss")
									shortText = (Get-Date).ToString("HH:mm:ss")
								},
								@{
									priority = 2
									text = " - [DEBUG] Quit dialog: Canceled"
									shortText = " - [DEBUG] Quit: No"
								}
							)
						}
					}
					$result = $false
					$needsRedraw = $false  # No redraw needed on cancel
					break
				}
				
				# Clear any remaining keys in buffer after processing
				try {
					while ($Host.UI.RawUI.KeyAvailable) {
						$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown,AllowCtrlC")
					}
				} catch {
					# Silently ignore - buffer might not be clearable
				}
			} until ($false)
			
			# Clear shadow before clearing dialog area
			Clear-DialogShadow -dialogX $dialogX -dialogY $dialogY -dialogWidth $dialogWidth -dialogHeight $dialogHeight
			
			# Clear dialog area
			for ($i = 0; $i -lt $dialogHeight; $i++) {
				Write-Buffer -X $dialogX -Y ($dialogY + $i) -Text (" " * $dialogWidth)
			}
			Flush-Buffer
			
			$script:CursorVisible = $savedCursorVisible
			if ($script:CursorVisible) { [Console]::Write("$($script:ESC)[?25h") } else { [Console]::Write("$($script:ESC)[?25l") }
			
			$script:DialogButtonBounds = $null
			$script:DialogButtonClick = $null
			
			# Return result object with result and redraw flag
			return @{
				Result = $result
				NeedsRedraw = $needsRedraw
			}
		}

	# Settings mini-dialog — slides up above the Settings menu button.
	# Handles sub-dialogs internally so it stays visible while they are open,
	# shifting to offfocus colors while the sub-dialog is active and back to
	# onfocus once it closes.  Clicking the settings button while open closes it.
	# Returns @{NeedsRedraw = $bool}.
	function Show-SettingsDialog {
		param(
			[ref]$HostWidthRef,
			[ref]$HostHeightRef,
			[ref]$EndTimeIntRef,    # $endTimeInt in the main loop
			[ref]$EndTimeStrRef,    # $endTimeStr
			[ref]$EndRef,           # $end
			[ref]$LogArrayRef,      # $LogArray
			[bool]$SkipAnimation = $false
		)

		$currentHostWidth  = $HostWidthRef.Value
		$currentHostHeight = $HostHeightRef.Value

	$dialogWidth  = 26
	# Layout (13 rows, indices 0-12):
	#  0: top border   1: title   2: divider   3: blank
	#  4: [⏳|end_(t)ime]  5: blank   6: [🖱|(m)ouse_movement]  7: blank
	#  8: [💻|(o)utput: Full/Min] (inline toggle)   9: blank
	#  10: [🐛|(d)ebug: On/Off]  (inline checkbox)  11: blank  12: bottom border
	$dialogHeight = 12

		# Left-aligned above the settings button; clamp so dialog fits on screen
		$settingsBtnX = if ($null -ne $script:SettingsButtonStartX) { $script:SettingsButtonStartX } else { 0 }
		$dialogX      = [math]::Max(0, [math]::Min($settingsBtnX, $currentHostWidth - $dialogWidth))
		$menuBarY     = if ($null -ne $script:MenuBarY) { $script:MenuBarY } else { $currentHostHeight - 2 }
		$dialogY      = [math]::Max(0, $menuBarY - 2 - $dialogHeight)

		$savedCursorVisible = $script:CursorVisible
		$script:CursorVisible = $false
		[Console]::Write("$($script:ESC)[?25l")

		# Icon emojis used in buttons
	$emojiHourglass = [char]::ConvertFromUtf32(0x23F3)  # ⏳
	$emojiMouse     = [char]::ConvertFromUtf32(0x1F5B1) # 🖱
		$emojiScreen    = [char]::ConvertFromUtf32(0x1F4BB) # 💻
		$emojiDebug     = [char]::ConvertFromUtf32(0x1F50D) # 🔍

		# Button width / position helper — dot-source to populate current scope
		$calcButtonVars = {
			$dlgIconWidth    = if ($script:DialogButtonShowIcon)         { 2 + $script:DialogButtonSeparator.Length } else { 0 }
			$dlgBracketWidth = if ($script:DialogButtonShowBrackets)     { 2 } else { 0 }
			$dlgParenAdj     = if ($script:DialogButtonShowHotkeyParens) { 0 } else { -2 }
		# Per-button right padding: dialogWidth - border(1) - space(1) - btnChars - border(1)
		# "end_(t)ime"=10, "(m)ouse_movement"=16; output/debug pads are computed dynamically in render
		$timePad  = $dialogWidth - (2 + $dlgBracketWidth + $dlgIconWidth + 10 + $dlgParenAdj + 1)
		$movePad  = $dialogWidth - (2 + $dlgBracketWidth + $dlgIconWidth + 16 + $dlgParenAdj + 1)
		$timeButtonStartX  = $dialogX + 2
		$timeButtonEndX    = $dialogX + 2 + $dlgBracketWidth + $dlgIconWidth + 10 + $dlgParenAdj - 1
		$moveButtonStartX  = $dialogX + 2
		$moveButtonEndX    = $dialogX + 2 + $dlgBracketWidth + $dlgIconWidth + 16 + $dlgParenAdj - 1
			# Output/debug rows: full inner-row clickable area
			$outputButtonStartX = $dialogX + 1
			$outputButtonEndX   = $dialogX + $dialogWidth - 2
			$debugButtonStartX  = $dialogX + 1
			$debugButtonEndX    = $dialogX + $dialogWidth - 2
		}
		. $calcButtonVars

		# Build static line strings (used by animation + full render)
		$hLine      = [string]$script:BoxHorizontal
		$inner      = $dialogWidth - 2  # 33
		$line0      = $script:BoxTopLeft    + ($hLine * $inner) + $script:BoxTopRight
		$line2      = $script:BoxVerticalRight + ($hLine * $inner) + $script:BoxVerticalLeft
		$lineBlank  = $script:BoxVertical   + (" "   * $inner) + $script:BoxVertical
		$lineBottom = $script:BoxBottomLeft + ($hLine * $inner) + $script:BoxBottomRight
		# indices 0-12; rows 4, 6, 8, 10 are $null — drawn as inline toggle rows
		$dialogLines = @($line0, $null, $line2, $lineBlank, $null, $lineBlank, $null, $lineBlank, $null, $lineBlank, $null, $lineBlank, $lineBottom)

	# ── Slide-up-from-behind animation (skipped on reopen after sub-dialog) ──
	if (-not $SkipAnimation) {
		$clipY        = $menuBarY - 1
		$animSteps    = $dialogHeight + 1
		$frameDelayMs = 15
		for ($step = 2; $step -le ($animSteps + 1); $step += 2) {
			$s     = [math]::Min($step, $animSteps)
			$animY = $menuBarY - 1 - $s
			for ($r = 0; $r -lt $s -and $r -le $dialogHeight; $r++) {
				$absY = $animY + $r
				if ($absY -ge $clipY) { continue }
				if ($dialogX -gt 0) { Write-Buffer -X ($dialogX - 1) -Y $absY -Text " " }
				if (($dialogX + $dialogWidth) -lt $currentHostWidth) { Write-Buffer -X ($dialogX + $dialogWidth) -Y $absY -Text " " }
				Write-Buffer -X $dialogX -Y $absY -Text (" " * $dialogWidth) -BG $script:SettingsDialogBg
				if ($r -eq 0) {
					Write-Buffer -X $dialogX -Y $absY -Text $line0 -FG $script:SettingsDialogBorder -BG $script:SettingsDialogBg
				} elseif ($r -eq $dialogHeight) {
					Write-Buffer -X $dialogX -Y $absY -Text $lineBottom -FG $script:SettingsDialogBorder -BG $script:SettingsDialogBg
				} else {
					Write-Buffer -X $dialogX                      -Y $absY -Text $script:BoxVertical -FG $script:SettingsDialogBorder -BG $script:SettingsDialogBg
					Write-Buffer -X ($dialogX + $dialogWidth - 1) -Y $absY -Text $script:BoxVertical -FG $script:SettingsDialogBorder -BG $script:SettingsDialogBg
				}
			}
			if ($s -eq $animSteps -and $animY -gt 0) {
				$aPadLeft  = [math]::Max(0, $dialogX - 1)
				$aPadWidth = $dialogWidth + ($dialogX - $aPadLeft) + 1
				Write-Buffer -X $aPadLeft -Y ($animY - 1) -Text (" " * $aPadWidth)
			}
			Flush-Buffer
			if ($frameDelayMs -gt 0) { Start-Sleep -Milliseconds $frameDelayMs }
		}
	}

		# ── Blank padding (terminal default BG) — top, left, right; no bottom ──
		if ($dialogY -gt 0) {
			$padLeft  = [math]::Max(0, $dialogX - 1)
			$padWidth = $dialogWidth + ($dialogX - $padLeft) + 1
			Write-Buffer -X $padLeft -Y ($dialogY - 1) -Text (" " * $padWidth)
		}
		for ($i = 0; $i -le $dialogHeight; $i++) {
			if ($dialogX -gt 0) { Write-Buffer -X ($dialogX - 1) -Y ($dialogY + $i) -Text " " }
			if (($dialogX + $dialogWidth) -lt $currentHostWidth) { Write-Buffer -X ($dialogX + $dialogWidth) -Y ($dialogY + $i) -Text " " }
		}

		# ── Render helper: one button row ─────────────────────────────────────────
		# Reads $cBg/$cBorder/$cBtnBg/$cBtnText/$cBtnHotkey set by $drawSettingsDialog
		$drawSettingsBtnRow = {
			param($dx, $absRowY, $emoji, $hotkeyChar, $labelSuffix, $rowPad, $labelPrefix = "")
			$bX = $dx + 2
			Write-Buffer -X $dx -Y $absRowY -Text "$($script:BoxVertical) " -FG $cBorder -BG $cBg
			if ($script:DialogButtonShowBrackets) { Write-Buffer -X $bX -Y $absRowY -Text "[" -FG $script:DialogButtonBracketFg -BG $script:DialogButtonBracketBg }
			$bCX = $bX + [int]$script:DialogButtonShowBrackets
			if ($script:DialogButtonShowIcon) {
				Write-Buffer -X $bCX -Y $absRowY -Text $emoji -BG $cBtnBg -Wide
				Write-Buffer -X ($bCX + 2) -Y $absRowY -Text $script:DialogButtonSeparator -FG $cBtnText -BG $cBtnBg
			} else {
				Write-Buffer -X $bCX -Y $absRowY -Text "" -BG $cBtnBg
			}
			if ($labelPrefix.Length -gt 0) { Write-Buffer -Text $labelPrefix -FG $cBtnText -BG $cBtnBg }
			$_rp = if ($script:DialogButtonShowHotkeyParens) { ")" } else { "" }
			if ($script:DialogButtonShowHotkeyParens) { Write-Buffer -Text "(" -FG $cBtnText -BG $cBtnBg }
			Write-Buffer -Text $hotkeyChar -FG $cBtnHotkey -BG $cBtnBg
			Write-Buffer -Text "${_rp}${labelSuffix}" -FG $cBtnText -BG $cBtnBg
			if ($script:DialogButtonShowBrackets) { Write-Buffer -Text "]" -FG $script:DialogButtonBracketFg -BG $script:DialogButtonBracketBg }
			Write-Buffer -Text (" " * $rowPad) -BG $cBg
			Write-Buffer -Text $script:BoxVertical -FG $cBorder -BG $cBg
		}

		# ── Render helper: full dialog — $focused selects onfocus vs offfocus ─────
		$drawSettingsDialog = {
			param($dx, $dy, [bool]$focused = $true)
			# Resolve color set for this draw
			$cBg        = if ($focused) { $script:SettingsDialogBg }                  else { $script:SettingsDialogOffFocusBg }
			$cBorder    = if ($focused) { $script:SettingsDialogBorder }               else { $script:SettingsDialogOffFocusBorder }
			$cTitle     = if ($focused) { $script:SettingsDialogTitle }                else { $script:SettingsDialogOffFocusTitle }
			$cText      = if ($focused) { $script:SettingsDialogText }                 else { $script:SettingsDialogOffFocusText }
			$cBtnBg     = if ($focused) { $script:SettingsDialogButtonBg }             else { $script:SettingsDialogOffFocusButtonBg }
			$cBtnText   = if ($focused) { $script:SettingsDialogButtonText }           else { $script:SettingsDialogOffFocusButtonText }
			$cBtnHotkey = if ($focused) { $script:SettingsDialogButtonHotkey }         else { $script:SettingsDialogOffFocusButtonHotkey }
			for ($i = 0; $i -le $dialogHeight; $i++) {
				$absY = $dy + $i
				Write-Buffer -X $dx -Y $absY -Text (" " * $dialogWidth) -BG $cBg
				if ($i -eq 1) {
					# Title row
					Write-Buffer -X $dx -Y $absY -Text "$($script:BoxVertical)  " -FG $cBorder -BG $cBg
					Write-Buffer -Text "Settings" -FG $cTitle -BG $cBg
					$tPad = Get-Padding -usedWidth (3 + "Settings".Length + 1) -totalWidth $dialogWidth
					Write-Buffer -Text (" " * $tPad) -BG $cBg
					Write-Buffer -Text $script:BoxVertical -FG $cBorder -BG $cBg
			} elseif ($i -eq 4) {
		& $drawSettingsBtnRow $dx $absY $emojiHourglass "t" "ime" $timePad "end_"
		} elseif ($i -eq 6) {
			& $drawSettingsBtnRow $dx $absY $emojiMouse "m" "ouse_movement" $movePad
			} elseif ($i -eq 8) {
				# Output inline toggle — shows current mode
				$_outName   = if ($script:Output -eq "full") { "Full" } else { "Min " }
				$_outSuffix = "utput: $_outName"
				$_outPad    = $dialogWidth - (2 + $dlgBracketWidth + $dlgIconWidth + 3 + $_outSuffix.Length + $dlgParenAdj + 1)
				& $drawSettingsBtnRow $dx $absY $emojiScreen "o" $_outSuffix ([math]::Max(0, $_outPad))
			} elseif ($i -eq 10) {
				# Debug inline checkbox — shows current state
				$_dbgSuffix = if ($script:DebugMode) { "ebug: On " } else { "ebug: Off" }
				$_dbgPad    = $dialogWidth - (2 + $dlgBracketWidth + $dlgIconWidth + 3 + $_dbgSuffix.Length + $dlgParenAdj + 1)
				& $drawSettingsBtnRow $dx $absY $emojiDebug "d" $_dbgSuffix ([math]::Max(0, $_dbgPad))
			} elseif ($i -eq $dialogHeight) {
					Write-Buffer -X $dx -Y $absY -Text $lineBottom -FG $cBorder -BG $cBg
				} elseif ($null -ne $dialogLines[$i]) {
					Write-Buffer -X $dx -Y $absY -Text $dialogLines[$i] -FG $cText -BG $cBg
				}
			}
		}

		& $drawSettingsDialog $dialogX $dialogY $true
		Flush-Buffer

	# ── Button row Y coordinates ───────────────────────────────────────────────
	$timeButtonRowY   = $dialogY + 4
	$moveButtonRowY   = $dialogY + 6
	$outputButtonRowY = $dialogY + 8
	$debugButtonRowY  = $dialogY + 10

	$script:DialogButtonBounds = @{
		buttonRowY   = $timeButtonRowY
		updateStartX = $timeButtonStartX
		updateEndX   = $timeButtonEndX
		cancelStartX = $moveButtonStartX
		cancelEndX   = $moveButtonEndX
	}
		$script:DialogButtonClick = $null

		$needsRedraw     = $false  # set true whenever a sub-dialog makes changes
		$settingsReopen  = $false  # set true to break and re-open after full screen clear

		:settingsLoop do {
			# ── Resize check ───────────────────────────────────────────────────────
			$pshost        = Get-Host
			$pswindow      = $pshost.UI.RawUI
			$newWindowSize = $pswindow.WindowSize
			if ($newWindowSize.Width -ne $currentHostWidth -or $newWindowSize.Height -ne $currentHostHeight) {
				$HostWidthRef.Value  = $newWindowSize.Width
				$HostHeightRef.Value = $newWindowSize.Height
				$currentHostWidth    = $newWindowSize.Width
				$currentHostHeight   = $newWindowSize.Height

				$settingsBtnX = if ($null -ne $script:SettingsButtonStartX) { $script:SettingsButtonStartX } else { 0 }
				$dialogX      = [math]::Max(0, [math]::Min($settingsBtnX, $currentHostWidth - $dialogWidth))
				$menuBarY     = if ($null -ne $script:MenuBarY) { $script:MenuBarY } else { $currentHostHeight - 2 }
				$dialogY      = [math]::Max(0, $menuBarY - 2 - $dialogHeight)
				. $calcButtonVars

				& $drawSettingsDialog $dialogX $dialogY $true
				Flush-Buffer -ClearFirst

		$timeButtonRowY   = $dialogY + 4
		$moveButtonRowY   = $dialogY + 6
		$outputButtonRowY = $dialogY + 8
		$debugButtonRowY  = $dialogY + 10
		$script:DialogButtonBounds = @{
			buttonRowY   = $timeButtonRowY
			updateStartX = $timeButtonStartX
			updateEndX   = $timeButtonEndX
			cancelStartX = $moveButtonStartX
			cancelEndX   = $moveButtonEndX
		}
		}

			# ── Mouse input ────────────────────────────────────────────────────────
			$keyProcessed = $false
			$char = $null; $key = $null; $keyInfo = $null

			try {
				$peekBuf  = New-Object 'mJiggAPI.INPUT_RECORD[]' 16
				$peekEvts = [uint32]0
				$hIn = [mJiggAPI.Mouse]::GetStdHandle(-10)
				if ([mJiggAPI.Mouse]::PeekConsoleInput($hIn, $peekBuf, 16, [ref]$peekEvts) -and $peekEvts -gt 0) {
					$lastClickIdx = -1; $clickX = -1; $clickY = -1
					for ($e = 0; $e -lt $peekEvts; $e++) {
						if ($peekBuf[$e].EventType -eq 0x0002 -and $peekBuf[$e].MouseEvent.dwEventFlags -eq 0 -and ($peekBuf[$e].MouseEvent.dwButtonState -band 0x0001) -ne 0) {
							$clickX = $peekBuf[$e].MouseEvent.dwMousePosition.X
							$clickY = $peekBuf[$e].MouseEvent.dwMousePosition.Y
							$lastClickIdx = $e
						}
					}
					if ($lastClickIdx -ge 0) {
						$consumeCount = [uint32]($lastClickIdx + 1)
						$flushBuf = New-Object 'mJiggAPI.INPUT_RECORD[]' $consumeCount
						$flushed  = [uint32]0
						[mJiggAPI.Mouse]::ReadConsoleInput($hIn, $flushBuf, $consumeCount, [ref]$flushed) | Out-Null
					# Click outside dialog bounds → close
				if ($clickX -lt $dialogX -or $clickX -ge ($dialogX + $dialogWidth) -or $clickY -lt $dialogY -or $clickY -gt ($dialogY + $dialogHeight)) {
					$char = "s"; $keyProcessed = $true
			} elseif ($clickY -eq $timeButtonRowY -and $clickX -ge $timeButtonStartX -and $clickX -le $timeButtonEndX) {
				$char = "t"; $keyProcessed = $true
				} elseif ($clickY -eq $moveButtonRowY -and $clickX -ge $moveButtonStartX -and $clickX -le $moveButtonEndX) {
					$char = "m"; $keyProcessed = $true
				} elseif ($clickY -eq $outputButtonRowY -and $clickX -ge $outputButtonStartX -and $clickX -le $outputButtonEndX) {
					$char = "o"; $keyProcessed = $true
				} elseif ($clickY -eq $debugButtonRowY -and $clickX -ge $debugButtonStartX -and $clickX -le $debugButtonEndX) {
					$char = "d"; $keyProcessed = $true
				}
				}
				}
			} catch { }

			if (-not $keyProcessed -and $null -ne $script:DialogButtonClick) {
				$buttonClick = $script:DialogButtonClick
				$script:DialogButtonClick = $null
				if ($buttonClick -eq "Update") { $char = "t"; $keyProcessed = $true }
				elseif ($buttonClick -eq "Cancel") { $char = "m"; $keyProcessed = $true }
			}

			if (-not $keyProcessed) {
				while ($Host.UI.RawUI.KeyAvailable -and -not $keyProcessed) {
					$keyInfo = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyup,AllowCtrlC")
					$isKeyDown = $false
					if ($null -ne $keyInfo.KeyDown) { $isKeyDown = $keyInfo.KeyDown }
					if (-not $isKeyDown) { $key = $keyInfo.Key; $char = $keyInfo.Character; $keyProcessed = $true }
				}
			}

			if (-not $keyProcessed) { Start-Sleep -Milliseconds 50; continue }

			# ── Dispatch ───────────────────────────────────────────────────────────
		if ($char -eq "t" -or $char -eq "T") {
			# ── Go offfocus while time dialog is open ──────────────────────────
				& $drawSettingsDialog $dialogX $dialogY $false
				Flush-Buffer
				$script:DialogButtonBounds = $null  # prevent outer loop interference

				$subHostWidthRef  = [ref]$currentHostWidth
				$subHostHeightRef = [ref]$currentHostHeight
				$timeResult = Show-TimeChangeDialog -currentEndTime $EndTimeIntRef.Value -hostWidthRef $subHostWidthRef -hostHeightRef $subHostHeightRef
				$currentHostWidth  = $subHostWidthRef.Value
				$currentHostHeight = $subHostHeightRef.Value
				$HostWidthRef.Value  = $currentHostWidth
				$HostHeightRef.Value = $currentHostHeight

				# Apply time result
				if ($null -ne $timeResult.Result) {
					$needsRedraw = $true
					if ($timeResult.Result -eq -1) {
						$oldStr = $EndTimeStrRef.Value
						$EndTimeIntRef.Value = -1; $EndTimeStrRef.Value = ""; $EndRef.Value = ""
						$cd = Get-Date
						$msg = if ([string]::IsNullOrEmpty($oldStr)) { " - End time cleared" } else { " - End time cleared (was: $oldStr)" }
						$LogArrayRef.Value += [PSCustomObject]@{ logRow = $true; components = @(
							@{ priority = 1; text = $cd.ToString(); shortText = $cd.ToString("HH:mm:ss") },
							@{ priority = 2; text = $msg; shortText = " - End time cleared" }
						)}
					} else {
						$needsRedraw = $true
						$oldInt = $EndTimeIntRef.Value; $oldStr = $EndTimeStrRef.Value
						$EndTimeIntRef.Value = $timeResult.Result
						$newStr = $EndTimeIntRef.Value.ToString().PadLeft(4, '0')
						$EndTimeStrRef.Value = $newStr
						$nowHHmm    = Get-Date -Format "HHmm"
						$isTomorrow = $EndTimeIntRef.Value -le [int]$nowHHmm
						$endDate    = if ($isTomorrow) { Get-Date (Get-Date).AddDays(1) -Format "MMdd" } else { Get-Date -Format "MMdd" }
						$EndRef.Value = "$endDate$newStr"
						$cd = Get-Date; $arrow = [char]0x2192
						$dayLabel = if ($isTomorrow) { " (tomorrow)" } else { " (today)" }
						$dd = $endDate.Substring(0,2) + "/" + $endDate.Substring(2,2)
						$td = $newStr.Substring(0,2) + ":" + $newStr.Substring(2,2)
						$msg = if ($oldInt -eq -1 -or [string]::IsNullOrEmpty($oldStr)) { " - End time set: $dd $td$dayLabel" } else { " - End time changed: $oldStr $arrow $dd $td$dayLabel" }
						$LogArrayRef.Value += [PSCustomObject]@{ logRow = $true; components = @(
							@{ priority = 1; text = $cd.ToString(); shortText = $cd.ToString("HH:mm:ss") },
							@{ priority = 2; text = $msg; shortText = " - End time: $dd $td" }
						)}
					}
				}

			# Sub-dialog dirtied the background — break out so the caller can do a
			# full screen repaint and then reopen settings cleanly.
			$settingsReopen = $true
			break :settingsLoop

			} elseif ($char -eq "m" -or $char -eq "M") {
				# ── Go offfocus while movement dialog is open ──────────────────────
				& $drawSettingsDialog $dialogX $dialogY $false
				Flush-Buffer
				$script:DialogButtonBounds = $null

				$subHostWidthRef  = [ref]$currentHostWidth
				$subHostHeightRef = [ref]$currentHostHeight
				$moveResult = Show-MovementModifyDialog `
					-currentIntervalSeconds $script:IntervalSeconds -currentIntervalVariance $script:IntervalVariance `
					-currentMoveSpeed $script:MoveSpeed -currentMoveVariance $script:MoveVariance `
					-currentTravelDistance $script:TravelDistance -currentTravelVariance $script:TravelVariance `
					-currentAutoResumeDelaySeconds $script:AutoResumeDelaySeconds `
					-hostWidthRef $subHostWidthRef -hostHeightRef $subHostHeightRef
				$currentHostWidth  = $subHostWidthRef.Value
				$currentHostHeight = $subHostHeightRef.Value
				$HostWidthRef.Value  = $currentHostWidth
				$HostHeightRef.Value = $currentHostHeight

				# Apply movement result
				if ($null -ne $moveResult.Result) {
					$needsRedraw = $true
					$old = @{
						Int  = $script:IntervalSeconds; IntV = $script:IntervalVariance
						Spd  = $script:MoveSpeed;       SpdV = $script:MoveVariance
						Dst  = $script:TravelDistance;  DstV = $script:TravelVariance
						Dly  = $script:AutoResumeDelaySeconds
					}
					$script:IntervalSeconds       = $moveResult.Result.IntervalSeconds
					$script:IntervalVariance      = $moveResult.Result.IntervalVariance
					$script:MoveSpeed             = $moveResult.Result.MoveSpeed
					$script:MoveVariance          = $moveResult.Result.MoveVariance
					$script:TravelDistance        = $moveResult.Result.TravelDistance
					$script:TravelVariance        = $moveResult.Result.TravelVariance
					$script:AutoResumeDelaySeconds = $moveResult.Result.AutoResumeDelaySeconds
					$arrow = [char]0x2192; $chg = @()
					if ($old.Int  -ne $script:IntervalSeconds)       { $chg += "Interval: $($old.Int) $arrow $($script:IntervalSeconds)" }
					if ($old.IntV -ne $script:IntervalVariance)      { $chg += "IntervalVar: $($old.IntV) $arrow $($script:IntervalVariance)" }
					if ($old.Spd  -ne $script:MoveSpeed)             { $chg += "Speed: $($old.Spd) $arrow $($script:MoveSpeed)" }
					if ($old.SpdV -ne $script:MoveVariance)          { $chg += "SpeedVar: $($old.SpdV) $arrow $($script:MoveVariance)" }
					if ($old.Dst  -ne $script:TravelDistance)        { $chg += "Distance: $($old.Dst) $arrow $($script:TravelDistance)" }
					if ($old.DstV -ne $script:TravelVariance)        { $chg += "DistVar: $($old.DstV) $arrow $($script:TravelVariance)" }
					if ($old.Dly  -ne $script:AutoResumeDelaySeconds){ $chg += "Delay: $($old.Dly) $arrow $($script:AutoResumeDelaySeconds)" }
					if ($chg.Count -gt 0) {
						$cd = Get-Date
						$LogArrayRef.Value += [PSCustomObject]@{ logRow = $true; components = @(
							@{ priority = 1; text = $cd.ToString(); shortText = $cd.ToString("HH:mm:ss") },
							@{ priority = 2; text = " - Settings updated: $($chg -join ', ')"; shortText = " - Updated: $($chg -join ', ')" }
						)}
					}
				}

			# Sub-dialog dirtied the background — break out so the caller can do a
			# full screen repaint and then reopen settings cleanly.
			$settingsReopen = $true
			break :settingsLoop

	} elseif ($char -eq "o" -or $char -eq "O") {
		# ── Inline output toggle: cycle Full ↔ Min ─────────────────────────
		$oldOutput = $script:Output
		$script:Output = if ($script:Output -eq "full") { "min" } else { "full" }
		$needsRedraw = $true
		$modeNames = @{ 'full' = 'Full'; 'min' = 'Minimal' }
		$oldName = if ($modeNames.ContainsKey($oldOutput))       { $modeNames[$oldOutput] }       else { $oldOutput }
		$newName = if ($modeNames.ContainsKey($script:Output)) { $modeNames[$script:Output] } else { $script:Output }
		$cd = Get-Date
		$LogArrayRef.Value += [PSCustomObject]@{ logRow = $true; components = @(
			@{ priority = 1; text = $cd.ToString(); shortText = $cd.ToString("HH:mm:ss") },
			@{ priority = 2; text = " - Output mode: $oldName $([char]0x2192) $newName"; shortText = " - Output: $newName" }
		)}
		& $drawSettingsDialog $dialogX $dialogY $true
		Flush-Buffer

	} elseif ($char -eq "d" -or $char -eq "D") {
		# ── Inline debug toggle ─────────────────────────────────────────────
		$script:DebugMode = -not $script:DebugMode
		$needsRedraw = $true
		$cd = Get-Date
		$dbgLabel = if ($script:DebugMode) { "enabled" } else { "disabled" }
		$LogArrayRef.Value += [PSCustomObject]@{ logRow = $true; components = @(
			@{ priority = 1; text = $cd.ToString(); shortText = $cd.ToString("HH:mm:ss") },
			@{ priority = 2; text = " - Debug mode: $dbgLabel"; shortText = " - Debug: $dbgLabel" }
		)}
		& $drawSettingsDialog $dialogX $dialogY $true
		Flush-Buffer

	} elseif ($char -eq "s" -or $char -eq "S" -or $char -eq "q" -or $char -eq "Q" -or
		          $key -eq "Escape" -or $key -eq "Enter" -or $char -eq [char]13 -or $char -eq [char]10 -or
		          ($null -ne $keyInfo -and $keyInfo.VirtualKeyCode -eq 27)) {
		break :settingsLoop
	}

			try {
				while ($Host.UI.RawUI.KeyAvailable) { $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown,AllowCtrlC") }
			} catch { }
		} until ($false)

		# ── Clear dialog area ─────────────────────────────────────────────────────
		for ($i = 0; $i -le $dialogHeight; $i++) {
			Write-Buffer -X $dialogX -Y ($dialogY + $i) -Text (" " * $dialogWidth)
		}
		Flush-Buffer

		$script:CursorVisible = $savedCursorVisible
		if ($script:CursorVisible) { [Console]::Write("$($script:ESC)[?25h") } else { [Console]::Write("$($script:ESC)[?25l") }

		$script:DialogButtonBounds = $null
		$script:DialogButtonClick  = $null

		return @{ NeedsRedraw = $needsRedraw; ReopenSettings = $settingsReopen }
	}

	# Info / About dialog — shows version, update status, and current configuration.
	# Triggered by pressing '?' or clicking the mJig logo in the header.
	function Show-InfoDialog {
		param([ref]$HostWidthRef, [ref]$HostHeightRef)

		$currentHostWidth  = $HostWidthRef.Value
		$currentHostHeight = $HostHeightRef.Value

		$dialogWidth  = 62
		$dialogHeight = 21  # Y-offset of the bottom border row (rows 0..21 = 22 visible rows)
		$dialogX = [math]::Max(0, [math]::Floor(($currentHostWidth  - $dialogWidth)  / 2))
		$dialogY = [math]::Max(0, [math]::Floor(($currentHostHeight - $dialogHeight) / 2))

		$savedCursorVisible = $script:CursorVisible
		$script:CursorVisible = $false
		[Console]::Write("$($script:ESC)[?25l")

		# Fetch version info (uses cached result on subsequent calls)
		$versionInfo = Get-LatestVersionInfo

	$dlgIconWidth    = if ($script:DialogButtonShowIcon)     { 2 + $script:DialogButtonSeparator.Length } else { 0 }
	$dlgBracketWidth = if ($script:DialogButtonShowBrackets) { 2 } else { 0 }
	$dlgParenAdj     = if ($script:DialogButtonShowHotkeyParens) { 0 } else { -2 }
	# Single close button: "│ " + bracket? + icon? + "(c)lose" + padding + "│"
	# padding = dialogWidth - 10 - bracketWidth - iconWidth  (= 52 - b - i)
	$bottomLinePadding = $dialogWidth - 10 - $dlgParenAdj - $dlgBracketWidth - $dlgIconWidth

		$drawInfoDialog = {
			param($dx, $dy)
			$inner = $dialogWidth - 2   # 60
			$hLine = [string]$script:BoxHorizontal
			$mouseEmoji = [char]::ConvertFromUtf32(0x1F400)  # 🐀
			$checkChar  = [char]0x2713   # ✓
			$arrowUp    = [char]0x2191   # ↑
			$redX       = [char]::ConvertFromUtf32(0x274C)   # ❌

			# Clear dialog background
			for ($i = 0; $i -lt $dialogHeight; $i++) {
				Write-Buffer -X $dx -Y ($dy + $i) -Text (" " * $dialogWidth) -BG $script:InfoDialogBg
			}

			# ── Line 0: top border ────────────────────────────────────────────
			Write-Buffer -X $dx -Y ($dy + 0) -Text ($script:BoxTopLeft + ($hLine * $inner) + $script:BoxTopRight) -FG $script:InfoDialogBorder -BG $script:InfoDialogBg

		# ── Line 1: title with logo emoji ─────────────────────────────────
		# Layout: │(1) + "  mJig("(7) + emoji(2) + ")"(1) + "  About & Version"(17) + pad(33) + │(1) = 62
		Write-Buffer -X $dx -Y ($dy + 1) -Text "$($script:BoxVertical)  mJig(" -FG $script:InfoDialogBorder -BG $script:InfoDialogBg
		Write-Buffer -Text $mouseEmoji -FG $script:InfoDialogTitle -BG $script:InfoDialogBg
		Write-Buffer -X ($dx + 10) -Y ($dy + 1) -Text ")" -FG $script:InfoDialogBorder -BG $script:InfoDialogBg
		Write-Buffer -Text "  About & Version" -FG $script:InfoDialogTitle -BG $script:InfoDialogBg
		Write-Buffer -Text (" " * 33) -BG $script:InfoDialogBg
		Write-Buffer -Text $script:BoxVertical -FG $script:InfoDialogBorder -BG $script:InfoDialogBg

			# ── Line 2: divider ───────────────────────────────────────────────
			Write-Buffer -X $dx -Y ($dy + 2) -Text ($script:BoxVerticalRight + ($hLine * $inner) + $script:BoxVerticalLeft) -FG $script:InfoDialogBorder -BG $script:InfoDialogBg

			# ── Line 3: blank ─────────────────────────────────────────────────
			Write-Buffer -X $dx -Y ($dy + 3) -Text ($script:BoxVertical + (" " * $inner) + $script:BoxVertical) -FG $script:InfoDialogBorder -BG $script:InfoDialogBg

			# ── Line 4: Version ───────────────────────────────────────────────
			$vLabel = "  Version:     "; $vVal = $script:Version
			Write-Buffer -X $dx -Y ($dy + 4) -Text $script:BoxVertical -FG $script:InfoDialogBorder -BG $script:InfoDialogBg
			Write-Buffer -Text $vLabel -FG $script:InfoDialogText -BG $script:InfoDialogBg
			Write-Buffer -Text $vVal   -FG $script:InfoDialogValue -BG $script:InfoDialogBg
			Write-Buffer -Text (" " * ($inner - $vLabel.Length - $vVal.Length)) -BG $script:InfoDialogBg
			Write-Buffer -Text $script:BoxVertical -FG $script:InfoDialogBorder -BG $script:InfoDialogBg

			# ── Line 5: Latest release ────────────────────────────────────────
			$lLabel = "  Latest:      "
			Write-Buffer -X $dx -Y ($dy + 5) -Text $script:BoxVertical -FG $script:InfoDialogBorder -BG $script:InfoDialogBg
			Write-Buffer -Text $lLabel -FG $script:InfoDialogText -BG $script:InfoDialogBg
			$lUsed = $lLabel.Length
			if ($null -eq $versionInfo -or $null -ne $versionInfo.error) {
				$failText = "Could not check for updates"
				Write-Buffer -Text $failText -FG $script:InfoDialogValueMuted -BG $script:InfoDialogBg
				$lUsed += $failText.Length
			} elseif ($versionInfo.isNewer) {
				Write-Buffer -Text $versionInfo.latest -FG $script:InfoDialogValueWarn -BG $script:InfoDialogBg
				Write-Buffer -Text "  " -BG $script:InfoDialogBg
				Write-Buffer -Text $arrowUp -FG $script:InfoDialogValueWarn -BG $script:InfoDialogBg
				Write-Buffer -Text " Update available!" -FG $script:InfoDialogValueWarn -BG $script:InfoDialogBg
				$lUsed += $versionInfo.latest.Length + 2 + 1 + " Update available!".Length
			} else {
				Write-Buffer -Text $versionInfo.latest -FG $script:InfoDialogValueGood -BG $script:InfoDialogBg
				Write-Buffer -Text "  " -BG $script:InfoDialogBg
				Write-Buffer -Text $checkChar -FG $script:InfoDialogValueGood -BG $script:InfoDialogBg
				Write-Buffer -Text " Up to date" -FG $script:InfoDialogValueGood -BG $script:InfoDialogBg
				$lUsed += $versionInfo.latest.Length + 2 + 1 + " Up to date".Length
			}
			Write-Buffer -Text (" " * [math]::Max(0, $inner - $lUsed)) -BG $script:InfoDialogBg
			Write-Buffer -Text $script:BoxVertical -FG $script:InfoDialogBorder -BG $script:InfoDialogBg

		# ── Line 6: Repository ────────────────────────────────────────────
		$rLabel = "  Repository:  "; $rVal = "https://github.com/ziaprazid0ne/mJig"
			Write-Buffer -X $dx -Y ($dy + 6) -Text $script:BoxVertical -FG $script:InfoDialogBorder -BG $script:InfoDialogBg
			Write-Buffer -Text $rLabel -FG $script:InfoDialogText -BG $script:InfoDialogBg
			Write-Buffer -Text $rVal   -FG $script:InfoDialogValue -BG $script:InfoDialogBg
			Write-Buffer -Text (" " * ($inner - $rLabel.Length - $rVal.Length)) -BG $script:InfoDialogBg
			Write-Buffer -Text $script:BoxVertical -FG $script:InfoDialogBorder -BG $script:InfoDialogBg

			# ── Line 7: blank ─────────────────────────────────────────────────
			Write-Buffer -X $dx -Y ($dy + 7) -Text ($script:BoxVertical + (" " * $inner) + $script:BoxVertical) -FG $script:InfoDialogBorder -BG $script:InfoDialogBg

			# ── Line 8: section divider ───────────────────────────────────────
			Write-Buffer -X $dx -Y ($dy + 8) -Text ($script:BoxVerticalRight + ($hLine * $inner) + $script:BoxVerticalLeft) -FG $script:InfoDialogBorder -BG $script:InfoDialogBg

			# ── Line 9: "Configuration" section title ─────────────────────────
			$secTitle = "  Configuration"
			Write-Buffer -X $dx -Y ($dy + 9) -Text $script:BoxVertical -FG $script:InfoDialogBorder -BG $script:InfoDialogBg
			Write-Buffer -Text $secTitle -FG $script:InfoDialogSectionTitle -BG $script:InfoDialogBg
			Write-Buffer -Text (" " * ($inner - $secTitle.Length)) -BG $script:InfoDialogBg
			Write-Buffer -Text $script:BoxVertical -FG $script:InfoDialogBorder -BG $script:InfoDialogBg

			# ── Line 10: section divider ──────────────────────────────────────
			Write-Buffer -X $dx -Y ($dy + 10) -Text ($script:BoxVerticalRight + ($hLine * $inner) + $script:BoxVerticalLeft) -FG $script:InfoDialogBorder -BG $script:InfoDialogBg

			# ── Line 11: blank ────────────────────────────────────────────────
			Write-Buffer -X $dx -Y ($dy + 11) -Text ($script:BoxVertical + (" " * $inner) + $script:BoxVertical) -FG $script:InfoDialogBorder -BG $script:InfoDialogBg

			# ── Lines 12-17: configuration rows ──────────────────────────────
			$endTimeDsp    = if ($endTimeInt -eq -1 -or [string]::IsNullOrEmpty($endTimeStr)) { "none" } else { "$($endTimeStr.Substring(0,2)):$($endTimeStr.Substring(2,2))" }
			$autoResumeDsp = if ($script:AutoResumeDelaySeconds -gt 0) { "$($script:AutoResumeDelaySeconds)s" } else { "off" }
			$cfgRows = @(
				@{ label = "  Output:       "; value = $Output },
				@{ label = "  Interval:     "; value = "$($script:IntervalSeconds)s  (+-$($script:IntervalVariance)s)" },
				@{ label = "  Distance:     "; value = "$($script:TravelDistance)px  (+-$($script:TravelVariance)px)" },
				@{ label = "  Move speed:   "; value = "$($script:MoveSpeed)s  (+-$($script:MoveVariance)s)" },
				@{ label = "  End time:     "; value = $endTimeDsp },
				@{ label = "  Auto-resume:  "; value = $autoResumeDsp }
			)
			for ($ri = 0; $ri -lt $cfgRows.Count; $ri++) {
				$row  = $cfgRows[$ri]
				$rowY = $dy + 12 + $ri
				Write-Buffer -X $dx -Y $rowY -Text $script:BoxVertical -FG $script:InfoDialogBorder -BG $script:InfoDialogBg
				Write-Buffer -Text $row.label -FG $script:InfoDialogText  -BG $script:InfoDialogBg
				Write-Buffer -Text $row.value -FG $script:InfoDialogValue -BG $script:InfoDialogBg
				Write-Buffer -Text (" " * [math]::Max(0, $inner - $row.label.Length - $row.value.Length)) -BG $script:InfoDialogBg
				Write-Buffer -Text $script:BoxVertical -FG $script:InfoDialogBorder -BG $script:InfoDialogBg
			}

			# ── Line 18: blank ────────────────────────────────────────────────
			Write-Buffer -X $dx -Y ($dy + 18) -Text ($script:BoxVertical + (" " * $inner) + $script:BoxVertical) -FG $script:InfoDialogBorder -BG $script:InfoDialogBg

			# ── Line 19: close button row ─────────────────────────────────────
			$btnX = $dx + 2
			Write-Buffer -X $dx -Y ($dy + 19) -Text "$($script:BoxVertical) " -FG $script:InfoDialogBorder -BG $script:InfoDialogBg
			if ($script:DialogButtonShowBrackets) {
				Write-Buffer -X $btnX -Y ($dy + 19) -Text "[" -FG $script:DialogButtonBracketFg -BG $script:DialogButtonBracketBg
			}
			$btnContentX = $btnX + [int]$script:DialogButtonShowBrackets
			if ($script:DialogButtonShowIcon) {
				Write-Buffer -X $btnContentX -Y ($dy + 19) -Text $redX -FG $script:InfoDialogButtonText -BG $script:InfoDialogButtonBg -Wide
				Write-Buffer -X ($btnContentX + 2) -Y ($dy + 19) -Text $script:DialogButtonSeparator -FG $script:InfoDialogButtonText -BG $script:InfoDialogButtonBg
			} else {
				Write-Buffer -X $btnContentX -Y ($dy + 19) -Text "" -BG $script:InfoDialogButtonBg
			}
		$_rp = if ($script:DialogButtonShowHotkeyParens) { ")" } else { "" }
		if ($script:DialogButtonShowHotkeyParens) { Write-Buffer -Text "(" -FG $script:InfoDialogButtonText -BG $script:InfoDialogButtonBg }
		Write-Buffer -Text "c" -FG $script:InfoDialogButtonHotkey -BG $script:InfoDialogButtonBg
		Write-Buffer -Text "${_rp}lose" -FG $script:InfoDialogButtonText -BG $script:InfoDialogButtonBg
			if ($script:DialogButtonShowBrackets) { Write-Buffer -Text "]" -FG $script:DialogButtonBracketFg -BG $script:DialogButtonBracketBg }
			Write-Buffer -Text (" " * $bottomLinePadding) -BG $script:InfoDialogBg
			Write-Buffer -Text $script:BoxVertical -FG $script:InfoDialogBorder -BG $script:InfoDialogBg

			# ── Line 20: blank ────────────────────────────────────────────────
			Write-Buffer -X $dx -Y ($dy + 20) -Text ($script:BoxVertical + (" " * $inner) + $script:BoxVertical) -FG $script:InfoDialogBorder -BG $script:InfoDialogBg

			# ── Line 21: bottom border ────────────────────────────────────────
			Write-Buffer -X $dx -Y ($dy + 21) -Text ($script:BoxBottomLeft + ($hLine * $inner) + $script:BoxBottomRight) -FG $script:InfoDialogBorder -BG $script:InfoDialogBg
		}

		# Initial draw
		& $drawInfoDialog $dialogX $dialogY
		Draw-DialogShadow -dialogX $dialogX -dialogY $dialogY -dialogWidth $dialogWidth -dialogHeight $dialogHeight -shadowColor $script:InfoDialogShadow
		Flush-Buffer

	# Button bounds (close button only — both update/cancel map to "close")
	$buttonRowY        = $dialogY + 19
	$closeButtonStartX = $dialogX + 2
	$closeButtonEndX   = $closeButtonStartX + $dlgBracketWidth + $dlgIconWidth + 7 + $dlgParenAdj - 1
	$script:DialogButtonBounds = @{
		buttonRowY   = $buttonRowY
		updateStartX = $closeButtonStartX
		updateEndX   = $closeButtonEndX
		cancelStartX = $closeButtonStartX
		cancelEndX   = $closeButtonEndX
	}
		$script:DialogButtonClick = $null

		$needsRedraw = $false

		:inputLoop do {
			# Resize check
			$pshost       = Get-Host
			$pswindow     = $pshost.UI.RawUI
			$newWindowSize = $pswindow.WindowSize
			if ($newWindowSize.Width -ne $currentHostWidth -or $newWindowSize.Height -ne $currentHostHeight) {
				$HostWidthRef.Value  = $newWindowSize.Width
				$HostHeightRef.Value = $newWindowSize.Height
				$currentHostWidth    = $newWindowSize.Width
				$currentHostHeight   = $newWindowSize.Height
				$needsRedraw         = $true

				$dialogX = [math]::Max(0, [math]::Floor(($currentHostWidth  - $dialogWidth)  / 2))
				$dialogY = [math]::Max(0, [math]::Floor(($currentHostHeight - $dialogHeight) / 2))

				& $drawInfoDialog $dialogX $dialogY
				Draw-DialogShadow -dialogX $dialogX -dialogY $dialogY -dialogWidth $dialogWidth -dialogHeight $dialogHeight -shadowColor $script:InfoDialogShadow
			Flush-Buffer -ClearFirst

			$buttonRowY        = $dialogY + 19
			$closeButtonStartX = $dialogX + 2
			$closeButtonEndX   = $closeButtonStartX + $dlgBracketWidth + $dlgIconWidth + 7 + $dlgParenAdj - 1
			$script:DialogButtonBounds = @{
				buttonRowY   = $buttonRowY
				updateStartX = $closeButtonStartX
				updateEndX   = $closeButtonEndX
				cancelStartX = $closeButtonStartX
				cancelEndX   = $closeButtonEndX
			}
			}

			# Mouse click detection
			$keyProcessed = $false
			$keyInfo = $null
			$key     = $null
			$char    = $null

			try {
				$peekBuf  = New-Object 'mJiggAPI.INPUT_RECORD[]' 16
				$peekEvts = [uint32]0
				$hIn      = [mJiggAPI.Mouse]::GetStdHandle(-10)
				if ([mJiggAPI.Mouse]::PeekConsoleInput($hIn, $peekBuf, 16, [ref]$peekEvts) -and $peekEvts -gt 0) {
					$lastClickIdx = -1
					$clickX = -1; $clickY = -1
					for ($e = 0; $e -lt $peekEvts; $e++) {
						if ($peekBuf[$e].EventType -eq 0x0002 -and $peekBuf[$e].MouseEvent.dwEventFlags -eq 0 -and ($peekBuf[$e].MouseEvent.dwButtonState -band 0x0001) -ne 0) {
							$clickX = $peekBuf[$e].MouseEvent.dwMousePosition.X
							$clickY = $peekBuf[$e].MouseEvent.dwMousePosition.Y
							$lastClickIdx = $e
						}
					}
					if ($lastClickIdx -ge 0) {
						$consumeCount = [uint32]($lastClickIdx + 1)
						$flushBuf     = New-Object 'mJiggAPI.INPUT_RECORD[]' $consumeCount
						$flushed      = [uint32]0
						[mJiggAPI.Mouse]::ReadConsoleInput($hIn, $flushBuf, $consumeCount, [ref]$flushed) | Out-Null
					# Click outside dialog bounds → close
					if ($clickX -lt $dialogX -or $clickX -ge ($dialogX + $dialogWidth) -or $clickY -lt $dialogY -or $clickY -gt ($dialogY + $dialogHeight)) {
						$char = "c"; $keyProcessed = $true
					} elseif ($clickY -eq $buttonRowY -and $clickX -ge $closeButtonStartX -and $clickX -le $closeButtonEndX) {
						$char = "c"; $keyProcessed = $true
					}
					}
				}
			} catch {}

			# Main-loop DialogButtonClick (set when click is routed through main input handler)
			if (-not $keyProcessed -and $null -ne $script:DialogButtonClick) {
				$script:DialogButtonClick = $null
				$char = "c"; $keyProcessed = $true
			}

			# Keyboard input
			if (-not $keyProcessed) {
				while ($Host.UI.RawUI.KeyAvailable -and -not $keyProcessed) {
					$keyInfo    = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyup,AllowCtrlC")
					$isKeyDown  = if ($null -ne $keyInfo.KeyDown) { $keyInfo.KeyDown } else { $false }
					if (-not $isKeyDown) {
						$key = $keyInfo.Key; $char = $keyInfo.Character; $keyProcessed = $true
					}
				}
			}

			if (-not $keyProcessed) { Start-Sleep -Milliseconds 50; continue }

		if ($char -eq "c" -or $char -eq "C" -or $char -eq "?" -or $char -eq "/" -or
			$key  -eq "Escape" -or $key -eq "Enter" -or $char -eq [char]13 -or $char -eq [char]10) {
				break inputLoop
			}

		} while ($true)

		$script:DialogButtonBounds = $null
		$script:DialogButtonClick  = $null

		# Clear key buffer
		try { while ($Host.UI.RawUI.KeyAvailable) { $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown,AllowCtrlC") } } catch {}

		# Clear dialog area
		Clear-DialogShadow -dialogX $dialogX -dialogY $dialogY -dialogWidth $dialogWidth -dialogHeight $dialogHeight
		for ($i = 0; $i -lt $dialogHeight; $i++) {
			Write-Buffer -X $dialogX -Y ($dialogY + $i) -Text (" " * $dialogWidth)
		}
		Flush-Buffer

		$script:CursorVisible = $savedCursorVisible
		if ($script:CursorVisible) { [Console]::Write("$($script:ESC)[?25h") } else { [Console]::Write("$($script:ESC)[?25l") }

		return @{ NeedsRedraw = $needsRedraw }
	}

	# Show startup complete screen (non-debug, non-hidden modes only)
	if (-not $DebugMode -and $Output -ne "hidden") {
		Show-StartupComplete -HasParams ($PSBoundParameters.Count -gt 0)
	}

	# Pause to read debug output if in debug mode
	if ($script:DiagEnabled) { "$(Get-Date -Format 'HH:mm:ss.fff') - CHECKPOINT 4: Before debug mode check (DebugMode=$DebugMode)" | Out-File $script:StartupDiagFile -Append }
	
	if ($DebugMode) {
		if ($script:DiagEnabled) { "$(Get-Date -Format 'HH:mm:ss.fff') - ENTERED DEBUG MODE KEY WAIT LOOP" | Out-File $script:StartupDiagFile -Append }

		Write-Host "`nPress any key to start mJig..." -ForegroundColor $script:TextWarning

		$dbgModifierVKs = @(0x10, 0x11, 0x12, 0xA0, 0xA1, 0xA2, 0xA3, 0xA4, 0xA5, 0x5B, 0x5C)
		$hIn      = [mJiggAPI.Mouse]::GetStdHandle(-10)
		$peekBuf  = New-Object 'mJiggAPI.INPUT_RECORD[]' 32
		$peekEvts = [uint32]0
		# Drain events buffered before the prompt appeared (e.g. Enter key-up from launch)
		try { $Host.UI.RawUI.FlushInputBuffer() } catch {}
		$detected = $false
		while (-not $detected) {
			Start-Sleep -Milliseconds 5
			try {
				if ([mJiggAPI.Mouse]::PeekConsoleInput($hIn, $peekBuf, 32, [ref]$peekEvts) -and $peekEvts -gt 0) {
					for ($e = 0; $e -lt [int]$peekEvts; $e++) {
						if ($peekBuf[$e].EventType -eq 0x0001 -and $peekBuf[$e].KeyEvent.bKeyDown -eq 0 -and
						    $peekBuf[$e].KeyEvent.wVirtualKeyCode -notin $dbgModifierVKs) {
							$detected = $true; break
						}
					}
					if ($detected) {
						$flushBuf = New-Object 'mJiggAPI.INPUT_RECORD[]' $peekEvts
						$flushed  = [uint32]0
						[mJiggAPI.Mouse]::ReadConsoleInput($hIn, $flushBuf, $peekEvts, [ref]$flushed) | Out-Null
					}
				}
			} catch {
				if ($Host.UI.RawUI.KeyAvailable) {
					try { $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown,IncludeKeyUp,AllowCtrlC") } catch {}
					$detected = $true
				} else {
					Start-Sleep -Milliseconds 45
				}
			}
		}

	}

	# Key-up detection above already flushes all buffered events via ReadConsoleInput,
	# so the main loop starts with a clean input queue.
	if ($script:DiagEnabled) { "$(Get-Date -Format 'HH:mm:ss.fff') - CHECKPOINT 5: Input buffer flushed by key-up handler" | Out-File $script:StartupDiagFile -Append }
		if ($script:DiagEnabled) { "$(Get-Date -Format 'HH:mm:ss.fff') - CHECKPOINT 6: Entering main loop" | Out-File $script:StartupDiagFile -Append }

	# Clear the entire console buffer (viewport + scrollback) so the startup screen
	# cannot be scrolled back to after the main UI takes over.
	try { [Console]::Clear() } catch {}
	# Signal the first render to atomically redraw over the now-blank console.
	$script:PendingForceRedraw = $true

	# Sync window/buffer tracking to the current state before the main loop.
	# Without this, the first iteration sees $oldWindowSize = $null → windowSizeChanged = $true
	# and immediately enters the resize handler even though nothing has changed.
	$oldWindowSize = (Get-Host).UI.RawUI.WindowSize
	$OldBufferSize = (Get-Host).UI.RawUI.BufferSize

	# Main Processing Loop
	:process while ($true) {
			$script:LoopIteration++
			
			# Reset state for this iteration
			$time = $false
			$script:userInputDetected = $false
			$keyboardInputDetected = $false
			$mouseInputDetected = $false
			$scrollDetectedInInterval = $false
			$waitExecuted = $false
			$intervalMouseInputs = @()
			$interval = 0
			$math = 0
		[System.TimeZoneInfo]::ClearCachedData()
		$date = Get-Date
		$currentTime = $date.ToString("HHmm")
	$forceRedraw = $false
	# If a sub-dialog was used inside settings, keep forceRedraw so the main
	# render uses ClearFirst and we get a pristine background before reopening.
	if ($script:PendingReopenSettings) { $forceRedraw = $true }
	# After the reopened Settings dialog closes, skip sleep so the screen
	# redraws immediately without ever going blank.
	if ($script:PendingForceRedraw) { $forceRedraw = $true; $script:PendingForceRedraw = $false }
		$automatedMovementPos = $null  # Track position after automated movement
			$directionArrow = ""  # Track direction arrow for log display
			$lastKeyPress = $null  # Reset key press tracking
			$lastKeyInfo = $null  # Reset key info tracking
			$pressedMenuKeys = @{}  # Track which menu keys are currently pressed (to detect key up)
			
			# Calculate interval and wait BEFORE doing movement (skip on first run or if forceRedraw)
			if ($null -ne $LastMovementTime -and -not $forceRedraw) {
				# Calculate random interval with variance
				# Convert to milliseconds for calculation
				$intervalSecondsMs = $script:IntervalSeconds * 1000
				$intervalVarianceMs = $script:IntervalVariance * 1000
				$intervalMs = Get-ValueWithVariance -baseValue $intervalSecondsMs -variance $intervalVarianceMs
				
				# Subtract the previous movement duration from the interval
				$intervalMs = $intervalMs - $LastMovementDurationMs
				
				# Ensure minimum interval of 1 second (variance can be larger than base interval)
				$minIntervalMs = 1000  # 1 second in milliseconds
				if ($intervalMs -lt $minIntervalMs) {
					$intervalMs = $minIntervalMs
				}
				
				# Convert back to seconds and round to 1 decimal place for display
				$interval = [math]::Round($intervalMs / 1000, 1)
				
				# Calculate number of 50ms iterations needed (1000ms / 50ms = 20 iterations per second)
				# Use the millisecond value for accurate calculation
				$math = [math]::Max(1, [math]::Floor($intervalMs / 50))
				
				$waitExecuted = $true
				$mousePosAtStart = Get-MousePosition
				
				# Wait Loop - Check window/buffer size changes, menu hotkeys, and keyboard input
				# Menu hotkeys checked every 200ms (every 4th iteration), keyboard input checked every 50ms for maximum reliability
				$x = 0
				:waitLoop while ($true) {
					$x++
					
					# Check for system-wide keyboard input every 50ms for maximum reliability
					# Skip checking if we recently sent a simulated key press (within last 300ms)
					$shouldCheckKeyboard = (Get-TimeSinceMs -startTime $LastSimulatedKeyPress) -ge 300
					if ($shouldCheckKeyboard) {
						$LastSimulatedKeyPress = $null
					}
					
					if ($shouldCheckKeyboard) {
						# Initialize previous key states lazily
						if ($null -eq $script:previousKeyStates) {
							$script:previousKeyStates = @{}
						}
						
						# Check mouse position every 50ms to detect movement for console skip
						# This prevents console updates from blocking during active mouse movement
						if ($null -eq $script:lastMousePosCheck) {
							$script:lastMousePosCheck = $null
						}
						try {
							$currentCheckPos = Get-MousePosition
							if ($script:DiagEnabled -and $null -ne $currentCheckPos) {
								$lastX = if ($null -ne $script:lastMousePosCheck) { $script:lastMousePosCheck.X } else { "null" }
								$lastY = if ($null -ne $script:lastMousePosCheck) { $script:lastMousePosCheck.Y } else { "null" }
								$moved = Test-MouseMoved -currentPos $currentCheckPos -lastPos $script:lastMousePosCheck -threshold 2
								"$(Get-Date -Format 'HH:mm:ss.fff') - MOUSEPOS cur=($($currentCheckPos.X),$($currentCheckPos.Y)) last=($lastX,$lastY) moved=$moved" | Out-File $script:InputDiagFile -Append
							}
							if ($null -ne $currentCheckPos) {
								if (Test-MouseMoved -currentPos $currentCheckPos -lastPos $script:lastMousePosCheck -threshold 2) {
									$script:LastMouseMovementTime = Get-Date
									$mouseInputDetected = $true
									$mouseMoveText = "Mouse"
									if ($intervalMouseInputs -notcontains $mouseMoveText) {
										$intervalMouseInputs += $mouseMoveText
									}
									if ($script:AutoResumeDelaySeconds -gt 0) {
										$LastUserInputTime = Get-Date
									}
								}
								$script:lastMousePosCheck = $currentCheckPos
							} elseif ($script:DiagEnabled) {
								"$(Get-Date -Format 'HH:mm:ss.fff') - MOUSEPOS: Get-MousePosition returned NULL" | Out-File $script:InputDiagFile -Append
							}
						} catch {
							if ($script:DiagEnabled) { "$(Get-Date -Format 'HH:mm:ss.fff') - MOUSEPOS ERROR: $($_.Exception.Message)" | Out-File $script:InputDiagFile -Append }
						}
						
						# Detect scroll, keyboard, and mouse clicks via PeekConsoleInput (works when console is focused)
						# Keyboard events are only peeked (not consumed) so the menu hotkey handler can still read them
						$scrollDetected = $false
						$script:ConsoleClickCoords = $null
						try {
							$peekBuffer = New-Object 'mJiggAPI.INPUT_RECORD[]' 32
							$peekEvents = [uint32]0
							$hStdIn = [mJiggAPI.Mouse]::GetStdHandle(-10)  # STD_INPUT_HANDLE
							if ([mJiggAPI.Mouse]::PeekConsoleInput($hStdIn, $peekBuffer, 32, [ref]$peekEvents) -and $peekEvents -gt 0) {
								$hasScrollEvent = $false
								$hasKeyboardEvent = $false
								$lastScrollIdx = -1
								$lastClickIdx = -1
								for ($e = 0; $e -lt $peekEvents; $e++) {
									if ($peekBuffer[$e].EventType -eq 0x0002) {
										$mouseFlags = $peekBuffer[$e].MouseEvent.dwEventFlags
										$mouseButtons = $peekBuffer[$e].MouseEvent.dwButtonState
										if ($mouseFlags -eq 0x0004) {
											$hasScrollEvent = $true
											$lastScrollIdx = $e
									} elseif ($mouseFlags -eq 0) {
										# Button press/release event (dwEventFlags=0); bit 0 of dwButtonState = left button currently held
										$lmbNow = ($mouseButtons -band 0x0001) -ne 0
										if ($lmbNow -and -not $script:LButtonWasDown) {
											# LMB DOWN: find button under cursor and immediately render it in onclick colors
											$dX = $peekBuffer[$e].MouseEvent.dwMousePosition.X
											$dY = $peekBuffer[$e].MouseEvent.dwMousePosition.Y
											$script:PressedMenuButton = $null
											if ($null -eq $script:DialogButtonBounds -and $null -ne $script:MenuItemsBounds) {
												foreach ($btn in $script:MenuItemsBounds) {
													if ($null -ne $btn.hotkey -and $dY -eq $btn.y -and $dX -ge $btn.startX -and $dX -le $btn.endX) {
														$script:PressedMenuButton = $btn.hotkey
						$ocFg         = if ($null -ne $btn.onClickFg)         { $btn.onClickFg }         else { $script:MenuButtonOnClickFg }
							$ocBg         = if ($null -ne $btn.onClickBg)         { $btn.onClickBg }         else { $script:MenuButtonOnClickBg }
							$ocHk         = if ($null -ne $btn.onClickHotkeyFg)   { $btn.onClickHotkeyFg }   else { $script:MenuButtonOnClickHotkey }
							$ocPipe       = if ($null -ne $btn.onClickPipeFg)      { $btn.onClickPipeFg }     else { $script:MenuButtonOnClickSeparatorFg }
							$ocBracketFg  = if ($null -ne $btn.onClickBracketFg)   { $btn.onClickBracketFg }  else { $script:MenuButtonOnClickBracketFg }
							$ocBracketBg  = if ($null -ne $btn.onClickBracketBg)   { $btn.onClickBracketBg }  else { $script:MenuButtonOnClickBracketBg }
							Write-ButtonImmediate -btn $btn -fg $ocFg -bg $ocBg -hotkeyFg $ocHk -pipeFg $ocPipe -bracketFg $ocBracketFg -bracketBg $ocBracketBg
														break
													}
												}
											}
											$lastClickIdx = $e
										} elseif (-not $lmbNow -and $script:LButtonWasDown) {
											# LMB UP: decide whether to trigger action and how to restore button colors
											$uX = $peekBuffer[$e].MouseEvent.dwMousePosition.X
											$uY = $peekBuffer[$e].MouseEvent.dwMousePosition.Y
											if ($null -ne $script:PressedMenuButton -and $null -ne $script:MenuItemsBounds) {
												foreach ($btn in $script:MenuItemsBounds) {
													if ($btn.hotkey -eq $script:PressedMenuButton) {
														$releasedOver = ($uY -eq $btn.y -and $uX -ge $btn.startX -and $uX -le $btn.endX)
													if ($releasedOver) {
														# Confirmed click: trigger action, leave onclick colors active.
														# PendingDialogCheck tells the render loop to clear the pressed state on the
														# first render UNLESS a dialog is open at that point (popup persists).
														$script:ConsoleClickCoords  = @{ X = $uX; Y = $uY }
														$script:ButtonClickedAt     = Get-Date
														$script:PendingDialogCheck  = $true
														# Don't clear PressedMenuButton here — render loop handles restoration
														} else {
															# Cancelled (dragged off): wait 100ms then restore immediately
															Start-Sleep -Milliseconds 100
								$nFg        = if ($null -ne $btn.fg)         { $btn.fg }         else { $script:MenuButtonText }
								$nBg        = if ($null -ne $btn.bg)         { $btn.bg }         else { $script:MenuButtonBg }
								$nHk        = if ($null -ne $btn.hotkeyFg)   { $btn.hotkeyFg }   else { $script:MenuButtonHotkey }
								$nPipe      = if ($null -ne $btn.pipeFg)     { $btn.pipeFg }     else { $script:MenuButtonSeparatorFg }
								$nBracketFg = if ($null -ne $btn.bracketFg)  { $btn.bracketFg }  else { $script:MenuButtonBracketFg }
								$nBracketBg = if ($null -ne $btn.bracketBg)  { $btn.bracketBg }  else { $script:MenuButtonBracketBg }
								Write-ButtonImmediate -btn $btn -fg $nFg -bg $nBg -hotkeyFg $nHk -pipeFg $nPipe -bracketFg $nBracketFg -bracketBg $nBracketBg
															$script:PressedMenuButton = $null
															$script:ButtonClickedAt   = $null
														}
														break
													}
												}
									} else {
										# No pressed menu button — always record coords so the processing
										# section can evaluate dialog buttons, mode button, and header
										# time regions against their bounds.
										$script:ConsoleClickCoords = @{ X = $uX; Y = $uY }
									}
											$lastClickIdx = $e
										}
										$script:LButtonWasDown = $lmbNow
									}
									}
									if ($peekBuffer[$e].EventType -eq 0x0001 -and $peekBuffer[$e].KeyEvent.wVirtualKeyCode -ne 0xA5) {
										$hasKeyboardEvent = $true
									}
								}
								# Consume scroll and click events to prevent buffer buildup
								$maxConsumeIdx = [Math]::Max($lastScrollIdx, $lastClickIdx)
								if ($maxConsumeIdx -ge 0) {
									$consumeCount = [uint32]($maxConsumeIdx + 1)
									$flushBuffer = New-Object 'mJiggAPI.INPUT_RECORD[]' $consumeCount
									$flushed = [uint32]0
									[mJiggAPI.Mouse]::ReadConsoleInput($hStdIn, $flushBuffer, $consumeCount, [ref]$flushed) | Out-Null
								}
								if ($hasScrollEvent) {
									$scrollDetected = $true
									$scrollDetectedInInterval = $true
									$otherText = "Scroll/Other"
									if ($intervalMouseInputs -notcontains $otherText) {
										$intervalMouseInputs += $otherText
									}
									$mouseInputDetected = $true
									$script:userInputDetected = $true
									if ($script:AutoResumeDelaySeconds -gt 0) {
										$LastUserInputTime = Get-Date
									}
									if ($script:DiagEnabled) { "$(Get-Date -Format 'HH:mm:ss.fff') - PeekConsoleInput: scroll detected (events=$peekEvents)" | Out-File $script:InputDiagFile -Append }
								}
								if ($hasKeyboardEvent) {
									$keyboardInputDetected = $true
									$script:userInputDetected = $true
									if ($script:AutoResumeDelaySeconds -gt 0) {
										$LastUserInputTime = Get-Date
									}
									if ($script:DiagEnabled) { "$(Get-Date -Format 'HH:mm:ss.fff') - PeekConsoleInput: keyboard detected (events=$peekEvents)" | Out-File $script:InputDiagFile -Append }
								}
							}
						} catch {
							if ($script:DiagEnabled) { "$(Get-Date -Format 'HH:mm:ss.fff') - PeekConsoleInput ERROR: $($_.Exception.Message)" | Out-File $script:InputDiagFile -Append }
						}
						
						# Detect user input via GetLastInputInfo (system-wide, passive)
						# Keyboard and scroll are evidence-based (PeekConsoleInput).
						# If GetLastInputInfo sees activity that wasn't classified as keyboard or scroll,
						# it's almost certainly mouse movement.
						try {
							$lii = New-Object mJiggAPI.LASTINPUTINFO
							$lii.cbSize = [uint32][System.Runtime.InteropServices.Marshal]::SizeOf([type][mJiggAPI.LASTINPUTINFO])
							$liiResult = [mJiggAPI.Mouse]::GetLastInputInfo([ref]$lii)
							if ($liiResult) {
								$tickNow = [uint64][mJiggAPI.Mouse]::GetTickCount64()
								$lastInputTick = [uint64]$lii.dwTime
								$systemIdleMs = $tickNow - $lastInputTick
								$recentSimulated = ($null -ne $LastSimulatedKeyPress) -and ((Get-TimeSinceMs -startTime $LastSimulatedKeyPress) -lt 500)
								$recentAutoMove = ($null -ne $LastAutomatedMouseMovement) -and ((Get-TimeSinceMs -startTime $LastAutomatedMouseMovement) -lt 500)
								if ($script:DiagEnabled) {
									$ts = Get-Date -Format 'HH:mm:ss.fff'
									"$ts - LII idleMs=$systemIdleMs simFilter=$recentSimulated autoFilter=$recentAutoMove kbDet=$keyboardInputDetected msDet=$mouseInputDetected scrollInt=$scrollDetectedInInterval" | Out-File $script:InputDiagFile -Append
								}
								if ($systemIdleMs -lt 300 -and -not $recentSimulated -and -not $recentAutoMove) {
									$script:userInputDetected = $true
									if ($script:AutoResumeDelaySeconds -gt 0) {
										$LastUserInputTime = Get-Date
									}
									if (-not $keyboardInputDetected -and -not $scrollDetectedInInterval -and -not $mouseInputDetected) {
										$mouseInputDetected = $true
										$script:LastMouseMovementTime = Get-Date
										$mouseMoveText = "Mouse"
										if ($intervalMouseInputs -notcontains $mouseMoveText) {
											$intervalMouseInputs += $mouseMoveText
										}
										if ($script:DiagEnabled) { "  >> userInput=TRUE idleMs=$systemIdleMs -> mouse (no kb/scroll/click evidence)" | Out-File $script:InputDiagFile -Append }
									} else {
										if ($script:DiagEnabled) { "  >> userInput=TRUE idleMs=$systemIdleMs (already classified: kb=$keyboardInputDetected ms=$mouseInputDetected scroll=$scrollDetectedInInterval)" | Out-File $script:InputDiagFile -Append }
									}
								}
							}
						} catch {
							if ($script:DiagEnabled) { "$(Get-Date -Format 'HH:mm:ss.fff') - GetLastInputInfo ERROR: $($_.Exception.Message)" | Out-File $script:InputDiagFile -Append }
						}
						
						# Check for left-click via console input buffer (exact cell coordinates from the console)
						if ($null -ne $script:ConsoleClickCoords) {
							$consoleX = $script:ConsoleClickCoords.X
							$consoleY = $script:ConsoleClickCoords.Y
							
							# Check dialog buttons first (if a dialog is open)
							if ($null -ne $script:DialogButtonBounds) {
								$bounds = $script:DialogButtonBounds
								if ($consoleY -eq $bounds.buttonRowY -and $consoleX -ge $bounds.updateStartX -and $consoleX -le $bounds.updateEndX) {
									$script:DialogButtonClick = "Update"
								} elseif ($consoleY -eq $bounds.buttonRowY -and $consoleX -ge $bounds.cancelStartX -and $consoleX -le $bounds.cancelEndX) {
									$script:DialogButtonClick = "Cancel"
								}
							}
							
					# Check output button in header
				if ($null -eq $script:DialogButtonBounds -and $null -ne $script:ModeButtonBounds) {
					$mb = $script:ModeButtonBounds
					if ($consoleY -eq $mb.y -and $consoleX -ge $mb.startX -and $consoleX -le $mb.endX) {
						$script:MenuClickHotkey = "o"
					}
				}
					# Check hidden time click regions (no dialog check — these are header-level easter eggs)
					if ($null -eq $script:DialogButtonBounds -and $null -eq $script:MenuClickHotkey) {
						if ($null -ne $script:HeaderEndTimeBounds) {
							$b = $script:HeaderEndTimeBounds
							if ($consoleY -eq $b.y -and $consoleX -ge $b.startX -and $consoleX -le $b.endX) {
								$script:MenuClickHotkey = "t"  # opens Set End Time dialog
							}
						}
					if ($null -eq $script:MenuClickHotkey -and $null -ne $script:HeaderCurrentTimeBounds) {
						$b = $script:HeaderCurrentTimeBounds
						if ($consoleY -eq $b.y -and $consoleX -ge $b.startX -and $consoleX -le $b.endX) {
							Start-Process "control.exe" -ArgumentList "timedate.cpl"
						}
					}
					if ($null -eq $script:MenuClickHotkey -and $null -ne $script:HeaderLogoBounds) {
						$b = $script:HeaderLogoBounds
						if ($consoleY -eq $b.y -and $consoleX -ge $b.startX -and $consoleX -le $b.endX) {
							$script:MenuClickHotkey = "?"  # opens info/about dialog
						}
					}
				}

						# Check menu items (only when no dialog is open)
						if ($null -eq $script:DialogButtonBounds -and $null -ne $script:MenuItemsBounds -and $script:MenuItemsBounds.Count -gt 0) {
							foreach ($menuItem in $script:MenuItemsBounds) {
								if ($null -ne $menuItem.hotkey -and $consoleY -eq $menuItem.y -and $consoleX -ge $menuItem.startX -and $consoleX -le $menuItem.endX) {
									$script:MenuClickHotkey = $menuItem.hotkey
									break
								}
							}
						}
							
							if ($DebugMode) {
								$clickTarget = "none"
								if ($null -ne $script:DialogButtonClick) { $clickTarget = "Dialog:$($script:DialogButtonClick)" }
								elseif ($null -ne $script:MenuClickHotkey) { $clickTarget = "Menu:$($script:MenuClickHotkey)" }
								if ($null -eq $LogArray -or -not ($LogArray -is [Array])) { $LogArray = @() }
								$LogArray += [PSCustomObject]@{
									logRow = $true
									components = @(
										@{ priority = 1; text = (Get-Date).ToString("HH:mm:ss"); shortText = (Get-Date).ToString("HH:mm:ss") },
										@{ priority = 2; text = " - [DEBUG] LButton click at console ($consoleX,$consoleY), target: $clickTarget"; shortText = " - [DEBUG] Click ($consoleX,$consoleY) -> $clickTarget" }
									)
								}
							}
						}
						
						# Check mouse buttons (0x01-0x06) for input detection (pause jiggler)
						for ($keyCode = 0x01; $keyCode -le 0x06; $keyCode++) {
							if ($keyCode -eq 0x03) { continue }  # 0x03 is VK_CANCEL, not a mouse button
							$currentKeyState = [mJiggAPI.Mouse]::GetAsyncKeyState($keyCode)
							$isCurrentlyPressed = (($currentKeyState -band 0x8000) -ne 0)
							$wasJustPressed = (($currentKeyState -band 0x0001) -ne 0)
							$wasPreviouslyPressed = if ($script:previousKeyStates.ContainsKey($keyCode)) { $script:previousKeyStates[$keyCode] } else { $false }
							
							if ($wasJustPressed -or ($isCurrentlyPressed -and -not $wasPreviouslyPressed)) {
								
								$mouseButtonName = switch ($keyCode) {
									0x01 { "LButton" }
									0x02 { "RButton" }
									0x04 { "MButton" }
									0x05 { "XButton1" }
									0x06 { "XButton2" }
								}
								if ($mouseButtonName -and $intervalMouseInputs -notcontains $mouseButtonName) {
									$intervalMouseInputs += $mouseButtonName
									$script:userInputDetected = $true
									$mouseInputDetected = $true
									if ($script:AutoResumeDelaySeconds -gt 0) {
										$LastUserInputTime = Get-Date
									}
								}
							}
							$script:previousKeyStates[$keyCode] = $isCurrentlyPressed
						}
					}
					
					# Check for console keyboard input (menu hotkeys) - only every 200ms to avoid stutter
					# Also check for menu clicks immediately (they're set by mouse click handler)
					$menuHotkeyToProcess = $null
					if ($null -ne $script:MenuClickHotkey) {
						# Menu item was clicked - process it immediately
						$menuHotkeyToProcess = $script:MenuClickHotkey
						$script:MenuClickHotkey = $null  # Clear it after using
					} elseif ($x % 4 -eq 0) {
						# Read available keys for menu hotkeys (only every 200ms)
						$lastKeyPress = $null
						$lastKeyInfo = $null
						$keysRead = 0
						$maxKeysToRead = 10  # Limit to prevent infinite loops
						while ($Host.UI.RawUI.KeyAvailable -and $keysRead -lt $maxKeysToRead) {
							try {
								$keyInfo = $Host.UI.RawUI.ReadKey("IncludeKeyup,NoEcho")
								$keysRead++
								$keyPress = $keyInfo.Character
								$isEscape = ($keyInfo.Key -eq "Escape" -or $keyInfo.VirtualKeyCode -eq 27)
								$isKeyDown = if ($null -ne $keyInfo.KeyDown) { $keyInfo.KeyDown } else { $false }
								
								# Only process key up events
								if (-not $isKeyDown) {
									$keyId = if ($isEscape) { "Escape" } elseif ($keyPress) { $keyPress } else { $null }
									if ($keyId) {
										if ($isEscape) {
											$lastKeyPress = "Escape"
											$lastKeyInfo = $keyInfo
										} else {
											$lastKeyPress = $keyPress
											$lastKeyInfo = $keyInfo
										}
									}
								}
							} catch {
								break
							}
						}
					}
					
					# Process menu hotkeys (check both lastKeyPress and menuHotkeyToProcess)
					if ($null -ne $menuHotkeyToProcess) {
						# Process menu click hotkey immediately
						$lastKeyPress = $menuHotkeyToProcess
						$lastKeyInfo = $null
					}
					
					if ($null -ne $lastKeyPress -or $null -ne $lastKeyInfo) {
						$shouldProcessEscape = ($lastKeyPress -eq "Escape" -or ($null -ne $lastKeyInfo -and ($lastKeyInfo.Key -eq "Escape" -or $lastKeyInfo.VirtualKeyCode -eq 27)))
						if ($shouldProcessEscape) {
							$lastKeyPress = $null
							$lastKeyInfo = $null
							$HostWidthRef = [ref]$HostWidth
							$HostHeightRef = [ref]$HostHeight
							$quitResult = Show-QuitConfirmationDialog -hostWidthRef $HostWidthRef -hostHeightRef $HostHeightRef
							$HostWidth = $HostWidthRef.Value
							$HostHeight = $HostHeightRef.Value
							if ($quitResult.NeedsRedraw) {
								$SkipUpdate = $true
								$forceRedraw = $true
								clear-host
								break
							}
							if ($quitResult.Result -eq $true) {
								Clear-Host
								$runtime = (Get-Date) - $ScriptStartTime
								$hours = [math]::Floor($runtime.TotalHours)
								$minutes = $runtime.Minutes
								$seconds = $runtime.Seconds
								$runtimeStr = ""
								if ($hours -gt 0) {
									$runtimeStr = "$hours hour$(if ($hours -ne 1) { 's' }), $minutes minute$(if ($minutes -ne 1) { 's' })"
								} elseif ($minutes -gt 0) {
									$runtimeStr = "$minutes minute$(if ($minutes -ne 1) { 's' }), $seconds second$(if ($seconds -ne 1) { 's' })"
								} else {
									$runtimeStr = "$seconds second$(if ($seconds -ne 1) { 's' })"
								}
								Write-Host ""
								$mouseEmoji = [char]::ConvertFromUtf32(0x1F400)
								Write-Host "  mJig($mouseEmoji) " -NoNewline -ForegroundColor $script:HeaderAppName
								Write-Host "Stopped" -ForegroundColor $script:TextError
								Write-Host ""
								Write-Host "  Runtime: " -NoNewline -ForegroundColor $script:StatsBoxLabel
								Write-Host $runtimeStr -ForegroundColor $script:StatsBoxValue
								Write-Host ""
								return
							} else {
								$SkipUpdate = $true
								$forceRedraw = $true
								clear-host
								break
							}
						} elseif ($lastKeyPress -eq "q") {
								$lastKeyPress = $null
								$lastKeyInfo = $null
								
								# Debug: Log quit dialog opened
								if ($DebugMode) {
									if ($null -eq $LogArray -or -not ($LogArray -is [Array])) {
										$LogArray = @()
									}
									$LogArray += [PSCustomObject]@{
										logRow = $true
										components = @(
											@{
												priority = 1
												text = (Get-Date).ToString("HH:mm:ss")
												shortText = (Get-Date).ToString("HH:mm:ss")
											},
											@{
												priority = 2
												text = " - [DEBUG] Quit dialog opened"
												shortText = " - [DEBUG] Quit opened"
											}
										)
									}
								}
								
								$HostWidthRef = [ref]$HostWidth
								$HostHeightRef = [ref]$HostHeight
								$quitResult = Show-QuitConfirmationDialog -hostWidthRef $HostWidthRef -hostHeightRef $HostHeightRef
								$HostWidth = $HostWidthRef.Value
								$HostHeight = $HostHeightRef.Value
								if ($quitResult.NeedsRedraw) {
									$SkipUpdate = $true
									$forceRedraw = $true
									clear-host
									break
								}
								if ($quitResult.Result -eq $true) {
									# Debug: Log quit confirmed
									if ($DebugMode) {
										if ($null -eq $LogArray -or -not ($LogArray -is [Array])) {
											$LogArray = @()
										}
										$LogArray += [PSCustomObject]@{
											logRow = $true
											components = @(
												@{
													priority = 1
													text = (Get-Date).ToString("HH:mm:ss")
													shortText = (Get-Date).ToString("HH:mm:ss")
												},
												@{
													priority = 2
													text = " - [DEBUG] Quit confirmed"
													shortText = " - [DEBUG] Quit confirmed"
												}
											)
										}
									}
									Clear-Host
									$runtime = (Get-Date) - $ScriptStartTime
									$hours = [math]::Floor($runtime.TotalHours)
									$minutes = $runtime.Minutes
									$seconds = $runtime.Seconds
									$runtimeStr = ""
									if ($hours -gt 0) {
										$runtimeStr = "$hours hour$(if ($hours -ne 1) { 's' }), $minutes minute$(if ($minutes -ne 1) { 's' })"
									} elseif ($minutes -gt 0) {
										$runtimeStr = "$minutes minute$(if ($minutes -ne 1) { 's' }), $seconds second$(if ($seconds -ne 1) { 's' })"
									} else {
										$runtimeStr = "$seconds second$(if ($seconds -ne 1) { 's' })"
									}
									Write-Host ""
									$mouseEmoji = [char]::ConvertFromUtf32(0x1F400)
									Write-Host "  mJig(" -NoNewline -ForegroundColor $script:HeaderAppName
									$mouseEmojiX = $Host.UI.RawUI.CursorPosition.X
									$mouseEmojiY = $Host.UI.RawUI.CursorPosition.Y
									Write-Host $mouseEmoji -NoNewline -ForegroundColor $script:HeaderIcon
									[Console]::SetCursorPosition($mouseEmojiX + 2, $mouseEmojiY)
									Write-Host ") " -NoNewline -ForegroundColor $script:HeaderAppName
									Write-Host "Stopped" -ForegroundColor $script:TextError
									Write-Host ""
									Write-Host "  Runtime: " -NoNewline -ForegroundColor $script:StatsBoxLabel
									Write-Host $runtimeStr -ForegroundColor $script:StatsBoxValue
									Write-Host ""
									return
								} else {
									# Debug: Log quit canceled
									if ($DebugMode) {
										if ($null -eq $LogArray -or -not ($LogArray -is [Array])) {
											$LogArray = @()
										}
										$LogArray += [PSCustomObject]@{
											logRow = $true
											components = @(
												@{
													priority = 1
													text = (Get-Date).ToString("HH:mm:ss")
													shortText = (Get-Date).ToString("HH:mm:ss")
												},
												@{
													priority = 2
													text = " - [DEBUG] Quit canceled"
													shortText = " - [DEBUG] Quit canceled"
												}
											)
										}
									}
									$SkipUpdate = $true
									$forceRedraw = $true
									clear-host
									break
								}
				} elseif ($lastKeyPress -eq "o" -and $Output -ne "hidden") {
					$oldOutput = $Output
					if ($Output -eq "full") {
						$Output = "min"
					} else {
						$Output = "full"
					}
					$script:Output = $Output
						# Debug: Log view toggle
						if ($DebugMode) {
							if ($null -eq $LogArray -or -not ($LogArray -is [Array])) {
								$LogArray = @()
							}
							$LogArray += [PSCustomObject]@{
								logRow = $true
								components = @(
									@{
										priority = 1
										text = (Get-Date).ToString("HH:mm:ss")
										shortText = (Get-Date).ToString("HH:mm:ss")
									},
									@{
										priority = [int]2
										text = " - [DEBUG] View toggle: $oldOutput $([char]0x2192) $Output"
										shortText = " - [DEBUG] View: $oldOutput $([char]0x2192) $Output"
									}
								)
							}
						}
						$SkipUpdate = $true
						$forceRedraw = $true
						clear-host
						break
					} elseif ($lastKeyPress -eq "i") {
					$oldOutput = $Output
					if ($Output -eq "hidden") {
						if ($PreviousView -ne $null) {
							$Output = $PreviousView
						} else {
							$Output = "min"
						}
						$PreviousView = $null
					} else {
						$PreviousView = $Output
						$Output = "hidden"
						$script:MenuItemsBounds = @()
					}
					$script:Output = $Output
						# Debug: Log incognito toggle
						if ($DebugMode) {
							if ($null -eq $LogArray -or -not ($LogArray -is [Array])) {
								$LogArray = @()
							}
							$LogArray += [PSCustomObject]@{
								logRow = $true
								components = @(
									@{
										priority = 1
										text = (Get-Date).ToString("HH:mm:ss")
										shortText = (Get-Date).ToString("HH:mm:ss")
									},
									@{
										priority = [int]2
										text = " - [DEBUG] Incognito toggle: $oldOutput $([char]0x2192) $Output"
										shortText = " - [DEBUG] Incognito: $oldOutput $([char]0x2192) $Output"
									}
								)
							}
						}
						$SkipUpdate = $true
						$forceRedraw = $true
						clear-host
						break
				} elseif ($lastKeyPress -eq "s") {
					$lastKeyPress = $null
					$lastKeyInfo  = $null
					$HostWidthRef  = [ref]$HostWidth;  $HostHeightRef = [ref]$HostHeight
					$endTimeIntRef = [ref]$endTimeInt; $endTimeStrRef = [ref]$endTimeStr
					$endRef        = [ref]$end;        $logArrayRef   = [ref]$LogArray
					$settingsResult = Show-SettingsDialog `
						-HostWidthRef $HostWidthRef -HostHeightRef $HostHeightRef `
						-EndTimeIntRef $endTimeIntRef -EndTimeStrRef $endTimeStrRef `
						-EndRef $endRef -LogArrayRef $logArrayRef
			$HostWidth  = $HostWidthRef.Value;  $HostHeight = $HostHeightRef.Value
			$endTimeInt = $endTimeIntRef.Value; $endTimeStr = $endTimeStrRef.Value
			$end        = $endRef.Value;        $LogArray   = $logArrayRef.Value
			$Output    = $script:Output
			$DebugMode = $script:DebugMode
			if ($settingsResult.ReopenSettings) {
					# Sub-dialog was used — flag so the main loop reopens settings
					# after it has repainted the full screen cleanly.
					$script:PendingReopenSettings = $true
				}
				$SkipUpdate  = $true
				$forceRedraw = $true
				clear-host
				break
					} elseif ($lastKeyPress -eq "m" -and $Output -ne "hidden") {
							# Debug: Log movement dialog opened (before calling dialog)
							if ($DebugMode) {
									if ($null -eq $LogArray -or -not ($LogArray -is [Array])) {
										$LogArray = @()
									}
									$LogArray += [PSCustomObject]@{
										logRow = $true
										components = @(
											@{
												priority = 1
												text = (Get-Date).ToString("HH:mm:ss")
												shortText = (Get-Date).ToString("HH:mm:ss")
											},
											@{
												priority = 2
												text = " - [DEBUG] Movement dialog opened"
												shortText = " - [DEBUG] Movement opened"
											}
										)
									}
								}
								
								$HostWidthRef = [ref]$HostWidth
								$HostHeightRef = [ref]$HostHeight
								$dialogResult = Show-MovementModifyDialog -currentIntervalSeconds $script:IntervalSeconds -currentIntervalVariance $script:IntervalVariance -currentMoveSpeed $script:MoveSpeed -currentMoveVariance $script:MoveVariance -currentTravelDistance $script:TravelDistance -currentTravelVariance $script:TravelVariance -currentAutoResumeDelaySeconds $script:AutoResumeDelaySeconds -hostWidthRef $HostWidthRef -hostHeightRef $HostHeightRef
								$HostWidth = $HostWidthRef.Value
								$HostHeight = $HostHeightRef.Value
								
								# Debug: Verify logs are preserved after dialog closes
								if ($DebugMode) {
									if ($null -eq $LogArray -or -not ($LogArray -is [Array])) {
										$LogArray = @()
									}
									$LogArray += [PSCustomObject]@{
										logRow = $true
										components = @(
											@{
												priority = 1
												text = (Get-Date).ToString("HH:mm:ss")
												shortText = (Get-Date).ToString("HH:mm:ss")
											},
											@{
												priority = 2
												text = " - [DEBUG] Movement dialog closed"
												shortText = " - [DEBUG] Movement closed"
											}
										)
									}
								}
								
								if ($dialogResult.NeedsRedraw) {
									$SkipUpdate = $true
									$forceRedraw = $true
									clear-host
									break
								}
								if ($null -ne $dialogResult.Result) {
									$oldIntervalSeconds = $script:IntervalSeconds
									$oldIntervalVariance = $script:IntervalVariance
									$oldMoveSpeed = $script:MoveSpeed
									$oldMoveVariance = $script:MoveVariance
									$oldTravelDistance = $script:TravelDistance
									$oldTravelVariance = $script:TravelVariance
									$oldAutoResumeDelaySeconds = $script:AutoResumeDelaySeconds
									$script:IntervalSeconds = $dialogResult.Result.IntervalSeconds
									$script:IntervalVariance = $dialogResult.Result.IntervalVariance
									$script:MoveSpeed = $dialogResult.Result.MoveSpeed
									$script:MoveVariance = $dialogResult.Result.MoveVariance
									$script:TravelDistance = $dialogResult.Result.TravelDistance
									$script:TravelVariance = $dialogResult.Result.TravelVariance
									$script:AutoResumeDelaySeconds = $dialogResult.Result.AutoResumeDelaySeconds
									$changeDetails = @()
									$arrowChar = [char]0x2192
									if ($oldIntervalSeconds -ne $script:IntervalSeconds) { $changeDetails += "Interval: $oldIntervalSeconds $arrowChar $($script:IntervalSeconds)" }
									if ($oldIntervalVariance -ne $script:IntervalVariance) { $changeDetails += "IntervalVar: $oldIntervalVariance $arrowChar $($script:IntervalVariance)" }
									if ($oldMoveSpeed -ne $script:MoveSpeed) { $changeDetails += "Speed: $oldMoveSpeed $arrowChar $($script:MoveSpeed)" }
									if ($oldMoveVariance -ne $script:MoveVariance) { $changeDetails += "SpeedVar: $oldMoveVariance $arrowChar $($script:MoveVariance)" }
									if ($oldTravelDistance -ne $script:TravelDistance) { $changeDetails += "Distance: $oldTravelDistance $arrowChar $($script:TravelDistance)" }
									if ($oldTravelVariance -ne $script:TravelVariance) { $changeDetails += "DistVar: $oldTravelVariance $arrowChar $($script:TravelVariance)" }
									if ($oldAutoResumeDelaySeconds -ne $script:AutoResumeDelaySeconds) { $changeDetails += "Delay: $oldAutoResumeDelaySeconds $arrowChar $($script:AutoResumeDelaySeconds)" }
									if ($changeDetails.Count -gt 0) {
										$changeDate = Get-Date
										$changeMessage = " - Settings updated: " + ($changeDetails -join ", ")
										$changeShortMessage = " - Updated: " + ($changeDetails -join ", ")
										$changeLogComponents = @(
											@{priority = 1; text = $changeDate.ToString(); shortText = $changeDate.ToString("HH:mm:ss")},
											@{priority = 2; text = $changeMessage; shortText = $changeShortMessage}
										)
										$LogArray += [PSCustomObject]@{logRow = $true; components = $changeLogComponents}
									}
								}
								$SkipUpdate = $true
								$forceRedraw = $true
								clear-host
								break
							} elseif ($lastKeyPress -eq "t") {
								# Debug: Log time dialog opened (before calling dialog)
								if ($DebugMode) {
									if ($null -eq $LogArray -or -not ($LogArray -is [Array])) {
										$LogArray = @()
									}
									$LogArray += [PSCustomObject]@{
										logRow = $true
										components = @(
											@{
												priority = 1
												text = (Get-Date).ToString("HH:mm:ss")
												shortText = (Get-Date).ToString("HH:mm:ss")
											},
											@{
												priority = 2
												text = " - [DEBUG] Time dialog opened"
												shortText = " - [DEBUG] Time opened"
											}
										)
									}
								}
								
								$HostWidthRef = [ref]$HostWidth
								$HostHeightRef = [ref]$HostHeight
								$dialogResult = Show-TimeChangeDialog -currentEndTime $endTimeInt -hostWidthRef $HostWidthRef -hostHeightRef $HostHeightRef
								$HostWidth = $HostWidthRef.Value
								$HostHeight = $HostHeightRef.Value
								
								# Debug: Verify logs are preserved after dialog closes
								if ($DebugMode) {
									if ($null -eq $LogArray -or -not ($LogArray -is [Array])) {
										$LogArray = @()
									}
									$LogArray += [PSCustomObject]@{
										logRow = $true
										components = @(
											@{
												priority = 1
												text = (Get-Date).ToString("HH:mm:ss")
												shortText = (Get-Date).ToString("HH:mm:ss")
											},
											@{
												priority = 2
												text = " - [DEBUG] Time dialog closed"
												shortText = " - [DEBUG] Time closed"
											}
										)
									}
								}
								
								if ($dialogResult.NeedsRedraw) {
									$SkipUpdate = $true
									$forceRedraw = $true
									clear-host
									break
								}
								if ($null -ne $dialogResult.Result) {
									$oldEndTimeInt = $endTimeInt
									$oldEndTimeStr = $endTimeStr
									if ($dialogResult.Result -eq -1) {
										$endTimeInt = -1
										$endTimeStr = ""
										$end = ""
										$changeDate = Get-Date
										$changeMessage = if ([string]::IsNullOrEmpty($oldEndTimeStr)) {" - End time cleared"} else {" - End time cleared (was: $oldEndTimeStr)"}
										$changeShortMessage = " - End time cleared"
										$changeLogComponents = @(
											@{priority = 1; text = $changeDate.ToString(); shortText = $changeDate.ToString("HH:mm:ss")},
											@{priority = 2; text = $changeMessage; shortText = $changeShortMessage}
										)
										$LogArray += [PSCustomObject]@{logRow = $true; components = $changeLogComponents}
									} else {
										$endTimeInt = $dialogResult.Result
										$endTimeStr = $endTimeInt.ToString().PadLeft(4, '0')
										$currentTime = Get-Date -Format "HHmm"
										$isTomorrow = $endTimeInt -le [int]$currentTime
										if ($isTomorrow) {
											$tommorow = (Get-Date).AddDays(1)
											$endDate = Get-Date $tommorow -Format "MMdd"
										} else {
											$endDate = Get-Date -Format "MMdd"
										}
										$end = "$endDate$endTimeStr"
										$changeDate = Get-Date
										$arrowChar = [char]0x2192
										$dayLabel = if ($isTomorrow) { " (tomorrow)" } else { " (today)" }
										$endDateDisplay = $endDate.Substring(0,2) + "/" + $endDate.Substring(2,2)
										$endTimeDisplay = $endTimeStr.Substring(0,2) + ":" + $endTimeStr.Substring(2,2)
										$changeMessage = if ($oldEndTimeInt -eq -1 -or [string]::IsNullOrEmpty($oldEndTimeStr)) {" - End time set: $endDateDisplay $endTimeDisplay$dayLabel"} else {" - End time changed: $oldEndTimeStr $arrowChar $endDateDisplay $endTimeDisplay$dayLabel"}
										$changeShortMessage = " - End time: $endDateDisplay $endTimeDisplay"
										$changeLogComponents = @(
											@{priority = 1; text = $changeDate.ToString(); shortText = $changeDate.ToString("HH:mm:ss")},
											@{priority = 2; text = $changeMessage; shortText = $changeShortMessage}
										)
										$LogArray += [PSCustomObject]@{logRow = $true; components = $changeLogComponents}
									}
								}
							$SkipUpdate = $true
							$forceRedraw = $true
							clear-host
							break
				} elseif (($lastKeyPress -eq "?" -or $lastKeyPress -eq "/") -and $Output -ne "hidden") {
						$lastKeyPress = $null
						$lastKeyInfo  = $null
						$HostWidthRef  = [ref]$HostWidth
						$HostHeightRef = [ref]$HostHeight
						$infoResult = Show-InfoDialog -hostWidthRef $HostWidthRef -hostHeightRef $HostHeightRef
						$HostWidth  = $HostWidthRef.Value
						$HostHeight = $HostHeightRef.Value
						$SkipUpdate  = $true
						$forceRedraw = $true
						clear-host
						break
					}
				}
				
				# Check for window size changes - process only when window stops resizing
					# Only check every 200ms (every 4th iteration) to avoid blocking Windows from processing mouse messages
					# Frequent window property access can interfere with cursor rendering during user mouse movement
					if ($Output -ne "hidden" -and ($x % 4 -eq 0)) {
						$pshost = Get-Host
						$pswindow = $pshost.UI.RawUI
						$newWindowSize = $pswindow.WindowSize
						$newBufferSize = $pswindow.BufferSize
						
						# Check if buffer size changed (e.g., from text zoom)
						# When text is zoomed, horizontal buffer size changes - this determines line length
						$bufferSizeChanged = ($null -eq $OldBufferSize -or 
							$newBufferSize.Width -ne $OldBufferSize.Width -or 
							$newBufferSize.Height -ne $OldBufferSize.Height)
						
						# Check if horizontal buffer changed but window width didn't (text zoom)
						# Also ensure vertical buffer matches window height
						$horizontalBufferChanged = ($null -ne $OldBufferSize -and $newBufferSize.Width -ne $OldBufferSize.Width)
						$windowWidthUnchanged = ($null -ne $oldWindowSize -and $newWindowSize.Width -eq $oldWindowSize.Width)
						
						# Set vertical buffer to match window height
						if ($newBufferSize.Height -ne $newWindowSize.Height) {
							try {
								$pswindow.BufferSize = New-Object System.Management.Automation.Host.Size($newBufferSize.Width, $newWindowSize.Height)
								$newBufferSize = $pswindow.BufferSize
							} catch {
								# If setting buffer size fails, continue with current buffer size
							}
						}
						
						# If horizontal buffer changed but window width didn't, it's text zoom - use buffer width for line length
						if ($horizontalBufferChanged -and $windowWidthUnchanged -and $null -ne $OldBufferSize) {
							# Text zoom detected - use buffer width for line length calculations
							$OldBufferSize = $newBufferSize
							# Use buffer width for HostWidth (determines line length), window height for HostHeight
							$HostWidth = $newBufferSize.Width
							$HostHeight = $newWindowSize.Height
							# Don't update oldWindowSize - keep the original so resize handler doesn't trigger
							$SkipUpdate = $true
							$forceRedraw = $true
							$waitExecuted = $false
							clear-host
							break
						}
						

						# Check if window size is different from what we last processed (oldWindowSize)
						# Skip this check if we just handled a text zoom
						$windowSizeChanged = ($null -eq $oldWindowSize -or
							$newWindowSize.Width -ne $oldWindowSize.Width -or
							$newWindowSize.Height -ne $oldWindowSize.Height)

						if ($windowSizeChanged) {
							# Unified handler — blocks until stable and LMB released, draws logo or blank
							$stableSize = Invoke-ResizeHandler
							$currentBufferSize = $pswindow.BufferSize
							try {
								$pswindow.BufferSize = New-Object System.Management.Automation.Host.Size($currentBufferSize.Width, $stableSize.Height)
							} catch {}
							$OldBufferSize       = $pswindow.BufferSize
							$oldWindowSize       = $stableSize
							$HostWidth           = $stableSize.Width
							$HostHeight          = $stableSize.Height
							$PendingResize       = $null
							$lastResizeDetection = $null
							$ResizeClearedScreen = $false
							$LastResizeLogoTime  = $null
							$SkipUpdate          = $true
							$forceRedraw         = $true
							$waitExecuted        = $false
						break
					}
				}

				# Hidden mode: unified resize handler (draws blank screen, waits for stability + LMB release)
				if ($Output -eq "hidden" -and ($x % 4 -eq 0)) {
					$hwSize = (Get-Host).UI.RawUI.WindowSize
					if ($null -ne $OldWindowSize -and ($hwSize.Width -ne $OldWindowSize.Width -or $hwSize.Height -ne $OldWindowSize.Height)) {
						$stableSize          = Invoke-ResizeHandler
						$oldWindowSize       = $stableSize
						$HostWidth           = $stableSize.Width
						$HostHeight          = $stableSize.Height
						$PendingResize       = $null
						$lastResizeDetection = $null
						$ResizeClearedScreen = $false
						$forceRedraw         = $true
						$waitExecuted        = $false
						break
					}
				}
				
				start-sleep -m 50
				
				# Check if we've waited long enough
				if ($x -ge $math) {
					break
				}
			} # end :waitLoop
			}
			
			# Keyboard and mouse input checking is now done every 200ms in the wait loop above
			# This provides more reliable detection compared to checking once per interval
			
			# Safety net: detect user input via GetLastInputInfo after wait loop.
			# Same inference as wait-loop: unclassified activity → mouse movement.
			try {
				$lii = New-Object mJiggAPI.LASTINPUTINFO
				$lii.cbSize = [uint32][System.Runtime.InteropServices.Marshal]::SizeOf([type][mJiggAPI.LASTINPUTINFO])
				if ([mJiggAPI.Mouse]::GetLastInputInfo([ref]$lii)) {
					$tickNow = [uint64][mJiggAPI.Mouse]::GetTickCount64()
					$lastInputTick = [uint64]$lii.dwTime
					$systemIdleMs = $tickNow - $lastInputTick
					$recentSimulated = ($null -ne $LastSimulatedKeyPress) -and ((Get-TimeSinceMs -startTime $LastSimulatedKeyPress) -lt 500)
					$recentAutoMove = ($null -ne $LastAutomatedMouseMovement) -and ((Get-TimeSinceMs -startTime $LastAutomatedMouseMovement) -lt 500)

					if ($systemIdleMs -lt 300 -and -not $recentSimulated -and -not $recentAutoMove) {
						$script:userInputDetected = $true
						if ($script:AutoResumeDelaySeconds -gt 0) {
							$LastUserInputTime = Get-Date
						}
						if (-not $keyboardInputDetected -and -not $scrollDetectedInInterval -and -not $mouseInputDetected) {
							$mouseInputDetected = $true
							$script:LastMouseMovementTime = Get-Date
							$mouseMoveText = "Mouse"
							if ($intervalMouseInputs -notcontains $mouseMoveText) {
								$intervalMouseInputs += $mouseMoveText
							}
						}
					}
				}
			} catch {
				# GetLastInputInfo not available, skip
			}
			
			# Check for window size changes outside the wait loop (catches resizes that happen during rendering)
		if (-not $forceRedraw) {
			$pshost     = Get-Host
			$pswindow   = $pshost.UI.RawUI
			$newWindowSize = $pswindow.WindowSize
			$newBufferSize = $pswindow.BufferSize

			# Ensure vertical buffer matches window height
			if ($newBufferSize.Height -ne $newWindowSize.Height) {
				try {
					$pswindow.BufferSize = New-Object System.Management.Automation.Host.Size($newBufferSize.Width, $newWindowSize.Height)
					$newBufferSize = $pswindow.BufferSize
				} catch {}
			}

			# Detect text zoom: horizontal buffer changed but window width did not
			$horizontalBufferChanged = ($null -ne $OldBufferSize -and $newBufferSize.Width -ne $OldBufferSize.Width)
			$windowWidthUnchanged    = ($null -ne $oldWindowSize -and $newWindowSize.Width -eq $oldWindowSize.Width)

			if ($horizontalBufferChanged -and $windowWidthUnchanged -and $null -ne $OldBufferSize) {
				$OldBufferSize = $newBufferSize
				$HostWidth     = $newBufferSize.Width
				$HostHeight    = $newWindowSize.Height
				$SkipUpdate    = $true
				$forceRedraw   = $true
				clear-host
			} elseif ($null -ne $oldWindowSize -and
					($newWindowSize.Width -ne $oldWindowSize.Width -or $newWindowSize.Height -ne $oldWindowSize.Height)) {
				# Unified handler — blocks until stable and LMB released
				$stableSize          = Invoke-ResizeHandler
				$currentBufferSize   = $pswindow.BufferSize
				try {
					$pswindow.BufferSize = New-Object System.Management.Automation.Host.Size($currentBufferSize.Width, $stableSize.Height)
				} catch {}
				$OldBufferSize       = $pswindow.BufferSize
				$oldWindowSize       = $stableSize
				$HostWidth           = $stableSize.Width
				$HostHeight          = $stableSize.Height
				$PendingResize       = $null
				$lastResizeDetection = $null
				$ResizeClearedScreen = $false
				$LastResizeLogoTime  = $null
				$SkipUpdate          = $true
				$forceRedraw         = $true
			}
		}
			
			# Check if this is the first run (before we modify lastMovementTime)
			$isFirstRun = ($null -eq $LastMovementTime)
			
			# Wait for mouse to stop moving before proceeding
			# This prevents stutter by ensuring the mouse is settled before we do expensive operations
			# Only do this if we actually waited (not on first run or force redraw)
			if (-not $isFirstRun -and -not $forceRedraw) {
				$mouseSettleMs = 150  # Must be still for this long
				$lastSettleCheckPos = Get-MousePosition
				$mouseSettledTime = $null
				$settleLoopCount = 0
				$maxMoveDelta = 0
				
				if ($script:DiagEnabled) {
					"$(Get-Date -Format 'HH:mm:ss.fff') - Loop $($script:LoopIteration): Starting settle wait, pos: $($lastSettleCheckPos.X),$($lastSettleCheckPos.Y)" | Out-File $script:SettleDiagFile -Append
				}
				
				while ($true) {
					$settleLoopCount++
					Start-Sleep -Milliseconds 25
					$currentSettlePos = Get-MousePosition
					
					$mouseMoved = $false
					if ($null -ne $currentSettlePos -and $null -ne $lastSettleCheckPos) {
						$deltaX = [Math]::Abs($currentSettlePos.X - $lastSettleCheckPos.X)
						$deltaY = [Math]::Abs($currentSettlePos.Y - $lastSettleCheckPos.Y)
						$moveDelta = [Math]::Max($deltaX, $deltaY)
						if ($moveDelta -gt $maxMoveDelta) { $maxMoveDelta = $moveDelta }
						if ($deltaX -gt 2 -or $deltaY -gt 2) {
							$mouseMoved = $true
						}
					}
					$lastSettleCheckPos = $currentSettlePos
					
					if ($mouseMoved) {
						$mouseSettledTime = $null
					} else {
						if ($null -eq $mouseSettledTime) {
							$mouseSettledTime = Get-Date
						} elseif (((Get-Date) - $mouseSettledTime).TotalMilliseconds -ge $mouseSettleMs) {
							if ($script:DiagEnabled) {
								"$(Get-Date -Format 'HH:mm:ss.fff') - Loop $($script:LoopIteration): Settled after $settleLoopCount checks, max delta: $maxMoveDelta" | Out-File $script:SettleDiagFile -Append
							}
							break
						}
					}
				}
			}
			
			# Determine if we should skip the update based on user input or first run
			if ($script:userInputDetected) {
				$SkipUpdate = $true
			} elseif ($isFirstRun) {
				# Skip automated input on first run
				$SkipUpdate = $true
			} elseif (-not $forceRedraw) {
				# Only set skipUpdate to false if we're not forcing a redraw
				$SkipUpdate = $false
			}
			
			# Prepare UI dimensions
			$outputline = 0
			$oldRows = $Rows
			$_bpV  = [math]::Max(1, $script:BorderPadV)
		$_bpH  = [math]::Max(1, $script:BorderPadH)
			$_hBg  = $script:HeaderBg
			$_hrBg = $script:HeaderRowBg
			$_fBg  = $script:FooterBg
			$_mrBg = $script:MenuRowBg
		# Chrome = (bpV-1) plain top + 1 hBg blank + header + sep + sep + menu + (bpV≥2: 1 fBg blank) + max(0,bpV-2) plain bottom + 1 reserved
		# For bpV=1 the reserved row *is* the footer blank, so chrome = 6 rows (same as original).
		# Each bpV beyond 1 adds 2 rows (1 top plain + 1 explicit bottom blank).
		$Rows = [math]::Max(1, $HostHeight - 4 - 2 * $_bpV)
			
			# Save current log array BEFORE building new one (this preserves the previous iteration's logs)
			# On first run, $LogArray might be null or empty, so handle that case
			if ($null -eq $LogArray -or $LogArray.Count -eq 0) {
				$tempOldLogArray = @()
			} else {
				$tempOldLogArray = $LogArray.Clone()
			}
			
			# Handle log array resizing when window height changes
			if ($oldRows -ne $Rows) {
				if ($oldRows -lt $Rows) {
					# Window got taller - add empty entries at the beginning
					$insertArray = @()
					$row = [PSCustomObject]@{
						logRow = $true
						components = @()
					}
					for ($i = 0; $i -lt ($Rows - $oldRows); $i++) {
						$insertArray += $row
					}
					$tempOldLogArray = $insertArray + $tempOldLogArray
				} else {
					# Window got shorter - trim old entries from the beginning
					$trimCount = $oldRows - $Rows
					if ($tempOldLogArray.Count -gt $trimCount) {
						$tempOldLogArray = $tempOldLogArray[$trimCount..($tempOldLogArray.Count - 1)]
					} else {
						$tempOldLogArray = @()
					}
				}
			}
			
			# Build new log array: take all entries from old array (they scroll up)
			# The old array already has the previous logs, we just need to keep them
			$LogArray = @()
			
			# Copy all old log entries (they will scroll up by one position)
			# We keep up to $Rows entries from the old array (we'll add a new one, then trim to $Rows)
			$maxOldEntries = $Rows
			$startIndex = [math]::Max(0, $tempOldLogArray.Count - $maxOldEntries)
			
			for ($i = $startIndex; $i -lt $tempOldLogArray.Count; $i++) {
				# Preserve components if they exist, otherwise create empty entry
				if ($tempOldLogArray[$i].components) {
					$LogArray += [PSCustomObject]@{
						logRow = $true
						components = $tempOldLogArray[$i].components
					}
				} else {
					# Legacy format - convert to components if needed
					if ($tempOldLogArray[$i].value) {
						$LogArray += [PSCustomObject]@{
							logRow = $true
							components = @(@{
								priority = 1
								text = $tempOldLogArray[$i].value
								shortText = $tempOldLogArray[$i].value
							})
						}
					} else {
						$LogArray += [PSCustomObject]@{
							logRow = $true
							components = @()
						}
					}
				}
			}
			
			# Fill remaining slots with empty entries if we don't have enough old entries
			# We fill up to $Rows entries (before adding the new one)
			while ($LogArray.Count -lt $Rows) {
				$LogArray += [PSCustomObject]@{
					logRow = $true
					components = @()
				}
			}
			
			# Check current mouse position to detect user movement (simple approach - only check at end of interval)
			# Compare end position to start position to detect if user moved mouse during the interval
			# This is simpler and doesn't interfere with mouse movement like checking during the wait loop
			$currentPos = Get-MousePosition
			$PosUpdate = $false
			$x = 0
			$y = 0
			
			# Only check for mouse movement if we haven't already detected user input
			# Skip checking if we recently performed automated mouse movement (within last 300ms)
			# This prevents our own automated movement from being detected as user input
			$shouldCheckMouseAfterWait = $true
			if ($null -ne $LastAutomatedMouseMovement) {
				$timeSinceAutomatedMovement = Get-TimeSinceMs -startTime $LastAutomatedMouseMovement
				if ($timeSinceAutomatedMovement -lt 300) {
					# Too soon after our automated movement - skip mouse detection
					$shouldCheckMouseAfterWait = $false
				}
			}
			
			if ($shouldCheckMouseAfterWait -and -not $script:userInputDetected -and $null -ne $mousePosAtStart -and $null -ne $currentPos) {
				# Compare current position to position at start of interval (simple approach)
				$deltaX = [Math]::Abs($currentPos.X - $mousePosAtStart.X)
				$deltaY = [Math]::Abs($currentPos.Y - $mousePosAtStart.Y)
				$movementThreshold = 3  # Only detect movement if it's more than 3 pixels
				
				if ($deltaX -gt $movementThreshold -or $deltaY -gt $movementThreshold) {
					# Check if this movement is from our automated movement
					$isAutomatedPos = ($null -ne $automatedMovementPos -and 
									   $null -ne $currentPos -and
									   $currentPos.X -eq $automatedMovementPos.X -and 
									   $currentPos.Y -eq $automatedMovementPos.Y)
					if (-not $isAutomatedPos) {
						# User moved mouse during interval - skip automated movement
						$SkipUpdate = $true
						$PosUpdate = $false
						$mouseInputDetected = $true
						# Reset auto-resume delay timer on user input
						if ($script:AutoResumeDelaySeconds -gt 0) {
							$LastUserInputTime = Get-Date
						}
						$mouseMoveText = "Mouse"
						if ($intervalMouseInputs -notcontains $mouseMoveText) {
							$intervalMouseInputs += $mouseMoveText
						}
						$LastPos = $currentPos
						$automatedMovementPos = $null  # Clear automated position since user moved
					}
					# If it matches our automated position, ignore it (it's from our movement)
				}
			}
			
			# Check if auto-resume delay timer is active (check before skipUpdate logic)
			$cooldownActive = $false
			$secondsRemaining = 0
			if ($script:AutoResumeDelaySeconds -gt 0) {
				if ($null -eq $LastUserInputTime) {
					# Timer hasn't started yet (no user input detected yet) - allow movement
					$cooldownActive = $false
				} else {
					$timeSinceInput = ((Get-Date) - $LastUserInputTime).TotalSeconds
					if ($timeSinceInput -lt $script:AutoResumeDelaySeconds) {
						$cooldownActive = $true
						$secondsRemaining = [Math]::Ceiling($script:AutoResumeDelaySeconds - $timeSinceInput)
					} else {
						# Timer expired - clear it
						# Debug: Log resume (timer expired)
						if ($DebugMode -and $null -ne $LastUserInputTime) {
							if ($null -eq $LogArray -or -not ($LogArray -is [Array])) {
								$LogArray = @()
							}
							$LogArray += [PSCustomObject]@{
								logRow = $true
								components = @(
									@{
										priority = 1
										text = (Get-Date).ToString("HH:mm:ss")
										shortText = (Get-Date).ToString("HH:mm:ss")
									},
									@{
										priority = 2
										text = " - [DEBUG] Auto-resume delay expired, resuming"
										shortText = " - [DEBUG] Resumed"
									}
								)
							}
						}
						$LastUserInputTime = $null
						$cooldownActive = $false
					}
				}
			}
			
			if ($SkipUpdate -ne $true) {
				if ($cooldownActive) {
					# Timer is active - skip coordinate updates and simulated key presses
					$SkipUpdate = $true
					$PosUpdate = $false
					# Store cooldown state for log component building (don't log directly here)
				} else {
					# No user movement detected - perform automated movement
					# Get fresh position right before movement to avoid stutter
					$pos = Get-MousePosition
					if ($null -eq $pos) {
						# API call failed - use last known position
						$pos = $LastPos
					}
					$PosUpdate = $true
				
				# Calculate travel distance with variance
				$baseDistance = $script:TravelDistance
				# Use double variance directly (Get-Random supports doubles, -Maximum is exclusive so add small epsilon)
				$varianceAmount = Get-Random -Minimum 0.0 -Maximum ($script:TravelVariance + 0.0001)
				$rasDist = Get-Random -Maximum 2
				if ($rasDist -eq 0) {
					$distance = $baseDistance - $varianceAmount
				} else {
					$distance = $baseDistance + $varianceAmount
				}
				# Ensure minimum distance of 1 pixel
				if ($distance -lt 1) {
					$distance = 1
				}
				
			# Calculate random direction (angle in radians)
			$angle = Get-Random -Minimum 0 -Maximum ([Math]::PI * 2)
			
			# Calculate target coordinates based on distance and angle
			$x = [Math]::Round($pos.X + ($distance * [Math]::Cos($angle)))
			$y = [Math]::Round($pos.Y + ($distance * [Math]::Sin($angle)))
			
			# Use the virtual screen rectangle so all connected monitors are reachable.
			# VirtualScreen is the bounding rect of every monitor combined.
			$vScreen  = [System.Windows.Forms.SystemInformation]::VirtualScreen
			$sLeft    = $vScreen.Left
			$sTop     = $vScreen.Top
			$sRight   = $vScreen.Right  - 1
			$sBottom  = $vScreen.Bottom - 1
			
			# Reflect off boundaries instead of clamping so the cursor naturally bounces
			# inward — no more rubbing along an edge across multiple consecutive moves.
			if ($x -lt $sLeft)   { $x = $sLeft   + ($sLeft   - $x) }
			if ($x -gt $sRight)  { $x = $sRight  - ($x - $sRight)  }
			if ($y -lt $sTop)    { $y = $sTop    + ($sTop    - $y)  }
			if ($y -gt $sBottom) { $y = $sBottom - ($y - $sBottom)  }
			# Final clamp handles the rare double-bounce edge case
			$x = [Math]::Max($sLeft, [Math]::Min($x, $sRight))
			$y = [Math]::Max($sTop,  [Math]::Min($y, $sBottom))
				
				# Calculate movement direction for arrow emoji
				try {
					$deltaX = $x - $pos.X
					$deltaY = $y - $pos.Y
					$directionArrow = Get-DirectionArrow -deltaX $deltaX -deltaY $deltaY -style "simple"
				} catch {
					# If arrow calculation fails, just use empty string
					$directionArrow = ""
				}
				
				# Calculate smooth movement path
				$movementPath = Get-SmoothMovementPath -startX $pos.X -startY $pos.Y -endX $x -endY $y -baseSpeedSeconds $script:MoveSpeed -varianceSeconds $script:MoveVariance
				$movementPoints = $movementPath.Points
				$LastMovementDurationMs = $movementPath.TotalTimeMs
				
			# Move through each point smoothly
			$movementAborted = $false
			if ($movementPoints.Count -gt 1) {
				# Constant 5ms between every cursor step. Point count was sized to match this
				# in Get-SmoothMovementPath, so total wall-time ≈ TotalTimeMs as requested.
				$stepIntervalMs = 5
				
				# Add a tiny initial delay to prevent stutter at movement start
				# This ensures smooth transition from wait loop to movement
				Start-Sleep -Milliseconds 1
				
				# Move to each point at a constant 5ms interval (skip first point = start position)
				for ($i = 1; $i -lt $movementPoints.Count; $i++) {
					$point = $movementPoints[$i]
					[System.Windows.Forms.Cursor]::Position = New-Object System.Drawing.Point ($point.X, $point.Y)
					
					# Sleep 5ms between steps; skip after the last point to avoid an extra delay
					if ($i -lt $movementPoints.Count - 1) {
						Start-Sleep -Milliseconds $stepIntervalMs
							
							# Check if user moved the mouse during animation by comparing
							# actual cursor position to where we just placed it
							$actualPos = Get-MousePosition
							if ($null -ne $actualPos) {
								$driftX = [Math]::Abs($actualPos.X - $point.X)
								$driftY = [Math]::Abs($actualPos.Y - $point.Y)
								if ($driftX -gt 3 -or $driftY -gt 3) {
									$movementAborted = $true
									$SkipUpdate = $true
									$script:userInputDetected = $true
									$mouseInputDetected = $true
									$mouseMoveText = "Mouse"
									if ($intervalMouseInputs -notcontains $mouseMoveText) {
										$intervalMouseInputs += $mouseMoveText
									}
									if ($script:AutoResumeDelaySeconds -gt 0) {
										$LastUserInputTime = Get-Date
									}
									$LastPos = $actualPos
									$automatedMovementPos = $null
									if ($script:DiagEnabled) {
										"$(Get-Date -Format 'HH:mm:ss.fff') - Loop $($script:LoopIteration): Movement aborted at step $i/$($movementPoints.Count) - user moved mouse (drift: $driftX,$driftY)" | Out-File $script:SettleDiagFile -Append
									}
									break
								}
							}
						}
					}
				} else {
					# Single point or no movement needed - just move directly
					[System.Windows.Forms.Cursor]::Position = New-Object System.Drawing.Point ($x, $y)
				}
				
				if ($movementAborted) {
					$PosUpdate = $false
				} else {
					# Update last position using cached method for better performance
					$newPos = Get-MousePosition
					if ($null -ne $newPos) {
						$LastPos = $newPos
					}
					$automatedMovementPos = $LastPos
					$LastAutomatedMouseMovement = Get-Date
					
					# Send Right Alt key press (modifier key - won't type anything or interfere with apps)
					try {
						$vkCode = [byte]0xA5  # VK_RMENU (Right Alt)
						[mJiggAPI.Keyboard]::keybd_event($vkCode, [byte]0, [uint32]0, [int]0)  # Key down
						Start-Sleep -Milliseconds 10
						[mJiggAPI.Keyboard]::keybd_event($vkCode, [byte]0, [uint32]0x0002, [int]0)  # Key up (KEYEVENTF_KEYUP = 0x0002)
						$LastSimulatedKeyPress = Get-Date
						Start-Sleep -Milliseconds 50
						# Flush any simulated key events from the console input buffer
						try {
							$hStdIn = [mJiggAPI.Mouse]::GetStdHandle(-10)
							$flushBuf = New-Object 'mJiggAPI.INPUT_RECORD[]' 32
							$flushCount = [uint32]0
							if ([mJiggAPI.Mouse]::PeekConsoleInput($hStdIn, $flushBuf, 32, [ref]$flushCount) -and $flushCount -gt 0) {
								[mJiggAPI.Mouse]::ReadConsoleInput($hStdIn, $flushBuf, $flushCount, [ref]$flushCount) | Out-Null
							}
						} catch { }
					} catch {
						# If keybd_event fails, continue without keyboard input
					}
				}
				
					$LastMovementTime = Get-Date
				}
			} else {
				# skipUpdate was set - just update tracking
				$PosUpdate = $false
				$LastPos = $currentPos
				if ($null -eq $LastMovementTime) {
					$LastMovementTime = Get-Date
				}
			}
			
			# Combine mouse inputs and keys for display
			# Mouse movement first, then clicks/scroll, then keyboard
			$allInputs = @()
			$mouseMovement = $intervalMouseInputs | Where-Object { $_ -eq "Mouse" }
			if ($mouseMovement) {
				$allInputs += $mouseMovement
				$otherMouseInputs = $intervalMouseInputs | Where-Object { $_ -ne "Mouse" }
				if ($otherMouseInputs) {
					$allInputs += $otherMouseInputs
				}
			} else {
				if ($intervalMouseInputs.Count -gt 0) {
					$allInputs += $intervalMouseInputs
				}
			}
			if ($keyboardInputDetected) {
				$allInputs += "Keyboard"
			}
			$PreviousIntervalKeys = $allInputs
			
			# Only create log entry when we complete a wait interval AND do something
			# Don't create log entries for window resize events
			$shouldCreateLogEntry = $false
			
			# If this is just a window resize (forceRedraw set), don't create log entry
			if ($forceRedraw -and -not $waitExecuted -and -not $PosUpdate) {
				# This is just a window resize redraw - skip log entry completely
				$shouldCreateLogEntry = $false
			} elseif ($PosUpdate) {
				# We did a movement - always log this
				$shouldCreateLogEntry = $true
			} elseif ($isFirstRun) {
				# First run - log this
				$shouldCreateLogEntry = $true
			} elseif ($waitExecuted -and -not $forceRedraw) {
				# We completed a wait interval (and it wasn't interrupted by resize) - log this
				$shouldCreateLogEntry = $true
			}
			
			if ($shouldCreateLogEntry) {
				# Build log entry components array (priority order: timestamp, message, coordinates, wait info, input detection)
				$logComponents = @()
				
				# Component 1: Timestamp (full format)
				$logComponents += @{
					priority = [int]1
					text = $date.ToString()
					shortText = $date.ToString("HH:mm:ss")
				}
				
				# Component 2: Main message
				if ($SkipUpdate -ne $true) {
					if ($PosUpdate) {
						# Get direction arrow if available
						$arrowText = if ($directionArrow) { " $directionArrow" } else { "" }
						$logComponents += @{
							priority = [int]2
							text = " - Coordinates updated$arrowText"
							shortText = " - Updated$arrowText"
						}
						# Component 3: Coordinates
						$logComponents += @{
							priority = [int]3
							text = " x$x/y$y"
							shortText = " x$x/y$y"
						}
					} else {
						$logComponents += @{
							priority = [int]2
							text = " - Input detected, skipping update"
							shortText = " - Input detected"
						}
					}
				} elseif ($isFirstRun) {
					# First run - show initialization message
					$logComponents += @{
						priority = [int]2
						text = " - Initialized"
						shortText = " - Initialized"
					}
				} elseif ($keyboardInputDetected -or $mouseInputDetected) {
					# User input was detected - show user input skip with KB/MS status
					$logComponents += @{
						priority = [int]2
						text = " - User input skip"
						shortText = " - Skipped"
					}
				} elseif ($cooldownActive) {
					# Auto-resume delay is active (no user input detected) - show custom message
					$logComponents += @{
						priority = [int]2
						text = " - Auto-Resume Delay"
						shortText = " - Auto-Resume Delay"
					}
					# Add resume timer component
					$logComponents += @{
						priority = [int]4
						text = " [Resume: ${secondsRemaining}s]"
						shortText = " [R: ${secondsRemaining}s]"
					}
				} else {
					$logComponents += @{
						priority = [int]2
						text = " - User input skip"
						shortText = " - Skipped"
					}
				}
				
				# Component 4: Wait interval info (only if not cooldown active or user input detected)
				if ($waitExecuted -and -not $cooldownActive) {
					$logComponents += @{
						priority = [int]4
						text = " [Interval:${interval}s]"
						shortText = " [Interval:${interval}s]"
					}
				} elseif (-not $isFirstRun -and -not $cooldownActive) {
					$logComponents += @{
						priority = [int]4
						text = " [First run]"
						shortText = " [First run]"
					}
				}
				
				# Component 5 & 6: Keyboard and Mouse detection (only when user input was detected, lowest priority - removed first)
				# These are the first to be removed when window gets narrow
				if ($SkipUpdate -eq $true -and -not $isFirstRun -and ($keyboardInputDetected -or $mouseInputDetected)) {
					# Keyboard detection status
					$kbStatus = if ($keyboardInputDetected) { "YES" } else { "NO" }
					$logComponents += @{
						priority = [int]5
						text = " [KB:$kbStatus]"
						shortText = " [K:" + $kbStatus.Substring(0,1) + "]"
					}
					
					# Mouse detection status
					$msStatus = if ($mouseInputDetected) { "YES" } else { "NO" }
					$logComponents += @{
						priority = [int]6
						text = " [MS:$msStatus]"
						shortText = " [M:" + $msStatus.Substring(0,1) + "]"
					}
				}
				
				# Add current log entry to array with components (append to end)
				$LogArray += [PSCustomObject]@{
					logRow = $true
					components = $logComponents
				}
				
				# Ensure we always have exactly $Rows entries
				# If we have more than $Rows, trim to keep the last $Rows entries (newest at bottom)
				if ($LogArray.Count -gt $Rows) {
					$LogArray = $LogArray[($LogArray.Count - $Rows)..($LogArray.Count - 1)]
				}
				# If we have fewer than $Rows, prepend empty entries at the beginning
				# This ensures the newest entry is always at the bottom (last index = $Rows - 1)
				while ($LogArray.Count -lt $Rows) {
					$LogArray = @([PSCustomObject]@{
						logRow = $true
						components = @()
					}) + $LogArray
				}
			} else {
				# No log entry created - ensure we have $Rows empty entries
				# Add empty entries at the beginning so existing entries stay at the bottom
				while ($LogArray.Count -lt $Rows) {
					$LogArray = @([PSCustomObject]@{
						logRow = $true
						components = @()
					}) + $LogArray
				}
			}
			
			# Final check: ensure we always have exactly $Rows entries before rendering
			# This handles edge cases where the array might not be properly sized
			# Initialize logArray if it's null or empty
			if ($null -eq $LogArray) {
				$LogArray = @()
			}
			# Ensure we have exactly $Rows entries
			while ($LogArray.Count -lt $Rows) {
				$LogArray = @([PSCustomObject]@{
					logRow = $true
					components = @()
				}) + $LogArray
			}
			# Trim if we somehow have more than $Rows (keep the last $Rows entries)
			if ($LogArray.Count -gt $Rows) {
				$LogArray = $LogArray[($LogArray.Count - $Rows)..($LogArray.Count - 1)]
			}
			# Final verification: logArray must have exactly $Rows entries at this point
			# If it doesn't, something went wrong - rebuild it with empty entries
			# This is a safety net to ensure we always have the correct structure
			if ($null -eq $LogArray -or $LogArray.Count -ne $Rows) {
				# Rebuild the array with exactly $Rows empty entries
				$LogArray = @()
				for ($fillIdx = 0; $fillIdx -lt $Rows; $fillIdx++) {
					$LogArray += [PSCustomObject]@{
						logRow = $true
						components = @()
					}
				}
				# If we had a log entry that was created, try to preserve it at the last index
				# (This shouldn't normally happen, but it's a safety check)
			}

			# Output Handling
			# Skip console updates if mouse movement was recently detected (every 50ms check) to prevent stutter
			# This prevents blocking console operations from interfering with Windows mouse message processing
			$skipConsoleUpdate = (Get-TimeSinceMs -startTime $script:LastMouseMovementTime) -lt 200
			# Force UI redraw when forceRedraw is true (e.g., after window resize) - override skipConsoleUpdate
			if ($forceRedraw) {
				$skipConsoleUpdate = $false
			}
			
		if ($Output -ne "hidden" -and -not $skipConsoleUpdate) {
		# Extra plain blank lines above the header background strip (beyond the 1-minimum)
		for ($__bpi = 0; $__bpi -lt ($_bpV - 1); $__bpi++) {
				Write-Buffer -X 0 -Y $Outputline -Text (" " * $HostWidth)
				$Outputline++
			}
		# The 1-minimum blank immediately before the header carries the header background (transparent outer, group-bg inner)
		if ($_bpH -gt 1) { Write-Buffer -X 0                   -Y $Outputline -Text (" " * ($_bpH - 1)) }                         # transparent left
		Write-Buffer -X ($_bpH - 1) -Y $Outputline -Text (" " * ($HostWidth - 2 * $_bpH + 2)) -BG $_hBg                           # group-bg centre
		if ($_bpH -gt 1) { Write-Buffer -X ($HostWidth-$_bpH+1) -Y $Outputline -Text (" " * ($_bpH - 1)) }                        # transparent right
		$Outputline++

			# Output header
			# Refresh current time. ClearCachedData() is required so that timezone changes
			# (e.g. via the Windows date/time settings) are picked up immediately — .NET
			# caches timezone info and won't reflect a changed timezone without this call.
			[System.TimeZoneInfo]::ClearCachedData()
			$currentTime = (Get-Date).ToString("HHmm")
			# Calculate widths for centering times between mJig title and view tag
			# Left part: "mJig(`u{1F400})" = 5 + 2 + 1 = 8 (content only; $_bpH+2 left margin handled separately)
			$headerLeftWidth = 5 + 2 + 1  # "mJig(" + emoji + ")"
				# Add DEBUGMODE text width if in debug mode
				if ($DebugMode) {
					$headerLeftWidth += 13  # " - DEBUGMODE" = 13 chars
				}
				
				# Time section: "Current`u{23F3}/" + time + " ➣  " + "End`u{23F3}/" + time (or "none")
				# Components: "Current" (7) + emoji (2) + "/" (1) + time + " ➣  " (4) + "End" (3) + emoji (2) + "/" (1) + time
				$timeSectionBaseWidth = 7 + 2 + 1 + 4 + 3 + 2 + 1  # Fixed text parts
				# Determine end time display text
				if ($endTimeInt -eq -1 -or [string]::IsNullOrEmpty($endTimeStr)) {
					$endTimeDisplay = "none"
				} else {
					$endTimeDisplay = $endTimeStr
				}
				$timeSectionTimeWidth = $currentTime.Length + $endTimeDisplay.Length
				$timeSectionWidth = $timeSectionBaseWidth + $timeSectionTimeWidth
				
		# Right part: output button (clickable, right-aligned)
		# Format: [(o)utput]|Full — button is just [(o)utput], separator and mode name are plain trailing text
		# Separator char uses $script:MenuButtonSeparator but is not part of the clickable button.
	$modeName = if ($Output -eq "full") { "Full" } else { " Min" }  # pad Min to match Full width
	$modeBracketWidth = if ($script:MenuButtonShowBrackets) { 2 } else { 0 }
	$hotkeyParenAdj = if ($script:MenuButtonShowHotkeyParens) { 0 } else { -2 }
	$modeButtonOnlyWidth = $modeBracketWidth + 8 + $hotkeyParenAdj   # brackets + "(o)utput"
		# Total display width: button + " " + separator + " " + modeName
		$modeButtonWidth = $modeButtonOnlyWidth + 1 + $script:MenuButtonSeparator.Length + 1 + $modeName.Length
			$rightMarginWidth = 0  # inner right padding handled by inset writes

			# Calculate spacing to center times between left and right parts
			$totalUsedWidth = $headerLeftWidth + $timeSectionWidth + $modeButtonWidth + $rightMarginWidth
				$remainingSpace = $HostWidth - 2 * ($_bpH + 2) - $totalUsedWidth
				$spacingBeforeTimes = [math]::Max(1, [math]::Floor($remainingSpace / 2))
				$spacingAfterTimes = [math]::Max(1, $remainingSpace - $spacingBeforeTimes)
				
			# Write left part (mJig title) via buffer with static emoji positioning
			$mouseEmoji = [char]::ConvertFromUtf32(0x1F400)  # 🐀
			$hourglassEmoji = [char]::ConvertFromUtf32(0x23F3)  # ⏳
	Write-Buffer -X ($_bpH + 2) -Y $Outputline -Text "mJig(" -FG $script:HeaderAppName -BG $_hrBg
	$curX = $_bpH + 2 + 5  # content starts at bpH+2; "mJig(" = 5 chars
			Write-Buffer -Text $mouseEmoji -FG $script:HeaderIcon -BG $_hrBg
		Write-Buffer -X ($curX + 2) -Y $Outputline -Text ")" -FG $script:HeaderAppName -BG $_hrBg
		$curX = $curX + 2 + 1  # emoji (2) + ")" (1)
		$script:HeaderLogoBounds = @{ y = $Outputline; startX = ($_bpH + 2); endX = ($curX - 1) }
		# Add DEBUGMODE indicator if in debug mode
		if ($DebugMode) {
			Write-Buffer -Text " - DEBUGMODE" -FG $script:TextError -BG $_hrBg
			$curX += 12
		}
			
			# Add spacing before times
			Write-Buffer -Text (" " * $spacingBeforeTimes) -BG $_hrBg
			$curX += $spacingBeforeTimes
			
		# Write times (Current first, then End) — hidden click regions track each section
		$currentTimeSectionStartX = $curX
		Write-Buffer -Text "Current" -FG $script:HeaderTimeLabel -BG $_hrBg
		$hourglassX1 = $curX + 7  # "Current" = 7 chars
		Write-Buffer -Text $hourglassEmoji -FG $script:HeaderIcon -BG $_hrBg
		Write-Buffer -X ($hourglassX1 + 2) -Y $Outputline -Text "/" -FG $script:TextDefault -BG $_hrBg
		$curX = $hourglassX1 + 2 + 1  # emoji (2) + "/" (1)
		Write-Buffer -Text "$currentTime" -FG $script:HeaderTimeValue -BG $_hrBg
		$curX += $currentTime.Length
		$script:HeaderCurrentTimeBounds = @{ y = $Outputline; startX = $currentTimeSectionStartX; endX = $curX - 1 }
		$arrowTriangle = [char]0x27A3  # ➣
		Write-Buffer -Text " $arrowTriangle  " -BG $_hrBg
		$curX += 4  # " ➣  " = 4 display chars
		$endTimeSectionStartX = $curX
		Write-Buffer -Text "End" -FG $script:HeaderTimeLabel -BG $_hrBg
		$hourglassX2 = $curX + 3  # "End" = 3 chars
		Write-Buffer -Text $hourglassEmoji -FG $script:HeaderIcon -BG $_hrBg
		Write-Buffer -X ($hourglassX2 + 2) -Y $Outputline -Text "/" -FG $script:TextDefault -BG $_hrBg
		$curX = $hourglassX2 + 2 + 1  # emoji (2) + "/" (1)
		Write-Buffer -Text "$endTimeDisplay" -FG $script:HeaderTimeValue -BG $_hrBg
		$curX += $endTimeDisplay.Length
		$script:HeaderEndTimeBounds = @{ y = $Outputline; startX = $endTimeSectionStartX; endX = $curX - 1 }
			
			# Add spacing after times and write view tag aligned to the right
			Write-Buffer -Text (" " * $spacingAfterTimes) -BG $_hrBg
			$curX += $spacingAfterTimes
		# Render mode button (clickable) then separator + mode name (plain, non-clickable)
	$modeButtonStartX = $curX
	if ($script:MenuButtonShowBrackets) {
		Write-Buffer -X $modeButtonStartX -Y $Outputline -Text "[" -FG $script:MenuButtonBracketFg -BG $script:MenuButtonBracketBg
		if ($script:MenuButtonShowHotkeyParens) { Write-Buffer -Text "(" -FG $script:MenuButtonText -BG $script:MenuButtonBg } else { Write-Buffer -Text "" -BG $script:MenuButtonBg }
	} else {
		if ($script:MenuButtonShowHotkeyParens) { Write-Buffer -X $modeButtonStartX -Y $Outputline -Text "(" -FG $script:MenuButtonText -BG $script:MenuButtonBg } else { Write-Buffer -X $modeButtonStartX -Y $Outputline -Text "" -BG $script:MenuButtonBg }
	}
	Write-Buffer -Text "o" -FG $script:MenuButtonHotkey -BG $script:MenuButtonBg
	if ($script:MenuButtonShowHotkeyParens) { Write-Buffer -Text ")" -FG $script:MenuButtonText -BG $script:MenuButtonBg }
	Write-Buffer -Text "utput" -FG $script:MenuButtonText -BG $script:MenuButtonBg
	if ($script:MenuButtonShowBrackets) {
		Write-Buffer -Text "]" -FG $script:MenuButtonBracketFg -BG $script:MenuButtonBracketBg
	}
	# Separator and mode name are plain header text — not part of the clickable area
	Write-Buffer -Text " $($script:MenuButtonSeparator)" -FG $script:MenuButtonSeparatorFg -BG $_hrBg
	Write-Buffer -Text " $modeName" -FG $script:HeaderViewTag -BG $_hrBg
		$curX += $modeButtonWidth
		$script:ModeButtonBounds = @{
			y      = $Outputline
			startX = $modeButtonStartX
			endX   = $modeButtonStartX + $modeButtonOnlyWidth - 1
		}

		# Clear any remaining characters on the line
			if ($curX -lt $HostWidth) {
				Write-Buffer -Text (" " * ($HostWidth - $curX)) -BG $_hrBg
			}
		# Outer transparent padding (bpH-1), then 1 group-bg, then 2 inner row-bg on each side
		if ($_bpH -gt 1) { Write-Buffer -X 0                     -Y $Outputline -Text (" " * ($_bpH - 1)) }  # transparent left outer
		Write-Buffer -X ($_bpH - 1)           -Y $Outputline -Text " "            -BG $_hBg                   # 1 group-bg left
		Write-Buffer -X $_bpH                 -Y $Outputline -Text "  "           -BG $_hrBg                  # 2 inner left  (row bg)
		Write-Buffer -X ($HostWidth-$_bpH-2)  -Y $Outputline -Text "  "           -BG $_hrBg                  # 2 inner right (row bg)
		Write-Buffer -X ($HostWidth-$_bpH)    -Y $Outputline -Text " "            -BG $_hBg                   # 1 group-bg right
		if ($_bpH -gt 1) { Write-Buffer -X ($HostWidth-$_bpH+1) -Y $Outputline -Text (" " * ($_bpH - 1)) }  # transparent right outer
			$Outputline++

		# Output Line Spacer
		if ($_bpH -gt 1) { Write-Buffer -X 0            -Y $Outputline -Text (" " * ($_bpH - 1)) }          # transparent left outer
		Write-Buffer -X ($_bpH - 1) -Y $Outputline -Text " " -BG $_hBg                                       # 1 group-bg left
		Write-Buffer -Text ("$($script:BoxHorizontal)" * ($HostWidth - 2 * $_bpH)) -FG $script:HeaderSeparator -BG $_hBg
		Write-Buffer -X ($HostWidth - $_bpH) -Y $Outputline -Text " " -BG $_hBg                              # 1 group-bg right
		if ($_bpH -gt 1) { Write-Buffer -X ($HostWidth-$_bpH+1) -Y $Outputline -Text (" " * ($_bpH - 1)) }  # transparent right outer
			$outputLine++

			# Only render console if not skipping updates (prevents stutter during mouse movement)
			if (-not $skipConsoleUpdate) {
			# Calculate view-dependent variables INSIDE the skip check to ensure they use current $Output value
			# This prevents stale view calculations when console updates resume after mouse movement
			$boxWidth = 50  # Width for stats box
			$boxPadding = 2  # Padding around box (1 space on each side)
			$verticalSeparatorWidth = 3  # " $($script:BoxVertical) " = 3 characters
		$showStatsBox = ($Output -eq "full" -and $HostWidth -ge ($boxWidth + $boxPadding + $verticalSeparatorWidth + 50 + 2 * $_bpH))  # Need at least 50 chars for logs + padding
		$logWidth = if ($showStatsBox) { $HostWidth - 2 * $_bpH - $boxWidth - $boxPadding - $verticalSeparatorWidth + 1 } else { $HostWidth - 2 * $_bpH + 1 }  # +1 extends right boundary to group-bg char
			
		# Pre-calculate key text splitting for full view
				$keysFirstLine = ""
				$keysSecondLine = ""
				if ($showStatsBox) {
					if ($PreviousIntervalKeys.Count -gt 0) {
						# Filter out empty/null values to prevent leading commas
						$filteredKeys = $PreviousIntervalKeys | Where-Object { $_ -and $_.ToString().Trim() -ne "" }
						$keysText = if ($filteredKeys.Count -gt 0) { ($filteredKeys -join ", ") } else { "" }
						# Split into two lines if needed (only if we have text)
						if ($keysText -and $keysText.Length -gt ($boxWidth - 2)) {
							# Try to split at a comma
							$splitPos = $keysText.LastIndexOf(", ", ($boxWidth - 2))
							if ($splitPos -gt 0) {
								$keysFirstLine = $keysText.Substring(0, $splitPos)
								$keysSecondLine = $keysText.Substring($splitPos + 2)
								# Truncate second line if still too long
								if ($keysSecondLine.Length -gt ($boxWidth - 2)) {
									$keysSecondLine = $keysSecondLine.Substring(0, ($boxWidth - 5)) + "..."
								}
							} else {
								# No comma found, just truncate
								$keysFirstLine = $keysText.Substring(0, ($boxWidth - 5)) + "..."
								$keysSecondLine = ""
							}
						} elseif ($keysText) {
							$keysFirstLine = $keysText
							$keysSecondLine = ""
						}
					}
				}
				
				for ($i = 0; $i -lt $Rows; $i++) {
				$rowY = $Outputline + $i
			$logStartX      = $_bpH - 2            # 1 col left of the group-bg char
			$availableWidth = $logWidth + 2        # +2: 1 for left shift + 1 for right expansion; separator X stays at bpH+logWidth
					
					$hasLogEntry = ($i -lt $LogArray.Count -and $null -ne $LogArray[$i] -and $null -ne $LogArray[$i].components)
					$hasContent = ($hasLogEntry -and $LogArray[$i].components.Count -gt 0)
					
					if ($hasContent) {
							# Format log line based on available width with priority
							$formattedLine = ""
							$useShortTimestamp = $false
							
							# Calculate total length with full components (accounting for 2-space indent)
							$fullLength = 2  # Start with 2 for leading spaces
							foreach ($component in $LogArray[$i].components) {
								$fullLength += $component.text.Length
							}
							
							# If full length exceeds width, start using shortened timestamp
							if ($fullLength -gt $availableWidth) {
								$useShortTimestamp = $true
								# Recalculate with short timestamp
								$shortLength = 2  # Start with 2 for leading spaces
								foreach ($component in $LogArray[$i].components) {
									if ($component.priority -eq 1) {
										$shortLength += $component.shortText.Length
									} else {
										$shortLength += $component.text.Length
									}
								}
								$fullLength = $shortLength
							}
							
							# Build line with priority-based truncation (accounting for 2-space indent)
							$formattedLine = "  "  # Add 2 leading spaces
							$remainingWidth = $availableWidth - 2  # Subtract 2 for leading spaces
							# Sort components by priority (ascending) - lower priority numbers appear first
							$sortedComponents = $LogArray[$i].components | Sort-Object { [int]$_.priority }
							foreach ($component in $sortedComponents) {
								$componentText = if ($component.priority -eq 1 -and $useShortTimestamp) {
									$component.shortText
								} else {
									$component.text
								}
								
								# Check if we have room for this component
								if ($componentText.Length -le $remainingWidth) {
									$formattedLine += $componentText
									$remainingWidth -= $componentText.Length
								} else {
									# Truncate this component if it's the last one and we have some room
									if ($remainingWidth -gt 3) {
										$formattedLine += $componentText.Substring(0, $remainingWidth - 3) + "..."
									}
									break
								}
							}
							
							# Clear the line first, then write the new content
							# Pad with spaces to clear any leftover characters and ensure exact width
							# Truncate if longer, pad if shorter to ensure exactly $availableWidth characters
							$truncatedLine = if ($formattedLine.Length -gt $availableWidth) {
								$formattedLine.Substring(0, $availableWidth)
							} else {
								$formattedLine
							}
					$paddedLine = $truncatedLine.PadRight($availableWidth)
					Write-Buffer -X $logStartX -Y $rowY -Text $paddedLine
						
						if ($showStatsBox) {
							Write-Buffer -X ($_bpH + $logWidth) -Y $rowY -Text " $($script:BoxVertical) " -FG $script:StatsBoxBorder
						}
							
							# Draw stats box in full view (with padding so it doesn't touch white lines)
							if ($showStatsBox) {
								Write-Buffer -Text " "
								
								# Draw box content
								if ($i -eq 0) {
									# Top border
									Write-Buffer -Text "$($script:BoxTopLeft)" -FG $script:StatsBoxBorder
									Write-Buffer -Text ("$($script:BoxHorizontal)" * ($boxWidth - 2)) -FG $script:StatsBoxBorder
									Write-Buffer -Text "$($script:BoxTopRight)" -FG $script:StatsBoxBorder
								} elseif ($i -eq 1) {
									# Header row
									$boxHeader = "Stats"
									Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
									Write-Buffer -Text $boxHeader.PadRight($boxWidth - 2) -FG $script:StatsBoxTitle
									Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
								} elseif ($i -eq 2) {
									# Separator row
									Write-Buffer -Text "$($script:BoxVerticalRight)" -FG $script:StatsBoxBorder
									Write-Buffer -Text ("$($script:BoxHorizontal)" * ($boxWidth - 2)) -FG $script:StatsBoxBorder
									Write-Buffer -Text "$($script:BoxVerticalLeft)" -FG $script:StatsBoxBorder
								} elseif ($i -eq $Rows - 5) {
									Write-Buffer -Text "$($script:BoxVerticalRight)" -FG $script:StatsBoxBorder
									Write-Buffer -Text ("$($script:BoxHorizontal)" * ($boxWidth - 2)) -FG $script:StatsBoxBorder
									Write-Buffer -Text "$($script:BoxVerticalLeft)" -FG $script:StatsBoxBorder
								} elseif ($i -eq $Rows - 4) {
									Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
									Write-Buffer -Text "Detected Inputs:".PadRight($boxWidth - 2) -FG $script:StatsBoxTitle
									Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
								} elseif ($i -eq $Rows - 3) {
									if ($PreviousIntervalKeys.Count -gt 0) {
										Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
										Write-Buffer -Text $keysFirstLine.PadRight($boxWidth - 2) -FG $script:StatsBoxValue
										Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
									} else {
										Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
										Write-Buffer -Text "(none)".PadRight($boxWidth - 2) -FG $script:TextMuted
										Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
									}
								} elseif ($i -eq $Rows - 2) {
									if ($PreviousIntervalKeys.Count -gt 0 -and $keysSecondLine -ne "") {
										Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
										Write-Buffer -Text $keysSecondLine.PadRight($boxWidth - 2) -FG $script:StatsBoxValue
										Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
									} else {
										Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
										Write-Buffer -Text (" " * ($boxWidth - 2))
										Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
									}
								} elseif ($i -eq $Rows - 1) {
									Write-Buffer -Text "$($script:BoxBottomLeft)" -FG $script:StatsBoxBorder
									Write-Buffer -Text ("$($script:BoxHorizontal)" * ($boxWidth - 2)) -FG $script:StatsBoxBorder
									Write-Buffer -Text "$($script:BoxBottomRight)" -FG $script:StatsBoxBorder
								} else {
									Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
									Write-Buffer -Text (" " * ($boxWidth - 2))
									Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
								}
								
								Write-Buffer -Text " "
							}
					} else {
					$emptyLine = "".PadRight($availableWidth)
					Write-Buffer -X $logStartX -Y $rowY -Text $emptyLine
						
						if ($showStatsBox) {
							Write-Buffer -X ($_bpH + $logWidth) -Y $rowY -Text " $($script:BoxVertical) " -FG $script:StatsBoxBorder
						}
							
							if ($showStatsBox) {
								Write-Buffer -Text " "
								if ($i -eq 0) {
									Write-Buffer -Text "$($script:BoxTopLeft)" -FG $script:StatsBoxBorder
									Write-Buffer -Text ("$($script:BoxHorizontal)" * ($boxWidth - 2)) -FG $script:StatsBoxBorder
									Write-Buffer -Text "$($script:BoxTopRight)" -FG $script:StatsBoxBorder
								} elseif ($i -eq 1) {
									Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
									Write-Buffer -Text "Stats".PadRight($boxWidth - 2) -FG $script:StatsBoxTitle
									Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
								} elseif ($i -eq 2) {
									Write-Buffer -Text "$($script:BoxVerticalRight)" -FG $script:StatsBoxBorder
									Write-Buffer -Text ("$($script:BoxHorizontal)" * ($boxWidth - 2)) -FG $script:StatsBoxBorder
									Write-Buffer -Text "$($script:BoxVerticalLeft)" -FG $script:StatsBoxBorder
								} elseif ($i -eq $Rows - 5) {
									Write-Buffer -Text "$($script:BoxVerticalRight)" -FG $script:StatsBoxBorder
									Write-Buffer -Text ("$($script:BoxHorizontal)" * ($boxWidth - 2)) -FG $script:StatsBoxBorder
									Write-Buffer -Text "$($script:BoxVerticalLeft)" -FG $script:StatsBoxBorder
								} elseif ($i -eq $Rows - 4) {
									Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
									Write-Buffer -Text "Detected Inputs:".PadRight($boxWidth - 2) -FG $script:StatsBoxTitle
									Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
								} elseif ($i -eq $Rows - 3) {
									if ($PreviousIntervalKeys.Count -gt 0) {
										Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
										Write-Buffer -Text $keysFirstLine.PadRight($boxWidth - 2) -FG $script:StatsBoxValue
										Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
									} else {
										Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
										Write-Buffer -Text "(none)".PadRight($boxWidth - 2) -FG $script:TextMuted
										Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
									}
								} elseif ($i -eq $Rows - 2) {
									if ($PreviousIntervalKeys.Count -gt 0 -and $keysSecondLine -ne "") {
										Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
										Write-Buffer -Text $keysSecondLine.PadRight($boxWidth - 2) -FG $script:StatsBoxValue
										Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
									} else {
										Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
										Write-Buffer -Text (" " * ($boxWidth - 2))
										Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
									}
								} elseif ($i -eq $Rows - 1) {
									Write-Buffer -Text "$($script:BoxBottomLeft)" -FG $script:StatsBoxBorder
									Write-Buffer -Text ("$($script:BoxHorizontal)" * ($boxWidth - 2)) -FG $script:StatsBoxBorder
									Write-Buffer -Text "$($script:BoxBottomRight)" -FG $script:StatsBoxBorder
								} else {
									Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
									Write-Buffer -Text (" " * ($boxWidth - 2))
									Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
								}
								Write-Buffer -Text " "
							}
						}
				}
				$outputLine += $Rows
			}
			}  # End of skipConsoleUpdate check

			# Output bottom separator (only if not skipping console updates)
			if ($Output -ne "hidden" -and -not $skipConsoleUpdate) {
			# Calculate if we should show stats box (full view, wide enough window)
			$boxWidth = 50  # Width for stats box
			$boxPadding = 2  # Padding around box (1 space on each side)
			$verticalSeparatorWidth = 3  # " $($script:BoxVertical) " = 3 characters
		$showStatsBox = ($Output -eq "full" -and $HostWidth -ge ($boxWidth + $boxPadding + $verticalSeparatorWidth + 50 + 2 * $_bpH))  # Need at least 50 chars for logs + padding
		$logWidth = if ($showStatsBox) { $HostWidth - 2 * $_bpH - $boxWidth - $boxPadding - $verticalSeparatorWidth + 1 } else { $HostWidth - 2 * $_bpH + 1 }  # +1 extends right boundary to group-bg char
				
		# Bottom separator line
		if ($_bpH -gt 1) { Write-Buffer -X 0            -Y $Outputline -Text (" " * ($_bpH - 1)) }          # transparent left outer
		Write-Buffer -X ($_bpH - 1) -Y $Outputline -Text " " -BG $_fBg                                       # 1 group-bg left
		Write-Buffer -Text ("$($script:BoxHorizontal)" * ($HostWidth - 2 * $_bpH)) -FG $script:HeaderSeparator -BG $_fBg
		Write-Buffer -X ($HostWidth - $_bpH) -Y $Outputline -Text " " -BG $_fBg                              # 1 group-bg right
		if ($_bpH -gt 1) { Write-Buffer -X ($HostWidth-$_bpH+1) -Y $Outputline -Text (" " * ($_bpH - 1)) }  # transparent right outer
			$outputLine++

			## Menu Options ##
			$emojiLock = [char]::ConvertFromUtf32(0x1F512)  # 🔒
			$emojiGear = [char]::ConvertFromUtf32(0x1F6E0)  # 🛠
				$emojiRedX = [char]::ConvertFromUtf32(0x274C)  # ❌
				
			$menuItemsList = @(
				@{
					full            = "$emojiGear|(s)ettings"
					noIcons         = "(s)ettings"
					short           = "(s)et"
					isSettingsButton = $true
				},
			@{
				full    = "$emojiLock|(i)ncognito"
				noIcons = "(i)ncognito"
				short   = "(i)nc"
			}
			)

			$menuItemsList += @{
				full    = "$emojiRedX|(q)uit"
				noIcons = "(q)uit"
				short   = "(q)uit"
			}

			$menuItems = $menuItemsList
				
		# Calculate widths for each format (emojis = 2 display chars)
		$menuIconWidth    = if ($script:MenuButtonShowIcon)    { 2 + $script:MenuButtonSeparator.Length } else { 0 }
		$menuBracketWidth = if ($script:MenuButtonShowBrackets) { 2 } else { 0 }
		$hotkeyParenAdj   = if ($script:MenuButtonShowHotkeyParens) { 0 } else { -2 }
		$format0Width = 2  # Leading spaces
		$format1Width = 2
		$format2Width = 2
		
		foreach ($item in $menuItems) {
			$textPart = $item.full -replace "^.+\|", ""
			$format0Width += $menuIconWidth + $textPart.Length + $hotkeyParenAdj + $menuBracketWidth + 2
			$format1Width += $item.noIcons.Length + $hotkeyParenAdj + 2
			$format2Width += $item.short.Length + $hotkeyParenAdj + 1
		}
			
			$format0Width += 2
			$format1Width += 2
			$format2Width += 2

			# ? help button contributes to format 0 and 1 only (hidden in format 2 / short mode)
			$helpButtonWidth = 0
			if ($Output -eq "full") {
				$helpButtonWidth = $menuBracketWidth + 1  # "?" char + optional brackets
				$format0Width += $helpButtonWidth + 2    # +2 for trailing spaces
				$format1Width += $helpButtonWidth + 2
			}

			$menuFormat = 0
			if ($HostWidth -lt $format0Width) {
				if ($HostWidth -lt $format1Width) {
					$menuFormat = 2
				} else {
					$menuFormat = 1
				}
			}
			
		$quitItem = $menuItems[$menuItems.Count - 1]
		if ($menuFormat -eq 0) {
			$textPart = $quitItem.full -replace "^.+\|", ""
			$quitWidth = $menuIconWidth + $textPart.Length + $hotkeyParenAdj + $menuBracketWidth
			} elseif ($menuFormat -eq 1) {
				$quitWidth = $quitItem.noIcons.Length + $hotkeyParenAdj
			} else {
				$quitWidth = $quitItem.short.Length + $hotkeyParenAdj
			}
				
			# Restore pressed-button highlight when appropriate:
			# - Immediate actions (toggle, hide): clear on the very first render after the click (no dialog opened)
			# - Popup actions (dialogs): the dialog is blocking so this render only runs after it closes — clear then too
			# - While a dialog IS open: skip this block so the button stays highlighted throughout the dialog
			if ($script:PendingDialogCheck -and $null -ne $script:PressedMenuButton) {
				if ($null -eq $script:DialogButtonBounds) {
					# No dialog is open: either the action was immediate or the dialog just closed — clear now
					$script:PressedMenuButton  = $null
					$script:ButtonClickedAt    = $null
					$script:PendingDialogCheck = $false
				}
				# If DialogButtonBounds is non-null a dialog is open; leave everything in place until it closes
			}

		# Write menu items via buffer with static position tracking
		$menuY = $Outputline
		$script:MenuBarY = $menuY  # stored for quit dialog positioning
	$currentMenuX = $_bpH + 2  # Start after group-bg + 2-char inner padding
				
				$script:MenuItemsBounds = @()
				$itemsBeforeQuit = $menuItems.Count - 1
				for ($mi = 0; $mi -lt $itemsBeforeQuit; $mi++) {
					$item = $menuItems[$mi]
					$itemStartX = $currentMenuX
					
					if ($menuFormat -eq 0) {
						$itemText = $item.full
					} elseif ($menuFormat -eq 1) {
						$itemText = $item.noIcons
					} else {
						$itemText = $item.short
					}
					
			# Calculate item display width statically (emoji = 2 display cells)
			$itemDisplayWidth = 0
			if ($menuFormat -eq 0) {
				$parts = $itemText -split "\|", 2
				if ($parts.Count -eq 2) {
					$itemDisplayWidth = $menuIconWidth + $parts[1].Length + $hotkeyParenAdj + $menuBracketWidth
				}
			} else {
					$itemDisplayWidth = $itemText.Length + $hotkeyParenAdj
				}
					
		# Resolve hotkey and pressed-state colors before rendering
		$hotkeyMatch = $itemText -match "\(([a-z])\)"
		$hotkey = if ($hotkeyMatch) { $matches[1] } else { $null }
		$isPressed = ($null -ne $script:PressedMenuButton -and $script:PressedMenuButton -eq $hotkey)
		if ($item.isSettingsButton -eq $true) {
			# Settings button uses its own dedicated color variables
			$btnFg        = if ($isPressed) { $script:SettingsButtonOnClickFg }          else { $script:SettingsButtonText }
			$btnBg        = if ($isPressed) { $script:SettingsButtonOnClickBg }          else { $script:SettingsButtonBg }
			$btnHkFg      = if ($isPressed) { $script:SettingsButtonOnClickHotkey }      else { $script:SettingsButtonHotkey }
			$btnPipeFg    = if ($isPressed) { $script:SettingsButtonOnClickSeparatorFg } else { $script:SettingsButtonSeparatorFg }
			$btnBracketFg = if ($isPressed) { $script:SettingsButtonOnClickBracketFg }   else { $script:SettingsButtonBracketFg }
			$btnBracketBg = if ($isPressed) { $script:SettingsButtonOnClickBracketBg }   else { $script:SettingsButtonBracketBg }
		} else {
			$btnFg        = if ($isPressed) { $script:MenuButtonOnClickFg }         else { $script:MenuButtonText }
			$btnBg        = if ($isPressed) { $script:MenuButtonOnClickBg }         else { $script:MenuButtonBg }
			$btnHkFg      = if ($isPressed) { $script:MenuButtonOnClickHotkey }     else { $script:MenuButtonHotkey }
			$btnPipeFg    = if ($isPressed) { $script:MenuButtonOnClickSeparatorFg } else { $script:MenuButtonSeparatorFg }
			$btnBracketFg = if ($isPressed) { $script:MenuButtonOnClickBracketFg }  else { $script:MenuButtonBracketFg }
			$btnBracketBg = if ($isPressed) { $script:MenuButtonOnClickBracketBg }  else { $script:MenuButtonBracketBg }
		}

		# Render the menu item
		if ($menuFormat -eq 0) {
			$parts = $itemText -split "\|", 2
			if ($parts.Count -eq 2) {
				$emoji = $parts[0]
				$text = $parts[1]
				$contentX = $itemStartX
				if ($script:MenuButtonShowBrackets) {
					Write-Buffer -X $contentX -Y $menuY -Text "[" -FG $btnBracketFg -BG $btnBracketBg
					$contentX += 1
				}
				if ($script:MenuButtonShowIcon) {
					Write-Buffer -X $contentX -Y $menuY -Text $emoji -BG $btnBg -Wide
					$sepX = $contentX + 2
					Write-Buffer -X $sepX -Y $menuY -Text $script:MenuButtonSeparator -FG $btnPipeFg -BG $btnBg
				} else {
					Write-Buffer -X $contentX -Y $menuY -Text "" -BG $btnBg
				}
		$textParts = $text -split "([()])"
			for ($j = 0; $j -lt $textParts.Count; $j++) {
				$part = $textParts[$j]
				if ($part -eq "(" -and $j + 2 -lt $textParts.Count -and $textParts[$j + 1] -match "^[a-z]$" -and $textParts[$j + 2] -eq ")") {
					if ($script:MenuButtonShowHotkeyParens) { Write-Buffer -Text "(" -FG $btnFg -BG $btnBg }
					Write-Buffer -Text $textParts[$j + 1] -FG $btnHkFg -BG $btnBg
					if ($script:MenuButtonShowHotkeyParens) { Write-Buffer -Text ")" -FG $btnFg -BG $btnBg }
					$j += 2
				} elseif ($part -ne "") {
					Write-Buffer -Text $part -FG $btnFg -BG $btnBg
				}
			}
			if ($script:MenuButtonShowBrackets) {
				Write-Buffer -Text "]" -FG $btnBracketFg -BG $btnBracketBg
			}
		}
	} else {
				Write-Buffer -X $itemStartX -Y $menuY -Text "" -BG $btnBg
				$textParts = $itemText -split "([()])"
				for ($j = 0; $j -lt $textParts.Count; $j++) {
					$part = $textParts[$j]
					if ($part -eq "(" -and $j + 2 -lt $textParts.Count -and $textParts[$j + 1] -match "^[a-z]$" -and $textParts[$j + 2] -eq ")") {
						if ($script:MenuButtonShowHotkeyParens) { Write-Buffer -Text "(" -FG $btnFg -BG $btnBg }
						Write-Buffer -Text $textParts[$j + 1] -FG $btnHkFg -BG $btnBg
						if ($script:MenuButtonShowHotkeyParens) { Write-Buffer -Text ")" -FG $btnFg -BG $btnBg }
						$j += 2
					} elseif ($part -ne "") {
						Write-Buffer -Text $part -FG $btnFg -BG $btnBg
					}
				}
			}
				
	# Store menu item bounds (computed statically)
	$itemEndX = $itemStartX + $itemDisplayWidth - 1
	if ($item.isSettingsButton -eq $true) {
		$script:SettingsButtonStartX = $itemStartX   # for dialog positioning
		$script:SettingsButtonEndX   = $itemEndX     # for close-on-reclick detection
		$script:MenuItemsBounds += @{
			startX           = $itemStartX
			endX             = $itemEndX
			y                = $menuY
			hotkey           = $hotkey
			isSettingsButton = $true
			index            = $mi
			displayText      = $itemText
			format           = $menuFormat
			fg               = $script:SettingsButtonText
			bg               = $script:SettingsButtonBg
			hotkeyFg         = $script:SettingsButtonHotkey
			pipeFg           = $script:SettingsButtonSeparatorFg
			bracketFg        = $script:SettingsButtonBracketFg
			bracketBg        = $script:SettingsButtonBracketBg
			onClickFg        = $script:SettingsButtonOnClickFg
			onClickBg        = $script:SettingsButtonOnClickBg
			onClickHotkeyFg  = $script:SettingsButtonOnClickHotkey
			onClickPipeFg    = $script:SettingsButtonOnClickSeparatorFg
			onClickBracketFg = $script:SettingsButtonOnClickBracketFg
			onClickBracketBg = $script:SettingsButtonOnClickBracketBg
		}
	} else {
		$script:MenuItemsBounds += @{
			startX      = $itemStartX
			endX        = $itemEndX
			y           = $menuY
			hotkey      = $hotkey
			index       = $mi
			displayText = $itemText
			format      = $menuFormat
			fg          = $script:MenuButtonText
			bg          = $script:MenuButtonBg
			hotkeyFg    = $script:MenuButtonHotkey
			pipeFg      = $script:MenuButtonSeparatorFg
			bracketFg   = $script:MenuButtonBracketFg
			bracketBg   = $script:MenuButtonBracketBg
			onClickFg          = $script:MenuButtonOnClickFg
			onClickBg          = $script:MenuButtonOnClickBg
			onClickHotkeyFg    = $script:MenuButtonOnClickHotkey
			onClickPipeFg      = $script:MenuButtonOnClickSeparatorFg
			onClickBracketFg   = $script:MenuButtonOnClickBracketFg
			onClickBracketBg   = $script:MenuButtonOnClickBracketBg
		}
	}
					
					# Advance position statically
					$currentMenuX = $itemStartX + $itemDisplayWidth
					
				if ($menuFormat -eq 2) {
					Write-Buffer -Text " " -BG $_mrBg
					$currentMenuX += 1
				} else {
					Write-Buffer -Text "  " -BG $_mrBg
					$currentMenuX += 2
				}
				}
				
				# Add spacing before right-side cluster (right-align quit; ? button sits just left of quit)
			if ($menuFormat -lt 2) {
				$desiredQuitX = $HostWidth - $_bpH - 2 - $quitWidth  # leave room for inner right padding + group bg
				# In full mode, gap ends at the ? button start; otherwise gap ends at quit start
				$gapTarget = if ($Output -eq "full") { $desiredQuitX - 2 - $helpButtonWidth } else { $desiredQuitX }
			$spacing = [math]::Max(1, $gapTarget - $currentMenuX)
			Write-Buffer -Text (" " * $spacing) -BG $_mrBg
			$currentMenuX += $spacing
			}

			# Render ? help button (full mode only; hidden in format 2 / short mode)
			if ($Output -eq "full" -and $menuFormat -lt 2) {
				$helpStartX  = $currentMenuX
				$helpHotkey  = "?"
				$hIsPressed  = ($null -ne $script:PressedMenuButton -and $script:PressedMenuButton -eq $helpHotkey)
				$hBtnBg      = if ($hIsPressed) { $script:MenuButtonOnClickBg }        else { $script:MenuButtonBg }
				$hBtnHkFg    = if ($hIsPressed) { $script:MenuButtonOnClickHotkey }    else { $script:MenuButtonHotkey }
				$hBracketFg  = if ($hIsPressed) { $script:MenuButtonOnClickBracketFg } else { $script:MenuButtonBracketFg }
				$hBracketBg  = if ($hIsPressed) { $script:MenuButtonOnClickBracketBg } else { $script:MenuButtonBracketBg }
				if ($script:MenuButtonShowBrackets) {
					Write-Buffer -X $helpStartX -Y $menuY -Text "[" -FG $hBracketFg -BG $hBracketBg
				}
				$hContentX = $helpStartX + [int]$script:MenuButtonShowBrackets
				Write-Buffer -X $hContentX -Y $menuY -Text "?" -FG $hBtnHkFg -BG $hBtnBg
				if ($script:MenuButtonShowBrackets) {
					Write-Buffer -Text "]" -FG $hBracketFg -BG $hBracketBg
				}
				$helpEndX = $helpStartX + $helpButtonWidth - 1
				$script:MenuItemsBounds += @{
					startX           = $helpStartX
					endX             = $helpEndX
					y                = $menuY
					hotkey           = $helpHotkey
					isHelpButton     = $true
					index            = -1
					displayText      = "?"
					format           = $menuFormat
					fg               = $script:MenuButtonText
					bg               = $script:MenuButtonBg
					hotkeyFg         = $script:MenuButtonHotkey
					pipeFg           = $script:MenuButtonSeparatorFg
					bracketFg        = $script:MenuButtonBracketFg
					bracketBg        = $script:MenuButtonBracketBg
					onClickFg        = $script:MenuButtonOnClickFg
					onClickBg        = $script:MenuButtonOnClickBg
					onClickHotkeyFg  = $script:MenuButtonOnClickHotkey
					onClickPipeFg    = $script:MenuButtonOnClickSeparatorFg
					onClickBracketFg = $script:MenuButtonOnClickBracketFg
					onClickBracketBg = $script:MenuButtonOnClickBracketBg
				}
			$currentMenuX = $helpStartX + $helpButtonWidth
			Write-Buffer -Text "  " -BG $_mrBg
			$currentMenuX += 2
		}
				
				# Write quit item
				$quitStartX = $currentMenuX
				if ($menuFormat -eq 0) {
					$itemText = $quitItem.full
				} elseif ($menuFormat -eq 1) {
					$itemText = $quitItem.noIcons
				} else {
					$itemText = $quitItem.short
				}
				
	# Resolve hotkey and pressed-state colors for quit button
	$quitHotkeyMatch = $itemText -match "\(([a-z])\)"
	$quitHotkey = if ($quitHotkeyMatch) { $matches[1] } else { $null }
	$qIsPressed      = ($null -ne $script:PressedMenuButton -and $script:PressedMenuButton -eq $quitHotkey)
	$qBtnFg          = if ($qIsPressed) { $script:QuitButtonOnClickFg }         else { $script:QuitButtonText }
	$qBtnBg          = if ($qIsPressed) { $script:QuitButtonOnClickBg }         else { $script:QuitButtonBg }
	$qBtnHkFg        = if ($qIsPressed) { $script:QuitButtonOnClickHotkey }     else { $script:QuitButtonHotkey }
	$qBtnPipeFg      = if ($qIsPressed) { $script:QuitButtonOnClickSeparatorFg } else { $script:QuitButtonSeparatorFg }
	$qBtnBracketFg   = if ($qIsPressed) { $script:QuitButtonOnClickBracketFg }  else { $script:QuitButtonBracketFg }
	$qBtnBracketBg   = if ($qIsPressed) { $script:QuitButtonOnClickBracketBg }  else { $script:QuitButtonBracketBg }

	if ($menuFormat -eq 0) {
		$parts = $itemText -split "\|", 2
		if ($parts.Count -eq 2) {
			$emoji = $parts[0]
			$text = $parts[1]
			$contentX = $quitStartX
			if ($script:MenuButtonShowBrackets) {
				Write-Buffer -X $contentX -Y $menuY -Text "[" -FG $qBtnBracketFg -BG $qBtnBracketBg
				$contentX += 1
			}
			if ($script:MenuButtonShowIcon) {
				Write-Buffer -X $contentX -Y $menuY -Text $emoji -BG $qBtnBg -Wide
				$sepX = $contentX + 2
				Write-Buffer -X $sepX -Y $menuY -Text $script:MenuButtonSeparator -FG $qBtnPipeFg -BG $qBtnBg
			} else {
				Write-Buffer -X $contentX -Y $menuY -Text "" -BG $qBtnBg
			}
		$textParts = $text -split "([()])"
		for ($j = 0; $j -lt $textParts.Count; $j++) {
			$part = $textParts[$j]
			if ($part -eq "(" -and $j + 2 -lt $textParts.Count -and $textParts[$j + 1] -match "^[a-z]$" -and $textParts[$j + 2] -eq ")") {
				if ($script:MenuButtonShowHotkeyParens) { Write-Buffer -Text "(" -FG $qBtnFg -BG $qBtnBg }
				Write-Buffer -Text $textParts[$j + 1] -FG $qBtnHkFg -BG $qBtnBg
				if ($script:MenuButtonShowHotkeyParens) { Write-Buffer -Text ")" -FG $qBtnFg -BG $qBtnBg }
				$j += 2
			} elseif ($part -ne "") {
				Write-Buffer -Text $part -FG $qBtnFg -BG $qBtnBg
			}
		}
		if ($script:MenuButtonShowBrackets) {
			Write-Buffer -Text "]" -FG $qBtnBracketFg -BG $qBtnBracketBg
		}
	}
} else {
			Write-Buffer -X $quitStartX -Y $menuY -Text "" -BG $qBtnBg
			$textParts = $itemText -split "([()])"
			for ($j = 0; $j -lt $textParts.Count; $j++) {
				$part = $textParts[$j]
				if ($part -eq "(" -and $j + 2 -lt $textParts.Count -and $textParts[$j + 1] -match "^[a-z]$" -and $textParts[$j + 2] -eq ")") {
					if ($script:MenuButtonShowHotkeyParens) { Write-Buffer -Text "(" -FG $qBtnFg -BG $qBtnBg }
					Write-Buffer -Text $textParts[$j + 1] -FG $qBtnHkFg -BG $qBtnBg
					if ($script:MenuButtonShowHotkeyParens) { Write-Buffer -Text ")" -FG $qBtnFg -BG $qBtnBg }
					$j += 2
				} elseif ($part -ne "") {
					Write-Buffer -Text $part -FG $qBtnFg -BG $qBtnBg
				}
			}
		}
			
	# Store quit item bounds (computed statically)
	$quitEndX = $quitStartX + $quitWidth - 1
	$script:MenuItemsBounds += @{
		startX      = $quitStartX
		endX        = $quitEndX
		y           = $menuY
	hotkey      = $quitHotkey
	index       = $menuItems.Count - 1
	displayText = $itemText
	format      = $menuFormat
	fg          = $script:QuitButtonText
	bg          = $script:QuitButtonBg
	hotkeyFg    = $script:QuitButtonHotkey
	pipeFg      = $script:QuitButtonSeparatorFg
	bracketFg   = $script:QuitButtonBracketFg
	bracketBg   = $script:QuitButtonBracketBg
	onClickFg          = $script:QuitButtonOnClickFg
	onClickBg          = $script:QuitButtonOnClickBg
	onClickHotkeyFg    = $script:QuitButtonOnClickHotkey
	onClickPipeFg      = $script:QuitButtonOnClickSeparatorFg
	onClickBracketFg   = $script:QuitButtonOnClickBracketFg
	onClickBracketBg   = $script:QuitButtonOnClickBracketBg
}
				
		# Clear remaining (inner right padding + group-bg handled by inset writes below)
		$menuEndX = $quitStartX + $quitWidth
	if ($menuEndX -lt $HostWidth) {
			Write-Buffer -Text (" " * ($HostWidth - $menuEndX)) -BG $_mrBg
		}
		# Outer transparent padding (bpH-1), then 1 group-bg, then 2 inner row-bg on each side
		if ($_bpH -gt 1) { Write-Buffer -X 0                     -Y $menuY -Text (" " * ($_bpH - 1)) }  # transparent left outer
		Write-Buffer -X ($_bpH - 1)           -Y $menuY -Text " "            -BG $_fBg                   # 1 group-bg left
		Write-Buffer -X $_bpH                 -Y $menuY -Text "  "           -BG $_mrBg                  # 2 inner left  (row bg)
		Write-Buffer -X ($HostWidth-$_bpH-2)  -Y $menuY -Text "  "           -BG $_mrBg                  # 2 inner right (row bg)
		Write-Buffer -X ($HostWidth-$_bpH)    -Y $menuY -Text " "            -BG $_fBg                   # 1 group-bg right
		if ($_bpH -gt 1) { Write-Buffer -X ($HostWidth-$_bpH+1) -Y $menuY -Text (" " * ($_bpH - 1)) }  # transparent right outer
		$Outputline++
				
	if ($_bpV -eq 1) {
		# For bpV=1 the reserved row (Y=$HostHeight-1) is the 1-minimum footer blank.
		# NoWrap disables auto-wrap so writing the last cell doesn't trigger a console scroll.
		# bpV=1: handle transparency based on $_bpH; apply NoWrap to the last segment.
		if ($_bpH -gt 1) {
			Write-Buffer -X 0                    -Y $Outputline -Text (" " * ($_bpH - 1))                             # transparent left
			Write-Buffer -X ($_bpH - 1)          -Y $Outputline -Text (" " * ($HostWidth - 2*$_bpH + 2)) -BG $_fBg   # group-bg centre
			Write-Buffer -X ($HostWidth-$_bpH+1) -Y $Outputline -Text (" " * ($_bpH - 1)) -NoWrap                    # transparent right (NoWrap on last)
		} else {
			Write-Buffer -X 0 -Y $Outputline -Text (" " * $HostWidth) -BG $_fBg -NoWrap
		}
		# Do NOT increment $Outputline — reserved row is the scroll guard.
	} else {
		# For bpV≥2 write the 1-minimum FooterBg blank (transparent outer, group-bg inner)
		if ($_bpH -gt 1) { Write-Buffer -X 0                    -Y $Outputline -Text (" " * ($_bpH - 1)) }                           # transparent left
		Write-Buffer -X ($_bpH - 1)          -Y $Outputline -Text (" " * ($HostWidth - 2*$_bpH + 2)) -BG $_fBg                       # group-bg centre
		if ($_bpH -gt 1) { Write-Buffer -X ($HostWidth-$_bpH+1) -Y $Outputline -Text (" " * ($_bpH - 1)) }                           # transparent right
		$Outputline++
		# ... then any extra plain blanks (bpV-2 rows).
		# The reserved row at $HostHeight-1 acts as the final extra plain blank.
		for ($__bpi = 0; $__bpi -lt ($_bpV - 2); $__bpi++) {
			Write-Buffer -X 0 -Y $Outputline -Text (" " * $HostWidth)
			$Outputline++
		}
	}
		# Flush entire UI to console in one operation
		# Use ClearFirst on forced redraws (startup transition, resize, re-open after dialog)
		# to atomically clear stale content and paint the new frame in one write.
		if ($forceRedraw) { Flush-Buffer -ClearFirst } else { Flush-Buffer }
	} elseif ($Output -eq "hidden") {
		$script:ModeButtonBounds        = $null  # Header not rendered in hidden mode
		$script:HeaderEndTimeBounds     = $null
		$script:HeaderCurrentTimeBounds = $null
		$script:HeaderLogoBounds        = $null
		if (-not $skipConsoleUpdate) {
			# Use live window dimensions for layout so the (h) button is always correctly
				# positioned even while a resize is in progress. The outer resize path (above)
				# handles updating $HostWidth/$HostHeight and firing Send-ResizeExitWakeKey
				# once the window has been stable for $ResizeThrottleMs.
				$pswindow = (Get-Host).UI.RawUI
				$newW = $pswindow.WindowSize.Width
				$newH = $pswindow.WindowSize.Height
				
				$timeStr = $date.ToString("HH:mm:ss")
				$statusLine = "$timeStr | running..."
				
				Write-Buffer -X 0 -Y 0 -Text $statusLine.PadRight($newW)
				
			$hBtnY = [math]::Max(1, $newH - 2)
			$hBtnX = [math]::Max(0, $newW - 4)
	$hIsPressed = ($script:PressedMenuButton -eq "i")
	$hBtnFg   = if ($hIsPressed) { $script:MenuButtonOnClickFg }     else { $script:MenuButtonText }
	$hBtnBg   = if ($hIsPressed) { $script:MenuButtonOnClickBg }     else { $script:MenuButtonBg }
	$hBtnHkFg = if ($hIsPressed) { $script:MenuButtonOnClickHotkey } else { $script:MenuButtonHotkey }
	Write-Buffer -X $hBtnX -Y $hBtnY -Text "(" -FG $hBtnFg -BG $hBtnBg
	Write-Buffer -Text "i" -FG $hBtnHkFg -BG $hBtnBg
	Write-Buffer -Text ")" -FG $hBtnFg -BG $hBtnBg
			
			if ($forceRedraw) { Flush-Buffer -ClearFirst } else { Flush-Buffer }
			
		$script:MenuItemsBounds = @(@{
			startX      = $hBtnX
			endX        = $hBtnX + 2
			y           = $hBtnY
		hotkey      = "i"
		index       = 0
		displayText = "(i)"
				format      = 1
				fg          = $script:MenuButtonText
				bg          = $script:MenuButtonBg
				hotkeyFg    = $script:MenuButtonHotkey
				pipeFg      = $script:MenuButtonSeparatorFg
				bracketFg   = $script:MenuButtonBracketFg
				bracketBg   = $script:MenuButtonBracketBg
				onClickFg          = $script:MenuButtonOnClickFg
				onClickBg          = $script:MenuButtonOnClickBg
				onClickHotkeyFg    = $script:MenuButtonOnClickHotkey
				onClickPipeFg      = $script:MenuButtonOnClickSeparatorFg
				onClickBracketFg   = $script:MenuButtonOnClickBracketFg
				onClickBracketBg   = $script:MenuButtonOnClickBracketBg
			})
			}
		}
			# If skipConsoleUpdate is true and Output is not "hidden", don't render anything (prevents stutter)
			
		# Reset resize cleared screen flag after we've completed a redraw
		# This ensures the screen will be cleared again if user starts a new resize
		if ($forceRedraw -and -not $skipConsoleUpdate) {
			$ResizeClearedScreen = $false

			# A sub-dialog was used inside the Settings dialog — the full screen has
			# just been repainted cleanly above, so reopen Settings instantly on top.
			if ($script:PendingReopenSettings) {
				$script:PendingReopenSettings = $false
				$HostWidthRef  = [ref]$HostWidth;  $HostHeightRef = [ref]$HostHeight
				$endTimeIntRef = [ref]$endTimeInt; $endTimeStrRef = [ref]$endTimeStr
				$endRef        = [ref]$end;        $logArrayRef   = [ref]$LogArray
				$settingsResult = Show-SettingsDialog `
					-HostWidthRef $HostWidthRef -HostHeightRef $HostHeightRef `
					-EndTimeIntRef $endTimeIntRef -EndTimeStrRef $endTimeStrRef `
					-EndRef $endRef -LogArrayRef $logArrayRef `
					-SkipAnimation:$true
			$HostWidth  = $HostWidthRef.Value;  $HostHeight = $HostHeightRef.Value
			$endTimeInt = $endTimeIntRef.Value; $endTimeStr = $endTimeStrRef.Value
			$end        = $endRef.Value;        $LogArray   = $logArrayRef.Value
			$Output    = $script:Output
			$DebugMode = $script:DebugMode
			if ($settingsResult.ReopenSettings) {
			# Another sub-dialog was used — loop again via the next iteration
			$script:PendingReopenSettings = $true
		}
			$SkipUpdate  = $true
			# Signal the next iteration to skip sleep and redraw immediately.
			# Do NOT call clear-host here — the screen was just rendered cleanly
			# above and clearing it would cause a blank-screen flash.
			$script:PendingForceRedraw = $true
		}
		}
		
		# Check if end time reached (only if end time is set)
			# Compare full MMddHHmm values to handle overnight runs correctly
			if ($endTimeInt -ne -1 -and -not [string]::IsNullOrEmpty($end)) {
				try {
					$currentDateTimeInt = [int]($date.ToString("MMddHHmm"))
					$endDateTimeInt = [int]$end
					if ($currentDateTimeInt -ge $endDateTimeInt) {
						$time = $true
					}
				} catch {
					# If comparison fails, don't stop the script
				}
			}
			
			# Only break if time is explicitly set to true
			if ($time -eq $true) {
				# End message
				if ($Output -ne "hidden") {
					[Console]::SetCursorPosition(0, $Outputline)
					Write-Host "       END TIME REACHED: " -NoNewline -ForegroundColor $script:TextError
					Write-Host "Stopping " -NoNewline
					Write-Host "mJig"
					write-host
				}
				break
			}
		} # end :process
}
