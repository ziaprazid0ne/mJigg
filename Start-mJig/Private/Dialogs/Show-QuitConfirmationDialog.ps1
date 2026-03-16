		function Show-QuitConfirmationDialog {
			param(
				[ref]$HostWidthRef,
				[ref]$HostHeightRef
			)
			
			$script:CurrentScreenState = "dialog-quit"

	if ($DebugMode) {
		Add-DebugLogEntry -LogArray $LogArray -Message "Quit confirmation dialog opened" -ShortMessage "Quit dialog opened"
	}

		$currentHostWidth = $HostWidthRef.Value
		$currentHostHeight = $HostHeightRef.Value

		$dialogWidth = 35
		$dialogHeight = 7
		# Right edge aligns with the right border padding column
		$_bpH    = [math]::Max(1, $script:BorderPadH)
			$dialogX = [math]::Max(0, $currentHostWidth - $dialogWidth - ($_bpH - 1))
			$menuBarY = if ($null -ne $script:MenuBarY) { $script:MenuBarY } else { $currentHostHeight - 2 }
			$dialogY = [math]::Max(0, $menuBarY - 2 - $dialogHeight)
			
			$savedCursorVisible = $script:CursorVisible
			$script:CursorVisible = $false
			[Console]::Write("$($script:ESC)[?25l")
			
$checkmark = [char]::ConvertFromUtf32(0x2705)
$redX = [char]::ConvertFromUtf32(0x274C)
$buttonLayout = Get-DialogButtonLayout
$dialogIconWidth = $buttonLayout.IconWidth; $dialogBracketWidth = $buttonLayout.BracketWidth; $dialogParenOffset = $buttonLayout.ParenAdjustment
$bottomLinePadding = $dialogWidth - (13 + 2 * $dialogParenOffset + 2 * $dialogIconWidth + 2 * $dialogBracketWidth) - 1
	$line0 =  "$($script:BoxTopLeft)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxTopRight)"  # 35 chars
			$line1Text = "$($script:BoxVertical)  Confirm Quit"
			$line1Padding = Get-Padding -UsedWidth ($line1Text.Length + 1) -TotalWidth $dialogWidth
			$line1 = $line1Text + (" " * $line1Padding) + "$($script:BoxVertical)"
			
			$line2 = "$($script:BoxVertical)" + (" " * 33) + "$($script:BoxVertical)"  # 35 chars
			
			$line3Text = "$($script:BoxVertical)  Are you sure you want to quit?"
			$line3Padding = Get-Padding -UsedWidth ($line3Text.Length + 1) -TotalWidth $dialogWidth
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
			
	# Slide-up animation: reveal rows progressively from behind the menu bar
	$clipY        = $menuBarY - 1   # separator row — nothing drawn at or below this Y
		$animSteps    = $dialogHeight + 1  # steps to fully reveal the box
		$frameDelayMs = 15  # 15ms per frame — at the Windows timer floor for consistency
		for ($step = 2; $step -le ($animSteps + 1); $step += 2) {
			$s     = [math]::Min($step, $animSteps)
			$animY = $menuBarY - 1 - $s  # top of box this step (rises 2 rows each step)
			for ($r = 0; $r -lt $s -and $r -le $dialogHeight; $r++) {
					$rowY = $animY + $r
					if ($rowY -ge $clipY) { continue }  # safety: never draw over separator
					# Side padding (terminal default background) — left only
					if ($dialogX -gt 0) {
						Write-Buffer -X ($dialogX - 1) -Y $rowY -Text " "
					}
					# Background fill
					Write-Buffer -X $dialogX -Y $rowY -Text (" " * $dialogWidth) -BG $script:QuitDialogBg
					# Row content
					if ($r -eq 0) {
						Write-Buffer -X $dialogX -Y $rowY -Text $line0 -FG $script:QuitDialogBorder -BG $script:QuitDialogBg
					} elseif ($r -eq $dialogHeight) {
						Write-Buffer -X $dialogX -Y $rowY -Text $dialogLines[$dialogLines.Count - 1] -FG $script:QuitDialogBorder -BG $script:QuitDialogBg
					} else {
						Write-Buffer -X $dialogX                      -Y $rowY -Text $script:BoxVertical -FG $script:QuitDialogBorder -BG $script:QuitDialogBg
						Write-Buffer -X ($dialogX + $dialogWidth - 1) -Y $rowY -Text $script:BoxVertical -FG $script:QuitDialogBorder -BG $script:QuitDialogBg
					}
				}
			# On the last step the box is fully revealed; draw the blank top-padding row
			if ($s -eq $animSteps -and $animY -gt 0) {
				$aPadLeft  = [math]::Max(0, $dialogX - 1)
				$aPadWidth = $dialogWidth + ($dialogX - $aPadLeft)
				Write-Buffer -X $aPadLeft -Y ($animY - 1) -Text (" " * $aPadWidth)
			}
			Flush-Buffer
			if ($frameDelayMs -gt 0) { Start-Sleep -Milliseconds $frameDelayMs }
		}

		# Draw blank padding (terminal default background) — top and left; no bottom or right
			if ($dialogY -gt 0) {
				$padLeft  = [math]::Max(0, $dialogX - 1)
				$padWidth = $dialogWidth + ($dialogX - $padLeft)
				Write-Buffer -X $padLeft -Y ($dialogY - 1) -Text (" " * $padWidth)
			}
			for ($i = 0; $i -le $dialogHeight; $i++) {
				if ($dialogX -gt 0) {
					Write-Buffer -X ($dialogX - 1) -Y ($dialogY + $i) -Text " "
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
					$titlePadding = Get-Padding -UsedWidth ($titleUsedWidth + 1) -TotalWidth $dialogWidth
					Write-Buffer -Text (" " * $titlePadding) -BG $script:QuitDialogBg
					Write-Buffer -Text "$($script:BoxVertical)" -FG $script:QuitDialogBorder -BG $script:QuitDialogBg
			} elseif ($i -eq 6) {
			# Bottom line - write with colored icons and hotkey letters
		$applyButtonX = $dialogX + 2
		$cancelButtonX = $applyButtonX + $dialogBracketWidth + $dialogIconWidth + 5 + $dialogParenOffset + 2  # bracket + icon + "(y)es"(5) + gap(2)
		Write-Buffer -X $dialogX -Y ($dialogY + $i) -Text "$($script:BoxVertical) " -FG $script:QuitDialogBorder -BG $script:QuitDialogBg
		if ($script:DialogButtonShowBrackets) {
			Write-Buffer -X $applyButtonX -Y ($dialogY + $i) -Text "[" -FG $script:DialogButtonBracketFg -BG $script:DialogButtonBracketBg
		}
		$applyButtonContentX = $applyButtonX + [int]$script:DialogButtonShowBrackets
		if ($script:DialogButtonShowIcon) {
			Write-Buffer -X $applyButtonContentX -Y ($dialogY + $i) -Text $checkmark -FG $script:TextSuccess -BG $script:QuitDialogButtonBg -Wide
			Write-Buffer -X ($applyButtonContentX + 2) -Y ($dialogY + $i) -Text $script:DialogButtonSeparator -FG $script:QuitDialogButtonText -BG $script:QuitDialogButtonBg
		} else {
			Write-Buffer -X $applyButtonContentX -Y ($dialogY + $i) -Text "" -BG $script:QuitDialogButtonBg
		}
		if ($script:DialogButtonShowHotkeyParens) { Write-Buffer -Text "(" -FG $script:QuitDialogButtonText -BG $script:QuitDialogButtonBg }
		Write-Buffer -Text "y" -FG $script:QuitDialogButtonHotkey -BG $script:QuitDialogButtonBg
		$closingParen = if ($script:DialogButtonShowHotkeyParens) { ")" } else { "" }
		Write-Buffer -Text "$($closingParen)es" -FG $script:QuitDialogButtonText -BG $script:QuitDialogButtonBg
		if ($script:DialogButtonShowBrackets) { Write-Buffer -Text "]" -FG $script:DialogButtonBracketFg -BG $script:DialogButtonBracketBg }
		Write-Buffer -Text "  " -BG $script:QuitDialogBg
		if ($script:DialogButtonShowBrackets) {
			Write-Buffer -X $cancelButtonX -Y ($dialogY + $i) -Text "[" -FG $script:DialogButtonBracketFg -BG $script:DialogButtonBracketBg
		}
		$cancelButtonContentX = $cancelButtonX + [int]$script:DialogButtonShowBrackets
		if ($script:DialogButtonShowIcon) {
			Write-Buffer -X $cancelButtonContentX -Y ($dialogY + $i) -Text $redX -FG $script:TextError -BG $script:QuitDialogButtonBg -Wide
			Write-Buffer -X ($cancelButtonContentX + 2) -Y ($dialogY + $i) -Text $script:DialogButtonSeparator -FG $script:QuitDialogButtonText -BG $script:QuitDialogButtonBg
		} else {
			Write-Buffer -X $cancelButtonContentX -Y ($dialogY + $i) -Text "" -BG $script:QuitDialogButtonBg
		}
		if ($script:DialogButtonShowHotkeyParens) { Write-Buffer -Text "(" -FG $script:QuitDialogButtonText -BG $script:QuitDialogButtonBg }
		Write-Buffer -Text "n" -FG $script:QuitDialogButtonHotkey -BG $script:QuitDialogButtonBg
		Write-Buffer -Text "$($closingParen)o" -FG $script:QuitDialogButtonText -BG $script:QuitDialogButtonBg
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
$yesButtonEndX   = $dialogX + 2 + $dialogBracketWidth + $dialogIconWidth + 5 + $dialogParenOffset - 1   # bracket + icon + "(y)es"(5) - 1 inclusive
$noButtonStartX  = $dialogX + 2 + $dialogBracketWidth + $dialogIconWidth + 5 + $dialogParenOffset + 2   # after btn1 + gap(2)
$noButtonEndX    = $noButtonStartX + $dialogBracketWidth + $dialogIconWidth + 4 + $dialogParenOffset - 1 # bracket + icon + "(n)o"(4) - 1 inclusive
			
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
					$stableSize = Invoke-ResizeHandler -PreviousScreenState "dialog-quit"
					$HostWidthRef.Value  = $stableSize.Width
					$HostHeightRef.Value = $stableSize.Height
					$currentHostWidth  = $stableSize.Width
					$currentHostHeight = $stableSize.Height
					Write-MainFrame -Force -NoFlush
					$needsRedraw = $true
					
				# Reposition dialog: right edge at first column of right-side border padding
				$_bpH    = [math]::Max(1, $script:BorderPadH)
				$dialogX = [math]::Max(0, $currentHostWidth - $dialogWidth - ($_bpH - 1))
				$menuBarY = if ($null -ne $script:MenuBarY) { $script:MenuBarY } else { $currentHostHeight - 2 }
				$dialogY = [math]::Max(0, $menuBarY - 2 - $dialogHeight)

				for ($i = 0; $i -lt $dialogLines.Count; $i++) {
						if ($i -eq 1) {
							# Title line
							Write-Buffer -X $dialogX -Y ($dialogY + $i) -Text "$($script:BoxVertical)  " -FG $script:QuitDialogBorder -BG $script:QuitDialogBg
							Write-Buffer -Text "Confirm Quit" -FG $script:QuitDialogTitle -BG $script:QuitDialogBg
							$titleUsedWidth = 3 + "Confirm Quit".Length  # "$($script:BoxVertical)  " + title
							$titlePadding = Get-Padding -UsedWidth ($titleUsedWidth + 1) -TotalWidth $dialogWidth
							Write-Buffer -Text (" " * $titlePadding) -BG $script:QuitDialogBg
							Write-Buffer -Text "$($script:BoxVertical)" -FG $script:QuitDialogBorder -BG $script:QuitDialogBg
					} elseif ($i -eq 6) {
					# Bottom line - write with colored icons and hotkey letters
				$applyButtonX = $dialogX + 2
				$cancelButtonX = $applyButtonX + $dialogBracketWidth + $dialogIconWidth + 5 + $dialogParenOffset + 2  # bracket + icon + "(y)es"(5) + gap(2)
				Write-Buffer -X $dialogX -Y ($dialogY + $i) -Text "$($script:BoxVertical) " -FG $script:QuitDialogBorder -BG $script:QuitDialogBg
				if ($script:DialogButtonShowBrackets) {
					Write-Buffer -X $applyButtonX -Y ($dialogY + $i) -Text "[" -FG $script:DialogButtonBracketFg -BG $script:DialogButtonBracketBg
				}
				$applyButtonContentX = $applyButtonX + [int]$script:DialogButtonShowBrackets
				if ($script:DialogButtonShowIcon) {
					Write-Buffer -X $applyButtonContentX -Y ($dialogY + $i) -Text $checkmark -FG $script:TextSuccess -BG $script:QuitDialogButtonBg -Wide
					Write-Buffer -X ($applyButtonContentX + 2) -Y ($dialogY + $i) -Text $script:DialogButtonSeparator -FG $script:QuitDialogButtonText -BG $script:QuitDialogButtonBg
				} else {
					Write-Buffer -X $applyButtonContentX -Y ($dialogY + $i) -Text "" -BG $script:QuitDialogButtonBg
				}
				if ($script:DialogButtonShowHotkeyParens) { Write-Buffer -Text "(" -FG $script:QuitDialogButtonText -BG $script:QuitDialogButtonBg }
				Write-Buffer -Text "y" -FG $script:QuitDialogButtonHotkey -BG $script:QuitDialogButtonBg
				$closingParen = if ($script:DialogButtonShowHotkeyParens) { ")" } else { "" }
				Write-Buffer -Text "$($closingParen)es" -FG $script:QuitDialogButtonText -BG $script:QuitDialogButtonBg
				if ($script:DialogButtonShowBrackets) { Write-Buffer -Text "]" -FG $script:DialogButtonBracketFg -BG $script:DialogButtonBracketBg }
				Write-Buffer -Text "  " -BG $script:QuitDialogBg
				if ($script:DialogButtonShowBrackets) {
					Write-Buffer -X $cancelButtonX -Y ($dialogY + $i) -Text "[" -FG $script:DialogButtonBracketFg -BG $script:DialogButtonBracketBg
				}
				$cancelButtonContentX = $cancelButtonX + [int]$script:DialogButtonShowBrackets
				if ($script:DialogButtonShowIcon) {
					Write-Buffer -X $cancelButtonContentX -Y ($dialogY + $i) -Text $redX -FG $script:TextError -BG $script:QuitDialogButtonBg -Wide
					Write-Buffer -X ($cancelButtonContentX + 2) -Y ($dialogY + $i) -Text $script:DialogButtonSeparator -FG $script:QuitDialogButtonText -BG $script:QuitDialogButtonBg
				} else {
					Write-Buffer -X $cancelButtonContentX -Y ($dialogY + $i) -Text "" -BG $script:QuitDialogButtonBg
				}
				if ($script:DialogButtonShowHotkeyParens) { Write-Buffer -Text "(" -FG $script:QuitDialogButtonText -BG $script:QuitDialogButtonBg }
				Write-Buffer -Text "n" -FG $script:QuitDialogButtonHotkey -BG $script:QuitDialogButtonBg
				Write-Buffer -Text "$($closingParen)o" -FG $script:QuitDialogButtonText -BG $script:QuitDialogButtonBg
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
		$yesButtonEndX   = $dialogX + 2 + $dialogBracketWidth + $dialogIconWidth + 5 + $dialogParenOffset - 1
		$noButtonStartX  = $dialogX + 2 + $dialogBracketWidth + $dialogIconWidth + 5 + $dialogParenOffset + 2
		$noButtonEndX    = $noButtonStartX + $dialogBracketWidth + $dialogIconWidth + 4 + $dialogParenOffset - 1
					
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
				
			$_click = Get-DialogMouseClick -PeekBuffer $script:_DialogPeekBuffer
			if ($null -ne $_click) {
				$clickX = $_click.X; $clickY = $_click.Y
				if ($clickX -lt $dialogX -or $clickX -ge ($dialogX + $dialogWidth) -or $clickY -lt $dialogY -or $clickY -gt ($dialogY + $dialogHeight)) {
					$char = "n"; $keyProcessed = $true
				} elseif ($clickY -eq $buttonRowY -and $clickX -ge $yesButtonStartX -and $clickX -le $yesButtonEndX) {
					$char = "y"; $keyProcessed = $true
				} elseif ($clickY -eq $buttonRowY -and $clickX -ge $noButtonStartX -and $clickX -le $noButtonEndX) {
					$char = "n"; $keyProcessed = $true
				}
				if ($DebugMode) {
					$clickTarget = if ($keyProcessed) { "button:$char" } else { "none" }
					Add-DebugLogEntry -LogArray $LogArray -Message "Quit dialog click at ($clickX,$clickY), target: $clickTarget" -ShortMessage "Click ($clickX,$clickY) -> $clickTarget"
				}
			}
				
				# Check for dialog button clicks detected by main loop
				if (-not $keyProcessed -and $null -ne $script:DialogButtonClick) {
					$buttonClick = $script:DialogButtonClick
					$script:DialogButtonClick = $null
					if ($buttonClick -eq "Update") { $char = "y"; $keyProcessed = $true }
					elseif ($buttonClick -eq "Cancel") { $char = "n"; $keyProcessed = $true }
				}
				
			if (-not $keyProcessed) {
				$keyInfo = Read-DialogKeyInput
				if ($null -ne $keyInfo) {
					$key = $keyInfo.Key; $char = $keyInfo.Character; $keyProcessed = $true
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
					Add-DebugLogEntry -LogArray $LogArray -Message "Quit dialog: Confirmed" -ShortMessage "Quit: Yes"
				}
					$result = $true
					break
				} elseif ($char -eq "n" -or $char -eq "N" -or $char -eq "q" -or $char -eq "Q" -or $key -eq "Escape" -or ($null -ne $keyInfo -and $keyInfo.VirtualKeyCode -eq 27)) {
					# No - cancel quit (Escape key and 'q' key also work as hidden functions)
					# Debug: Log quit cancellation
				if ($DebugMode) {
					Add-DebugLogEntry -LogArray $LogArray -Message "Quit dialog: Canceled" -ShortMessage "Quit: No"
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
			
		Invoke-DialogCleanup -DialogX $dialogX -DialogY $dialogY -DialogWidth $dialogWidth -DialogHeight $dialogHeight -SavedCursorVisible $savedCursorVisible -ClearShadow
			# Return result object with result and redraw flag
			return @{
				Result = $result
				NeedsRedraw = $needsRedraw
			}
		}
