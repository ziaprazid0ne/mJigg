	function Show-SettingsDialog {
		param(
			[ref]$HostWidthRef,
			[ref]$HostHeightRef,
			[ref]$EndTimeIntRef,    # $endTimeInt in the main loop
			[ref]$EndTimeStrRef,    # $endTimeStr
			[ref]$EndRef,           # $end
			[ref]$LogArrayRef,      # $LogArray
			[bool]$SkipAnimation = $false,
			[switch]$DeferFlush = $false
		)

		$script:CurrentScreenState = "dialog-settings"

		$currentHostWidth  = $HostWidthRef.Value
		$currentHostHeight = $HostHeightRef.Value

$dialogWidth  = 26
# Rows: 0=border, 1=title, 2=divider, 3=blank, 4=time, 5=blank, 6=movement, 7=blank, 8=options, 9=blank, 10=theme, 11=blank, 12=border
$dialogHeight = 12

		# Left edge aligns with the first column of the border padding area
		$_bpH    = [math]::Max(1, $script:BorderPadH)
		$dialogX = [math]::Max(0, [math]::Min($_bpH - 1, $currentHostWidth - $dialogWidth))
		$menuBarY     = if ($null -ne $script:MenuBarY) { $script:MenuBarY } else { $currentHostHeight - 2 }
		$dialogY      = [math]::Max(0, $menuBarY - 2 - $dialogHeight)

		$savedCursorVisible = $script:CursorVisible
		$script:CursorVisible = $false
		[Console]::Write("$($script:ESC)[?25l")

		# Icon emojis used in buttons
	$emojiHourglass = [char]::ConvertFromUtf32(0x23F3)  # U+23F3 hourglass
	$emojiMouse     = [char]::ConvertFromUtf32(0x1F5B1) # U+1F5B1 mouse
		$emojiOptions   = [char]::ConvertFromUtf32(0x2699)  # U+2699 gear
		$emojiTheme     = [char]::ConvertFromUtf32(0x1F3A8) # U+1F3A8 palette

		$buttonLayout = Get-DialogButtonLayout
		$dialogIconWidth = $buttonLayout.IconWidth; $dialogBracketWidth = $buttonLayout.BracketWidth; $dialogParenOffset = $buttonLayout.ParenAdjustment
	# Per-button right padding: dialogWidth - border(1) - space(1) - btnChars - border(1)
	# "End (T)ime"=10, "(M)ouse Movement"=16, "(O)ptions"=9, "(T)heme"=7
		$timePad    = $dialogWidth - (2 + $dialogBracketWidth + $dialogIconWidth + 10 + $dialogParenOffset + 1)
		$movePad    = $dialogWidth - (2 + $dialogBracketWidth + $dialogIconWidth + 16 + $dialogParenOffset + 1)
		$optionsPad = $dialogWidth - (2 + $dialogBracketWidth + $dialogIconWidth + 9  + $dialogParenOffset + 1)
		$themePad   = $dialogWidth - (2 + $dialogBracketWidth + $dialogIconWidth + 7  + $dialogParenOffset + 1)
		$timeButtonStartX    = $dialogX + 2
		$timeButtonEndX      = $dialogX + 2 + $dialogBracketWidth + $dialogIconWidth + 10 + $dialogParenOffset - 1
		$moveButtonStartX    = $dialogX + 2
		$moveButtonEndX      = $dialogX + 2 + $dialogBracketWidth + $dialogIconWidth + 16 + $dialogParenOffset - 1
		$optionsButtonStartX = $dialogX + 2
		$optionsButtonEndX   = $dialogX + 2 + $dialogBracketWidth + $dialogIconWidth + 9  + $dialogParenOffset - 1
		$themeButtonStartX   = $dialogX + 2
		$themeButtonEndX     = $dialogX + 2 + $dialogBracketWidth + $dialogIconWidth + 7  + $dialogParenOffset - 1

		# Build static line strings (used by animation + full render)
		$hLine      = [string]$script:BoxHorizontal
		$inner      = $dialogWidth - 2  # 33
		$line0      = $script:BoxTopLeft    + ($hLine * $inner) + $script:BoxTopRight
		$line2      = $script:BoxVerticalRight + ($hLine * $inner) + $script:BoxVerticalLeft
		$lineBlank  = $script:BoxVertical   + (" "   * $inner) + $script:BoxVertical
		$lineBottom = $script:BoxBottomLeft + ($hLine * $inner) + $script:BoxBottomRight
		# indices 0-12; rows 4, 6, 8, 10 are $null — drawn as inline toggle rows
		$dialogLines = @($line0, $null, $line2, $lineBlank, $null, $lineBlank, $null, $lineBlank, $null, $lineBlank, $null, $lineBlank, $lineBottom)
		$_stgDialogWidth  = $dialogWidth
		$_stgDialogHeight = $dialogHeight
		$_stgDialogLines  = $dialogLines

	# — Slide-up-from-behind animation (skipped on reopen after sub-dialog) --
	if (-not $SkipAnimation) {
		$clipY        = $menuBarY - 1
		$animSteps    = $dialogHeight + 1
		$frameDelayMs = 15
		for ($step = 2; $step -le ($animSteps + 1); $step += 2) {
			$s     = [math]::Min($step, $animSteps)
			$animY = $menuBarY - 1 - $s
			for ($r = 0; $r -lt $s -and $r -le $dialogHeight; $r++) {
				$rowY = $animY + $r
				if ($rowY -ge $clipY) { continue }
				if (($dialogX + $dialogWidth) -lt $currentHostWidth) { Write-Buffer -X ($dialogX + $dialogWidth) -Y $rowY -Text " " }
				Write-Buffer -X $dialogX -Y $rowY -Text (" " * $dialogWidth) -BG $script:SettingsDialogBg
				if ($r -eq 0) {
					Write-Buffer -X $dialogX -Y $rowY -Text $line0 -FG $script:SettingsDialogBorder -BG $script:SettingsDialogBg
				} elseif ($r -eq $dialogHeight) {
					Write-Buffer -X $dialogX -Y $rowY -Text $lineBottom -FG $script:SettingsDialogBorder -BG $script:SettingsDialogBg
				} else {
					Write-Buffer -X $dialogX                      -Y $rowY -Text $script:BoxVertical -FG $script:SettingsDialogBorder -BG $script:SettingsDialogBg
					Write-Buffer -X ($dialogX + $dialogWidth - 1) -Y $rowY -Text $script:BoxVertical -FG $script:SettingsDialogBorder -BG $script:SettingsDialogBg
				}
			}
			if ($s -eq $animSteps -and $animY -gt 0) {
				$aPadWidth = $dialogWidth + 1
				Write-Buffer -X $dialogX -Y ($animY - 1) -Text (" " * $aPadWidth)
			}
			Flush-Buffer
			if ($frameDelayMs -gt 0) { Start-Sleep -Milliseconds $frameDelayMs }
		}
	}

		# — Blank padding (terminal default BG) — top and right; no bottom or left --
		if ($dialogY -gt 0) {
			$padWidth = $dialogWidth + 1
			Write-Buffer -X $dialogX -Y ($dialogY - 1) -Text (" " * $padWidth)
		}
		for ($i = 0; $i -le $dialogHeight; $i++) {
			if (($dialogX + $dialogWidth) -lt $currentHostWidth) { Write-Buffer -X ($dialogX + $dialogWidth) -Y ($dialogY + $i) -Text " " }
		}

		$drawSettingsBtnRow = {
			param($dx, $absRowY, $emoji, $hotkeyChar, $labelSuffix, $rowPad, $btnBg, $btnText, $btnHotkey, $bgColor, $borderColor, $labelPrefix = "")
			$buttonX = $dx + 2
			Write-Buffer -X $dx -Y $absRowY -Text "$($script:BoxVertical) " -FG $borderColor -BG $bgColor
			if ($script:DialogButtonShowBrackets) { Write-Buffer -X $buttonX -Y $absRowY -Text "[" -FG $script:DialogButtonBracketFg -BG $script:DialogButtonBracketBg }
			$buttonContentX = $buttonX + [int]$script:DialogButtonShowBrackets
			if ($script:DialogButtonShowIcon) {
				Write-Buffer -X $buttonContentX -Y $absRowY -Text $emoji -BG $btnBg -Wide
				Write-Buffer -X ($buttonContentX + 2) -Y $absRowY -Text $script:DialogButtonSeparator -FG $btnText -BG $btnBg
			} else {
				Write-Buffer -X $buttonContentX -Y $absRowY -Text "" -BG $btnBg
			}
			if ($labelPrefix.Length -gt 0) { Write-Buffer -Text $labelPrefix -FG $btnText -BG $btnBg }
			$closingParen = if ($script:DialogButtonShowHotkeyParens) { ")" } else { "" }
			if ($script:DialogButtonShowHotkeyParens) { Write-Buffer -Text "(" -FG $btnText -BG $btnBg }
			Write-Buffer -Text $hotkeyChar -FG $btnHotkey -BG $btnBg
			Write-Buffer -Text "$closingParen${labelSuffix}" -FG $btnText -BG $btnBg
			if ($script:DialogButtonShowBrackets) { Write-Buffer -Text "]" -FG $script:DialogButtonBracketFg -BG $script:DialogButtonBracketBg }
			Write-Buffer -Text (" " * $rowPad) -BG $bgColor
			Write-Buffer -Text $script:BoxVertical -FG $borderColor -BG $bgColor
		}

		# — Render helper: full dialog — $focused selects onfocus vs offfocus -----
		$drawSettingsDialog = {
			param($dx, $dy, [bool]$focused = $true, $dlgLines = $null)
			if ($null -eq $dlgLines) { $dlgLines = $dialogLines }
			$localBg        = if ($focused) { $script:SettingsDialogBg }                  else { $script:SettingsDialogOffFocusBg }
			$localBorder    = if ($focused) { $script:SettingsDialogBorder }               else { $script:SettingsDialogOffFocusBorder }
			$localTitle     = if ($focused) { $script:SettingsDialogTitle }                else { $script:SettingsDialogOffFocusTitle }
			$localText      = if ($focused) { $script:SettingsDialogText }                 else { $script:SettingsDialogOffFocusText }
			$localBtnBg     = if ($focused) { $script:SettingsDialogButtonBg }             else { $script:SettingsDialogOffFocusButtonBg }
			$localBtnText   = if ($focused) { $script:SettingsDialogButtonText }           else { $script:SettingsDialogOffFocusButtonText }
			$localBtnHotkey = if ($focused) { $script:SettingsDialogButtonHotkey }         else { $script:SettingsDialogOffFocusButtonHotkey }
			for ($i = 0; $i -le $dialogHeight; $i++) {
				$rowY = $dy + $i
				Write-Buffer -X $dx -Y $rowY -Text (" " * $dialogWidth) -BG $localBg
				if ($i -eq 1) {
					Write-Buffer -X $dx -Y $rowY -Text "$($script:BoxVertical)  " -FG $localBorder -BG $localBg
					Write-Buffer -Text "Settings" -FG $localTitle -BG $localBg
					$titlePadding = Get-Padding -UsedWidth (3 + "Settings".Length + 1) -TotalWidth $dialogWidth
					Write-Buffer -Text (" " * $titlePadding) -BG $localBg
					Write-Buffer -Text $script:BoxVertical -FG $localBorder -BG $localBg
				} elseif ($i -eq 4) {
				& $drawSettingsBtnRow $dx $rowY $emojiHourglass "t" "ime" $timePad $localBtnBg $localBtnText $localBtnHotkey $localBg $localBorder "End "
			} elseif ($i -eq 6) {
				& $drawSettingsBtnRow $dx $rowY $emojiMouse "m" "ouse Movement" $movePad $localBtnBg $localBtnText $localBtnHotkey $localBg $localBorder
			} elseif ($i -eq 8) {
				& $drawSettingsBtnRow $dx $rowY $emojiOptions "o" "ptions" $optionsPad $localBtnBg $localBtnText $localBtnHotkey $localBg $localBorder
			} elseif ($i -eq 10) {
				& $drawSettingsBtnRow $dx $rowY $emojiTheme "t" "heme" ([math]::Max(0, $themePad)) $localBtnBg $localBtnText $localBtnHotkey $localBg $localBorder
				} elseif ($i -eq $dialogHeight) {
					Write-Buffer -X $dx -Y $rowY -Text $lineBottom -FG $localBorder -BG $localBg
				} elseif ($null -ne $dlgLines[$i]) {
					Write-Buffer -X $dx -Y $rowY -Text $dlgLines[$i] -FG $localText -BG $localBg
				}
			}
		}

		& $drawSettingsDialog $dialogX $dialogY $true
		if ($DeferFlush) { Flush-Buffer -ClearFirst } else { Flush-Buffer }

	# — Button row Y coordinates -----------------------------------------------
	$timeButtonRowY    = $dialogY + 4
	$moveButtonRowY    = $dialogY + 6
	$optionsButtonRowY = $dialogY + 8
	$themeButtonRowY   = $dialogY + 10

	$script:DialogButtonBounds = @{
		buttonRowY   = $timeButtonRowY
		updateStartX = $timeButtonStartX
		updateEndX   = $timeButtonEndX
		cancelStartX = $moveButtonStartX
		cancelEndX   = $moveButtonEndX
	}
		$script:DialogButtonClick = $null

	$needsRedraw     = $false
	$settingsReopen  = $false
	$titleChanged    = $false

	:settingsLoop do {
			# — Resize check -------------------------------------------------------
			$pshost        = Get-Host
			$pswindow      = $pshost.UI.RawUI
			$newWindowSize = $pswindow.WindowSize
			if ($newWindowSize.Width -ne $currentHostWidth -or $newWindowSize.Height -ne $currentHostHeight) {
				$stableSize = Invoke-ResizeHandler -PreviousScreenState "dialog-settings"
				$HostWidthRef.Value  = $stableSize.Width
				$HostHeightRef.Value = $stableSize.Height
				$currentHostWidth    = $stableSize.Width
				$currentHostHeight   = $stableSize.Height
				Write-MainFrame -Force -NoFlush

				$_bpH    = [math]::Max(1, $script:BorderPadH)
				$dialogX = [math]::Max(0, [math]::Min($_bpH - 1, $currentHostWidth - $dialogWidth))
				$menuBarY     = if ($null -ne $script:MenuBarY) { $script:MenuBarY } else { $currentHostHeight - 2 }
				$dialogY      = [math]::Max(0, $menuBarY - 2 - $dialogHeight)
				$timePad    = $dialogWidth - (2 + $dialogBracketWidth + $dialogIconWidth + 10 + $dialogParenOffset + 1)
				$movePad    = $dialogWidth - (2 + $dialogBracketWidth + $dialogIconWidth + 16 + $dialogParenOffset + 1)
				$optionsPad = $dialogWidth - (2 + $dialogBracketWidth + $dialogIconWidth + 9  + $dialogParenOffset + 1)
				$themePad   = $dialogWidth - (2 + $dialogBracketWidth + $dialogIconWidth + 7  + $dialogParenOffset + 1)
				$timeButtonStartX    = $dialogX + 2
				$timeButtonEndX      = $dialogX + 2 + $dialogBracketWidth + $dialogIconWidth + 10 + $dialogParenOffset - 1
				$moveButtonStartX    = $dialogX + 2
				$moveButtonEndX      = $dialogX + 2 + $dialogBracketWidth + $dialogIconWidth + 16 + $dialogParenOffset - 1
				$optionsButtonStartX = $dialogX + 2
				$optionsButtonEndX   = $dialogX + 2 + $dialogBracketWidth + $dialogIconWidth + 9  + $dialogParenOffset - 1
				$themeButtonStartX   = $dialogX + 2
				$themeButtonEndX     = $dialogX + 2 + $dialogBracketWidth + $dialogIconWidth + 7  + $dialogParenOffset - 1

				& $drawSettingsDialog $dialogX $dialogY $true
				Flush-Buffer -ClearFirst

		$timeButtonRowY    = $dialogY + 4
		$moveButtonRowY    = $dialogY + 6
		$optionsButtonRowY = $dialogY + 8
		$themeButtonRowY   = $dialogY + 10
		$script:DialogButtonBounds = @{
			buttonRowY   = $timeButtonRowY
			updateStartX = $timeButtonStartX
			updateEndX   = $timeButtonEndX
			cancelStartX = $moveButtonStartX
			cancelEndX   = $moveButtonEndX
		}
		}

			# — Mouse input --------------------------------------------------------
			$keyProcessed = $false
			$char = $null; $key = $null; $keyInfo = $null

		$_click = Get-DialogMouseClick -PeekBuffer $script:_DialogPeekBuffer
		if ($null -ne $_click) {
			$clickX = $_click.X; $clickY = $_click.Y
			if ($clickX -lt $dialogX -or $clickX -ge ($dialogX + $dialogWidth) -or $clickY -lt $dialogY -or $clickY -gt ($dialogY + $dialogHeight)) {
				$char = "s"; $keyProcessed = $true
			} elseif ($clickY -eq $timeButtonRowY -and $clickX -ge $timeButtonStartX -and $clickX -le $timeButtonEndX) {
				$char = "t"; $keyProcessed = $true
			} elseif ($clickY -eq $moveButtonRowY -and $clickX -ge $moveButtonStartX -and $clickX -le $moveButtonEndX) {
				$char = "m"; $keyProcessed = $true
			} elseif ($clickY -eq $optionsButtonRowY -and $clickX -ge $optionsButtonStartX -and $clickX -le $optionsButtonEndX) {
				$char = "o"; $keyProcessed = $true
			} elseif ($clickY -eq $themeButtonRowY -and $clickX -ge $themeButtonStartX -and $clickX -le $themeButtonEndX) {
				$keyProcessed = $true
			}
		}

			if (-not $keyProcessed -and $null -ne $script:DialogButtonClick) {
				$buttonClick = $script:DialogButtonClick
				$script:DialogButtonClick = $null
				if ($buttonClick -eq "Update") { $char = "t"; $keyProcessed = $true }
				elseif ($buttonClick -eq "Cancel") { $char = "m"; $keyProcessed = $true }
			}

		if (-not $keyProcessed) {
			$keyInfo = Read-DialogKeyInput
			if ($null -ne $keyInfo) {
				$key = $keyInfo.Key; $char = $keyInfo.Character; $keyProcessed = $true
			}
		}

			if (-not $keyProcessed) { Start-Sleep -Milliseconds 50; continue }

			# — Dispatch -----------------------------------------------------------
		if ($char -eq "t" -or $char -eq "T") {
			# — Go offfocus while time dialog is open --------------------------
				& $drawSettingsDialog $dialogX $dialogY $false
				Flush-Buffer
				$script:DialogButtonBounds = $null  # prevent outer loop interference

				$subHostWidthRef  = $HostWidthRef
				$subHostHeightRef = $HostHeightRef
				$settingsParentRedraw = {
					param($w, $h)
					$dialogWidth  = $_stgDialogWidth
					$dialogHeight = $_stgDialogHeight
					$_bpH     = [math]::Max(1, $script:BorderPadH)
					$parentDX = [math]::Max(0, [math]::Min($_bpH - 1, $w - $dialogWidth))
					$mBarY    = if ($null -ne $script:MenuBarY) { $script:MenuBarY } else { $h - 2 }
					$parentDY = [math]::Max(0, $mBarY - 2 - $dialogHeight)
					& $drawSettingsDialog $parentDX $parentDY $false $_stgDialogLines
				}
				$timeResult = Show-TimeChangeDialog -currentEndTime $EndTimeIntRef.Value -hostWidthRef $subHostWidthRef -hostHeightRef $subHostHeightRef -ParentRedrawCallback $settingsParentRedraw
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
						$currentDate = Get-Date
						$msg = if ([string]::IsNullOrEmpty($oldStr)) { " - End time cleared" } else { " - End time cleared (was: $oldStr)" }
						$LogArrayRef.Value += [PSCustomObject]@{ logRow = $true; components = @(
							@{ priority = 1; text = $currentDate.ToString(); shortText = $currentDate.ToString("HH:mm:ss") },
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
						$currentDate = Get-Date; $arrow = [char]0x2192
						$dayLabel = if ($isTomorrow) { " (next day)" } else { " (same day)" }
						$dd = $endDate.Substring(0,2) + "/" + $endDate.Substring(2,2)
						$td = $newStr.Substring(0,2) + ":" + $newStr.Substring(2,2)
						$msg = if ($oldInt -eq -1 -or [string]::IsNullOrEmpty($oldStr)) { " - End time set: $dd $td$dayLabel" } else { " - End time changed: $oldStr $arrow $dd $td$dayLabel" }
						$LogArrayRef.Value += [PSCustomObject]@{ logRow = $true; components = @(
							@{ priority = 1; text = $currentDate.ToString(); shortText = $currentDate.ToString("HH:mm:ss") },
							@{ priority = 2; text = $msg; shortText = " - End time: $dd $td" }
						)}
					}
				}

			# Sub-dialog dirtied the background — break out so the caller can do a
			# full screen repaint and then reopen settings cleanly.
			$settingsReopen = $true
			break :settingsLoop

			} elseif ($char -eq "m" -or $char -eq "M") {
				# — Go offfocus while movement dialog is open ----------------------
				& $drawSettingsDialog $dialogX $dialogY $false
				Flush-Buffer
				$script:DialogButtonBounds = $null

				$subHostWidthRef  = $HostWidthRef
				$subHostHeightRef = $HostHeightRef
				$settingsParentRedraw = {
					param($w, $h)
					$dialogWidth  = $_stgDialogWidth
					$dialogHeight = $_stgDialogHeight
					$_bpH     = [math]::Max(1, $script:BorderPadH)
					$parentDX = [math]::Max(0, [math]::Min($_bpH - 1, $w - $dialogWidth))
					$mBarY    = if ($null -ne $script:MenuBarY) { $script:MenuBarY } else { $h - 2 }
					$parentDY = [math]::Max(0, $mBarY - 2 - $dialogHeight)
					& $drawSettingsDialog $parentDX $parentDY $false $_stgDialogLines
				}
				$moveResult = Show-MovementModifyDialog `
					-currentIntervalSeconds $script:IntervalSeconds -currentIntervalVariance $script:IntervalVariance `
					-currentMoveSpeed $script:MoveSpeed -currentMoveVariance $script:MoveVariance `
					-currentTravelDistance $script:TravelDistance -currentTravelVariance $script:TravelVariance `
					-currentAutoResumeDelaySeconds $script:AutoResumeDelaySeconds `
					-hostWidthRef $subHostWidthRef -hostHeightRef $subHostHeightRef `
					-ParentRedrawCallback $settingsParentRedraw
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
					if ($old.IntV -ne $script:IntervalVariance)      { $chg += "Interval ±: $($old.IntV) $arrow $($script:IntervalVariance)" }
					if ($old.Spd  -ne $script:MoveSpeed)             { $chg += "Speed: $($old.Spd) $arrow $($script:MoveSpeed)" }
					if ($old.SpdV -ne $script:MoveVariance)          { $chg += "Speed ±: $($old.SpdV) $arrow $($script:MoveVariance)" }
					if ($old.Dst  -ne $script:TravelDistance)        { $chg += "Distance: $($old.Dst) $arrow $($script:TravelDistance)" }
					if ($old.DstV -ne $script:TravelVariance)        { $chg += "Distance ±: $($old.DstV) $arrow $($script:TravelVariance)" }
					if ($old.Dly  -ne $script:AutoResumeDelaySeconds){ $chg += "Delay: $($old.Dly) $arrow $($script:AutoResumeDelaySeconds)" }
					if ($chg.Count -gt 0) {
						$currentDate = Get-Date
						$LogArrayRef.Value += [PSCustomObject]@{ logRow = $true; components = @(
							@{ priority = 1; text = $currentDate.ToString(); shortText = $currentDate.ToString("HH:mm:ss") },
							@{ priority = 2; text = " - Settings updated: $($chg -join ', ')"; shortText = " - Updated: $($chg -join ', ')" }
						)}
					}
				}

			# Sub-dialog dirtied the background — break out so the caller can do a
			# full screen repaint and then reopen settings cleanly.
			$settingsReopen = $true
			break :settingsLoop

	} elseif ($char -eq "o" -or $char -eq "O") {
		# — Go offfocus while options dialog is open -----------------------
		& $drawSettingsDialog $dialogX $dialogY $false
		Flush-Buffer
		$script:DialogButtonBounds = $null

		$subHostWidthRef  = $HostWidthRef
		$subHostHeightRef = $HostHeightRef
		$settingsParentRedraw = {
			param($w, $h)
			$dialogWidth  = $_stgDialogWidth
			$dialogHeight = $_stgDialogHeight
			$_bpH     = [math]::Max(1, $script:BorderPadH)
			$parentDX = [math]::Max(0, [math]::Min($_bpH - 1, $w - $dialogWidth))
			$mBarY    = if ($null -ne $script:MenuBarY) { $script:MenuBarY } else { $h - 2 }
			$parentDY = [math]::Max(0, $mBarY - 2 - $dialogHeight)
			& $drawSettingsDialog $parentDX $parentDY $false $_stgDialogLines
		}
		$optionsResult = Show-OptionsDialog -HostWidthRef $subHostWidthRef -HostHeightRef $subHostHeightRef -ParentRedrawCallback $settingsParentRedraw -LogArrayRef $LogArrayRef
		$currentHostWidth  = $subHostWidthRef.Value
		$currentHostHeight = $subHostHeightRef.Value
		$HostWidthRef.Value  = $currentHostWidth
		$HostHeightRef.Value = $currentHostHeight

	if ($null -ne $optionsResult -and $optionsResult.NeedsRedraw) {
		$needsRedraw = $true
	}
	if ($null -ne $optionsResult -and $optionsResult.TitleChanged) {
		$titleChanged = $true
	}

		$settingsReopen = $true
		break :settingsLoop

	} elseif ($char -eq "s" -or $char -eq "S" -or $char -eq "q" -or $char -eq "Q" -or
		          $key -eq "Escape" -or $key -eq "Enter" -or $char -eq [char]13 -or $char -eq [char]10 -or
		          ($null -ne $keyInfo -and $keyInfo.VirtualKeyCode -eq 27)) {
		break :settingsLoop
	}

			try {
				while ($Host.UI.RawUI.KeyAvailable) { $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown,AllowCtrlC") }
			} catch { }
		} until ($false)

	Invoke-DialogCleanup -DialogX $dialogX -DialogY $dialogY -DialogWidth $dialogWidth -DialogHeight $dialogHeight -SavedCursorVisible $savedCursorVisible -IncludeBorderRow
		return @{ NeedsRedraw = $needsRedraw; ReopenSettings = $settingsReopen; TitleChanged = $titleChanged }
	}
