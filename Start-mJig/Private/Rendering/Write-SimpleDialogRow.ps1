		function Write-SimpleDialogRow {
			param(
				[int]$x,
				[int]$y,
				[int]$width,
				[string]$content = "",
				[System.ConsoleColor]$contentColor = [System.ConsoleColor]::White,
				[System.ConsoleColor]$backgroundColor = $null
			)
			
			$borderFG = if ($null -ne $backgroundColor) { $script:MoveDialogBorder } else { $null }
			Write-Buffer -X $x -Y $y -Text "$($script:BoxVertical)" -FG $borderFG -BG $backgroundColor
			if ($content.Length -gt 0) {
				Write-Buffer -Text " " -BG $backgroundColor
				Write-Buffer -Text $content -FG $contentColor -BG $backgroundColor
				$usedWidth = 1 + 1 + $content.Length
				$padding = Get-Padding -usedWidth ($usedWidth + 1) -totalWidth $width
				Write-Buffer -Text (" " * $padding) -BG $backgroundColor
			} else {
				Write-Buffer -Text (" " * ($width - 2)) -BG $backgroundColor
			}
			Write-Buffer -Text "$($script:BoxVertical)" -FG $borderFG -BG $backgroundColor
		}
