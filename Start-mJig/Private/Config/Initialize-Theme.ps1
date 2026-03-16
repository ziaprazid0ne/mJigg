	# ============================================================================
	# Theme Colors — all $script:* visual color variables
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
	$script:HeaderPauseButton = "White"   # pause / play emoji color
	$script:HeaderSeparator   = "White"   # full-width top and bottom separator lines
	# Header group background ($null = transparent); only innermost padding col/row gets this
	$script:HeaderBg         = "DarkBlue"
	# Header content row background (inset, does not bleed into padding)
	$script:HeaderRowBg      = "DarkCyan"
	# Footer group background ($null = transparent)
	$script:FooterBg         = "DarkBlue"
	# Menu bar content row background (inset)
	$script:MenuRowBg        = "DarkCyan"
	# Blank rows above/below chrome; blank columns left/right of each chrome row (clamped 1-5)
	$script:BorderPadV       = 1
	$script:BorderPadH       = 1
	$script:BorderPadV = [math]::Max(1, [math]::Min(5, $script:BorderPadV))
	$script:BorderPadH = [math]::Max(1, [math]::Min(5, $script:BorderPadH))

	# --- Main Display: Stats Box — panel level ---------------------------------
	# Outer box border and the "Stats" panel header title.
	$script:StatsBoxBorder    = "Cyan"
	$script:StatsBoxTitle     = "Cyan"

	# --- Main Display: Stats Box — Section 1: Session --------------------------
	$script:StatsSessionTitle = "Cyan"
	$script:StatsSessionLabel = "White"
	$script:StatsSessionValue = "Yellow"

	# --- Main Display: Stats Box — Section 2: Movement -------------------------
	$script:StatsMovementTitle = "Cyan"
	$script:StatsMovementLabel = "White"
	$script:StatsMovementValue = "Yellow"

	# --- Main Display: Stats Box — Section 3: Performance ----------------------
	$script:StatsPerformanceTitle = "Cyan"
	$script:StatsPerformanceLabel = "White"
	$script:StatsPerformanceValue = "Yellow"

	# --- Main Display: Stats Box — Section 4: Travel Distance ------------------
	$script:StatsTravelTitle = "Cyan"
	$script:StatsTravelLabel = "White"
	$script:StatsTravelValue = "Yellow"

	# --- Main Display: Stats Box — Section 5: Settings Snapshot ----------------
	$script:StatsSettingsTitle = "Cyan"
	$script:StatsSettingsLabel = "White"
	$script:StatsSettingsValue = "Yellow"

	# --- Main Display: Stats Box — Detected Inputs section ---------------------
	$script:StatsInputsTitle = "Cyan"
	$script:StatsInputsValue = "Yellow"

	# --- Main Display: Stats Box — Curve diagram section -----------------------
	$script:StatsCurveHeader = "Cyan"      # "Last Movement's Curve" title row
	$script:StatsCurveBorder = "Cyan"      # inner curve box borders
	$script:StatsCurveLine   = "DarkGray"  # horizontal reference line
	$script:StatsCurveDots   = "Yellow"    # plotted path dots
	$script:StatsCurveEq1    = "DarkGray"  # ease(t) formula
	$script:StatsCurveEq2    = "Yellow"    # L(t) formula

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
	$script:MenuButtonShowIcon  = $true   # Show/hide the icon prefix
	$script:MenuButtonSeparator = "|"     # Character between icon and label

	# --- Menu Bar: Bracket Wrapping --------------------------------------------
	$script:MenuButtonShowBrackets     = $true
	$script:MenuButtonBracketFg        = "DarkCyan"
	$script:MenuButtonBracketBg        = "DarkBlue"
	$script:MenuButtonOnClickBracketFg = "Black"
	$script:MenuButtonOnClickBracketBg = "DarkCyan"

	# --- Global: Hotkey Parentheses — independent for menu bar and dialogs ----
	$script:MenuButtonShowHotkeyParens   = $false   # Menu bar buttons + header mode button
	$script:DialogButtonShowHotkeyParens = $false    # All dialog box buttons

	# --- Dialogs: Shared Button Settings ---------------------------------------
	$script:DialogButtonShowIcon     = $true
	$script:DialogButtonSeparator    = "|"
	$script:DialogButtonShowBrackets = $false
	$script:DialogButtonBracketFg    = "White"
	$script:DialogButtonBracketBg    = $null   # null = transparent (inherits dialog BG)

	# --- Dialogs: Quit ---------------------------------------------------------
	$script:QuitDialogBg           = "DarkMagenta"
	$script:QuitDialogShadow       = "DarkMagenta"
	$script:QuitDialogBorder       = "White"
	$script:QuitDialogTitle        = "Yellow"
	$script:QuitDialogText         = "White"
	$script:QuitDialogButtonBg     = "Magenta"
	$script:QuitDialogButtonText   = "White"
	$script:QuitDialogButtonHotkey = "Green"

	# --- Menu Bar: Quit Button — inherits MenuButton* defaults ----------------
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

	# --- Dialogs: Settings — onfocus + offfocus (sub-dialog open) states ------
	$script:SettingsDialogBg           = "DarkBlue"
	$script:SettingsDialogBorder       = "White"
	$script:SettingsDialogTitle        = "Yellow"
	$script:SettingsDialogText         = "White"
	$script:SettingsDialogButtonBg     = "DarkCyan"
	$script:SettingsDialogButtonText   = "White"
	$script:SettingsDialogButtonHotkey = "Green"
	# Off-focus colors (sub-dialog open)
	$script:SettingsDialogShadow               = "DarkBlue"

	$script:SettingsDialogOffFocusBg           = "DarkGray"
	$script:SettingsDialogOffFocusBorder       = "Gray"
	$script:SettingsDialogOffFocusTitle        = "DarkYellow"
	$script:SettingsDialogOffFocusText         = "Gray"
	$script:SettingsDialogOffFocusButtonBg     = "DarkGray"
	$script:SettingsDialogOffFocusButtonText   = "Gray"
	$script:SettingsDialogOffFocusButtonHotkey = "DarkYellow"

	# --- Menu Bar: Settings Button — OnClick defaults match settings dialog ----
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
	$script:TimeDialogBg           = "DarkBlue"
	$script:TimeDialogShadow       = "DarkBlue"
	$script:TimeDialogBorder       = "White"
	$script:TimeDialogTitle        = "Yellow"
	$script:TimeDialogText         = "White"
	$script:TimeDialogButtonBg     = "DarkCyan"
	$script:TimeDialogButtonText   = "White"
	$script:TimeDialogButtonHotkey = "Green"
	$script:TimeDialogFieldBg      = "Blue"
	$script:TimeDialogFieldText    = "White"

	# --- Dialogs: Modify Movement ----------------------------------------------
	$script:MoveDialogBg            = "DarkBlue"
	$script:MoveDialogShadow        = "DarkBlue"
	$script:MoveDialogBorder        = "White"
	$script:MoveDialogTitle         = "Yellow"
	$script:MoveDialogSectionTitle  = "Yellow"
	$script:MoveDialogText          = "White"
	$script:MoveDialogButtonBg      = "DarkCyan"
	$script:MoveDialogButtonText    = "White"
	$script:MoveDialogButtonHotkey  = "Green"
	$script:MoveDialogFieldBg       = "Blue"
	$script:MoveDialogFieldText     = "White"

	# --- Dialogs: Info / About -------------------------------------------------
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
	$script:InfoDialogButtonBg     = "DarkCyan"
	$script:InfoDialogButtonText   = "White"
	$script:InfoDialogButtonHotkey = "Green"

	# --- Dialogs: Theme --------------------------------------------------------
	$script:ThemeDialogBg           = "DarkBlue"
	$script:ThemeDialogShadow       = "DarkBlue"
	$script:ThemeDialogBorder       = "White"
	$script:ThemeDialogTitle        = "Yellow"
	$script:ThemeDialogText         = "White"
	$script:ThemeDialogNameFg       = "Cyan"    # current theme name display color
	$script:ThemeDialogButtonBg     = "DarkCyan"
	$script:ThemeDialogButtonText   = "White"
	$script:ThemeDialogButtonHotkey = "Green"

	# --- Menu Bar: Theme Button — OnClick defaults match theme dialog ----------
	$script:ThemeButtonBg                  = $script:MenuButtonBg
	$script:ThemeButtonText                = $script:MenuButtonText
	$script:ThemeButtonHotkey              = $script:MenuButtonHotkey
	$script:ThemeButtonSeparatorFg         = $script:MenuButtonSeparatorFg
	$script:ThemeButtonBracketFg           = $script:MenuButtonBracketFg
	$script:ThemeButtonBracketBg           = $script:MenuButtonBracketBg
	$script:ThemeButtonOnClickBg           = $script:ThemeDialogBg
	$script:ThemeButtonOnClickFg           = $script:ThemeDialogText
	$script:ThemeButtonOnClickHotkey       = $script:ThemeDialogTitle
	$script:ThemeButtonOnClickSeparatorFg  = $script:ThemeDialogText
	$script:ThemeButtonOnClickBracketFg    = $script:ThemeDialogBorder
	$script:ThemeButtonOnClickBracketBg    = $script:ThemeDialogBg

	# --- Resize Screen ---------------------------------------------------------
	$script:ResizeBoxBorder  = "White"
	$script:ResizeLogoName   = "Magenta"
	$script:ResizeLogoIcon   = "White"
	$script:ResizeQuoteText  = "White"

	# --- Theme Profile State ---------------------------------------------------
	# Active theme name and index; set by Set-ThemeProfile.
	$script:CurrentThemeName  = ""
	$script:CurrentThemeIndex = 0

	# --- Theme Profiles --------------------------------------------------------
	# Each profile has a Name and an Apply scriptblock that sets $script:* color vars.
	# Apply runs via & in the caller's scope so $script: assignments work correctly.
	$script:ThemeProfiles = @(
		@{
			Name  = "default"
			Apply = {
				# General
				$script:TextDefault   = "White"
				$script:TextMuted     = "DarkGray"
				$script:TextHighlight = "Cyan"
				$script:TextSuccess   = "Green"
				$script:TextWarning   = "Yellow"
				$script:TextError     = "Red"

				# Header — no chrome backgrounds; only on-click and popups use backgrounds
				$script:HeaderAppName     = "Magenta"
				$script:HeaderIcon        = "White"
				$script:HeaderStatus      = "Green"
				$script:HeaderPaused      = "Yellow"
				$script:HeaderTimeLabel   = "Yellow"
				$script:HeaderTimeValue   = "Green"
				$script:HeaderViewTag     = "Magenta"
				$script:HeaderPauseButton = "White"
				$script:HeaderSeparator   = "DarkCyan"
				$script:HeaderBg          = $null
				$script:HeaderRowBg       = $null
				$script:FooterBg          = $null
				$script:MenuRowBg         = $null
				$script:BorderPadV        = 1
				$script:BorderPadH        = 1

				# Stats box
				$script:StatsBoxBorder = "Cyan"
				$script:StatsBoxTitle  = "Cyan"

				# Stats: Session
				$script:StatsSessionTitle = "Cyan"
				$script:StatsSessionLabel = "DarkGray"
				$script:StatsSessionValue = "White"

				# Stats: Movement
				$script:StatsMovementTitle = "Cyan"
				$script:StatsMovementLabel = "DarkGray"
				$script:StatsMovementValue = "White"

				# Stats: Performance
				$script:StatsPerformanceTitle = "Cyan"
				$script:StatsPerformanceLabel = "DarkGray"
				$script:StatsPerformanceValue = "White"

				# Stats: Travel Distance
				$script:StatsTravelTitle = "Cyan"
				$script:StatsTravelLabel = "DarkGray"
				$script:StatsTravelValue = "White"

				# Stats: Settings Snapshot
				$script:StatsSettingsTitle = "Cyan"
				$script:StatsSettingsLabel = "DarkGray"
				$script:StatsSettingsValue = "White"

				# Stats: Detected Inputs
				$script:StatsInputsTitle = "Cyan"
				$script:StatsInputsValue = "White"

				# Stats: Curve
				$script:StatsCurveHeader = "Cyan"
				$script:StatsCurveBorder = "DarkCyan"
				$script:StatsCurveLine   = "DarkGray"
				$script:StatsCurveDots   = "Cyan"
				$script:StatsCurveEq1    = "DarkGray"
				$script:StatsCurveEq2    = "DarkGray"

				# Menu bar — transparent bg; only on-click gets a background
				$script:MenuButtonBg               = $null
				$script:MenuButtonText             = "White"
				$script:MenuButtonHotkey           = "Cyan"
				$script:MenuButtonSeparatorFg      = "DarkGray"
				$script:MenuButtonOnClickBg        = "DarkBlue"
				$script:MenuButtonOnClickFg        = "White"
				$script:MenuButtonOnClickHotkey    = "Cyan"
				$script:MenuButtonOnClickSeparatorFg = "DarkGray"
				$script:MenuButtonShowIcon         = $true
				$script:MenuButtonSeparator        = "|"
				$script:MenuButtonShowBrackets     = $false
				$script:MenuButtonBracketFg        = "DarkCyan"
				$script:MenuButtonBracketBg        = $null
				$script:MenuButtonOnClickBracketFg = "Cyan"
				$script:MenuButtonOnClickBracketBg = "DarkBlue"
				$script:MenuButtonShowHotkeyParens   = $false
				$script:DialogButtonShowHotkeyParens = $false

				# Dialog shared
				$script:DialogButtonShowIcon     = $true
				$script:DialogButtonSeparator    = "|"
				$script:DialogButtonShowBrackets = $false
				$script:DialogButtonBracketFg    = "White"
				$script:DialogButtonBracketBg    = $null

				# Quit dialog
				$script:QuitDialogBg           = "DarkMagenta"
				$script:QuitDialogShadow       = "DarkMagenta"
				$script:QuitDialogBorder       = "White"
				$script:QuitDialogTitle        = "Yellow"
				$script:QuitDialogText         = "White"
				$script:QuitDialogButtonBg     = "Magenta"
				$script:QuitDialogButtonText   = "White"
				$script:QuitDialogButtonHotkey = "Green"
				$script:QuitButtonBg                  = $script:MenuButtonBg
				$script:QuitButtonText                = $script:MenuButtonText
				$script:QuitButtonHotkey              = $script:MenuButtonHotkey
				$script:QuitButtonSeparatorFg         = $script:MenuButtonSeparatorFg
				$script:QuitButtonBracketFg           = $script:MenuButtonBracketFg
				$script:QuitButtonBracketBg           = $script:MenuButtonBracketBg
				$script:QuitButtonOnClickBg           = $script:QuitDialogBg
				$script:QuitButtonOnClickFg           = $script:QuitDialogText
				$script:QuitButtonOnClickHotkey       = $script:QuitDialogTitle
				$script:QuitButtonOnClickSeparatorFg  = $script:QuitDialogText
				$script:QuitButtonOnClickBracketFg    = $script:QuitDialogBorder
				$script:QuitButtonOnClickBracketBg    = $script:QuitDialogBg

				# Settings dialog
				$script:SettingsDialogBg                    = "DarkBlue"
				$script:SettingsDialogShadow                = "DarkBlue"
				$script:SettingsDialogBorder                = "White"
				$script:SettingsDialogTitle                 = "Yellow"
				$script:SettingsDialogText                  = "White"
				$script:SettingsDialogButtonBg              = "Blue"
				$script:SettingsDialogButtonText            = "White"
				$script:SettingsDialogButtonHotkey          = "Green"
				$script:SettingsDialogOffFocusBg            = "DarkGray"
				$script:SettingsDialogOffFocusBorder        = "Gray"
				$script:SettingsDialogOffFocusTitle         = "DarkYellow"
				$script:SettingsDialogOffFocusText          = "Gray"
				$script:SettingsDialogOffFocusButtonBg      = "DarkGray"
				$script:SettingsDialogOffFocusButtonText    = "Gray"
				$script:SettingsDialogOffFocusButtonHotkey  = "DarkYellow"
				$script:SettingsButtonBg                    = $script:MenuButtonBg
				$script:SettingsButtonText                  = $script:MenuButtonText
				$script:SettingsButtonHotkey                = $script:MenuButtonHotkey
				$script:SettingsButtonSeparatorFg           = $script:MenuButtonSeparatorFg
				$script:SettingsButtonBracketFg             = $script:MenuButtonBracketFg
				$script:SettingsButtonBracketBg             = $script:MenuButtonBracketBg
				$script:SettingsButtonOnClickBg             = $script:SettingsDialogBg
				$script:SettingsButtonOnClickFg             = $script:SettingsDialogText
				$script:SettingsButtonOnClickHotkey         = $script:SettingsDialogTitle
				$script:SettingsButtonOnClickSeparatorFg    = $script:SettingsDialogText
				$script:SettingsButtonOnClickBracketFg      = $script:SettingsDialogBorder
				$script:SettingsButtonOnClickBracketBg      = $script:SettingsDialogBg

				# Time dialog
				$script:TimeDialogBg           = "DarkBlue"
				$script:TimeDialogShadow       = "DarkBlue"
				$script:TimeDialogBorder       = "White"
				$script:TimeDialogTitle        = "Yellow"
				$script:TimeDialogText         = "White"
				$script:TimeDialogButtonBg     = "DarkCyan"
				$script:TimeDialogButtonText   = "White"
				$script:TimeDialogButtonHotkey = "Green"
				$script:TimeDialogFieldBg      = "Blue"
				$script:TimeDialogFieldText    = "White"

				# Move dialog
				$script:MoveDialogBg           = "DarkBlue"
				$script:MoveDialogShadow       = "DarkBlue"
				$script:MoveDialogBorder       = "White"
				$script:MoveDialogTitle        = "Yellow"
				$script:MoveDialogSectionTitle = "Yellow"
				$script:MoveDialogText         = "White"
				$script:MoveDialogButtonBg     = "Blue"
				$script:MoveDialogButtonText   = "White"
				$script:MoveDialogButtonHotkey = "Green"
				$script:MoveDialogFieldBg      = "Blue"
				$script:MoveDialogFieldText    = "White"

				# Info dialog
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
				$script:InfoDialogButtonBg     = "DarkCyan"
				$script:InfoDialogButtonText   = "White"
				$script:InfoDialogButtonHotkey = "Green"

				# Theme dialog
				$script:ThemeDialogBg           = "DarkBlue"
				$script:ThemeDialogShadow       = "DarkBlue"
				$script:ThemeDialogBorder       = "White"
				$script:ThemeDialogTitle        = "Yellow"
				$script:ThemeDialogText         = "White"
				$script:ThemeDialogNameFg       = "Cyan"
				$script:ThemeDialogButtonBg     = "DarkCyan"
				$script:ThemeDialogButtonText   = "White"
				$script:ThemeDialogButtonHotkey = "Green"
				$script:ThemeButtonBg                 = $script:MenuButtonBg
				$script:ThemeButtonText               = $script:MenuButtonText
				$script:ThemeButtonHotkey             = $script:MenuButtonHotkey
				$script:ThemeButtonSeparatorFg        = $script:MenuButtonSeparatorFg
				$script:ThemeButtonBracketFg          = $script:MenuButtonBracketFg
				$script:ThemeButtonBracketBg          = $script:MenuButtonBracketBg
				$script:ThemeButtonOnClickBg          = $script:ThemeDialogBg
				$script:ThemeButtonOnClickFg          = $script:ThemeDialogText
				$script:ThemeButtonOnClickHotkey      = $script:ThemeDialogTitle
				$script:ThemeButtonOnClickSeparatorFg = $script:ThemeDialogText
				$script:ThemeButtonOnClickBracketFg   = $script:ThemeDialogBorder
				$script:ThemeButtonOnClickBracketBg   = $script:ThemeDialogBg

				# Resize screen
				$script:ResizeBoxBorder = "White"
				$script:ResizeLogoName  = "Magenta"
				$script:ResizeLogoIcon  = "White"
				$script:ResizeQuoteText = "White"
			}
		},
		@{
			Name  = "debug"
			Apply = {
				# General
				$script:TextDefault   = "White"
				$script:TextMuted     = "DarkGray"
				$script:TextHighlight = "Yellow"
				$script:TextSuccess   = "Green"
				$script:TextWarning   = "DarkYellow"
				$script:TextError     = "Red"

				# Header — all backgrounds visible to show layout
				$script:HeaderAppName     = "Yellow"
				$script:HeaderIcon        = "White"
				$script:HeaderStatus      = "Cyan"
				$script:HeaderPaused      = "Magenta"
				$script:HeaderTimeLabel   = "DarkYellow"
				$script:HeaderTimeValue   = "Green"
				$script:HeaderViewTag     = "DarkCyan"
				$script:HeaderPauseButton = "Yellow"
				$script:HeaderSeparator   = "Cyan"
				$script:HeaderBg          = "DarkBlue"
				$script:HeaderRowBg       = "Blue"
				$script:FooterBg          = "DarkGreen"
				$script:MenuRowBg         = "Green"
				$script:BorderPadV        = 2
				$script:BorderPadH        = 2

				# Stats box
				$script:StatsBoxBorder = "DarkCyan"
				$script:StatsBoxTitle  = "Cyan"

				# Stats: Session — Cyan family
				$script:StatsSessionTitle = "Cyan"
				$script:StatsSessionLabel = "DarkCyan"
				$script:StatsSessionValue = "White"

				# Stats: Movement — Green family
				$script:StatsMovementTitle = "Green"
				$script:StatsMovementLabel = "DarkGreen"
				$script:StatsMovementValue = "Yellow"

				# Stats: Performance — Magenta family
				$script:StatsPerformanceTitle = "Magenta"
				$script:StatsPerformanceLabel = "DarkMagenta"
				$script:StatsPerformanceValue = "Red"

				# Stats: Travel Distance — Yellow family
				$script:StatsTravelTitle = "Yellow"
				$script:StatsTravelLabel = "DarkYellow"
				$script:StatsTravelValue = "Cyan"

				# Stats: Settings Snapshot — Gray family
				$script:StatsSettingsTitle = "White"
				$script:StatsSettingsLabel = "DarkGray"
				$script:StatsSettingsValue = "Gray"

				# Stats: Detected Inputs
				$script:StatsInputsTitle = "DarkCyan"
				$script:StatsInputsValue = "Cyan"

				# Stats: Curve — distinct from all sections
				$script:StatsCurveHeader = "Yellow"
				$script:StatsCurveBorder = "DarkYellow"
				$script:StatsCurveLine   = "DarkGray"
				$script:StatsCurveDots   = "Green"
				$script:StatsCurveEq1    = "DarkGray"
				$script:StatsCurveEq2    = "Cyan"

				# Menu bar — visible background to contrast footer
				$script:MenuButtonBg               = "DarkGray"
				$script:MenuButtonText             = "White"
				$script:MenuButtonHotkey           = "Yellow"
				$script:MenuButtonSeparatorFg      = "Gray"
				$script:MenuButtonOnClickBg        = "Yellow"
				$script:MenuButtonOnClickFg        = "Black"
				$script:MenuButtonOnClickHotkey    = "Black"
				$script:MenuButtonOnClickSeparatorFg = "DarkGray"
				$script:MenuButtonShowIcon         = $true
				$script:MenuButtonSeparator        = "|"
				$script:MenuButtonShowBrackets     = $true
				$script:MenuButtonBracketFg        = "DarkCyan"
				$script:MenuButtonBracketBg        = "DarkGray"
				$script:MenuButtonOnClickBracketFg = "Black"
				$script:MenuButtonOnClickBracketBg = "Yellow"
				$script:MenuButtonShowHotkeyParens   = $true
				$script:DialogButtonShowHotkeyParens = $true

				# Dialog shared
				$script:DialogButtonShowIcon     = $true
				$script:DialogButtonSeparator    = "|"
				$script:DialogButtonShowBrackets = $true
				$script:DialogButtonBracketFg    = "Yellow"
				$script:DialogButtonBracketBg    = $null

				# Quit dialog
				$script:QuitDialogBg           = "DarkMagenta"
				$script:QuitDialogShadow       = "DarkMagenta"
				$script:QuitDialogBorder       = "Yellow"
				$script:QuitDialogTitle        = "White"
				$script:QuitDialogText         = "White"
				$script:QuitDialogButtonBg     = "Magenta"
				$script:QuitDialogButtonText   = "Yellow"
				$script:QuitDialogButtonHotkey = "White"
				$script:QuitButtonBg                  = $script:MenuButtonBg
				$script:QuitButtonText                = $script:MenuButtonText
				$script:QuitButtonHotkey              = $script:MenuButtonHotkey
				$script:QuitButtonSeparatorFg         = $script:MenuButtonSeparatorFg
				$script:QuitButtonBracketFg           = $script:MenuButtonBracketFg
				$script:QuitButtonBracketBg           = $script:MenuButtonBracketBg
				$script:QuitButtonOnClickBg           = $script:QuitDialogBg
				$script:QuitButtonOnClickFg           = $script:QuitDialogText
				$script:QuitButtonOnClickHotkey       = $script:QuitDialogTitle
				$script:QuitButtonOnClickSeparatorFg  = $script:QuitDialogText
				$script:QuitButtonOnClickBracketFg    = $script:QuitDialogBorder
				$script:QuitButtonOnClickBracketBg    = $script:QuitDialogBg

				# Settings dialog
				$script:SettingsDialogBg                    = "DarkBlue"
				$script:SettingsDialogShadow                = "DarkBlue"
				$script:SettingsDialogBorder                = "Cyan"
				$script:SettingsDialogTitle                 = "Yellow"
				$script:SettingsDialogText                  = "White"
				$script:SettingsDialogButtonBg              = "Blue"
				$script:SettingsDialogButtonText            = "Cyan"
				$script:SettingsDialogButtonHotkey          = "Green"
				$script:SettingsDialogOffFocusBg            = "DarkGray"
				$script:SettingsDialogOffFocusBorder        = "Gray"
				$script:SettingsDialogOffFocusTitle         = "DarkYellow"
				$script:SettingsDialogOffFocusText          = "Gray"
				$script:SettingsDialogOffFocusButtonBg      = "DarkGray"
				$script:SettingsDialogOffFocusButtonText    = "Gray"
				$script:SettingsDialogOffFocusButtonHotkey  = "DarkYellow"
				$script:SettingsButtonBg                    = $script:MenuButtonBg
				$script:SettingsButtonText                  = $script:MenuButtonText
				$script:SettingsButtonHotkey                = $script:MenuButtonHotkey
				$script:SettingsButtonSeparatorFg           = $script:MenuButtonSeparatorFg
				$script:SettingsButtonBracketFg             = $script:MenuButtonBracketFg
				$script:SettingsButtonBracketBg             = $script:MenuButtonBracketBg
				$script:SettingsButtonOnClickBg             = $script:SettingsDialogBg
				$script:SettingsButtonOnClickFg             = $script:SettingsDialogText
				$script:SettingsButtonOnClickHotkey         = $script:SettingsDialogTitle
				$script:SettingsButtonOnClickSeparatorFg    = $script:SettingsDialogText
				$script:SettingsButtonOnClickBracketFg      = $script:SettingsDialogBorder
				$script:SettingsButtonOnClickBracketBg      = $script:SettingsDialogBg

				# Time dialog
				$script:TimeDialogBg           = "DarkBlue"
				$script:TimeDialogShadow       = "DarkBlue"
				$script:TimeDialogBorder       = "Cyan"
				$script:TimeDialogTitle        = "Yellow"
				$script:TimeDialogText         = "White"
				$script:TimeDialogButtonBg     = "DarkCyan"
				$script:TimeDialogButtonText   = "Cyan"
				$script:TimeDialogButtonHotkey = "Green"
				$script:TimeDialogFieldBg      = "DarkCyan"
				$script:TimeDialogFieldText    = "White"

				# Move dialog
				$script:MoveDialogBg           = "DarkBlue"
				$script:MoveDialogShadow       = "DarkBlue"
				$script:MoveDialogBorder       = "Green"
				$script:MoveDialogTitle        = "Yellow"
				$script:MoveDialogSectionTitle = "Cyan"
				$script:MoveDialogText         = "White"
				$script:MoveDialogButtonBg     = "DarkGreen"
				$script:MoveDialogButtonText   = "White"
				$script:MoveDialogButtonHotkey = "Yellow"
				$script:MoveDialogFieldBg      = "DarkCyan"
				$script:MoveDialogFieldText    = "White"

				# Info dialog
				$script:InfoDialogBg           = "DarkBlue"
				$script:InfoDialogShadow       = "DarkBlue"
				$script:InfoDialogBorder       = "Magenta"
				$script:InfoDialogTitle        = "Yellow"
				$script:InfoDialogText         = "White"
				$script:InfoDialogValue        = "Cyan"
				$script:InfoDialogValueGood    = "Green"
				$script:InfoDialogValueWarn    = "Yellow"
				$script:InfoDialogValueMuted   = "DarkGray"
				$script:InfoDialogSectionTitle = "Magenta"
				$script:InfoDialogButtonBg     = "DarkMagenta"
				$script:InfoDialogButtonText   = "White"
				$script:InfoDialogButtonHotkey = "Green"

				# Theme dialog — distinct from other dialogs
				$script:ThemeDialogBg           = "DarkGreen"
				$script:ThemeDialogShadow       = "DarkGreen"
				$script:ThemeDialogBorder       = "Green"
				$script:ThemeDialogTitle        = "Yellow"
				$script:ThemeDialogText         = "White"
				$script:ThemeDialogNameFg       = "Cyan"
				$script:ThemeDialogButtonBg     = "DarkCyan"
				$script:ThemeDialogButtonText   = "White"
				$script:ThemeDialogButtonHotkey = "Green"
				$script:ThemeButtonBg                 = $script:MenuButtonBg
				$script:ThemeButtonText               = $script:MenuButtonText
				$script:ThemeButtonHotkey             = $script:MenuButtonHotkey
				$script:ThemeButtonSeparatorFg        = $script:MenuButtonSeparatorFg
				$script:ThemeButtonBracketFg          = $script:MenuButtonBracketFg
				$script:ThemeButtonBracketBg          = $script:MenuButtonBracketBg
				$script:ThemeButtonOnClickBg          = $script:ThemeDialogBg
				$script:ThemeButtonOnClickFg          = $script:ThemeDialogText
				$script:ThemeButtonOnClickHotkey      = $script:ThemeDialogTitle
				$script:ThemeButtonOnClickSeparatorFg = $script:ThemeDialogText
				$script:ThemeButtonOnClickBracketFg   = $script:ThemeDialogBorder
				$script:ThemeButtonOnClickBracketBg   = $script:ThemeDialogBg

				# Resize screen
				$script:ResizeBoxBorder = "Cyan"
				$script:ResizeLogoName  = "Yellow"
				$script:ResizeLogoIcon  = "Green"
				$script:ResizeQuoteText = "DarkCyan"
			}
		}
	)
