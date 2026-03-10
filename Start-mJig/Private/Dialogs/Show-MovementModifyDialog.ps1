		function Show-MovementModifyDialog {
			param(
				[double]$currentIntervalSeconds,
				[double]$currentIntervalVariance,
				[double]$currentMoveSpeed,
				[double]$currentMoveVariance,
				[double]$currentTravelDistance,
				[double]$currentTravelVariance,
				[double]$currentAutoResumeDelaySeconds,
				[ref]$HostWidthRef,
				[ref]$HostHeightRef,
				[scriptblock]$ParentRedrawCallback = $null
			)
			
			$script:CurrentScreenState = "dialog-movement"

			# Get current host dimensions from references
			$currentHostWidth = $HostWidthRef.Value
			$currentHostHeight = $HostHeightRef.Value
			
			# Dialog dimensions - simplified (no description box)
			$dialogWidth = 30  # Width for parameters section (reduced by 20)
			$dialogHeight = 17  # Increased by 1 for new auto-resume delay field
			$dialogX = [math]::Max(0, [math]::Floor(($currentHostWidth - $dialogWidth) / 2))
			$dialogY = [math]::Max(0, [math]::Floor(($currentHostHeight - $dialogHeight) / 2))
			
			$savedCursorVisible = $script:CursorVisible
			$script:CursorVisible = $false
			[Console]::Write("$($script:ESC)[?25l")
			
			# Input field values
			$intervalSecondsInput = $currentIntervalSeconds.ToString()
			$intervalVarianceInput = $currentIntervalVariance.ToString()
			$moveSpeedInput = $currentMoveSpeed.ToString()
			$moveVarianceInput = $currentMoveVariance.ToString()
			$travelDistanceInput = $currentTravelDistance.ToString()
			$travelVarianceInput = $currentTravelVariance.ToString()
			$autoResumeDelaySecondsInput = $currentAutoResumeDelaySeconds.ToString()
			
			# Current field index (0-6)
			$currentField = 0
			$errorMessage = ""
			$lastFieldWithInput = -1  # Track which field last received input (to detect first character)
			
			# Field positions (Y coordinates relative to dialogY)
			$fieldYPositions = @(5, 6, 9, 10, 13, 14, 15)  # Y positions for each input field
			$fieldWidth = 6  # Width of input field (max 6 characters)
			# Calculate the longest label width for alignment
			$label1 = [Math]::Max("Interval (sec): ".Length, "Variance (sec): ".Length)
			$label2 = [Math]::Max("Distance (px): ".Length, "Variance (px): ".Length)
			$label3 = [Math]::Max($label1, $label2)
			$label4 = [Math]::Max($label3, "Speed (sec): ".Length)
			$longestLabel = [Math]::Max($label4, "Delay (sec): ".Length)
			$inputBoxStartX = 3 + $longestLabel  # "$($script:BoxVertical)  " + longest label = X position where all input boxes start
			
			# Draw dialog function - simplified (no description box)
			$drawDialog = {
				param($x, $y, $width, $height, $currentFieldIndex, $errorMsg, $inputBoxStartXPos, $fieldWidthValue, $intervalSec, $intervalVar, $moveSpeed, $moveVar, $travelDist, $travelDistVar, $autoResumeDelaySec)
				
				$fieldWidth = $fieldWidthValue
				
				# Calculate longest label for alignment
				$label1 = [Math]::Max("Interval (sec): ".Length, "Variance (sec): ".Length)
				$label2 = [Math]::Max("Distance (px): ".Length, "Variance (px): ".Length)
				$label3 = [Math]::Max($label1, $label2)
				$label4 = [Math]::Max($label3, "Speed (sec): ".Length)
				$longestLabel = [Math]::Max($label4, "Delay (sec): ".Length)
				
				# Define field data structure
				$fields = @(
					@{ Index = 0; Label = "Interval (sec): "; Value = $intervalSec },
					@{ Index = 1; Label = "Variance (sec): "; Value = $intervalVar },
					@{ Index = 2; Label = "Distance (px): "; Value = $travelDist },
					@{ Index = 3; Label = "Variance (px): "; Value = $travelDistVar },
					@{ Index = 4; Label = "Speed (sec): "; Value = $moveSpeed },
					@{ Index = 5; Label = "Variance (sec): "; Value = $moveVar },
					@{ Index = 6; Label = "Delay (sec): "; Value = $autoResumeDelaySec }
				)
				
			# Clear dialog area with themed background
			for ($i = 0; $i -lt $height; $i++) {
				Write-Buffer -X $x -Y ($y + $i) -Text (" " * $width) -BG $script:MoveDialogBg
			}
				
			# Top border (spans full width)
			Write-Buffer -X $x -Y $y -Text "$($script:BoxTopLeft)" -FG $script:MoveDialogBorder -BG $script:MoveDialogBg
			Write-Buffer -Text ("$($script:BoxHorizontal)" * ($width - 2)) -FG $script:MoveDialogBorder -BG $script:MoveDialogBg
			Write-Buffer -Text "$($script:BoxTopRight)" -FG $script:MoveDialogBorder -BG $script:MoveDialogBg
				
				# Title line
				Write-SimpleDialogRow -x $x -y ($y + 1) -width $width -content "Modify Movement Settings" -contentColor $script:MoveDialogTitle -backgroundColor $script:MoveDialogBg
				
				# Empty line (row 2)
				Write-SimpleDialogRow -x $x -y ($y + 2) -width $width -backgroundColor $script:MoveDialogBg
				
				# Interval section header (row 3)
				Write-SimpleDialogRow -x $x -y ($y + 3) -width $width -content "Interval:" -contentColor $script:MoveDialogSectionTitle -backgroundColor $script:MoveDialogBg
				
				# Interval fields (rows 4-5)
				Write-SimpleFieldRow -x $x -y ($y + 4) -width $width `
					-label $fields[0].Label -longestLabel $longestLabel -fieldValue $fields[0].Value `
					-fieldWidth $fieldWidth -fieldIndex $fields[0].Index -currentFieldIndex $currentFieldIndex -backgroundColor $script:MoveDialogBg
				
				Write-SimpleFieldRow -x $x -y ($y + 5) -width $width `
					-label $fields[1].Label -longestLabel $longestLabel -fieldValue $fields[1].Value `
					-fieldWidth $fieldWidth -fieldIndex $fields[1].Index -currentFieldIndex $currentFieldIndex -backgroundColor $script:MoveDialogBg
				
				# Travel Distance section header (row 6)
				Write-SimpleDialogRow -x $x -y ($y + 6) -width $width -content "Travel Distance:" -contentColor $script:MoveDialogSectionTitle -backgroundColor $script:MoveDialogBg
				
				# Travel Distance fields (rows 7-8)
				Write-SimpleFieldRow -x $x -y ($y + 7) -width $width `
					-label $fields[2].Label -longestLabel $longestLabel -fieldValue $fields[2].Value `
					-fieldWidth $fieldWidth -fieldIndex $fields[2].Index -currentFieldIndex $currentFieldIndex -backgroundColor $script:MoveDialogBg
				
				Write-SimpleFieldRow -x $x -y ($y + 8) -width $width `
					-label $fields[3].Label -longestLabel $longestLabel -fieldValue $fields[3].Value `
					-fieldWidth $fieldWidth -fieldIndex $fields[3].Index -currentFieldIndex $currentFieldIndex -backgroundColor $script:MoveDialogBg
				
				# Movement Speed section header (row 9)
				Write-SimpleDialogRow -x $x -y ($y + 9) -width $width -content "Movement Speed:" -contentColor $script:MoveDialogSectionTitle -backgroundColor $script:MoveDialogBg
				
				# Movement Speed fields (rows 10-11)
				Write-SimpleFieldRow -x $x -y ($y + 10) -width $width `
					-label $fields[4].Label -longestLabel $longestLabel -fieldValue $fields[4].Value `
					-fieldWidth $fieldWidth -fieldIndex $fields[4].Index -currentFieldIndex $currentFieldIndex -backgroundColor $script:MoveDialogBg
				
				Write-SimpleFieldRow -x $x -y ($y + 11) -width $width `
					-label $fields[5].Label -longestLabel $longestLabel -fieldValue $fields[5].Value `
					-fieldWidth $fieldWidth -fieldIndex $fields[5].Index -currentFieldIndex $currentFieldIndex -backgroundColor $script:MoveDialogBg
				
				# Auto-Resume Delay section header (row 12)
				Write-SimpleDialogRow -x $x -y ($y + 12) -width $width -content "Auto-Resume Delay:" -contentColor $script:MoveDialogSectionTitle -backgroundColor $script:MoveDialogBg
				
				# Auto-Resume Delay field (row 13)
				Write-SimpleFieldRow -x $x -y ($y + 13) -width $width `
					-label $fields[6].Label -longestLabel $longestLabel -fieldValue $fields[6].Value `
					-fieldWidth $fieldWidth -fieldIndex $fields[6].Index -currentFieldIndex $currentFieldIndex -backgroundColor $script:MoveDialogBg
				
				# Empty line (row 14)
				Write-SimpleDialogRow -x $x -y ($y + 14) -width $width -backgroundColor $script:MoveDialogBg
				
				# Error line (row 15)
				if ($errorMsg) {
					Write-SimpleDialogRow -x $x -y ($y + 15) -width $width -content $errorMsg -contentColor $script:TextError -backgroundColor $script:MoveDialogBg
				} else {
					Write-SimpleDialogRow -x $x -y ($y + 15) -width $width -backgroundColor $script:MoveDialogBg
				}
				
	# Bottom line with buttons (row 16)
	$checkmark = [char]::ConvertFromUtf32(0x2705)
	$redX = [char]::ConvertFromUtf32(0x274C)
$_dlgIW = if ($script:DialogButtonShowIcon)     { 2 + $script:DialogButtonSeparator.Length } else { 0 }
$_dlgBW = if ($script:DialogButtonShowBrackets) { 2 } else { 0 }
$_dlgPA = if ($script:DialogButtonShowHotkeyParens) { 0 } else { -2 }
$btn1X = $x + 2
$btn2X = $btn1X + $_dlgBW + $_dlgIW + 7 + $_dlgPA + 2  # bracket + icon + "(a)pply"(7) + gap(2)
# Button line: border+space(2) + btn1(bracketW+iconW+7) + gap(2) + btn2(bracketW+iconW+8) = 19 + 2*iconWidth + 2*bracketWidth
$buttonPadding = $width - (19 + 2 * $_dlgPA + 2 * $_dlgIW + 2 * $_dlgBW) - 1
Write-Buffer -X $x -Y ($y + 16) -Text "$($script:BoxVertical)" -FG $script:MoveDialogBorder -BG $script:MoveDialogBg
Write-Buffer -Text " " -BG $script:MoveDialogBg
if ($script:DialogButtonShowBrackets) {
	Write-Buffer -X $btn1X -Y ($y + 16) -Text "[" -FG $script:DialogButtonBracketFg -BG $script:DialogButtonBracketBg
}
$btn1ContentX = $btn1X + [int]$script:DialogButtonShowBrackets
if ($script:DialogButtonShowIcon) {
	Write-Buffer -X $btn1ContentX -Y ($y + 16) -Text $checkmark -FG $script:TextSuccess -BG $script:MoveDialogButtonBg -Wide
	Write-Buffer -X ($btn1ContentX + 2) -Y ($y + 16) -Text $script:DialogButtonSeparator -FG $script:MoveDialogButtonText -BG $script:MoveDialogButtonBg
} else {
	Write-Buffer -X $btn1ContentX -Y ($y + 16) -Text "" -BG $script:MoveDialogButtonBg
}
$_rp = if ($script:DialogButtonShowHotkeyParens) { ")" } else { "" }
if ($script:DialogButtonShowHotkeyParens) { Write-Buffer -Text "(" -FG $script:MoveDialogButtonText -BG $script:MoveDialogButtonBg }
Write-Buffer -Text "a" -FG $script:MoveDialogButtonHotkey -BG $script:MoveDialogButtonBg
Write-Buffer -Text "${_rp}pply" -FG $script:MoveDialogButtonText -BG $script:MoveDialogButtonBg
if ($script:DialogButtonShowBrackets) { Write-Buffer -Text "]" -FG $script:DialogButtonBracketFg -BG $script:DialogButtonBracketBg }
Write-Buffer -Text "  " -BG $script:MoveDialogBg
if ($script:DialogButtonShowBrackets) {
	Write-Buffer -X $btn2X -Y ($y + 16) -Text "[" -FG $script:DialogButtonBracketFg -BG $script:DialogButtonBracketBg
}
$btn2ContentX = $btn2X + [int]$script:DialogButtonShowBrackets
if ($script:DialogButtonShowIcon) {
	Write-Buffer -X $btn2ContentX -Y ($y + 16) -Text $redX -FG $script:TextError -BG $script:MoveDialogButtonBg -Wide
	Write-Buffer -X ($btn2ContentX + 2) -Y ($y + 16) -Text $script:DialogButtonSeparator -FG $script:MoveDialogButtonText -BG $script:MoveDialogButtonBg
} else {
	Write-Buffer -X $btn2ContentX -Y ($y + 16) -Text "" -BG $script:MoveDialogButtonBg
}
if ($script:DialogButtonShowHotkeyParens) { Write-Buffer -Text "(" -FG $script:MoveDialogButtonText -BG $script:MoveDialogButtonBg }
Write-Buffer -Text "c" -FG $script:MoveDialogButtonHotkey -BG $script:MoveDialogButtonBg
Write-Buffer -Text "${_rp}ancel" -FG $script:MoveDialogButtonText -BG $script:MoveDialogButtonBg
	if ($script:DialogButtonShowBrackets) { Write-Buffer -Text "]" -FG $script:DialogButtonBracketFg -BG $script:DialogButtonBracketBg }
	Write-Buffer -Text (" " * $buttonPadding) -BG $script:MoveDialogBg
	Write-Buffer -Text "$($script:BoxVertical)" -FG $script:MoveDialogBorder -BG $script:MoveDialogBg
				
			# Bottom border (spans full width)
			Write-Buffer -X $x -Y ($y + 17) -Text "$($script:BoxBottomLeft)" -FG $script:MoveDialogBorder -BG $script:MoveDialogBg
			Write-Buffer -Text ("$($script:BoxHorizontal)" * ($width - 2)) -FG $script:MoveDialogBorder -BG $script:MoveDialogBg
			Write-Buffer -Text "$($script:BoxBottomRight)" -FG $script:MoveDialogBorder -BG $script:MoveDialogBg
				
				# Draw drop shadow
				Draw-DialogShadow -dialogX $x -dialogY $y -dialogWidth $width -dialogHeight $height -shadowColor $script:MoveDialogShadow
			}
			
		# Initial draw
		& $drawDialog $dialogX $dialogY $dialogWidth $dialogHeight $currentField $errorMessage $inputBoxStartX $fieldWidth $intervalSecondsInput $intervalVarianceInput $moveSpeedInput $moveVarianceInput $travelDistanceInput $travelVarianceInput $autoResumeDelaySecondsInput
		Flush-Buffer
		
	# Calculate button bounds for click detection
	# Button row is at dialogY + 16 (row 16)
	$buttonRowY = $dialogY + 16
$_moveDlgIW = if ($script:DialogButtonShowIcon)     { 2 + $script:DialogButtonSeparator.Length } else { 0 }
$_moveDlgBW = if ($script:DialogButtonShowBrackets) { 2 } else { 0 }
$_moveDlgPA = if ($script:DialogButtonShowHotkeyParens) { 0 } else { -2 }
$updateButtonStartX = $dialogX + 2
$updateButtonEndX   = $dialogX + 2 + $_moveDlgBW + $_moveDlgIW + 7 + $_moveDlgPA - 1   # bracket + icon + "(a)pply"(7) - 1 inclusive
$cancelButtonStartX = $dialogX + 2 + $_moveDlgBW + $_moveDlgIW + 7 + $_moveDlgPA + 2   # after btn1 + gap(2)
$cancelButtonEndX   = $cancelButtonStartX + $_moveDlgBW + $_moveDlgIW + 8 + $_moveDlgPA - 1  # bracket + icon + "(c)ancel"(8) - 1 inclusive
			
			# Store button bounds in script scope for main loop click detection
			$script:DialogButtonBounds = @{
				buttonRowY = $buttonRowY
				updateStartX = $updateButtonStartX
				updateEndX = $updateButtonEndX
				cancelStartX = $cancelButtonStartX
				cancelEndX = $cancelButtonEndX
			}
			$script:DialogButtonClick = $null  # Clear any previous click  # 19 + 2 (emoji) + 1 (pipe) + 8 (text) - 1 (inclusive)
			
			# Position cursor at the first field after initial draw (ready for input)
			$fieldYOffsets = @(4, 5, 7, 8, 10, 11, 13)  # Y offsets for each field relative to dialogY
			$fieldY = $dialogY + $fieldYOffsets[$currentField]
			# Get the current field's input value
			$currentInputRef = switch ($currentField) {
				0 { [ref]$intervalSecondsInput }
				1 { [ref]$intervalVarianceInput }
				2 { [ref]$travelDistanceInput }
				3 { [ref]$travelVarianceInput }
				4 { [ref]$moveSpeedInput }
				5 { [ref]$moveVarianceInput }
				6 { [ref]$autoResumeDelaySecondsInput }
			}
			# Cursor X: dialogX + inputBoxStartX + 1 (for opening bracket) + length of actual value
			$cursorX = $dialogX + $inputBoxStartX + 1 + $currentInputRef.Value.Length
			[Console]::SetCursorPosition($cursorX, $fieldY)
			$result = $null
			$needsRedraw = $false
			
		if ($DebugMode) {
			Add-DebugLogEntry -LogArray $LogArray -Message "Movement dialog input loop started, button row Y: $buttonRowY" -ShortMessage "Dialog started"
		}
			
			:inputLoop do {
				# Check for window resize
				$pshost = Get-Host
				$pswindow = $pshost.UI.RawUI
				$newWindowSize = $pswindow.WindowSize
				if ($newWindowSize.Width -ne $currentHostWidth -or $newWindowSize.Height -ne $currentHostHeight) {
					$stableSize = Invoke-ResizeHandler -PreviousScreenState "dialog-movement"
					$HostWidthRef.Value  = $stableSize.Width
					$HostHeightRef.Value = $stableSize.Height
					$currentHostWidth  = $stableSize.Width
					$currentHostHeight = $stableSize.Height
					Draw-MainFrame -Force -NoFlush
					if ($null -ne $ParentRedrawCallback) {
						& $ParentRedrawCallback $currentHostWidth $currentHostHeight
					}
					$needsRedraw = $true
					$dialogX = [math]::Max(0, [math]::Floor(($currentHostWidth - $dialogWidth) / 2))
					$dialogY = [math]::Max(0, [math]::Floor(($currentHostHeight - $dialogHeight) / 2))
					
			# Recalculate button bounds after repositioning
			$buttonRowY = $dialogY + 16
			$_moveDlgIW = if ($script:DialogButtonShowIcon)     { 2 + $script:DialogButtonSeparator.Length } else { 0 }
			$_moveDlgBW = if ($script:DialogButtonShowBrackets) { 2 } else { 0 }
		$updateButtonStartX = $dialogX + 2
		$updateButtonEndX   = $dialogX + 2 + $_moveDlgBW + $_moveDlgIW + 7 - 1
		$cancelButtonStartX = $dialogX + 2 + $_moveDlgBW + $_moveDlgIW + 7 + 2
		$cancelButtonEndX   = $cancelButtonStartX + $_moveDlgBW + $_moveDlgIW + 8 - 1
					
					# Update button bounds in script scope
					$script:DialogButtonBounds = @{
						buttonRowY = $buttonRowY
						updateStartX = $updateButtonStartX
						updateEndX = $updateButtonEndX
						cancelStartX = $cancelButtonStartX
						cancelEndX = $cancelButtonEndX
					}
					
				& $drawDialog $dialogX $dialogY $dialogWidth $dialogHeight $currentField $errorMessage $inputBoxStartX $fieldWidth $intervalSecondsInput $intervalVarianceInput $moveSpeedInput $moveVarianceInput $travelDistanceInput $travelVarianceInput $autoResumeDelaySecondsInput
				Flush-Buffer -ClearFirst
				# Position cursor at the active field after resize
					$fieldYOffsets = @(4, 5, 7, 8, 10, 11, 13)  # Y offsets for each field relative to dialogY
					$fieldY = $dialogY + $fieldYOffsets[$currentField]
					$currentInputRef = switch ($currentField) {
						0 { [ref]$intervalSecondsInput }
						1 { [ref]$intervalVarianceInput }
						2 { [ref]$travelDistanceInput }
						3 { [ref]$travelVarianceInput }
						4 { [ref]$moveSpeedInput }
						5 { [ref]$moveVarianceInput }
						6 { [ref]$autoResumeDelaySecondsInput }
					}
					$cursorX = $dialogX + $inputBoxStartX + 1 + $currentInputRef.Value.Length
					[Console]::SetCursorPosition($cursorX, $fieldY)
				}
				
				# Check for mouse button clicks on dialog buttons/fields via console input buffer
				$keyProcessed = $false
				$keyInfo = $null
				$key = $null
				$char = $null
				
			$_click = Get-DialogMouseClick -PeekBuffer $script:_DialogPeekBuffer
			if ($null -ne $_click) {
				$clickX = $_click.X; $clickY = $_click.Y
				$clickedField = -1
				if ($clickX -lt $dialogX -or $clickX -ge ($dialogX + $dialogWidth) -or $clickY -lt $dialogY -or $clickY -gt ($dialogY + $dialogHeight)) {
					$char = "c"; $keyProcessed = $true
				} elseif ($clickY -eq $buttonRowY -and $clickX -ge $updateButtonStartX -and $clickX -le $updateButtonEndX) {
					$char = "a"; $keyProcessed = $true
				} elseif ($clickY -eq $buttonRowY -and $clickX -ge $cancelButtonStartX -and $clickX -le $cancelButtonEndX) {
					$char = "c"; $keyProcessed = $true
				}
				if (-not $keyProcessed -and $clickX -ge $dialogX -and $clickX -lt ($dialogX + $dialogWidth)) {
					$clickFieldYOffsets = @(4, 5, 7, 8, 10, 11, 13)
					for ($fi = 0; $fi -lt $clickFieldYOffsets.Count; $fi++) {
						$fy = $dialogY + $clickFieldYOffsets[$fi]
						if ($clickY -eq $fy) {
							$clickedField = $fi
							break
						}
					}
					if ($clickedField -ge 0 -and $clickedField -ne $currentField) {
						$previousField = $currentField
						$currentField = $clickedField
						$errorMessage = ""
						$lastFieldWithInput = -1
						
						$fieldLabels = @("Interval (sec): ", "Variance (sec): ", "Distance (px): ", "Variance (px): ", "Speed (sec): ", "Variance (sec): ", "Delay (sec): ")
						$fieldValues = @($intervalSecondsInput, $intervalVarianceInput, $travelDistanceInput, $travelVarianceInput, $moveSpeedInput, $moveVarianceInput, $autoResumeDelaySecondsInput)
						
						Write-SimpleFieldRow -x $dialogX -y ($dialogY + $clickFieldYOffsets[$previousField]) -width $dialogWidth `
							-label $fieldLabels[$previousField] -longestLabel $longestLabel -fieldValue $fieldValues[$previousField] `
							-fieldWidth $fieldWidth -fieldIndex $previousField -currentFieldIndex $currentField -backgroundColor DarkBlue
						
						Write-SimpleFieldRow -x $dialogX -y ($dialogY + $clickFieldYOffsets[$currentField]) -width $dialogWidth `
							-label $fieldLabels[$currentField] -longestLabel $longestLabel -fieldValue $fieldValues[$currentField] `
							-fieldWidth $fieldWidth -fieldIndex $currentField -currentFieldIndex $currentField -backgroundColor DarkBlue
						Flush-Buffer
						
						$fieldY = $dialogY + $clickFieldYOffsets[$currentField]
						$currentInputRef = switch ($currentField) {
							0 { [ref]$intervalSecondsInput }
							1 { [ref]$intervalVarianceInput }
							2 { [ref]$travelDistanceInput }
							3 { [ref]$travelVarianceInput }
							4 { [ref]$moveSpeedInput }
							5 { [ref]$moveVarianceInput }
							6 { [ref]$autoResumeDelaySecondsInput }
						}
						$cursorX = $dialogX + $inputBoxStartX + 1 + $currentInputRef.Value.Length
						[Console]::SetCursorPosition($cursorX, $fieldY)
						$keyProcessed = $true
					}
				}
				if ($DebugMode) {
					$clickTarget = "none"
					if ($keyProcessed -and $char) { $clickTarget = "button:$char" }
					elseif ($clickedField -ge 0) { $clickTarget = "field:$clickedField" }
					Add-DebugLogEntry -LogArray $LogArray -Message "Movement dialog click at ($clickX,$clickY), target: $clickTarget" -ShortMessage "Click ($clickX,$clickY) -> $clickTarget"
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
					Start-Sleep -Milliseconds 50
					continue
				}
				
				# Get current field input string reference
				$currentInputRef = switch ($currentField) {
					0 { [ref]$intervalSecondsInput }
					1 { [ref]$intervalVarianceInput }
					2 { [ref]$travelDistanceInput }      # Travel Distance (swapped)
					3 { [ref]$travelVarianceInput }  # Travel Variance (swapped)
					4 { [ref]$moveSpeedInput }           # Move Speed (swapped)
					5 { [ref]$moveVarianceInput }        # Move Variance (swapped)
					6 { [ref]$autoResumeDelaySecondsInput }  # Auto-Resume Delay
				}
				
			if ($char -eq "a" -or $char -eq "A" -or $key -eq "Enter" -or $char -eq [char]13 -or $char -eq [char]10) {
				# Apply - validate and save all values
				if ($DebugMode) {
					Add-DebugLogEntry -LogArray $LogArray -Message "Movement dialog: Update clicked" -ShortMessage "Movement: Update"
				}
					$errorMessage = ""
					try {
						$newIntervalSeconds = [double]$intervalSecondsInput
						$newIntervalVariance = [double]$intervalVarianceInput
						$newMoveSpeed = [double]$moveSpeedInput
						$newMoveVariance = [double]$moveVarianceInput
						$newTravelDistance = [double]$travelDistanceInput
						$newTravelVariance = [double]$travelVarianceInput
						$newAutoResumeDelaySeconds = [double]$autoResumeDelaySecondsInput
						
						# Validate ranges
						if ($newIntervalSeconds -le 0) {
							$errorMessage = "Interval must be greater than 0"
						} elseif ($newIntervalVariance -lt 0) {
							$errorMessage = "Interval variance must be >= 0"
						} elseif ($newMoveSpeed -le 0) {
							$errorMessage = "Move speed must be greater than 0"
						} elseif ($newMoveVariance -lt 0) {
							$errorMessage = "Move variance must be >= 0"
						} elseif ($newTravelDistance -le 0) {
							$errorMessage = "Travel distance must be greater than 0"
						} elseif ($newTravelVariance -lt 0) {
							$errorMessage = "Travel variance must be >= 0"
						} elseif ($newAutoResumeDelaySeconds -lt 0) {
							$errorMessage = "Auto-resume delay must be >= 0"
						}
						
						if (-not $errorMessage) {
							$result = @{
								IntervalSeconds = $newIntervalSeconds
								IntervalVariance = $newIntervalVariance
								MoveSpeed = $newMoveSpeed
								MoveVariance = $newMoveVariance
								TravelDistance = $newTravelDistance
								TravelVariance = $newTravelVariance
								AutoResumeDelaySeconds = $newAutoResumeDelaySeconds
							}
							break
						}
					} catch {
						$errorMessage = "Invalid number format"
					}
				& $drawDialog $dialogX $dialogY $dialogWidth $dialogHeight $currentField $errorMessage $inputBoxStartX $fieldWidth $intervalSecondsInput $intervalVarianceInput $moveSpeedInput $moveVarianceInput $travelDistanceInput $travelVarianceInput $autoResumeDelaySecondsInput
				Flush-Buffer
			} elseif ($char -eq "c" -or $char -eq "C" -or $char -eq "t" -or $char -eq "T" -or $key -eq "Escape" -or ($null -ne $keyInfo -and $keyInfo.VirtualKeyCode -eq 27)) {
					# Cancel
				if ($DebugMode) {
					Add-DebugLogEntry -LogArray $LogArray -Message "Movement dialog: Cancel clicked" -ShortMessage "Movement: Cancel"
				}
					$result = $null
					$needsRedraw = $false
					break
				} elseif ($char -eq "m" -or $char -eq "M") {
					# Hidden option: Close dialog with 'm' key
					$result = $null
					$needsRedraw = $false
					break
				} elseif ($key -eq "Tab" -or ($null -ne $keyInfo -and $keyInfo.VirtualKeyCode -eq 9)) {
					# Tab - check if Shift is pressed for reverse tab
					# Use Windows API to check if Shift keys are currently pressed (more reliable than ControlKeyState)
					$VK_LSHIFT = 0xA0  # Left Shift virtual key code
					$VK_RSHIFT = 0xA1  # Right Shift virtual key code
					$isShiftPressed = $false
					try {
						$shiftState = [mJiggAPI.Mouse]::GetAsyncKeyState($VK_LSHIFT) -bor [mJiggAPI.Mouse]::GetAsyncKeyState($VK_RSHIFT)
						$isShiftPressed = (($shiftState -band 0x8000) -ne 0)
					} catch {
						# Fallback to ControlKeyState if API call fails
						if ($null -ne $keyInfo.ControlKeyState) {
							$isShiftPressed = (($keyInfo.ControlKeyState -band 4) -ne 0) -or 
											   (($keyInfo.ControlKeyState -band 1) -ne 0) -or 
											   (($keyInfo.ControlKeyState -band 2) -ne 0)
						}
					}
					if ($isShiftPressed) {
						# Shift+Tab - move to previous field
						$currentField = ($currentField - 1 + 7) % 7
					} else {
						# Tab - move to next field
						$currentField = ($currentField + 1) % 7
					}
					$errorMessage = ""
					$lastFieldWithInput = -1  # Reset input tracking when switching fields
			& $drawDialog $dialogX $dialogY $dialogWidth $dialogHeight $currentField $errorMessage $inputBoxStartX $fieldWidth $intervalSecondsInput $intervalVarianceInput $moveSpeedInput $moveVarianceInput $travelDistanceInput $travelVarianceInput $autoResumeDelaySecondsInput
				Flush-Buffer
				# Position cursor at the active field after tab navigation
					$fieldYOffsets = @(4, 5, 7, 8, 10, 11, 13)  # Y offsets for each field relative to dialogY
					$fieldY = $dialogY + $fieldYOffsets[$currentField]
					$currentInputRef = switch ($currentField) {
						0 { [ref]$intervalSecondsInput }
						1 { [ref]$intervalVarianceInput }
						2 { [ref]$travelDistanceInput }
						3 { [ref]$travelVarianceInput }
						4 { [ref]$moveSpeedInput }
						5 { [ref]$moveVarianceInput }
						6 { [ref]$autoResumeDelaySecondsInput }
					}
					$cursorX = $dialogX + $inputBoxStartX + 1 + $currentInputRef.Value.Length
					[Console]::SetCursorPosition($cursorX, $fieldY)
				} elseif ($key -eq "Backspace" -or $char -eq [char]8 -or ($null -ne $keyInfo -and $keyInfo.VirtualKeyCode -eq 8)) {
					# Backspace
					# Ensure value is a string (in case it was somehow set as a char)
					$currentInputRef.Value = $currentInputRef.Value.ToString()
					if ($currentInputRef.Value.Length -gt 0) {
						$currentInputRef.Value = $currentInputRef.Value.Substring(0, $currentInputRef.Value.Length - 1)
						# If field is now empty, reset the input tracking so next char will clear again
						if ($currentInputRef.Value.Length -eq 0) {
							$lastFieldWithInput = -1
							$script:CursorVisible = $false; [Console]::Write("$($script:ESC)[?25l")
						}
						$errorMessage = ""
						# Optimized: only redraw current field instead of entire dialog
						$fieldYOffsets = @(4, 5, 7, 8, 10, 11, 13)
						$fieldLabels = @("Interval (sec): ", "Variance (sec): ", "Distance (px): ", "Variance (px): ", "Speed (sec): ", "Variance (sec): ", "Delay (sec): ")
					Write-SimpleFieldRow -x $dialogX -y ($dialogY + $fieldYOffsets[$currentField]) -width $dialogWidth `
						-label $fieldLabels[$currentField] -longestLabel $longestLabel -fieldValue $currentInputRef.Value `
						-fieldWidth $fieldWidth -fieldIndex $currentField -currentFieldIndex $currentField -backgroundColor DarkBlue
					Flush-Buffer
					# Position cursor at end of input
					$fieldY = $dialogY + $fieldYOffsets[$currentField]
					$cursorX = $dialogX + $inputBoxStartX + 1 + $currentInputRef.Value.Length
					[Console]::SetCursorPosition($cursorX, $fieldY)
				}
			} elseif ($char -match "[0-9]") {
					# Numeric input - limit to 6 characters
					# If this is the first character typed in this field, clear the field first
					$isFirstChar = ($lastFieldWithInput -ne $currentField)
					if ($isFirstChar) {
						$currentInputRef.Value = $char.ToString()  # Convert char to string
						$lastFieldWithInput = $currentField
						$script:CursorVisible = $true; [Console]::Write("$($script:ESC)[?25h")
					} elseif ($currentInputRef.Value.Length -lt 6) {
						$currentInputRef.Value += $char.ToString()  # Convert char to string
					}
					$errorMessage = ""
					# Optimized: only redraw current field instead of entire dialog
					$fieldYOffsets = @(4, 5, 7, 8, 10, 11, 13)
					$fieldLabels = @("Interval (sec): ", "Variance (sec): ", "Distance (px): ", "Variance (px): ", "Speed (sec): ", "Variance (sec): ", "Delay (sec): ")
				Write-SimpleFieldRow -x $dialogX -y ($dialogY + $fieldYOffsets[$currentField]) -width $dialogWidth `
					-label $fieldLabels[$currentField] -longestLabel $longestLabel -fieldValue $currentInputRef.Value `
					-fieldWidth $fieldWidth -fieldIndex $currentField -currentFieldIndex $currentField -backgroundColor DarkBlue
				Flush-Buffer
				# Position cursor at end of input
				$fieldY = $dialogY + $fieldYOffsets[$currentField]
				$cursorX = $dialogX + $inputBoxStartX + 1 + $currentInputRef.Value.Length
				[Console]::SetCursorPosition($cursorX, $fieldY)
			} elseif ($char -eq ".") {
					# Decimal point for all fields - limit to 6 characters (including decimal point)
					# If this is the first character typed in this field, clear the field first
					$isFirstChar = ($lastFieldWithInput -ne $currentField)
					if ($isFirstChar) {
						$currentInputRef.Value = "."  # Already a string
						$lastFieldWithInput = $currentField
						$script:CursorVisible = $true; [Console]::Write("$($script:ESC)[?25h")
					} elseif ($currentInputRef.Value -notmatch "\." -and $currentInputRef.Value.Length -lt 6) {
						$currentInputRef.Value += "."  # Already a string
					}
					$errorMessage = ""
					# Optimized: only redraw current field instead of entire dialog
					$fieldYOffsets = @(4, 5, 7, 8, 10, 11, 13)
					$fieldLabels = @("Interval (sec): ", "Variance (sec): ", "Distance (px): ", "Variance (px): ", "Speed (sec): ", "Variance (sec): ", "Delay (sec): ")
				Write-SimpleFieldRow -x $dialogX -y ($dialogY + $fieldYOffsets[$currentField]) -width $dialogWidth `
					-label $fieldLabels[$currentField] -longestLabel $longestLabel -fieldValue $currentInputRef.Value `
					-fieldWidth $fieldWidth -fieldIndex $currentField -currentFieldIndex $currentField -backgroundColor DarkBlue
				Flush-Buffer
				# Position cursor at end of input
				$fieldY = $dialogY + $fieldYOffsets[$currentField]
				$cursorX = $dialogX + $inputBoxStartX + 1 + $currentInputRef.Value.Length
				[Console]::SetCursorPosition($cursorX, $fieldY)
			} elseif ($key -eq "UpArrow" -or ($null -ne $keyInfo -and $keyInfo.VirtualKeyCode -eq 38)) {
					# UpArrow - move to previous field (reverse tab)
					$previousField = $currentField
					$currentField = ($currentField - 1 + 7) % 7
					$errorMessage = ""
					$lastFieldWithInput = -1  # Reset input tracking when switching fields
					
					# Optimized redraw: only update the two affected field rows instead of entire dialog
					$fieldYOffsets = @(4, 5, 7, 8, 10, 11, 13)  # Y offsets for each field relative to dialogY
					$fieldLabels = @("Interval (sec): ", "Variance (sec): ", "Distance (px): ", "Variance (px): ", "Speed (sec): ", "Variance (sec): ", "Delay (sec): ")
					$fieldValues = @($intervalSecondsInput, $intervalVarianceInput, $travelDistanceInput, $travelVarianceInput, $moveSpeedInput, $moveVarianceInput, $autoResumeDelaySecondsInput)
					
					# Redraw previous field (unhighlight)
					Write-SimpleFieldRow -x $dialogX -y ($dialogY + $fieldYOffsets[$previousField]) -width $dialogWidth `
						-label $fieldLabels[$previousField] -longestLabel $longestLabel -fieldValue $fieldValues[$previousField] `
						-fieldWidth $fieldWidth -fieldIndex $previousField -currentFieldIndex $currentField -backgroundColor DarkBlue
					
				# Redraw new field (highlight)
				Write-SimpleFieldRow -x $dialogX -y ($dialogY + $fieldYOffsets[$currentField]) -width $dialogWidth `
					-label $fieldLabels[$currentField] -longestLabel $longestLabel -fieldValue $fieldValues[$currentField] `
					-fieldWidth $fieldWidth -fieldIndex $currentField -currentFieldIndex $currentField -backgroundColor DarkBlue
				Flush-Buffer
				
				# Position cursor at the active field after arrow navigation
				$fieldY = $dialogY + $fieldYOffsets[$currentField]
				$currentInputRef = switch ($currentField) {
					0 { [ref]$intervalSecondsInput }
					1 { [ref]$intervalVarianceInput }
					2 { [ref]$travelDistanceInput }
					3 { [ref]$travelVarianceInput }
					4 { [ref]$moveSpeedInput }
					5 { [ref]$moveVarianceInput }
					6 { [ref]$autoResumeDelaySecondsInput }
				}
				$cursorX = $dialogX + $inputBoxStartX + 1 + $currentInputRef.Value.Length
				[Console]::SetCursorPosition($cursorX, $fieldY)
			} elseif ($key -eq "DownArrow" -or ($null -ne $keyInfo -and $keyInfo.VirtualKeyCode -eq 40)) {
					# DownArrow - move to next field (forward tab)
					$previousField = $currentField
					$currentField = ($currentField + 1) % 7
					$errorMessage = ""
					$lastFieldWithInput = -1  # Reset input tracking when switching fields
					
					# Optimized redraw: only update the two affected field rows instead of entire dialog
					$fieldYOffsets = @(4, 5, 7, 8, 10, 11, 13)  # Y offsets for each field relative to dialogY
					$fieldLabels = @("Interval (sec): ", "Variance (sec): ", "Distance (px): ", "Variance (px): ", "Speed (sec): ", "Variance (sec): ", "Delay (sec): ")
					$fieldValues = @($intervalSecondsInput, $intervalVarianceInput, $travelDistanceInput, $travelVarianceInput, $moveSpeedInput, $moveVarianceInput, $autoResumeDelaySecondsInput)
					
					# Redraw previous field (unhighlight)
					Write-SimpleFieldRow -x $dialogX -y ($dialogY + $fieldYOffsets[$previousField]) -width $dialogWidth `
						-label $fieldLabels[$previousField] -longestLabel $longestLabel -fieldValue $fieldValues[$previousField] `
						-fieldWidth $fieldWidth -fieldIndex $previousField -currentFieldIndex $currentField -backgroundColor DarkBlue
					
				# Redraw new field (highlight)
				Write-SimpleFieldRow -x $dialogX -y ($dialogY + $fieldYOffsets[$currentField]) -width $dialogWidth `
					-label $fieldLabels[$currentField] -longestLabel $longestLabel -fieldValue $fieldValues[$currentField] `
					-fieldWidth $fieldWidth -fieldIndex $currentField -currentFieldIndex $currentField -backgroundColor DarkBlue
				Flush-Buffer
				
				# Position cursor at the active field after arrow navigation
				$fieldY = $dialogY + $fieldYOffsets[$currentField]
				$currentInputRef = switch ($currentField) {
					0 { [ref]$intervalSecondsInput }
					1 { [ref]$intervalVarianceInput }
					2 { [ref]$travelDistanceInput }
					3 { [ref]$travelVarianceInput }
					4 { [ref]$moveSpeedInput }
					5 { [ref]$moveVarianceInput }
					6 { [ref]$autoResumeDelaySecondsInput }
				}
				$cursorX = $dialogX + $inputBoxStartX + 1 + $currentInputRef.Value.Length
				[Console]::SetCursorPosition($cursorX, $fieldY)
			}
			
			# Clear any remaining keys in buffer
				try {
					while ($Host.UI.RawUI.KeyAvailable) {
						$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown,AllowCtrlC")
					}
				} catch {
					# Silently ignore
				}
			} until ($false)
			
		Invoke-DialogExitCleanup -DialogX $dialogX -DialogY $dialogY -DialogWidth $dialogWidth -DialogHeight $dialogHeight -SavedCursorVisible $savedCursorVisible -ClearShadow
			# Return result object
			return @{
				Result = $result
				NeedsRedraw = $needsRedraw
			}
		}
