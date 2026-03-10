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
	# Blank-line/column border around the chrome. Clamped to 1–5 below.
	# Only the innermost row/column on each side receives the Header/FooterBg; extras stay transparent.
	# YAML: mainDisplay.borderPadV (top/bottom rows)
	$script:BorderPadV       = 1
	# YAML: mainDisplay.borderPadH (left/right columns)
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
