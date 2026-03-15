		function Write-SimpleFieldRow {
			param(
				[int]$X,
				[int]$Y,
				[int]$Width,
				[string]$Label,
				[int]$LongestLabel,
				[string]$FieldValue,
				[int]$FieldWidth,
				[int]$FieldIndex,
				[int]$CurrentFieldIndex,
				[System.ConsoleColor]$BackgroundColor = $null
			)
			
			$labelPadding = [Math]::Max(0, $LongestLabel - $Label.Length)
			$labelText = "$($script:BoxVertical)  " + $Label + (" " * $labelPadding)
			
			$fieldDisplay = if ([string]::IsNullOrEmpty($FieldValue)) { "" } else { $FieldValue }
			$fieldDisplay = $fieldDisplay.PadRight($FieldWidth)
			$fieldContent = "[" + $fieldDisplay + "]"
			
			$labelFG = if ($null -ne $BackgroundColor) { $script:MoveDialogText } else { $null }
			$borderFG = if ($null -ne $BackgroundColor) { $script:MoveDialogBorder } else { $null }
			$fieldFG = if ($FieldIndex -eq $CurrentFieldIndex) {
				if ($null -ne $BackgroundColor) { $script:MoveDialogFieldText } else { $script:TimeDialogFieldText }
			} else {
				$script:TextHighlight
			}
			$fieldBG = if ($FieldIndex -eq $CurrentFieldIndex) {
				if ($null -ne $BackgroundColor) { $script:MoveDialogFieldBg } else { $script:TimeDialogFieldBg }
			} else {
				$BackgroundColor
			}
			
			Write-Buffer -X $X -Y $Y -Text $labelText -FG $labelFG -BG $BackgroundColor
			Write-Buffer -Text "[" -FG $labelFG -BG $BackgroundColor
			Write-Buffer -Text $fieldDisplay -FG $fieldFG -BG $fieldBG
			Write-Buffer -Text "]" -FG $labelFG -BG $BackgroundColor
			$usedWidth = $labelText.Length + $fieldContent.Length
			$remainingPadding = Get-Padding -UsedWidth ($usedWidth + 1) -TotalWidth $Width
			Write-Buffer -Text (" " * $remainingPadding) -BG $BackgroundColor
			Write-Buffer -Text "$($script:BoxVertical)" -FG $borderFG -BG $BackgroundColor
		}
