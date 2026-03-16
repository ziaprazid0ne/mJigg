	function Show-InfoDialog {
		param([ref]$HostWidthRef, [ref]$HostHeightRef)

		$script:CurrentScreenState = "dialog-info"

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

	$buttonLayout = Get-DialogButtonLayout
	$dialogIconWidth = $buttonLayout.IconWidth; $dialogBracketWidth = $buttonLayout.BracketWidth; $dialogParenOffset = $buttonLayout.ParenAdjustment
	# Single close button: "| " + bracket? + icon? + "(c)lose" + padding + "|"
	# padding = dialogWidth - 10 - bracketWidth - iconWidth  (= 52 - b - i)
	$bottomLinePadding = $dialogWidth - 10 - $dialogParenOffset - $dialogBracketWidth - $dialogIconWidth

		$drawInfoDialog = {
			param($dx, $dy)
			$inner = $dialogWidth - 2   # 60
			$hLine = [string]$script:BoxHorizontal
			$mouseEmoji = [char]::ConvertFromUtf32(0x1F400)  # U+1F400 mouse
			$checkChar  = [char]0x2713   # U+2713 checkmark
			$arrowUp    = [char]0x2191   # U+2191 arrow up
			$redX       = [char]::ConvertFromUtf32(0x274C)   # U+274C red X

			# Clear dialog background
			for ($i = 0; $i -lt $dialogHeight; $i++) {
				Write-Buffer -X $dx -Y ($dy + $i) -Text (" " * $dialogWidth) -BG $script:InfoDialogBg
			}

			# — Line 0: top border --------------------------------------------
			Write-Buffer -X $dx -Y ($dy + 0) -Text ($script:BoxTopLeft + ($hLine * $inner) + $script:BoxTopRight) -FG $script:InfoDialogBorder -BG $script:InfoDialogBg

		# — Line 1: title with logo emoji ---------------------------------
		# Layout: |(1) + "  mJig("(7) + emoji(2) + ")"(1) + "  About & Version"(17) + pad(33) + |(1) = 62
		Write-Buffer -X $dx -Y ($dy + 1) -Text "$($script:BoxVertical)  mJig(" -FG $script:InfoDialogBorder -BG $script:InfoDialogBg
		Write-Buffer -Text $mouseEmoji -FG $script:InfoDialogTitle -BG $script:InfoDialogBg
		Write-Buffer -X ($dx + 10) -Y ($dy + 1) -Text ")" -FG $script:InfoDialogBorder -BG $script:InfoDialogBg
		Write-Buffer -Text "  About & Version" -FG $script:InfoDialogTitle -BG $script:InfoDialogBg
		Write-Buffer -Text (" " * 33) -BG $script:InfoDialogBg
		Write-Buffer -Text $script:BoxVertical -FG $script:InfoDialogBorder -BG $script:InfoDialogBg

			# — Line 2: divider -----------------------------------------------
			Write-Buffer -X $dx -Y ($dy + 2) -Text ($script:BoxVerticalRight + ($hLine * $inner) + $script:BoxVerticalLeft) -FG $script:InfoDialogBorder -BG $script:InfoDialogBg

			# — Line 3: blank -------------------------------------------------
			Write-Buffer -X $dx -Y ($dy + 3) -Text ($script:BoxVertical + (" " * $inner) + $script:BoxVertical) -FG $script:InfoDialogBorder -BG $script:InfoDialogBg

			# — Line 4: Version -----------------------------------------------
			$vLabel = "  Version:     "; $vVal = $script:Version
			Write-Buffer -X $dx -Y ($dy + 4) -Text $script:BoxVertical -FG $script:InfoDialogBorder -BG $script:InfoDialogBg
			Write-Buffer -Text $vLabel -FG $script:InfoDialogText -BG $script:InfoDialogBg
			Write-Buffer -Text $vVal   -FG $script:InfoDialogValue -BG $script:InfoDialogBg
			Write-Buffer -Text (" " * ($inner - $vLabel.Length - $vVal.Length)) -BG $script:InfoDialogBg
			Write-Buffer -Text $script:BoxVertical -FG $script:InfoDialogBorder -BG $script:InfoDialogBg

			# — Line 5: Latest release ----------------------------------------
			$lLabel = "  Latest:      "
			Write-Buffer -X $dx -Y ($dy + 5) -Text $script:BoxVertical -FG $script:InfoDialogBorder -BG $script:InfoDialogBg
			Write-Buffer -Text $lLabel -FG $script:InfoDialogText -BG $script:InfoDialogBg
			$lUsed = $lLabel.Length
			if ($null -eq $versionInfo -or $null -ne $versionInfo.error) {
				$failText = "Version check failed"
				Write-Buffer -Text $failText -FG $script:InfoDialogValueMuted -BG $script:InfoDialogBg
				$lUsed += $failText.Length
			} elseif ($versionInfo.isNewer) {
				Write-Buffer -Text $versionInfo.latest -FG $script:InfoDialogValueWarn -BG $script:InfoDialogBg
				Write-Buffer -Text "  " -BG $script:InfoDialogBg
				Write-Buffer -Text $arrowUp -FG $script:InfoDialogValueWarn -BG $script:InfoDialogBg
			Write-Buffer -Text " Update available" -FG $script:InfoDialogValueWarn -BG $script:InfoDialogBg
			$lUsed += $versionInfo.latest.Length + 2 + 1 + " Update available".Length
			} else {
				Write-Buffer -Text $versionInfo.latest -FG $script:InfoDialogValueGood -BG $script:InfoDialogBg
				Write-Buffer -Text "  " -BG $script:InfoDialogBg
				Write-Buffer -Text $checkChar -FG $script:InfoDialogValueGood -BG $script:InfoDialogBg
				Write-Buffer -Text " Up to date" -FG $script:InfoDialogValueGood -BG $script:InfoDialogBg
				$lUsed += $versionInfo.latest.Length + 2 + 1 + " Up to date".Length
			}
			Write-Buffer -Text (" " * [math]::Max(0, $inner - $lUsed)) -BG $script:InfoDialogBg
			Write-Buffer -Text $script:BoxVertical -FG $script:InfoDialogBorder -BG $script:InfoDialogBg

		# — Line 6: Repository --------------------------------------------
		$rLabel = "  Repository:  "; $rVal = "https://github.com/ziaprazid0ne/mJig"
			Write-Buffer -X $dx -Y ($dy + 6) -Text $script:BoxVertical -FG $script:InfoDialogBorder -BG $script:InfoDialogBg
			Write-Buffer -Text $rLabel -FG $script:InfoDialogText -BG $script:InfoDialogBg
			Write-Buffer -Text $rVal   -FG $script:InfoDialogValue -BG $script:InfoDialogBg
			Write-Buffer -Text (" " * ($inner - $rLabel.Length - $rVal.Length)) -BG $script:InfoDialogBg
			Write-Buffer -Text $script:BoxVertical -FG $script:InfoDialogBorder -BG $script:InfoDialogBg

			# — Line 7: blank -------------------------------------------------
			Write-Buffer -X $dx -Y ($dy + 7) -Text ($script:BoxVertical + (" " * $inner) + $script:BoxVertical) -FG $script:InfoDialogBorder -BG $script:InfoDialogBg

			# — Line 8: section divider ---------------------------------------
			Write-Buffer -X $dx -Y ($dy + 8) -Text ($script:BoxVerticalRight + ($hLine * $inner) + $script:BoxVerticalLeft) -FG $script:InfoDialogBorder -BG $script:InfoDialogBg

			# — Line 9: "Configuration" section title -------------------------
			$secTitle = "  Configuration"
			Write-Buffer -X $dx -Y ($dy + 9) -Text $script:BoxVertical -FG $script:InfoDialogBorder -BG $script:InfoDialogBg
			Write-Buffer -Text $secTitle -FG $script:InfoDialogSectionTitle -BG $script:InfoDialogBg
			Write-Buffer -Text (" " * ($inner - $secTitle.Length)) -BG $script:InfoDialogBg
			Write-Buffer -Text $script:BoxVertical -FG $script:InfoDialogBorder -BG $script:InfoDialogBg

			# — Line 10: section divider --------------------------------------
			Write-Buffer -X $dx -Y ($dy + 10) -Text ($script:BoxVerticalRight + ($hLine * $inner) + $script:BoxVerticalLeft) -FG $script:InfoDialogBorder -BG $script:InfoDialogBg

			# — Line 11: blank ------------------------------------------------
			Write-Buffer -X $dx -Y ($dy + 11) -Text ($script:BoxVertical + (" " * $inner) + $script:BoxVertical) -FG $script:InfoDialogBorder -BG $script:InfoDialogBg

			# — Lines 12-17: configuration rows ------------------------------
		$endTimeDsp    = if ($endTimeInt -eq -1 -or [string]::IsNullOrEmpty($endTimeStr)) { [char]0x2014 } else { "$($endTimeStr.Substring(0,2)):$($endTimeStr.Substring(2,2))" }
		$autoResumeDsp = if ($script:AutoResumeDelaySeconds -gt 0) { "$($script:AutoResumeDelaySeconds)s" } else { "Disabled" }
		$cfgRows = @(
			@{ label = "  Output:       "; value = $Output },
			@{ label = "  Interval:     "; value = "$($script:IntervalSeconds)s  (±$($script:IntervalVariance)s)" },
			@{ label = "  Distance:     "; value = "$($script:TravelDistance)px  (±$($script:TravelVariance)px)" },
			@{ label = "  Move speed:   "; value = "$($script:MoveSpeed)s  (±$($script:MoveVariance)s)" },
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

			# — Line 18: blank ------------------------------------------------
			Write-Buffer -X $dx -Y ($dy + 18) -Text ($script:BoxVertical + (" " * $inner) + $script:BoxVertical) -FG $script:InfoDialogBorder -BG $script:InfoDialogBg

			# — Line 19: close button row -------------------------------------
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
		$closingParen = if ($script:DialogButtonShowHotkeyParens) { ")" } else { "" }
		if ($script:DialogButtonShowHotkeyParens) { Write-Buffer -Text "(" -FG $script:InfoDialogButtonText -BG $script:InfoDialogButtonBg }
		Write-Buffer -Text "c" -FG $script:InfoDialogButtonHotkey -BG $script:InfoDialogButtonBg
		Write-Buffer -Text "$($closingParen)lose" -FG $script:InfoDialogButtonText -BG $script:InfoDialogButtonBg
			if ($script:DialogButtonShowBrackets) { Write-Buffer -Text "]" -FG $script:DialogButtonBracketFg -BG $script:DialogButtonBracketBg }
			Write-Buffer -Text (" " * $bottomLinePadding) -BG $script:InfoDialogBg
			Write-Buffer -Text $script:BoxVertical -FG $script:InfoDialogBorder -BG $script:InfoDialogBg

			# — Line 20: blank ------------------------------------------------
			Write-Buffer -X $dx -Y ($dy + 20) -Text ($script:BoxVertical + (" " * $inner) + $script:BoxVertical) -FG $script:InfoDialogBorder -BG $script:InfoDialogBg

			# — Line 21: bottom border ----------------------------------------
			Write-Buffer -X $dx -Y ($dy + 21) -Text ($script:BoxBottomLeft + ($hLine * $inner) + $script:BoxBottomRight) -FG $script:InfoDialogBorder -BG $script:InfoDialogBg
		}

		# Initial draw
		& $drawInfoDialog $dialogX $dialogY
		Write-DialogShadow -dialogX $dialogX -dialogY $dialogY -dialogWidth $dialogWidth -dialogHeight $dialogHeight -shadowColor $script:InfoDialogShadow
		Flush-Buffer

	# Button bounds (close button only — both update/cancel map to "close")
	$buttonRowY        = $dialogY + 19
	$closeButtonStartX = $dialogX + 2
	$closeButtonEndX   = $closeButtonStartX + $dialogBracketWidth + $dialogIconWidth + 7 + $dialogParenOffset - 1
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
				$stableSize = Invoke-ResizeHandler -PreviousScreenState "dialog-info"
				$HostWidthRef.Value  = $stableSize.Width
				$HostHeightRef.Value = $stableSize.Height
				$currentHostWidth    = $stableSize.Width
				$currentHostHeight   = $stableSize.Height
				Write-MainFrame -Force -NoFlush
				$needsRedraw         = $true

				$dialogX = [math]::Max(0, [math]::Floor(($currentHostWidth  - $dialogWidth)  / 2))
				$dialogY = [math]::Max(0, [math]::Floor(($currentHostHeight - $dialogHeight) / 2))

				& $drawInfoDialog $dialogX $dialogY
				Write-DialogShadow -dialogX $dialogX -dialogY $dialogY -dialogWidth $dialogWidth -dialogHeight $dialogHeight -shadowColor $script:InfoDialogShadow
			Flush-Buffer -ClearFirst

			$buttonRowY        = $dialogY + 19
			$closeButtonStartX = $dialogX + 2
			$closeButtonEndX   = $closeButtonStartX + $dialogBracketWidth + $dialogIconWidth + 7 + $dialogParenOffset - 1
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

		$_click = Get-DialogMouseClick -PeekBuffer $script:_DialogPeekBuffer
		if ($null -ne $_click) {
			$clickX = $_click.X; $clickY = $_click.Y
			if ($clickX -lt $dialogX -or $clickX -ge ($dialogX + $dialogWidth) -or $clickY -lt $dialogY -or $clickY -gt ($dialogY + $dialogHeight)) {
				$char = "c"; $keyProcessed = $true
			} elseif ($clickY -eq $buttonRowY -and $clickX -ge $closeButtonStartX -and $clickX -le $closeButtonEndX) {
				$char = "c"; $keyProcessed = $true
			}
		}

			# Main-loop DialogButtonClick (set when click is routed through main input handler)
			if (-not $keyProcessed -and $null -ne $script:DialogButtonClick) {
				$script:DialogButtonClick = $null
				$char = "c"; $keyProcessed = $true
			}

			# Keyboard input
		if (-not $keyProcessed) {
			$keyInfo = Read-DialogKeyInput
			if ($null -ne $keyInfo) {
				$key = $keyInfo.Key; $char = $keyInfo.Character; $keyProcessed = $true
			}
		}

			if (-not $keyProcessed) { Start-Sleep -Milliseconds 50; continue }

		if ($char -eq "c" -or $char -eq "C" -or $char -eq "?" -or $char -eq "/" -or
			$key  -eq "Escape" -or $key -eq "Enter" -or $char -eq [char]13 -or $char -eq [char]10) {
				break inputLoop
			}

		} while ($true)

	try { while ($Host.UI.RawUI.KeyAvailable) { $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown,AllowCtrlC") } } catch {}

	Invoke-DialogCleanup -DialogX $dialogX -DialogY $dialogY -DialogWidth $dialogWidth -DialogHeight $dialogHeight -SavedCursorVisible $savedCursorVisible -ClearShadow

	return @{ NeedsRedraw = $needsRedraw }
	}
