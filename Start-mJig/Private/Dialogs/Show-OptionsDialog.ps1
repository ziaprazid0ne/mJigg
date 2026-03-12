	function Show-OptionsDialog {
		param(
			[ref]$HostWidthRef,
			[ref]$HostHeightRef,
			[scriptblock]$ParentRedrawCallback,
			$LogArrayRef
		)

		$script:CurrentScreenState = "dialog-options"

		$currentHostWidth  = $HostWidthRef.Value
		$currentHostHeight = $HostHeightRef.Value

		$dialogWidth  = 36
		# Layout (15 rows, indices 0-14):
		#  0: top border   1: title   2: divider   3: blank
		#  4: (o)utput: Full/Min   5: blank   6: (d)ebug: On/Off   7: blank
		#  8: (n)otifications: On/Off   9: blank
		#  10: (w)indow Title: ...   11: blank
		#  12: (c)lose   13: blank   14: bottom border
		$dialogHeight = 14

		$dialogX = [math]::Max(0, [math]::Floor(($currentHostWidth - $dialogWidth) / 2))
		$dialogY = [math]::Max(0, [math]::Floor(($currentHostHeight - $dialogHeight) / 2))

		$savedCursorVisible = $script:CursorVisible
		$script:CursorVisible = $false
		[Console]::Write("$($script:ESC)[?25l")

		$_bl = Get-DialogButtonLayout
		$dlgIconWidth = $_bl.IconWidth; $dlgBracketWidth = $_bl.BracketWidth; $dlgParenAdj = $_bl.ParenAdj

		$hLine      = [string]$script:BoxHorizontal
		$inner      = $dialogWidth - 2
		$line0      = $script:BoxTopLeft    + ($hLine * $inner) + $script:BoxTopRight
		$line2      = $script:BoxVerticalRight + ($hLine * $inner) + $script:BoxVerticalLeft
		$lineBlank  = $script:BoxVertical   + (" "   * $inner) + $script:BoxVertical
		$lineBottom = $script:BoxBottomLeft + ($hLine * $inner) + $script:BoxBottomRight

		$emojiScreen  = [char]::ConvertFromUtf32(0x1F4BB) # screen
		$emojiDebug   = [char]::ConvertFromUtf32(0x1F50D) # search
		$emojiNotify  = [char]::ConvertFromUtf32(0x1F514) # bell
		$emojiTitle   = [char]::ConvertFromUtf32(0x1F3F7) # label
		$emojiClose   = [char]::ConvertFromUtf32(0x274C)  # red X

		$drawOptionsBtnRow = {
			param($dx, $absRowY, $emoji, $hotkeyChar, $labelSuffix, $rowPad, $btnBg, $btnText, $btnHotkey, $bgColor, $borderColor, $labelPrefix = "")
			$bX = $dx + 2
			Write-Buffer -X $dx -Y $absRowY -Text "$($script:BoxVertical) " -FG $borderColor -BG $bgColor
			if ($script:DialogButtonShowBrackets) { Write-Buffer -X $bX -Y $absRowY -Text "[" -FG $script:DialogButtonBracketFg -BG $script:DialogButtonBracketBg }
			$bCX = $bX + [int]$script:DialogButtonShowBrackets
			if ($script:DialogButtonShowIcon) {
				Write-Buffer -X $bCX -Y $absRowY -Text $emoji -BG $btnBg -Wide
				Write-Buffer -X ($bCX + 2) -Y $absRowY -Text $script:DialogButtonSeparator -FG $btnText -BG $btnBg
			} else {
				Write-Buffer -X $bCX -Y $absRowY -Text "" -BG $btnBg
			}
			if ($labelPrefix.Length -gt 0) { Write-Buffer -Text $labelPrefix -FG $btnText -BG $btnBg }
			$_rp = if ($script:DialogButtonShowHotkeyParens) { ")" } else { "" }
			if ($script:DialogButtonShowHotkeyParens) { Write-Buffer -Text "(" -FG $btnText -BG $btnBg }
			Write-Buffer -Text $hotkeyChar -FG $btnHotkey -BG $btnBg
			Write-Buffer -Text "${_rp}${labelSuffix}" -FG $btnText -BG $btnBg
			if ($script:DialogButtonShowBrackets) { Write-Buffer -Text "]" -FG $script:DialogButtonBracketFg -BG $script:DialogButtonBracketBg }
			Write-Buffer -Text (" " * [math]::Max(0, $rowPad)) -BG $bgColor
			Write-Buffer -Text $script:BoxVertical -FG $borderColor -BG $bgColor
		}

		$drawOptionsDialog = {
			param($dx, $dy)
			$localBg        = $script:SettingsDialogBg
			$localBorder    = $script:SettingsDialogBorder
			$localTitle     = $script:SettingsDialogTitle
			$localText      = $script:SettingsDialogText
			$localBtnBg     = $script:SettingsDialogButtonBg
			$localBtnText   = $script:SettingsDialogButtonText
			$localBtnHotkey = $script:SettingsDialogButtonHotkey
			for ($i = 0; $i -le $dialogHeight; $i++) {
				$absY = $dy + $i
				Write-Buffer -X $dx -Y $absY -Text (" " * $dialogWidth) -BG $localBg
				if ($i -eq 0) {
					Write-Buffer -X $dx -Y $absY -Text $line0 -FG $localBorder -BG $localBg
				} elseif ($i -eq 1) {
					Write-Buffer -X $dx -Y $absY -Text "$($script:BoxVertical)  " -FG $localBorder -BG $localBg
					Write-Buffer -Text "Options" -FG $localTitle -BG $localBg
					$tPad = Get-Padding -usedWidth (3 + "Options".Length + 1) -totalWidth $dialogWidth
					Write-Buffer -Text (" " * $tPad) -BG $localBg
					Write-Buffer -Text $script:BoxVertical -FG $localBorder -BG $localBg
				} elseif ($i -eq 2) {
					Write-Buffer -X $dx -Y $absY -Text $line2 -FG $localBorder -BG $localBg
				} elseif ($i -eq 4) {
					$_outName   = if ($script:Output -eq "full") { "Full" } else { "Min " }
					$_outSuffix = "utput: $_outName"
					$_outPad    = $dialogWidth - (2 + $dlgBracketWidth + $dlgIconWidth + 3 + $_outSuffix.Length + $dlgParenAdj + 1)
					& $drawOptionsBtnRow $dx $absY $emojiScreen "o" $_outSuffix ([math]::Max(0, $_outPad)) $localBtnBg $localBtnText $localBtnHotkey $localBg $localBorder
				} elseif ($i -eq 6) {
					$_dbgSuffix = if ($script:DebugMode) { "ebug: On " } else { "ebug: Off" }
					$_dbgPad    = $dialogWidth - (2 + $dlgBracketWidth + $dlgIconWidth + 3 + $_dbgSuffix.Length + $dlgParenAdj + 1)
					& $drawOptionsBtnRow $dx $absY $emojiDebug "d" $_dbgSuffix ([math]::Max(0, $_dbgPad)) $localBtnBg $localBtnText $localBtnHotkey $localBg $localBorder
				} elseif ($i -eq 8) {
					$_notifSuffix = if ($script:NotificationsEnabled) { "otifications: On " } else { "otifications: Off" }
					$_notifPad    = $dialogWidth - (2 + $dlgBracketWidth + $dlgIconWidth + 3 + $_notifSuffix.Length + $dlgParenAdj + 1)
					& $drawOptionsBtnRow $dx $absY $emojiNotify "n" $_notifSuffix ([math]::Max(0, $_notifPad)) $localBtnBg $localBtnText $localBtnHotkey $localBg $localBorder
				} elseif ($i -eq 10) {
				$_curTitle = $script:TitlePresets[$script:TitlePresetIndex].Name
				$_maxLen = $dialogWidth - (2 + $dlgBracketWidth + $dlgIconWidth + 10 + $dlgParenAdj + 1)
				if ($_curTitle.Length -gt $_maxLen) { $_curTitle = $_curTitle.Substring(0, [math]::Max(0, $_maxLen - 1)) + [char]0x2026 }
					$_titleSuffix = "indow: $_curTitle"
					$_titlePad = $dialogWidth - (2 + $dlgBracketWidth + $dlgIconWidth + 3 + $_titleSuffix.Length + $dlgParenAdj + 1)
					& $drawOptionsBtnRow $dx $absY $emojiTitle "w" $_titleSuffix ([math]::Max(0, $_titlePad)) $localBtnBg $localBtnText $localBtnHotkey $localBg $localBorder
				} elseif ($i -eq 12) {
					$_closePad = $dialogWidth - (2 + $dlgBracketWidth + $dlgIconWidth + 7 + $dlgParenAdj + 1)
					& $drawOptionsBtnRow $dx $absY $emojiClose "c" "lose" ([math]::Max(0, $_closePad)) $localBtnBg $localBtnText $localBtnHotkey $localBg $localBorder
				} elseif ($i -eq $dialogHeight) {
					Write-Buffer -X $dx -Y $absY -Text $lineBottom -FG $localBorder -BG $localBg
				} elseif ($i -eq 3 -or $i -eq 5 -or $i -eq 7 -or $i -eq 9 -or $i -eq 11 -or $i -eq 13) {
					Write-Buffer -X $dx -Y $absY -Text $lineBlank -FG $localText -BG $localBg
				}
			}
		}

		& $drawOptionsDialog $dialogX $dialogY
		Draw-DialogShadow -dialogX $dialogX -dialogY $dialogY -dialogWidth $dialogWidth -dialogHeight $dialogHeight -shadowColor $script:SettingsDialogShadow
		Flush-Buffer

	$needsRedraw = $false
	$titleChanged = $false

	:optionsLoop do {
			# Resize check
			$pshost        = Get-Host
			$pswindow      = $pshost.UI.RawUI
			$newWindowSize = $pswindow.WindowSize
			if ($newWindowSize.Width -ne $currentHostWidth -or $newWindowSize.Height -ne $currentHostHeight) {
				$stableSize = Invoke-ResizeHandler -PreviousScreenState "dialog-options"
				$HostWidthRef.Value  = $stableSize.Width
				$HostHeightRef.Value = $stableSize.Height
				$currentHostWidth    = $stableSize.Width
				$currentHostHeight   = $stableSize.Height
				Draw-MainFrame -Force -NoFlush
				if ($null -ne $ParentRedrawCallback) {
					& $ParentRedrawCallback $currentHostWidth $currentHostHeight
				}

				$dialogX = [math]::Max(0, [math]::Floor(($currentHostWidth - $dialogWidth) / 2))
				$dialogY = [math]::Max(0, [math]::Floor(($currentHostHeight - $dialogHeight) / 2))

				& $drawOptionsDialog $dialogX $dialogY
				Draw-DialogShadow -dialogX $dialogX -dialogY $dialogY -dialogWidth $dialogWidth -dialogHeight $dialogHeight -shadowColor $script:SettingsDialogShadow
				Flush-Buffer -ClearFirst
			}

			# Mouse input
			$keyProcessed = $false
			$char = $null; $key = $null; $keyInfo = $null

			$_click = Get-DialogMouseClick -PeekBuffer $script:_DialogPeekBuffer
			if ($null -ne $_click) {
				$clickX = $_click.X; $clickY = $_click.Y
				if ($clickX -lt $dialogX -or $clickX -ge ($dialogX + $dialogWidth) -or $clickY -lt $dialogY -or $clickY -gt ($dialogY + $dialogHeight)) {
					$char = "c"; $keyProcessed = $true
				} else {
					$_rowInDialog = $clickY - $dialogY
					if ($_rowInDialog -eq 4)  { $char = "o"; $keyProcessed = $true }
					if ($_rowInDialog -eq 6)  { $char = "d"; $keyProcessed = $true }
					if ($_rowInDialog -eq 8)  { $char = "n"; $keyProcessed = $true }
					if ($_rowInDialog -eq 10) { $char = "w"; $keyProcessed = $true }
					if ($_rowInDialog -eq 12) { $char = "c"; $keyProcessed = $true }
				}
			}

			if (-not $keyProcessed) {
				$keyInfo = Read-DialogKeyInput
				if ($null -ne $keyInfo) {
					$key = $keyInfo.Key; $char = $keyInfo.Character; $keyProcessed = $true
				}
			}

			if (-not $keyProcessed) { Start-Sleep -Milliseconds 50; continue }

			# Dispatch
			if ($char -eq "o" -or $char -eq "O") {
				$oldOutput = $script:Output
				$script:Output = if ($script:Output -eq "full") { "min" } else { "full" }
				$needsRedraw = $true
				$modeNames = @{ 'full' = 'Full'; 'min' = 'Minimal' }
				$oldName = if ($modeNames.ContainsKey($oldOutput))     { $modeNames[$oldOutput] }     else { $oldOutput }
				$newName = if ($modeNames.ContainsKey($script:Output)) { $modeNames[$script:Output] } else { $script:Output }
				$cd = Get-Date
				$null = $LogArrayRef.Value.Add([PSCustomObject]@{ logRow = $true; components = @(
					@{ priority = 1; text = $cd.ToString(); shortText = $cd.ToString("HH:mm:ss") },
					@{ priority = 2; text = " - Output mode: $oldName $([char]0x2192) $newName"; shortText = " - Output: $newName" }
				)})
				& $drawOptionsDialog $dialogX $dialogY
				Flush-Buffer

			} elseif ($char -eq "d" -or $char -eq "D") {
				$script:DebugMode = -not $script:DebugMode
				$needsRedraw = $true
				$cd = Get-Date
				$dbgLabel = if ($script:DebugMode) { "enabled" } else { "disabled" }
				$null = $LogArrayRef.Value.Add([PSCustomObject]@{ logRow = $true; components = @(
					@{ priority = 1; text = $cd.ToString(); shortText = $cd.ToString("HH:mm:ss") },
					@{ priority = 2; text = " - Debug mode: $dbgLabel"; shortText = " - Debug: $dbgLabel" }
				)})
				& $drawOptionsDialog $dialogX $dialogY
				Flush-Buffer

			} elseif ($char -eq "n" -or $char -eq "N") {
				$script:NotificationsEnabled = -not $script:NotificationsEnabled
				$needsRedraw = $true
				$cd = Get-Date
				$notifLabel = if ($script:NotificationsEnabled) { "enabled" } else { "disabled" }
				$null = $LogArrayRef.Value.Add([PSCustomObject]@{ logRow = $true; components = @(
					@{ priority = 1; text = $cd.ToString(); shortText = $cd.ToString("HH:mm:ss") },
					@{ priority = 2; text = " - Notifications: $notifLabel"; shortText = " - Notif: $notifLabel" }
				)})
				& $drawOptionsDialog $dialogX $dialogY
				Flush-Buffer

			} elseif ($char -eq "w" -or $char -eq "W") {
			$script:TitlePresetIndex = ($script:TitlePresetIndex + 1) % $script:TitlePresets.Count
			$_preset = $script:TitlePresets[$script:TitlePresetIndex]
			$script:WindowTitle = $_preset.Name
			$script:TitleEmoji  = $_preset.Emoji
			try { $Host.UI.RawUI.WindowTitle = if ($script:DebugMode) { "$($script:WindowTitle) - DEBUGMODE" } else { $script:WindowTitle } } catch {}
			$needsRedraw = $true
			$titleChanged = $true
			$cd = Get-Date
			$null = $LogArrayRef.Value.Add([PSCustomObject]@{ logRow = $true; components = @(
				@{ priority = 1; text = $cd.ToString(); shortText = $cd.ToString("HH:mm:ss") },
				@{ priority = 2; text = " - Window title: $($script:WindowTitle)"; shortText = " - Title changed" }
			)})
			& $drawOptionsDialog $dialogX $dialogY
			Flush-Buffer

			} elseif ($char -eq "c" -or $char -eq "C" -or $key -eq "Escape" -or $key -eq "Enter" -or
				      $char -eq [char]13 -or $char -eq [char]10 -or
				      ($null -ne $keyInfo -and $keyInfo.VirtualKeyCode -eq 27)) {
				break :optionsLoop
			}

			try {
				while ($Host.UI.RawUI.KeyAvailable) { $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown,AllowCtrlC") }
			} catch { }
		} until ($false)

		Invoke-DialogExitCleanup -DialogX $dialogX -DialogY $dialogY -DialogWidth $dialogWidth -DialogHeight $dialogHeight -SavedCursorVisible $savedCursorVisible -ClearShadow
		return @{ NeedsRedraw = $needsRedraw; TitleChanged = $titleChanged }
	}
