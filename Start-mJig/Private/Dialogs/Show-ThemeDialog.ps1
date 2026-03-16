	function Show-ThemeDialog {
		param(
			[ref]$HostWidthRef,
			[ref]$HostHeightRef,
			[System.IO.StreamWriter]$ViewerPipeWriter = $null
		)

		$script:CurrentScreenState = "dialog-theme"

		$currentHostWidth  = $HostWidthRef.Value
		$currentHostHeight = $HostHeightRef.Value

		$dialogWidth  = 32
		# Rows: 0=border, 1=title, 2=divider, 3=blank, 4=theme-name, 5=blank, 6=next, 7=blank, 8=apply+cancel, 9=border
		$dialogHeight = 9
		$dialogX = [math]::Max(0, [math]::Floor(($currentHostWidth  - $dialogWidth)  / 2))
		$dialogY = [math]::Max(0, [math]::Floor(($currentHostHeight - $dialogHeight) / 2))

		$savedCursorVisible = $script:CursorVisible
		$script:CursorVisible = $false
		[Console]::Write("$($script:ESC)[?25l")

		$buttonLayout      = Get-DialogButtonLayout
		$dialogIconWidth   = $buttonLayout.IconWidth
		$dialogBracketWidth = $buttonLayout.BracketWidth
		$dialogParenOffset = $buttonLayout.ParenAdjustment
		# Next-theme button: bracket? + icon? + "(" + "n" + ")" + "ext theme" + trailing pad + "|"
		$buttonLabelLength = 9 + 1 + 2 * [int]$script:DialogButtonShowHotkeyParens
		$bottomLinePadding = $dialogWidth - 4 - $dialogParenOffset - $dialogBracketWidth - $dialogIconWidth - $buttonLabelLength

		# Apply / Cancel button sizes
		$applyBtnChars   = $dialogBracketWidth + $dialogIconWidth + 7 + $dialogParenOffset
		$cancelBtnChars  = $dialogBracketWidth + $dialogIconWidth + 8 + $dialogParenOffset
		$applyRowPadding = [math]::Max(0, $dialogWidth - 2 - $applyBtnChars - 2 - $cancelBtnChars - 1)

		$paletteEmoji  = [char]::ConvertFromUtf32(0x1F3A8) # artist palette
		$emojiApply    = [char]::ConvertFromUtf32(0x2705)  # checkmark
		$emojiClose    = [char]::ConvertFromUtf32(0x274C)  # red X

		$drawThemeDialog = {
			param($dx, $dy)
			$inner  = $dialogWidth - 2
			$hLine  = [string]$script:BoxHorizontal

			# Clear background
			for ($i = 0; $i -le $dialogHeight; $i++) {
				Write-Buffer -X $dx -Y ($dy + $i) -Text (" " * $dialogWidth) -BG $script:ThemeDialogBg
			}

			# — Line 0: top border -----------------------------------------------
			Write-Buffer -X $dx -Y ($dy + 0) -Text ($script:BoxTopLeft + ($hLine * $inner) + $script:BoxTopRight) -FG $script:ThemeDialogBorder -BG $script:ThemeDialogBg

			# — Line 1: title ----------------------------------------------------
			$titleText = "  Theme"
			Write-Buffer -X $dx -Y ($dy + 1) -Text $script:BoxVertical -FG $script:ThemeDialogBorder -BG $script:ThemeDialogBg
			Write-Buffer -Text $titleText.PadRight($inner) -FG $script:ThemeDialogTitle -BG $script:ThemeDialogBg
			Write-Buffer -Text $script:BoxVertical -FG $script:ThemeDialogBorder -BG $script:ThemeDialogBg

			# — Line 2: divider --------------------------------------------------
			Write-Buffer -X $dx -Y ($dy + 2) -Text ($script:BoxVerticalRight + ($hLine * $inner) + $script:BoxVerticalLeft) -FG $script:ThemeDialogBorder -BG $script:ThemeDialogBg

			# — Line 3: blank ----------------------------------------------------
			Write-Buffer -X $dx -Y ($dy + 3) -Text ($script:BoxVertical + (" " * $inner) + $script:BoxVertical) -FG $script:ThemeDialogBorder -BG $script:ThemeDialogBg

			# — Line 4: current theme name (centered) ----------------------------
			$themeName   = if ($script:CurrentThemeName -ne "") { $script:CurrentThemeName } else { "default" }
			$nameLen     = $themeName.Length
			$namePad     = [math]::Max(0, [math]::Floor(($inner - $nameLen) / 2))
			$nameContent = (" " * $namePad) + $themeName + (" " * ($inner - $namePad - $nameLen))
			Write-Buffer -X $dx -Y ($dy + 4) -Text $script:BoxVertical -FG $script:ThemeDialogBorder -BG $script:ThemeDialogBg
			Write-Buffer -Text $nameContent -FG $script:ThemeDialogNameFg -BG $script:ThemeDialogBg
			Write-Buffer -Text $script:BoxVertical -FG $script:ThemeDialogBorder -BG $script:ThemeDialogBg

			# — Line 5: blank ----------------------------------------------------
			Write-Buffer -X $dx -Y ($dy + 5) -Text ($script:BoxVertical + (" " * $inner) + $script:BoxVertical) -FG $script:ThemeDialogBorder -BG $script:ThemeDialogBg

			# — Line 6: next-theme button ----------------------------------------
			Write-Buffer -X $dx -Y ($dy + 6) -Text "$($script:BoxVertical) " -FG $script:ThemeDialogBorder -BG $script:ThemeDialogBg
			if ($script:DialogButtonShowBrackets) { Write-Buffer -Text "[" -FG $script:DialogButtonBracketFg -BG $script:ThemeDialogButtonBg }
			if ($script:DialogButtonShowIcon) {
				Write-Buffer -Text $paletteEmoji -FG $script:ThemeDialogButtonText -BG $script:ThemeDialogButtonBg
				Write-Buffer -Text $script:DialogButtonSeparator -FG $script:ThemeDialogButtonText -BG $script:ThemeDialogButtonBg
			}
			if ($script:DialogButtonShowHotkeyParens) { Write-Buffer -Text "(" -FG $script:ThemeDialogButtonText -BG $script:ThemeDialogButtonBg }
			Write-Buffer -Text "n" -FG $script:ThemeDialogButtonHotkey -BG $script:ThemeDialogButtonBg
			$closingParen = if ($script:DialogButtonShowHotkeyParens) { ")" } else { "" }
			Write-Buffer -Text "${closingParen}ext theme" -FG $script:ThemeDialogButtonText -BG $script:ThemeDialogButtonBg
			if ($script:DialogButtonShowBrackets) { Write-Buffer -Text "]" -FG $script:DialogButtonBracketFg -BG $script:DialogButtonBracketBg }
			Write-Buffer -Text (" " * $bottomLinePadding) -BG $script:ThemeDialogBg
			Write-Buffer -Text $script:BoxVertical -FG $script:ThemeDialogBorder -BG $script:ThemeDialogBg

			# — Line 7: blank ----------------------------------------------------
			Write-Buffer -X $dx -Y ($dy + 7) -Text ($script:BoxVertical + (" " * $inner) + $script:BoxVertical) -FG $script:ThemeDialogBorder -BG $script:ThemeDialogBg

			# — Line 8: apply + cancel buttons -----------------------------------
			$_applyX  = $dx + 2
			$_cancelX = $_applyX + $applyBtnChars + 2
			Write-Buffer -X $dx -Y ($dy + 8) -Text "$($script:BoxVertical) " -FG $script:ThemeDialogBorder -BG $script:ThemeDialogBg
			if ($script:DialogButtonShowBrackets) { Write-Buffer -X $_applyX -Y ($dy + 8) -Text "[" -FG $script:DialogButtonBracketFg -BG $script:DialogButtonBracketBg }
			$_applyContentX = $_applyX + [int]$script:DialogButtonShowBrackets
			if ($script:DialogButtonShowIcon) {
				Write-Buffer -X $_applyContentX -Y ($dy + 8) -Text $emojiApply -FG $script:ThemeDialogButtonText -BG $script:ThemeDialogButtonBg -Wide
				Write-Buffer -X ($_applyContentX + 2) -Y ($dy + 8) -Text $script:DialogButtonSeparator -FG $script:ThemeDialogButtonText -BG $script:ThemeDialogButtonBg
			} else { Write-Buffer -X $_applyContentX -Y ($dy + 8) -Text "" -BG $script:ThemeDialogButtonBg }
			$_cp = if ($script:DialogButtonShowHotkeyParens) { ")" } else { "" }
			if ($script:DialogButtonShowHotkeyParens) { Write-Buffer -Text "(" -FG $script:ThemeDialogButtonText -BG $script:ThemeDialogButtonBg }
			Write-Buffer -Text "a" -FG $script:ThemeDialogButtonHotkey -BG $script:ThemeDialogButtonBg
			Write-Buffer -Text "${_cp}pply" -FG $script:ThemeDialogButtonText -BG $script:ThemeDialogButtonBg
			if ($script:DialogButtonShowBrackets) { Write-Buffer -Text "]" -FG $script:DialogButtonBracketFg -BG $script:DialogButtonBracketBg }
			Write-Buffer -Text "  " -BG $script:ThemeDialogBg
			if ($script:DialogButtonShowBrackets) { Write-Buffer -X $_cancelX -Y ($dy + 8) -Text "[" -FG $script:DialogButtonBracketFg -BG $script:DialogButtonBracketBg }
			$_cancelContentX = $_cancelX + [int]$script:DialogButtonShowBrackets
			if ($script:DialogButtonShowIcon) {
				Write-Buffer -X $_cancelContentX -Y ($dy + 8) -Text $emojiClose -FG $script:TextError -BG $script:ThemeDialogButtonBg -Wide
				Write-Buffer -X ($_cancelContentX + 2) -Y ($dy + 8) -Text $script:DialogButtonSeparator -FG $script:ThemeDialogButtonText -BG $script:ThemeDialogButtonBg
			} else { Write-Buffer -X $_cancelContentX -Y ($dy + 8) -Text "" -BG $script:ThemeDialogButtonBg }
			if ($script:DialogButtonShowHotkeyParens) { Write-Buffer -Text "(" -FG $script:ThemeDialogButtonText -BG $script:ThemeDialogButtonBg }
			Write-Buffer -Text "c" -FG $script:ThemeDialogButtonHotkey -BG $script:ThemeDialogButtonBg
			Write-Buffer -Text "${_cp}ancel" -FG $script:ThemeDialogButtonText -BG $script:ThemeDialogButtonBg
			if ($script:DialogButtonShowBrackets) { Write-Buffer -Text "]" -FG $script:DialogButtonBracketFg -BG $script:DialogButtonBracketBg }
			Write-Buffer -Text (" " * $applyRowPadding) -BG $script:ThemeDialogBg
			Write-Buffer -Text $script:BoxVertical -FG $script:ThemeDialogBorder -BG $script:ThemeDialogBg

			# — Line 9: bottom border --------------------------------------------
			Write-Buffer -X $dx -Y ($dy + 9) -Text ($script:BoxBottomLeft + ($hLine * $inner) + $script:BoxBottomRight) -FG $script:ThemeDialogBorder -BG $script:ThemeDialogBg
		}

		# Send viewerState before opening
		if ($null -ne $ViewerPipeWriter) {
			Send-PipeMessage -Writer $ViewerPipeWriter -Message @{ type='viewerState'; activeDialog='theme' }
		}

		# Save initial theme so Cancel can revert
		$initialThemeName  = $script:CurrentThemeName
		$initialThemeIndex = $script:CurrentThemeIndex

		# Initial draw
		& $drawThemeDialog $dialogX $dialogY
		Write-DialogShadow -dialogX $dialogX -dialogY $dialogY -dialogWidth $dialogWidth -dialogHeight $dialogHeight -shadowColor $script:ThemeDialogShadow
		Flush-Buffer

		$nextButtonRowY   = $dialogY + 6
		$nextButtonStartX = $dialogX + 2
		$nextButtonEndX   = $nextButtonStartX + $dialogBracketWidth + $dialogIconWidth + $buttonLabelLength + $dialogParenOffset - 1
		$applyButtonRowY  = $dialogY + 8
		$applyButtonStartX  = $dialogX + 2
		$applyButtonEndX    = $applyButtonStartX + $applyBtnChars - 1
		$cancelButtonStartX = $applyButtonStartX + $applyBtnChars + 2
		$cancelButtonEndX   = $cancelButtonStartX + $cancelBtnChars - 1

		$script:DialogButtonBounds = @{
			buttonRowY   = $applyButtonRowY
			updateStartX = $applyButtonStartX
			updateEndX   = $applyButtonEndX
			cancelStartX = $cancelButtonStartX
			cancelEndX   = $cancelButtonEndX
		}
		$script:DialogButtonClick = $null

		$needsRedraw = $false

		:inputLoop do {
			# Resize check
			$pswindow = (Get-Host).UI.RawUI
			$newWindowSize = $pswindow.WindowSize
			if ($newWindowSize.Width -ne $currentHostWidth -or $newWindowSize.Height -ne $currentHostHeight) {
				$stableSize = Invoke-ResizeHandler -PreviousScreenState "dialog-theme"
				$HostWidthRef.Value  = $stableSize.Width
				$HostHeightRef.Value = $stableSize.Height
				$currentHostWidth    = $stableSize.Width
				$currentHostHeight   = $stableSize.Height
				Write-MainFrame -Force -NoFlush
				$needsRedraw = $true

				$dialogX = [math]::Max(0, [math]::Floor(($currentHostWidth  - $dialogWidth)  / 2))
				$dialogY = [math]::Max(0, [math]::Floor(($currentHostHeight - $dialogHeight) / 2))

				& $drawThemeDialog $dialogX $dialogY
				Write-DialogShadow -dialogX $dialogX -dialogY $dialogY -dialogWidth $dialogWidth -dialogHeight $dialogHeight -shadowColor $script:ThemeDialogShadow
				Flush-Buffer -ClearFirst

				$nextButtonRowY     = $dialogY + 6
				$nextButtonStartX   = $dialogX + 2
				$nextButtonEndX     = $nextButtonStartX + $dialogBracketWidth + $dialogIconWidth + $buttonLabelLength + $dialogParenOffset - 1
				$applyButtonRowY    = $dialogY + 8
				$applyButtonStartX  = $dialogX + 2
				$applyButtonEndX    = $applyButtonStartX + $applyBtnChars - 1
				$cancelButtonStartX = $applyButtonStartX + $applyBtnChars + 2
				$cancelButtonEndX   = $cancelButtonStartX + $cancelBtnChars - 1
				$script:DialogButtonBounds = @{
					buttonRowY   = $applyButtonRowY
					updateStartX = $applyButtonStartX
					updateEndX   = $applyButtonEndX
					cancelStartX = $cancelButtonStartX
					cancelEndX   = $cancelButtonEndX
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
				if ($clickX -lt $dialogX -or $clickX -ge ($dialogX + $dialogWidth) -or
					$clickY -lt $dialogY -or $clickY -gt ($dialogY + $dialogHeight)) {
					$char = "c"; $keyProcessed = $true
				} elseif ($clickY -eq $nextButtonRowY -and $clickX -ge $nextButtonStartX -and $clickX -le $nextButtonEndX) {
					$char = "n"; $keyProcessed = $true
				} elseif ($clickY -eq $applyButtonRowY -and $clickX -ge $applyButtonStartX -and $clickX -le $applyButtonEndX) {
					$char = "a"; $keyProcessed = $true
				} elseif ($clickY -eq $applyButtonRowY -and $clickX -ge $cancelButtonStartX -and $clickX -le $cancelButtonEndX) {
					$char = "c"; $keyProcessed = $true
				}
			}

			if (-not $keyProcessed -and $null -ne $script:DialogButtonClick) {
				$script:DialogButtonClick = $null
				$char = "a"; $keyProcessed = $true
			}

			if (-not $keyProcessed) {
				$keyInfo = Read-DialogKeyInput
				if ($null -ne $keyInfo) {
					$key = $keyInfo.Key; $char = $keyInfo.Character; $keyProcessed = $true
				}
			}

			if (-not $keyProcessed) { Start-Sleep -Milliseconds 50; continue }

			if ($char -eq "n" -or $char -eq "N") {
				# Cycle to the next theme
				$nextIndex = ($script:CurrentThemeIndex + 1) % $script:ThemeProfiles.Count
				$nextName  = $script:ThemeProfiles[$nextIndex].Name
				Set-ThemeProfile -Name $nextName

				# Redraw the name row only
				$themeName   = $script:CurrentThemeName
				$nameLen     = $themeName.Length
				$inner       = $dialogWidth - 2
				$namePad     = [math]::Max(0, [math]::Floor(($inner - $nameLen) / 2))
				$nameContent = (" " * $namePad) + $themeName + (" " * ($inner - $namePad - $nameLen))
				Write-Buffer -X $dialogX -Y ($dialogY + 4) -Text $script:BoxVertical -FG $script:ThemeDialogBorder -BG $script:ThemeDialogBg
				Write-Buffer -Text $nameContent -FG $script:ThemeDialogNameFg -BG $script:ThemeDialogBg
				Write-Buffer -Text $script:BoxVertical -FG $script:ThemeDialogBorder -BG $script:ThemeDialogBg
				Flush-Buffer

				$needsRedraw = $true
				continue
			}

			if ($char -eq "a" -or $char -eq "A" -or $key -eq "Enter" -or
				$char -eq [char]13 -or $char -eq [char]10) {
				# Apply — keep current theme and close
				break inputLoop
			}

			if ($key -eq "Escape" -or $char -eq "c" -or $char -eq "C" -or
				($null -ne $keyInfo -and $keyInfo.VirtualKeyCode -eq 27)) {
				# Cancel — revert to theme that was active when dialog opened
				if ($script:CurrentThemeName -ne $initialThemeName) {
					Set-ThemeProfile -Name $initialThemeName
					$needsRedraw = $true
				}
				break inputLoop
			}

		} while ($true)

		try { while ($Host.UI.RawUI.KeyAvailable) { $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown,AllowCtrlC") } } catch {}

		# Send viewerState after close
		if ($null -ne $ViewerPipeWriter) {
			Send-PipeMessage -Writer $ViewerPipeWriter -Message @{ type='viewerState'; activeDialog=$null }
		}

		Invoke-DialogCleanup -DialogX $dialogX -DialogY $dialogY -DialogWidth $dialogWidth -DialogHeight $dialogHeight -SavedCursorVisible $savedCursorVisible -ClearShadow

		return @{ NeedsRedraw = $needsRedraw }
	}
