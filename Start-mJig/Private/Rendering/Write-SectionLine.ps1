		function Write-SectionLine {
			param(
				[int]$x,
				[int]$y,
				[int]$width,
				[string]$leftChar = "$($script:BoxVertical)",
				[string]$rightChar = "$($script:BoxVertical)",
				[string]$fillChar = " ",
				[System.ConsoleColor]$borderColor = [System.ConsoleColor]::White,
				[System.ConsoleColor]$fillColor = [System.ConsoleColor]::White
			)
			
			$fillWidth = $width - 2
			Write-Buffer -X $x -Y $y -Text $leftChar -FG $borderColor
			Write-Buffer -Text ($fillChar * $fillWidth) -FG $fillColor
			Write-Buffer -Text $rightChar -FG $borderColor
		}
