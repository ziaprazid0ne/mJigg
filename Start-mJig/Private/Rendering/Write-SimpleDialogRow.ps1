		function Write-SimpleDialogRow {
			param(
				[int]$X,
				[int]$Y,
				[int]$Width,
				[string]$Content = "",
				[System.ConsoleColor]$ContentColor = [System.ConsoleColor]::White,
				[System.ConsoleColor]$BackgroundColor = $null
			)
			
			$borderFG = if ($null -ne $BackgroundColor) { $script:MoveDialogBorder } else { $null }
			Write-Buffer -X $X -Y $Y -Text "$($script:BoxVertical)" -FG $borderFG -BG $BackgroundColor
			if ($Content.Length -gt 0) {
				Write-Buffer -Text " " -BG $BackgroundColor
				Write-Buffer -Text $Content -FG $ContentColor -BG $BackgroundColor
				$usedWidth = 1 + 1 + $Content.Length
				$padding = Get-Padding -UsedWidth ($usedWidth + 1) -TotalWidth $Width
				Write-Buffer -Text (" " * $padding) -BG $BackgroundColor
			} else {
				Write-Buffer -Text (" " * ($Width - 2)) -BG $BackgroundColor
			}
			Write-Buffer -Text "$($script:BoxVertical)" -FG $borderFG -BG $BackgroundColor
		}
