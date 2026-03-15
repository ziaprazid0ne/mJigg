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
	$script:HeaderSeparator  = "White"
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
	$script:QuitDialogButtonHotkey = "Yellow"

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
	$script:SettingsDialogButtonBg     = "Blue"
	$script:SettingsDialogButtonText   = "White"
	$script:SettingsDialogButtonHotkey = "Yellow"
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
	$script:TimeDialogButtonBg     = "Blue"
	$script:TimeDialogButtonText   = "White"
	$script:TimeDialogButtonHotkey = "Yellow"
	$script:TimeDialogFieldBg      = "Blue"
	$script:TimeDialogFieldText    = "White"

	# --- Dialogs: Modify Movement ----------------------------------------------
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
	$script:ResizeBoxBorder  = "White"
	$script:ResizeLogoName   = "Magenta"
	$script:ResizeLogoIcon   = "White"
	$script:ResizeQuoteText  = "White"
