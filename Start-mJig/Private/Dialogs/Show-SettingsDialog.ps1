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

		$script:CurrentScreenState = "dialog-settings"

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
		$_stgDialogWidth  = $dialogWidth
		$_stgDialogHeight = $dialogHeight
		$_stgDialogLines  = $dialogLines

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
				$stableSize = Invoke-ResizeHandler -PreviousScreenState "dialog-settings"
				$HostWidthRef.Value  = $stableSize.Width
				$HostHeightRef.Value = $stableSize.Height
				$currentHostWidth    = $stableSize.Width
				$currentHostHeight   = $stableSize.Height
				Draw-MainFrame -Force -NoFlush

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

				$subHostWidthRef  = $HostWidthRef
				$subHostHeightRef = $HostHeightRef
				$settingsParentRedraw = {
					param($w, $h)
					$dialogWidth  = $_stgDialogWidth
					$dialogHeight = $_stgDialogHeight
					$dialogLines  = $_stgDialogLines
					$sBtnX    = if ($null -ne $script:SettingsButtonStartX) { $script:SettingsButtonStartX } else { 0 }
					$parentDX = [math]::Max(0, [math]::Min($sBtnX, $w - $dialogWidth))
					$mBarY    = if ($null -ne $script:MenuBarY) { $script:MenuBarY } else { $h - 2 }
					$parentDY = [math]::Max(0, $mBarY - 2 - $dialogHeight)
					& $drawSettingsDialog $parentDX $parentDY $false
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

				$subHostWidthRef  = $HostWidthRef
				$subHostHeightRef = $HostHeightRef
				$settingsParentRedraw = {
					param($w, $h)
					$dialogWidth  = $_stgDialogWidth
					$dialogHeight = $_stgDialogHeight
					$dialogLines  = $_stgDialogLines
					$sBtnX    = if ($null -ne $script:SettingsButtonStartX) { $script:SettingsButtonStartX } else { 0 }
					$parentDX = [math]::Max(0, [math]::Min($sBtnX, $w - $dialogWidth))
					$mBarY    = if ($null -ne $script:MenuBarY) { $script:MenuBarY } else { $h - 2 }
					$parentDY = [math]::Max(0, $mBarY - 2 - $dialogHeight)
					& $drawSettingsDialog $parentDX $parentDY $false
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

		$script:CurrentScreenState = if ($Output -eq "hidden") { "hidden" } else { "main" }
		return @{ NeedsRedraw = $needsRedraw; ReopenSettings = $settingsReopen }
	}
