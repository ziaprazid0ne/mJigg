		function Write-SimpleFieldRow {
			param(
				[int]$x,
				[int]$y,
				[int]$width,
				[string]$label,
				[int]$longestLabel,
				[string]$fieldValue,
				[int]$fieldWidth,
				[int]$fieldIndex,
				[int]$currentFieldIndex,
				[System.ConsoleColor]$backgroundColor = $null
			)
			
			$labelPadding = [Math]::Max(0, $longestLabel - $label.Length)
			$labelText = "$($script:BoxVertical)  " + $label + (" " * $labelPadding)
			
			$fieldDisplay = if ([string]::IsNullOrEmpty($fieldValue)) { "" } else { $fieldValue }
			$fieldDisplay = $fieldDisplay.PadRight($fieldWidth)
			$fieldContent = "[" + $fieldDisplay + "]"
			
			$labelFG = if ($null -ne $backgroundColor) { $script:MoveDialogText } else { $null }
			$borderFG = if ($null -ne $backgroundColor) { $script:MoveDialogBorder } else { $null }
			$fieldFG = if ($fieldIndex -eq $currentFieldIndex) {
				if ($null -ne $backgroundColor) { $script:MoveDialogFieldText } else { $script:TimeDialogFieldText }
			} else {
				$script:TextHighlight
			}
			$fieldBG = if ($fieldIndex -eq $currentFieldIndex) {
				if ($null -ne $backgroundColor) { $script:MoveDialogFieldBg } else { $script:TimeDialogFieldBg }
			} else {
				$backgroundColor
			}
			
			Write-Buffer -X $x -Y $y -Text $labelText -FG $labelFG -BG $backgroundColor
			Write-Buffer -Text "[" -FG $labelFG -BG $backgroundColor
			Write-Buffer -Text $fieldDisplay -FG $fieldFG -BG $fieldBG
			Write-Buffer -Text "]" -FG $labelFG -BG $backgroundColor
			$usedWidth = $labelText.Length + $fieldContent.Length
			$remainingPadding = Get-Padding -usedWidth ($usedWidth + 1) -totalWidth $width
			Write-Buffer -Text (" " * $remainingPadding) -BG $backgroundColor
			Write-Buffer -Text "$($script:BoxVertical)" -FG $borderFG -BG $backgroundColor
		}
