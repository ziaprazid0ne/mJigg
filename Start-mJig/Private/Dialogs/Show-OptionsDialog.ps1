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
	# Rows: 0=border, 1=title, 2=divider, 3=blank, 4=output, 5=blank, 6=debug, 7=blank, 8=notifications, 9=blank, 10=window, 11=blank, 12=apply+cancel, 13=blank, 14=border
	$dialogHeight = 14

		$dialogX = [math]::Max(0, [math]::Floor(($currentHostWidth - $dialogWidth) / 2))
		$dialogY = [math]::Max(0, [math]::Floor(($currentHostHeight - $dialogHeight) / 2))

		$savedCursorVisible = $script:CursorVisible
		$script:CursorVisible = $false
		[Console]::Write("$($script:ESC)[?25l")

		$buttonLayout = Get-DialogButtonLayout
		$dialogIconWidth = $buttonLayout.IconWidth; $dialogBracketWidth = $buttonLayout.BracketWidth; $dialogParenOffset = $buttonLayout.ParenAdjustment

		$applyBtnChars  = $dialogBracketWidth + $dialogIconWidth + 7 + $dialogParenOffset
		$cancelBtnChars = $dialogBracketWidth + $dialogIconWidth + 8 + $dialogParenOffset
		$applyRowPadding = [math]::Max(0, $dialogWidth - 2 - $applyBtnChars - 2 - $cancelBtnChars - 1)

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
		$emojiApply   = [char]::ConvertFromUtf32(0x2705)  # checkmark
		$emojiClose   = [char]::ConvertFromUtf32(0x274C)  # red X

		$drawOptionsBtnRow = {
			param($DialogX, $RowY, $emoji, $hotkeyChar, $labelSuffix, $RowPadding, $ButtonBackground, $ButtonTextColor, $btnHotkey, $BackgroundColor, $borderColor, $labelPrefix = "")
			$buttonX = $DialogX + 2
			Write-Buffer -X $DialogX -Y $RowY -Text "$($script:BoxVertical) " -FG $borderColor -BG $BackgroundColor
			if ($script:DialogButtonShowBrackets) { Write-Buffer -X $buttonX -Y $RowY -Text "[" -FG $script:DialogButtonBracketFg -BG $script:DialogButtonBracketBg }
			$buttonContentX = $buttonX + [int]$script:DialogButtonShowBrackets
			if ($script:DialogButtonShowIcon) {
				Write-Buffer -X $buttonContentX -Y $RowY -Text $emoji -BG $ButtonBackground -Wide
				Write-Buffer -X ($buttonContentX + 2) -Y $RowY -Text $script:DialogButtonSeparator -FG $ButtonTextColor -BG $ButtonBackground
			} else {
				Write-Buffer -X $buttonContentX -Y $RowY -Text "" -BG $ButtonBackground
			}
			if ($labelPrefix.Length -gt 0) { Write-Buffer -Text $labelPrefix -FG $ButtonTextColor -BG $ButtonBackground }
			$closingParen = if ($script:DialogButtonShowHotkeyParens) { ")" } else { "" }
			if ($script:DialogButtonShowHotkeyParens) { Write-Buffer -Text "(" -FG $ButtonTextColor -BG $ButtonBackground }
			Write-Buffer -Text $hotkeyChar -FG $btnHotkey -BG $ButtonBackground
			Write-Buffer -Text "$closingParen$labelSuffix" -FG $ButtonTextColor -BG $ButtonBackground
			if ($script:DialogButtonShowBrackets) { Write-Buffer -Text "]" -FG $script:DialogButtonBracketFg -BG $script:DialogButtonBracketBg }
			Write-Buffer -Text (" " * [math]::Max(0, $RowPadding)) -BG $BackgroundColor
			Write-Buffer -Text $script:BoxVertical -FG $borderColor -BG $BackgroundColor
		}

		$drawOptionsDialog = {
			param($DialogX, $DialogY)
			$localBg        = $script:SettingsDialogBg
			$localBorder    = $script:SettingsDialogBorder
			$localTitle     = $script:SettingsDialogTitle
			$localText      = $script:SettingsDialogText
			$localBtnBg     = $script:SettingsDialogButtonBg
			$localBtnText   = $script:SettingsDialogButtonText
			$localBtnHotkey = $script:SettingsDialogButtonHotkey
			for ($i = 0; $i -le $dialogHeight; $i++) {
				$rowY = $DialogY + $i
				Write-Buffer -X $DialogX -Y $rowY -Text (" " * $dialogWidth) -BG $localBg
				if ($i -eq 0) {
					Write-Buffer -X $DialogX -Y $rowY -Text $line0 -FG $localBorder -BG $localBg
				} elseif ($i -eq 1) {
					Write-Buffer -X $DialogX -Y $rowY -Text "$($script:BoxVertical)  " -FG $localBorder -BG $localBg
					Write-Buffer -Text "Options" -FG $localTitle -BG $localBg
					$titlePadding = Get-Padding -UsedWidth (3 + "Options".Length + 1) -TotalWidth $dialogWidth
					Write-Buffer -Text (" " * $titlePadding) -BG $localBg
					Write-Buffer -Text $script:BoxVertical -FG $localBorder -BG $localBg
				} elseif ($i -eq 2) {
					Write-Buffer -X $DialogX -Y $rowY -Text $line2 -FG $localBorder -BG $localBg
				} elseif ($i -eq 4) {
					$outputDisplayName   = if ($script:Output -eq "full") { "Full" } else { "Min " }
					$outputLabelSuffix = "utput: $outputDisplayName"
					$outputRowPadding    = $dialogWidth - (2 + $dialogBracketWidth + $dialogIconWidth + 3 + $outputLabelSuffix.Length + $dialogParenOffset + 1)
					& $drawOptionsBtnRow $DialogX $rowY $emojiScreen "o" $outputLabelSuffix ([math]::Max(0, $outputRowPadding)) $localBtnBg $localBtnText $localBtnHotkey $localBg $localBorder
				} elseif ($i -eq 6) {
					$debugLabelSuffix = if ($script:DebugMode) { "ebug: On " } else { "ebug: Off" }
					$debugRowPadding    = $dialogWidth - (2 + $dialogBracketWidth + $dialogIconWidth + 3 + $debugLabelSuffix.Length + $dialogParenOffset + 1)
					& $drawOptionsBtnRow $DialogX $rowY $emojiDebug "d" $debugLabelSuffix ([math]::Max(0, $debugRowPadding)) $localBtnBg $localBtnText $localBtnHotkey $localBg $localBorder
				} elseif ($i -eq 8) {
					$notificationLabelSuffix = if ($script:NotificationsEnabled) { "otifications: On " } else { "otifications: Off" }
					$notificationRowPadding    = $dialogWidth - (2 + $dialogBracketWidth + $dialogIconWidth + 3 + $notificationLabelSuffix.Length + $dialogParenOffset + 1)
					& $drawOptionsBtnRow $DialogX $rowY $emojiNotify "n" $notificationLabelSuffix ([math]::Max(0, $notificationRowPadding)) $localBtnBg $localBtnText $localBtnHotkey $localBg $localBorder
				} elseif ($i -eq 10) {
				$currentTitleName = $script:TitlePresets[$script:TitlePresetIndex].Name
				$maxTitleLength = $dialogWidth - (2 + $dialogBracketWidth + $dialogIconWidth + 10 + $dialogParenOffset + 1)
				if ($currentTitleName.Length -gt $maxTitleLength) { $currentTitleName = $currentTitleName.Substring(0, [math]::Max(0, $maxTitleLength - 1)) + [char]0x2026 }
					$titleLabelSuffix = "indow: $currentTitleName"
					$titleRowPadding = $dialogWidth - (2 + $dialogBracketWidth + $dialogIconWidth + 3 + $titleLabelSuffix.Length + $dialogParenOffset + 1)
					& $drawOptionsBtnRow $DialogX $rowY $emojiTitle "w" $titleLabelSuffix ([math]::Max(0, $titleRowPadding)) $localBtnBg $localBtnText $localBtnHotkey $localBg $localBorder
				} elseif ($i -eq 12) {
					$_applyX   = $DialogX + 2
					$_cancelX  = $_applyX + $applyBtnChars + 2
					Write-Buffer -X $DialogX -Y $rowY -Text "$($script:BoxVertical) " -FG $localBorder -BG $localBg
					if ($script:DialogButtonShowBrackets) { Write-Buffer -X $_applyX -Y $rowY -Text "[" -FG $script:DialogButtonBracketFg -BG $script:DialogButtonBracketBg }
					$_applyContentX = $_applyX + [int]$script:DialogButtonShowBrackets
					if ($script:DialogButtonShowIcon) {
						Write-Buffer -X $_applyContentX -Y $rowY -Text $emojiApply -FG $localBtnText -BG $localBtnBg -Wide
						Write-Buffer -X ($_applyContentX + 2) -Y $rowY -Text $script:DialogButtonSeparator -FG $localBtnText -BG $localBtnBg
					} else { Write-Buffer -X $_applyContentX -Y $rowY -Text "" -BG $localBtnBg }
					$_cp = if ($script:DialogButtonShowHotkeyParens) { ")" } else { "" }
					if ($script:DialogButtonShowHotkeyParens) { Write-Buffer -Text "(" -FG $localBtnText -BG $localBtnBg }
					Write-Buffer -Text "a" -FG $localBtnHotkey -BG $localBtnBg
					Write-Buffer -Text "${_cp}pply" -FG $localBtnText -BG $localBtnBg
					if ($script:DialogButtonShowBrackets) { Write-Buffer -Text "]" -FG $script:DialogButtonBracketFg -BG $script:DialogButtonBracketBg }
					Write-Buffer -Text "  " -BG $localBg
					if ($script:DialogButtonShowBrackets) { Write-Buffer -X $_cancelX -Y $rowY -Text "[" -FG $script:DialogButtonBracketFg -BG $script:DialogButtonBracketBg }
					$_cancelContentX = $_cancelX + [int]$script:DialogButtonShowBrackets
					if ($script:DialogButtonShowIcon) {
						Write-Buffer -X $_cancelContentX -Y $rowY -Text $emojiClose -FG $script:TextError -BG $localBtnBg -Wide
						Write-Buffer -X ($_cancelContentX + 2) -Y $rowY -Text $script:DialogButtonSeparator -FG $localBtnText -BG $localBtnBg
					} else { Write-Buffer -X $_cancelContentX -Y $rowY -Text "" -BG $localBtnBg }
					if ($script:DialogButtonShowHotkeyParens) { Write-Buffer -Text "(" -FG $localBtnText -BG $localBtnBg }
					Write-Buffer -Text "c" -FG $localBtnHotkey -BG $localBtnBg
					Write-Buffer -Text "${_cp}ancel" -FG $localBtnText -BG $localBtnBg
					if ($script:DialogButtonShowBrackets) { Write-Buffer -Text "]" -FG $script:DialogButtonBracketFg -BG $script:DialogButtonBracketBg }
					Write-Buffer -Text (" " * $applyRowPadding) -BG $localBg
					Write-Buffer -Text $script:BoxVertical -FG $localBorder -BG $localBg
				} elseif ($i -eq $dialogHeight) {
					Write-Buffer -X $DialogX -Y $rowY -Text $lineBottom -FG $localBorder -BG $localBg
				} elseif ($i -eq 3 -or $i -eq 5 -or $i -eq 7 -or $i -eq 9 -or $i -eq 11 -or $i -eq 13) {
					Write-Buffer -X $DialogX -Y $rowY -Text $lineBlank -FG $localText -BG $localBg
				}
			}
		}

		& $drawOptionsDialog $dialogX $dialogY
		Write-DialogShadow -dialogX $dialogX -dialogY $dialogY -dialogWidth $dialogWidth -dialogHeight $dialogHeight -shadowColor $script:SettingsDialogShadow
		Flush-Buffer

	$initialOutput               = $script:Output
	$initialDebugMode            = $script:DebugMode
	$initialNotificationsEnabled = $script:NotificationsEnabled
	$initialTitlePresetIndex     = $script:TitlePresetIndex
	$initialWindowTitle          = $script:WindowTitle
	$initialTitleEmoji           = $script:TitleEmoji

	$needsRedraw  = $false
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
				Write-MainFrame -Force -NoFlush
				if ($null -ne $ParentRedrawCallback) {
					& $ParentRedrawCallback $currentHostWidth $currentHostHeight
				}

				$dialogX = [math]::Max(0, [math]::Floor(($currentHostWidth - $dialogWidth) / 2))
				$dialogY = [math]::Max(0, [math]::Floor(($currentHostHeight - $dialogHeight) / 2))

				& $drawOptionsDialog $dialogX $dialogY
				Write-DialogShadow -dialogX $dialogX -dialogY $dialogY -dialogWidth $dialogWidth -dialogHeight $dialogHeight -shadowColor $script:SettingsDialogShadow
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
					if ($_rowInDialog -eq 12) {
						$_applyStartX  = $dialogX + 2
						$_applyEndX    = $_applyStartX + $applyBtnChars - 1
						$_cancelStartX = $_applyStartX + $applyBtnChars + 2
						$_cancelEndX   = $_cancelStartX + $cancelBtnChars - 1
						if ($clickX -ge $_applyStartX -and $clickX -le $_applyEndX)   { $char = "a"; $keyProcessed = $true }
						elseif ($clickX -ge $_cancelStartX -and $clickX -le $_cancelEndX) { $char = "c"; $keyProcessed = $true }
					}
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
				$currentDate = Get-Date
				$null = $LogArrayRef.Value.Add([PSCustomObject]@{ logRow = $true; components = @(
					@{ priority = 1; text = $currentDate.ToString(); shortText = $currentDate.ToString("HH:mm:ss") },
					@{ priority = 2; text = " - Output mode: $oldName $([char]0x2192) $newName"; shortText = " - Output: $newName" }
				)})
				& $drawOptionsDialog $dialogX $dialogY
				Flush-Buffer

		} elseif ($char -eq "d" -or $char -eq "D") {
			$script:DebugMode = -not $script:DebugMode
			if ($script:DebugMode) { Set-ThemeProfile -Name "debug" } else { Set-ThemeProfile -Name "default" }
			$needsRedraw = $true
			$currentDate = Get-Date
			$dbgLabel = if ($script:DebugMode) { "enabled" } else { "disabled" }
			$null = $LogArrayRef.Value.Add([PSCustomObject]@{ logRow = $true; components = @(
				@{ priority = 1; text = $currentDate.ToString(); shortText = $currentDate.ToString("HH:mm:ss") },
				@{ priority = 2; text = " - Debug mode: $dbgLabel"; shortText = " - Debug: $dbgLabel" }
			)})
			& $drawOptionsDialog $dialogX $dialogY
			Flush-Buffer

			} elseif ($char -eq "n" -or $char -eq "N") {
				$script:NotificationsEnabled = -not $script:NotificationsEnabled
				$needsRedraw = $true
				$currentDate = Get-Date
				$notificationLabel = if ($script:NotificationsEnabled) { "enabled" } else { "disabled" }
				$null = $LogArrayRef.Value.Add([PSCustomObject]@{ logRow = $true; components = @(
					@{ priority = 1; text = $currentDate.ToString(); shortText = $currentDate.ToString("HH:mm:ss") },
					@{ priority = 2; text = " - Notifications: $notificationLabel"; shortText = " - Notif: $notificationLabel" }
				)})
				& $drawOptionsDialog $dialogX $dialogY
				Flush-Buffer

			} elseif ($char -eq "w" -or $char -eq "W") {
			$script:TitlePresetIndex = ($script:TitlePresetIndex + 1) % $script:TitlePresets.Count
			$_preset = $script:TitlePresets[$script:TitlePresetIndex]
			$script:WindowTitle = $_preset.Name
			$script:TitleEmoji  = $_preset.Emoji
			try { $Host.UI.RawUI.WindowTitle = if ($script:DebugMode) { "$($script:WindowTitle) - Debug Mode" } else { $script:WindowTitle } } catch {}
			$needsRedraw = $true
			$titleChanged = $true
			$currentDate = Get-Date
			$null = $LogArrayRef.Value.Add([PSCustomObject]@{ logRow = $true; components = @(
				@{ priority = 1; text = $currentDate.ToString(); shortText = $currentDate.ToString("HH:mm:ss") },
				@{ priority = 2; text = " - Window title: $($script:WindowTitle)"; shortText = " - Title changed" }
			)})
			& $drawOptionsDialog $dialogX $dialogY
			Flush-Buffer

			} elseif ($char -eq "a" -or $char -eq "A" -or $key -eq "Enter" -or
				      $char -eq [char]13 -or $char -eq [char]10) {
				# Apply — keep all changes and close
				break :optionsLoop

			} elseif ($char -eq "c" -or $char -eq "C" -or $key -eq "Escape" -or
				      ($null -ne $keyInfo -and $keyInfo.VirtualKeyCode -eq 27)) {
				# Cancel — revert all changes made during this dialog session
				if ($script:DebugMode -ne $initialDebugMode) {
					$script:DebugMode = $initialDebugMode
					if ($script:DebugMode) { Set-ThemeProfile -Name "debug" } else { Set-ThemeProfile -Name "default" }
					$needsRedraw = $true
				}
				if ($script:Output -ne $initialOutput) {
					$script:Output = $initialOutput
					$needsRedraw = $true
				}
				if ($script:NotificationsEnabled -ne $initialNotificationsEnabled) {
					$script:NotificationsEnabled = $initialNotificationsEnabled
				}
				if ($script:TitlePresetIndex -ne $initialTitlePresetIndex) {
					$script:TitlePresetIndex = $initialTitlePresetIndex
					$script:WindowTitle      = $initialWindowTitle
					$script:TitleEmoji       = $initialTitleEmoji
					try { $Host.UI.RawUI.WindowTitle = if ($script:DebugMode) { "$($script:WindowTitle) - Debug Mode" } else { $script:WindowTitle } } catch {}
					$needsRedraw  = $true
					$titleChanged = $false
				}
				break :optionsLoop
			}

			try {
				while ($Host.UI.RawUI.KeyAvailable) { $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown,AllowCtrlC") }
			} catch { }
		} until ($false)

		Invoke-DialogCleanup -DialogX $dialogX -DialogY $dialogY -DialogWidth $dialogWidth -DialogHeight $dialogHeight -SavedCursorVisible $savedCursorVisible -ClearShadow
		return @{ NeedsRedraw = $needsRedraw; TitleChanged = $titleChanged }
	}
