		function Show-TimeChangeDialog {
			param(
				[int]$currentEndTime,
				[ref]$HostWidthRef,
				[ref]$HostHeightRef,
				[scriptblock]$ParentRedrawCallback = $null
			)
			
			$script:CurrentScreenState = "dialog-time"

			# Get current host dimensions from references
			$currentHostWidth = $HostWidthRef.Value
			$currentHostHeight = $HostHeightRef.Value
			
			# Dialog dimensions (reduced width)
			$dialogWidth = 35
			$dialogHeight = 7
			$dialogX = [math]::Max(0, [math]::Floor(($currentHostWidth - $dialogWidth) / 2))
			$dialogY = [math]::Max(0, [math]::Floor(($currentHostHeight - $dialogHeight) / 2))
			
			$savedCursorVisible = $script:CursorVisible
			$script:CursorVisible = $true
			[Console]::Write("$($script:ESC)[?25h")
			
		$checkmark = [char]::ConvertFromUtf32(0x2705)  # ✅ green checkmark
		$redX = [char]::ConvertFromUtf32(0x274C)  # ❌ red X
$_bl = Get-DialogButtonLayout
$dlgIconWidth = $_bl.IconWidth; $dlgBracketWidth = $_bl.BracketWidth; $dlgParenAdj = $_bl.ParenAdj
# Button line: border+space(2) + btn1(bracketW+iconW+"(a)pply"=7) + gap(2) + btn2(bracketW+iconW+"(c)ancel"=8) = 19 + 2*iconWidth + 2*bracketWidth
$bottomLinePadding = $dialogWidth - (19 + 2 * $dlgParenAdj + 2 * $dlgIconWidth + 2 * $dlgBracketWidth) - 1
			
			# Build all lines to be exactly 35 characters using Get-Padding helper
			$line0 = "$($script:BoxTopLeft)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxTopRight)"  # 35 chars
			$line1Text = "$($script:BoxVertical)  Change End Time"
			$line1Padding = Get-Padding -usedWidth ($line1Text.Length + 1) -totalWidth $dialogWidth
			$line1 = $line1Text + (" " * $line1Padding) + "$($script:BoxVertical)"
			
			$line2 = "$($script:BoxVertical)" + (" " * 33) + "$($script:BoxVertical)"  # 35 chars
			
			$line3Text = "$($script:BoxVertical)  Enter new time (HHmm format):"
			$line3Padding = Get-Padding -usedWidth ($line3Text.Length + 1) -totalWidth $dialogWidth
			$line3 = $line3Text + (" " * $line3Padding) + "$($script:BoxVertical)"
			
			# Line 4 will be drawn separately with highlighted field
			$line4Text = "$($script:BoxVertical)  "
			$line4Padding = Get-Padding -usedWidth ($line4Text.Length + 1 + 6) -totalWidth $dialogWidth  # +6 for "[    ]"
			$line4 = $line4Text + (" " * $line4Padding) + "$($script:BoxVertical)"
			
			$line5 = "$($script:BoxVertical)" + (" " * 33) + "$($script:BoxVertical)"  # 35 chars
			
			$line7 = "$($script:BoxBottomLeft)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxHorizontal)$($script:BoxBottomRight)"  # 35 chars
			
			$dialogLines = @(
				$line0,
				$line1,
				$line2,
				$line3,
				$line4,
				$line5,
				$null,  # Bottom line will be written separately with colors
				$line7
			)
			
			# Draw dialog background (clear area) with themed background
			for ($i = 0; $i -lt $dialogHeight; $i++) {
				Write-Buffer -X $dialogX -Y ($dialogY + $i) -Text (" " * $dialogWidth) -BG $script:TimeDialogBg
			}
			
			# Draw dialog box with themed background
			for ($i = 0; $i -lt $dialogLines.Count; $i++) {
				if ($i -eq 1) {
					Write-Buffer -X $dialogX -Y ($dialogY + $i) -Text "$($script:BoxVertical)  " -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
					Write-Buffer -Text "Change End Time" -FG $script:TimeDialogTitle -BG $script:TimeDialogBg
					$titleUsedWidth = 3 + "Change End Time".Length
					$titlePadding = Get-Padding -usedWidth ($titleUsedWidth + 1) -totalWidth $dialogWidth
					Write-Buffer -Text (" " * $titlePadding) -BG $script:TimeDialogBg
					Write-Buffer -Text "$($script:BoxVertical)" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
				} elseif ($i -eq 4) {
					$initialTimeDisplay = if ($currentEndTime -ne -1 -and $currentEndTime -ne 0) { 
						$currentEndTime.ToString().PadLeft(4, '0') 
					} else { 
						"" 
					}
					$fieldDisplay = $initialTimeDisplay.PadRight(4)
					Write-Buffer -X $dialogX -Y ($dialogY + $i) -Text "$($script:BoxVertical)  " -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
					Write-Buffer -Text "[" -FG $script:TimeDialogText -BG $script:TimeDialogBg
					Write-Buffer -Text $fieldDisplay -FG $script:TimeDialogFieldText -BG $script:TimeDialogFieldBg
					Write-Buffer -Text "]" -FG $script:TimeDialogText -BG $script:TimeDialogBg
					$fieldUsedWidth = 3 + 6
					$fieldPadding = Get-Padding -usedWidth ($fieldUsedWidth + 1) -totalWidth $dialogWidth
					Write-Buffer -Text (" " * $fieldPadding) -BG $script:TimeDialogBg
					Write-Buffer -Text "$($script:BoxVertical)" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
			} elseif ($i -eq 6) {
			$btn1X = $dialogX + 2
		$btn2X = $btn1X + $dlgBracketWidth + $dlgIconWidth + 7 + $dlgParenAdj + 2  # bracket + icon + "(a)pply"(7) + gap(2)
		Write-Buffer -X $dialogX -Y ($dialogY + $i) -Text "$($script:BoxVertical) " -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
		if ($script:DialogButtonShowBrackets) {
			Write-Buffer -X $btn1X -Y ($dialogY + $i) -Text "[" -FG $script:DialogButtonBracketFg -BG $script:DialogButtonBracketBg
		}
		$btn1ContentX = $btn1X + [int]$script:DialogButtonShowBrackets
		if ($script:DialogButtonShowIcon) {
			Write-Buffer -X $btn1ContentX -Y ($dialogY + $i) -Text $checkmark -FG $script:TextSuccess -BG $script:TimeDialogButtonBg -Wide
			Write-Buffer -X ($btn1ContentX + 2) -Y ($dialogY + $i) -Text $script:DialogButtonSeparator -FG $script:TimeDialogButtonText -BG $script:TimeDialogButtonBg
		} else {
			Write-Buffer -X $btn1ContentX -Y ($dialogY + $i) -Text "" -BG $script:TimeDialogButtonBg
		}
		$_rp = if ($script:DialogButtonShowHotkeyParens) { ")" } else { "" }
		if ($script:DialogButtonShowHotkeyParens) { Write-Buffer -Text "(" -FG $script:TimeDialogButtonText -BG $script:TimeDialogButtonBg }
	Write-Buffer -Text "a" -FG $script:TimeDialogButtonHotkey -BG $script:TimeDialogButtonBg
	Write-Buffer -Text "${_rp}pply" -FG $script:TimeDialogButtonText -BG $script:TimeDialogButtonBg
		if ($script:DialogButtonShowBrackets) { Write-Buffer -Text "]" -FG $script:DialogButtonBracketFg -BG $script:DialogButtonBracketBg }
		Write-Buffer -Text "  " -BG $script:TimeDialogBg
		if ($script:DialogButtonShowBrackets) {
			Write-Buffer -X $btn2X -Y ($dialogY + $i) -Text "[" -FG $script:DialogButtonBracketFg -BG $script:DialogButtonBracketBg
		}
		$btn2ContentX = $btn2X + [int]$script:DialogButtonShowBrackets
		if ($script:DialogButtonShowIcon) {
			Write-Buffer -X $btn2ContentX -Y ($dialogY + $i) -Text $redX -FG $script:TextError -BG $script:TimeDialogButtonBg -Wide
			Write-Buffer -X ($btn2ContentX + 2) -Y ($dialogY + $i) -Text $script:DialogButtonSeparator -FG $script:TimeDialogButtonText -BG $script:TimeDialogButtonBg
		} else {
			Write-Buffer -X $btn2ContentX -Y ($dialogY + $i) -Text "" -BG $script:TimeDialogButtonBg
		}
		if ($script:DialogButtonShowHotkeyParens) { Write-Buffer -Text "(" -FG $script:TimeDialogButtonText -BG $script:TimeDialogButtonBg }
		Write-Buffer -Text "c" -FG $script:TimeDialogButtonHotkey -BG $script:TimeDialogButtonBg
		Write-Buffer -Text "${_rp}ancel" -FG $script:TimeDialogButtonText -BG $script:TimeDialogButtonBg
		if ($script:DialogButtonShowBrackets) { Write-Buffer -Text "]" -FG $script:DialogButtonBracketFg -BG $script:DialogButtonBracketBg }
		Write-Buffer -Text (" " * $bottomLinePadding) -BG $script:TimeDialogBg
		Write-Buffer -Text "$($script:BoxVertical)" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
	} else {
		Write-Buffer -X $dialogX -Y ($dialogY + $i) -Text $dialogLines[$i] -FG $script:TimeDialogText -BG $script:TimeDialogBg
	}
}

# Draw drop shadow
Draw-DialogShadow -dialogX $dialogX -dialogY $dialogY -dialogWidth $dialogWidth -dialogHeight $dialogHeight -shadowColor $script:TimeDialogShadow
	Flush-Buffer
	
	# Calculate button bounds for click detection (visible characters only)
	# Button row is at dialogY + 6 (line 6)
	$buttonRowY = $dialogY + 6
$updateButtonStartX = $dialogX + 2
$updateButtonEndX   = $dialogX + 2 + $dlgBracketWidth + $dlgIconWidth + 7 + $dlgParenAdj - 1   # bracket + icon + "(a)pply"(7) - 1 inclusive
$cancelButtonStartX = $dialogX + 2 + $dlgBracketWidth + $dlgIconWidth + 7 + $dlgParenAdj + 2   # after btn1 + gap(2)
$cancelButtonEndX   = $cancelButtonStartX + $dlgBracketWidth + $dlgIconWidth + 8 + $dlgParenAdj - 1  # bracket + icon + "(c)ancel"(8) - 1 inclusive
		
		# Store button bounds in script scope for main loop click detection
		$script:DialogButtonBounds = @{
			buttonRowY = $buttonRowY
			updateStartX = $updateButtonStartX
			updateEndX = $updateButtonEndX
			cancelStartX = $cancelButtonStartX
			cancelEndX = $cancelButtonEndX
		}
		$script:DialogButtonClick = $null  # Clear any previous click  # 20 + 2 (emoji) + 1 (pipe) + 8 (text) - 1 (inclusive)
			
			# Position cursor in input field (inside the brackets, after "$($script:BoxVertical)  [")
			# Line 4 is "$($script:BoxVertical)  [" + 4 spaces + "]", so input starts at position 4
			$inputX = $dialogX + 4
			$inputY = $dialogY + 4
			$script:CursorVisible = $false
			[Console]::Write("$($script:ESC)[?25l")
			
			# Get input
			# Initialize with current end time if it exists (convert to 4-digit string)
			if ($currentEndTime -ne -1 -and $currentEndTime -ne 0) {
				$timeInput = $currentEndTime.ToString().PadLeft(4, '0')
			} else {
				$timeInput = ""
			}
			$result = $null
			$needsRedraw = $false
			$errorMessage = ""
			$isFirstChar = $true  # Track if this is the first character typed
			
			# Don't draw initial input value - cursor is hidden until first character is typed
			# Position cursor at the input field after initial draw (even if hidden, so it's ready when shown)
			[Console]::SetCursorPosition($inputX + $timeInput.Length, $inputY)
			
			# Debug: Log that dialog input loop has started
		if ($DebugMode) {
			Add-DebugLogEntry -LogArray $LogArray -Message "Time dialog input loop started, button row Y: $buttonRowY" -ShortMessage "Dialog started"
		}
			
			:inputLoop do {
				# Check for window resize and update references
				$pshost = Get-Host
				$pswindow = $pshost.UI.RawUI
				$newWindowSize = $pswindow.WindowSize
				if ($newWindowSize.Width -ne $currentHostWidth -or $newWindowSize.Height -ne $currentHostHeight) {
					$stableSize = Invoke-ResizeHandler -PreviousScreenState "dialog-time"
					$HostWidthRef.Value  = $stableSize.Width
					$HostHeightRef.Value = $stableSize.Height
					$currentHostWidth  = $stableSize.Width
					$currentHostHeight = $stableSize.Height
					Draw-MainFrame -Force -NoFlush
					if ($null -ne $ParentRedrawCallback) {
						& $ParentRedrawCallback $currentHostWidth $currentHostHeight
					}
					$needsRedraw = $true
					
					# Reposition dialog
					$dialogX = [math]::Max(0, [math]::Floor(($currentHostWidth - $dialogWidth) / 2))
					$dialogY = [math]::Max(0, [math]::Floor(($currentHostHeight - $dialogHeight) / 2))
					$inputX = $dialogX + 4
					$inputY = $dialogY + 4
					
				# Recalculate button bounds after repositioning
			$buttonRowY = $dialogY + 6
		$updateButtonStartX = $dialogX + 2
		$updateButtonEndX   = $dialogX + 2 + $dlgBracketWidth + $dlgIconWidth + 7 - 1
		$cancelButtonStartX = $dialogX + 2 + $dlgBracketWidth + $dlgIconWidth + 7 + 2
		$cancelButtonEndX   = $cancelButtonStartX + $dlgBracketWidth + $dlgIconWidth + 8 - 1
		
		# Update button bounds in script scope
		$script:DialogButtonBounds = @{
			buttonRowY = $buttonRowY
			updateStartX = $updateButtonStartX
			updateEndX = $updateButtonEndX
			cancelStartX = $cancelButtonStartX
			cancelEndX = $cancelButtonEndX
		}
		
		for ($i = 0; $i -lt $dialogLines.Count; $i++) {
			if ($i -eq 1) {
				Write-Buffer -X $dialogX -Y ($dialogY + $i) -Text "$($script:BoxVertical)  " -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
				Write-Buffer -Text "Change End Time" -FG $script:TimeDialogTitle -BG $script:TimeDialogBg
					$titleUsedWidth = 3 + "Change End Time".Length
					$titlePadding = Get-Padding -usedWidth ($titleUsedWidth + 1) -totalWidth $dialogWidth
					Write-Buffer -Text (" " * $titlePadding) -BG $script:TimeDialogBg
					Write-Buffer -Text "$($script:BoxVertical)" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
				} elseif ($i -eq 4) {
					$fieldDisplay = $timeInput.PadRight(4)
					Write-Buffer -X $dialogX -Y ($dialogY + $i) -Text "$($script:BoxVertical)  " -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
					Write-Buffer -Text "[" -FG $script:TimeDialogText -BG $script:TimeDialogBg
					Write-Buffer -Text $fieldDisplay -FG $script:TimeDialogFieldText -BG $script:TimeDialogFieldBg
					Write-Buffer -Text "]" -FG $script:TimeDialogText -BG $script:TimeDialogBg
					$fieldUsedWidth = 3 + 6
					$fieldPadding = Get-Padding -usedWidth ($fieldUsedWidth + 1) -totalWidth $dialogWidth
					Write-Buffer -Text (" " * $fieldPadding) -BG $script:TimeDialogBg
					Write-Buffer -Text "$($script:BoxVertical)" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
				} elseif ($i -eq 6) {
				$btn1X = $dialogX + 2
				$btn2X = $btn1X + $dlgBracketWidth + $dlgIconWidth + 7 + $dlgParenAdj + 2
				Write-Buffer -X $dialogX -Y ($dialogY + $i) -Text "$($script:BoxVertical) " -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
				if ($script:DialogButtonShowBrackets) {
					Write-Buffer -X $btn1X -Y ($dialogY + $i) -Text "[" -FG $script:DialogButtonBracketFg -BG $script:DialogButtonBracketBg
				}
				$btn1ContentX = $btn1X + [int]$script:DialogButtonShowBrackets
				if ($script:DialogButtonShowIcon) {
					Write-Buffer -X $btn1ContentX -Y ($dialogY + $i) -Text $checkmark -FG $script:TextSuccess -BG $script:TimeDialogButtonBg -Wide
					Write-Buffer -X ($btn1ContentX + 2) -Y ($dialogY + $i) -Text $script:DialogButtonSeparator -FG $script:TimeDialogButtonText -BG $script:TimeDialogButtonBg
				} else {
					Write-Buffer -X $btn1ContentX -Y ($dialogY + $i) -Text "" -BG $script:TimeDialogButtonBg
				}
				$_rp = if ($script:DialogButtonShowHotkeyParens) { ")" } else { "" }
				if ($script:DialogButtonShowHotkeyParens) { Write-Buffer -Text "(" -FG $script:TimeDialogButtonText -BG $script:TimeDialogButtonBg }
	Write-Buffer -Text "a" -FG $script:TimeDialogButtonHotkey -BG $script:TimeDialogButtonBg
	Write-Buffer -Text "${_rp}pply" -FG $script:TimeDialogButtonText -BG $script:TimeDialogButtonBg
				if ($script:DialogButtonShowBrackets) { Write-Buffer -Text "]" -FG $script:DialogButtonBracketFg -BG $script:DialogButtonBracketBg }
				Write-Buffer -Text "  " -BG $script:TimeDialogBg
				if ($script:DialogButtonShowBrackets) {
					Write-Buffer -X $btn2X -Y ($dialogY + $i) -Text "[" -FG $script:DialogButtonBracketFg -BG $script:DialogButtonBracketBg
				}
				$btn2ContentX = $btn2X + [int]$script:DialogButtonShowBrackets
				if ($script:DialogButtonShowIcon) {
					Write-Buffer -X $btn2ContentX -Y ($dialogY + $i) -Text $redX -FG $script:TextError -BG $script:TimeDialogButtonBg -Wide
					Write-Buffer -X ($btn2ContentX + 2) -Y ($dialogY + $i) -Text $script:DialogButtonSeparator -FG $script:TimeDialogButtonText -BG $script:TimeDialogButtonBg
				} else {
					Write-Buffer -X $btn2ContentX -Y ($dialogY + $i) -Text "" -BG $script:TimeDialogButtonBg
				}
				if ($script:DialogButtonShowHotkeyParens) { Write-Buffer -Text "(" -FG $script:TimeDialogButtonText -BG $script:TimeDialogButtonBg }
				Write-Buffer -Text "c" -FG $script:TimeDialogButtonHotkey -BG $script:TimeDialogButtonBg
				Write-Buffer -Text "${_rp}ancel" -FG $script:TimeDialogButtonText -BG $script:TimeDialogButtonBg
				if ($script:DialogButtonShowBrackets) { Write-Buffer -Text "]" -FG $script:DialogButtonBracketFg -BG $script:DialogButtonBracketBg }
				Write-Buffer -Text (" " * $bottomLinePadding) -BG $script:TimeDialogBg
				Write-Buffer -Text "$($script:BoxVertical)" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
			} else {
				Write-Buffer -X $dialogX -Y ($dialogY + $i) -Text $dialogLines[$i] -FG $script:TimeDialogText -BG $script:TimeDialogBg
			}
		}
					
					Draw-DialogShadow -dialogX $dialogX -dialogY $dialogY -dialogWidth $dialogWidth -dialogHeight $dialogHeight -shadowColor $script:TimeDialogShadow
					
					$fieldDisplay = $timeInput.PadRight(4)
					Write-Buffer -X $dialogX -Y $inputY -Text "$($script:BoxVertical)  " -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
					Write-Buffer -Text "[" -FG $script:TimeDialogText -BG $script:TimeDialogBg
					Write-Buffer -Text $fieldDisplay -FG $script:TimeDialogFieldText -BG $script:TimeDialogFieldBg
					Write-Buffer -Text "]" -FG $script:TimeDialogText -BG $script:TimeDialogBg
					$fieldUsedWidth = 3 + 6
					$fieldPadding = Get-Padding -usedWidth ($fieldUsedWidth + 1) -totalWidth $dialogWidth
					Write-Buffer -Text (" " * $fieldPadding) -BG $script:TimeDialogBg
					Write-Buffer -Text "$($script:BoxVertical)" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
					if ($errorMessage -ne "") {
						Write-Buffer -X $dialogX -Y ($dialogY + 5) -Text "$($script:BoxVertical)  " -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
						Write-Buffer -Text $errorMessage -FG $script:TextError -BG $script:TimeDialogBg
						$errorLineUsedWidth = 3 + $errorMessage.Length
						$errorLinePadding = Get-Padding -usedWidth ($errorLineUsedWidth + 1) -totalWidth $dialogWidth
						Write-Buffer -Text (" " * $errorLinePadding) -BG $script:TimeDialogBg
						Write-Buffer -Text "$($script:BoxVertical)" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
					} else {
						Write-Buffer -X $dialogX -Y ($dialogY + 5) -Text "$($script:BoxVertical)" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
						Write-Buffer -Text (" " * ($dialogWidth - 2)) -BG $script:TimeDialogBg
						Write-Buffer -Text "$($script:BoxVertical)" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
					}
					Flush-Buffer -ClearFirst
					[Console]::SetCursorPosition($inputX + $timeInput.Length, $inputY)
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
					$char = "c"; $keyProcessed = $true
				} elseif ($clickY -eq $buttonRowY -and $clickX -ge $updateButtonStartX -and $clickX -le $updateButtonEndX) {
					$char = "a"; $keyProcessed = $true
				} elseif ($clickY -eq $buttonRowY -and $clickX -ge $cancelButtonStartX -and $clickX -le $cancelButtonEndX) {
					$char = "c"; $keyProcessed = $true
				}
			if ($DebugMode) {
				$clickTarget = if ($keyProcessed) { "button:$char" } else { "none" }
				Add-DebugLogEntry -LogArray $LogArray -Message "Time dialog click at ($clickX,$clickY), target: $clickTarget" -ShortMessage "Click ($clickX,$clickY) -> $clickTarget"
			}
			}
				
				# Check for dialog button clicks detected by main loop
				if (-not $keyProcessed -and $null -ne $script:DialogButtonClick) {
					$buttonClick = $script:DialogButtonClick
					$script:DialogButtonClick = $null
				if ($buttonClick -eq "Apply") { $char = "a"; $keyProcessed = $true }
				elseif ($buttonClick -eq "Cancel") { $char = "c"; $keyProcessed = $true }
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
				
			if ($char -eq "a" -or $char -eq "A" -or $key -eq "Enter" -or $char -eq [char]13 -or $char -eq [char]10) {
				# Apply - allow blank input to clear end time (Enter key also works as hidden function)
					# Debug: Log time dialog update
				if ($DebugMode) {
				$updateValue = if ($timeInput.Length -eq 0) { "cleared" } else { $timeInput }
				Add-DebugLogEntry -LogArray $LogArray -Message "Time dialog: Update clicked (value: $updateValue)" -ShortMessage "Time: Update"
				}
					if ($timeInput.Length -eq 0) {
						# Blank input - clear end time (use -1 as special value)
						$result = -1
						break
					} elseif ($timeInput.Length -eq 1 -and $timeInput -eq "0") {
						# Single "0" = no end time
						$result = -1
						break
					} elseif ($timeInput.Length -eq 2) {
						# 2 digits entered - treat as hours, auto-fill minutes as 00
						try {
							$hours = [int]$timeInput
							if ($hours -ge 0 -and $hours -le 23) {
								# Valid hours - pad with "00" for minutes
								$timeInput = $timeInput.PadRight(4, '0')
								$newTime = [int]$timeInput
								$result = $newTime
								break
							} else {
								# Invalid hours - show error
								$errorMessage = "Hours out of range (00-23)"
								# Redraw input field with highlight - redraw entire line 4
								$fieldDisplay = $timeInput.PadRight(4)
								Write-Buffer -X $dialogX -Y $inputY -Text "$($script:BoxVertical)  " -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
								Write-Buffer -Text "[" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
								Write-Buffer -Text $fieldDisplay -FG $script:TimeDialogFieldText -BG $script:TimeDialogFieldBg
								Write-Buffer -Text "]" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
								$fieldUsedWidth = 3 + 6
								$fieldPadding = Get-Padding -usedWidth ($fieldUsedWidth + 1) -totalWidth $dialogWidth
								Write-Buffer -Text (" " * $fieldPadding) -BG $script:TimeDialogBg
								Write-Buffer -Text "$($script:BoxVertical)" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
								Write-Buffer -X $dialogX -Y ($dialogY + 5) -Text "$($script:BoxVertical)  " -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
								Write-Buffer -Text $errorMessage -FG $script:TextError -BG $script:TimeDialogBg
								$errorLineUsedWidth = 3 + $errorMessage.Length
								$errorLinePadding = Get-Padding -usedWidth ($errorLineUsedWidth + 1) -totalWidth $dialogWidth
								Write-Buffer -Text (" " * $errorLinePadding) -BG $script:TimeDialogBg
								Write-Buffer -Text "$($script:BoxVertical)" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
								Flush-Buffer
								[Console]::SetCursorPosition($inputX + 1 + $timeInput.Length, $inputY)
							}
						} catch {
							# Invalid input - show error
							$errorMessage = "Invalid hours"
							# Redraw input field with highlight - redraw entire line 4
							$fieldDisplay = $timeInput.PadRight(4)
							Write-Buffer -X $dialogX -Y $inputY -Text "$($script:BoxVertical)  " -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
							Write-Buffer -Text "[" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
							Write-Buffer -Text $fieldDisplay -FG $script:TimeDialogFieldText -BG $script:TimeDialogFieldBg
							Write-Buffer -Text "]" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
							$fieldUsedWidth = 3 + 6
							$fieldPadding = Get-Padding -usedWidth ($fieldUsedWidth + 1) -totalWidth $dialogWidth
							Write-Buffer -Text (" " * $fieldPadding) -BG $script:TimeDialogBg
							Write-Buffer -Text "$($script:BoxVertical)" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
							Write-Buffer -X $dialogX -Y ($dialogY + 5) -Text "$($script:BoxVertical)  " -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
							Write-Buffer -Text $errorMessage -FG $script:TextError -BG $script:TimeDialogBg
							$errorLineUsedWidth = 3 + $errorMessage.Length
							$errorLinePadding = Get-Padding -usedWidth ($errorLineUsedWidth + 1) -totalWidth $dialogWidth
							Write-Buffer -Text (" " * $errorLinePadding) -BG $script:TimeDialogBg
							Write-Buffer -Text "$($script:BoxVertical)" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
							Flush-Buffer
							[Console]::SetCursorPosition($inputX + 1 + $timeInput.Length, $inputY)
						}
					} elseif ($timeInput.Length -eq 4) {
						try {
							$newTime = [int]$timeInput
							# Validate time format: HHmm where HH is 00-23 and mm is 00-59
							$hours = [int]$timeInput.Substring(0, 2)
							$minutes = [int]$timeInput.Substring(2, 2)
							
							# "0000" is midnight (12:00 AM), not "no end time"
							if ($newTime -ge 0 -and $newTime -le 2359 -and $hours -le 23 -and $minutes -le 59) {
								$result = $newTime
								break
							} else {
								# Invalid time - show error
								if ($hours -gt 23) {
									$errorMessage = "Hours out of range (00-23)"
								} elseif ($minutes -gt 59) {
									$errorMessage = "Minutes out of range (00-59)"
								} else {
									$errorMessage = "Time out of range (0000-2359)"
								}
								# Redraw input field with highlight - redraw entire line 4
								$fieldDisplay = $timeInput.PadRight(4)
								Write-Buffer -X $dialogX -Y $inputY -Text "$($script:BoxVertical)  " -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
								Write-Buffer -Text "[" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
								Write-Buffer -Text $fieldDisplay -FG $script:TimeDialogFieldText -BG $script:TimeDialogFieldBg
								Write-Buffer -Text "]" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
								$fieldUsedWidth = 3 + 6
								$fieldPadding = Get-Padding -usedWidth ($fieldUsedWidth + 1) -totalWidth $dialogWidth
								Write-Buffer -Text (" " * $fieldPadding) -BG $script:TimeDialogBg
								Write-Buffer -Text "$($script:BoxVertical)" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
								Write-Buffer -X $dialogX -Y ($dialogY + 5) -Text "$($script:BoxVertical)  " -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
								Write-Buffer -Text $errorMessage -FG $script:TextError -BG $script:TimeDialogBg
								$errorLineUsedWidth = 3 + $errorMessage.Length
								$errorLinePadding = Get-Padding -usedWidth ($errorLineUsedWidth + 1) -totalWidth $dialogWidth
								Write-Buffer -Text (" " * $errorLinePadding) -BG $script:TimeDialogBg
								Write-Buffer -Text "$($script:BoxVertical)" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
								Flush-Buffer
								[Console]::SetCursorPosition($inputX + 1 + $timeInput.Length, $inputY)
							}
						} catch {
							# Invalid input - show error (shouldn't normally happen with numeric-only input)
							$errorMessage = "Number out of range"
							# Redraw input field with highlight - redraw entire line 4
							$fieldDisplay = $timeInput.PadRight(4)
							Write-Buffer -X $dialogX -Y $inputY -Text "$($script:BoxVertical)  " -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
							Write-Buffer -Text "[" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
							Write-Buffer -Text $fieldDisplay -FG $script:TimeDialogFieldText -BG $script:TimeDialogFieldBg
							Write-Buffer -Text "]" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
							$fieldUsedWidth = 3 + 6
							$fieldPadding = Get-Padding -usedWidth ($fieldUsedWidth + 1) -totalWidth $dialogWidth
							Write-Buffer -Text (" " * $fieldPadding) -BG $script:TimeDialogBg
							Write-Buffer -Text "$($script:BoxVertical)" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
							Write-Buffer -X $dialogX -Y ($dialogY + 5) -Text "$($script:BoxVertical)  " -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
							Write-Buffer -Text $errorMessage -FG $script:TextError -BG $script:TimeDialogBg
							$errorLineUsedWidth = 3 + $errorMessage.Length
							$errorLinePadding = Get-Padding -usedWidth ($errorLineUsedWidth + 1) -totalWidth $dialogWidth
							Write-Buffer -Text (" " * $errorLinePadding) -BG $script:TimeDialogBg
							Write-Buffer -Text "$($script:BoxVertical)" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
							Flush-Buffer
							[Console]::SetCursorPosition($inputX + 1 + $timeInput.Length, $inputY)
						}
					} else {
						# Not 4 digits yet - show error
						$errorMessage = "Enter 4 digits (HHmm format)"
						# Redraw input field with highlight - redraw entire line 4
						$fieldDisplay = $timeInput.PadRight(4)
						Write-Buffer -X $dialogX -Y $inputY -Text "$($script:BoxVertical)  " -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
						Write-Buffer -Text "[" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
						Write-Buffer -Text $fieldDisplay -FG $script:TimeDialogFieldText -BG $script:TimeDialogFieldBg
						Write-Buffer -Text "]" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
						$fieldUsedWidth = 3 + 6
						$fieldPadding = Get-Padding -usedWidth ($fieldUsedWidth + 1) -totalWidth $dialogWidth
						Write-Buffer -Text (" " * $fieldPadding) -BG $script:TimeDialogBg
						Write-Buffer -Text "$($script:BoxVertical)" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
						Write-Buffer -X $dialogX -Y ($dialogY + 5) -Text "$($script:BoxVertical)  " -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
						Write-Buffer -Text $errorMessage -FG $script:TextError -BG $script:TimeDialogBg
						$errorLineUsedWidth = 3 + $errorMessage.Length
						$errorLinePadding = Get-Padding -usedWidth ($errorLineUsedWidth + 1) -totalWidth $dialogWidth
						Write-Buffer -Text (" " * $errorLinePadding) -BG $script:TimeDialogBg
						Write-Buffer -Text "$($script:BoxVertical)" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
						Flush-Buffer
						[Console]::SetCursorPosition($inputX + 1 + $timeInput.Length, $inputY)
					}
				} elseif ($char -eq "c" -or $char -eq "C" -or $char -eq "t" -or $char -eq "T" -or $key -eq "Escape" -or ($null -ne $keyInfo -and $keyInfo.VirtualKeyCode -eq 27)) {
					# Cancel (Escape key and 't' key also work as hidden functions)
					# Debug: Log time dialog cancel
				if ($DebugMode) {
				Add-DebugLogEntry -LogArray $LogArray -Message "Time dialog: Cancel clicked" -ShortMessage "Time: Cancel"
				}
					$result = $null
					$needsRedraw = $false  # No redraw needed on cancel
					break
				} elseif ($key -eq "Backspace" -or $char -eq [char]8 -or ($null -ne $keyInfo -and $keyInfo.VirtualKeyCode -eq 8)) {
					# Backspace - handle multiple ways to ensure it works
					# Ensure value is a string (in case it was somehow set as a char)
					$timeInput = $timeInput.ToString()
					if ($timeInput.Length -gt 0) {
						$timeInput = $timeInput.Substring(0, $timeInput.Length - 1)
						# If field is now empty, reset the input tracking so next char will clear again
						if ($timeInput.Length -eq 0) {
							$isFirstChar = $true
							$script:CursorVisible = $false; [Console]::Write("$($script:ESC)[?25l")
						}
						$errorMessage = ""  # Clear error when editing
						# Redraw input with highlight - redraw entire line 4 to ensure clean overwrite
						$fieldDisplay = $timeInput.PadRight(4)
						Write-Buffer -X $dialogX -Y $inputY -Text "$($script:BoxVertical)  " -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
						Write-Buffer -Text "[" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
						Write-Buffer -Text $fieldDisplay -FG $script:TimeDialogFieldText -BG $script:TimeDialogFieldBg
						Write-Buffer -Text "]" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
						$fieldUsedWidth = 3 + 6
						$fieldPadding = Get-Padding -usedWidth ($fieldUsedWidth + 1) -totalWidth $dialogWidth
						Write-Buffer -Text (" " * $fieldPadding) -BG $script:TimeDialogBg
						Write-Buffer -Text "$($script:BoxVertical)" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
						Write-Buffer -X $dialogX -Y ($dialogY + 5) -Text "$($script:BoxVertical)" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
						Write-Buffer -Text (" " * 33) -BG $script:TimeDialogBg
						Write-Buffer -Text "$($script:BoxVertical)" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
						Flush-Buffer
						# Position cursor at end of input (only if field has content, after opening bracket)
						if ($timeInput.Length -gt 0) {
							[Console]::SetCursorPosition($inputX + $timeInput.Length, $inputY)
						}
					}
				} elseif ($char -match "[0-9]") {
					# Numeric input
					# If this is the first character typed, clear the field first and show cursor
					if ($isFirstChar) {
						$timeInput = $char.ToString()  # Convert char to string
						$isFirstChar = $false
						$script:CursorVisible = $true; [Console]::Write("$($script:ESC)[?25h")
					} elseif ($timeInput.Length -lt 4) {
						$timeInput += $char.ToString()  # Convert char to string
					}
					$errorMessage = ""  # Clear error when typing
					# Redraw input field with highlight - redraw entire line 4 to ensure clean overwrite
					$fieldDisplay = $timeInput.PadRight(4)
					Write-Buffer -X $dialogX -Y $inputY -Text "$($script:BoxVertical)  " -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
					Write-Buffer -Text "[" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
					Write-Buffer -Text $fieldDisplay -FG $script:TimeDialogFieldText -BG $script:TimeDialogFieldBg
					Write-Buffer -Text "]" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
					$fieldUsedWidth = 3 + 6
					$fieldPadding = Get-Padding -usedWidth ($fieldUsedWidth + 1) -totalWidth $dialogWidth
					Write-Buffer -Text (" " * $fieldPadding) -BG $script:TimeDialogBg
					Write-Buffer -Text "$($script:BoxVertical)" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
					Write-Buffer -X $dialogX -Y ($dialogY + 5) -Text "$($script:BoxVertical)" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
					Write-Buffer -Text (" " * 33) -BG $script:TimeDialogBg
					Write-Buffer -Text "$($script:BoxVertical)" -FG $script:TimeDialogBorder -BG $script:TimeDialogBg
					Flush-Buffer
					[Console]::SetCursorPosition($inputX + $timeInput.Length, $inputY)
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
			
		Invoke-DialogExitCleanup -DialogX $dialogX -DialogY $dialogY -DialogWidth $dialogWidth -DialogHeight $dialogHeight -SavedCursorVisible $savedCursorVisible -ClearShadow
			return @{
				Result = $result
				NeedsRedraw = $needsRedraw
			}
		}
