		function Write-SectionLine {
			param(
				[int]$X,
				[int]$Y,
				[int]$Width,
				[string]$LeftChar = "$($script:BoxVertical)",
				[string]$RightChar = "$($script:BoxVertical)",
				[string]$FillChar = " ",
				[System.ConsoleColor]$BorderColor = [System.ConsoleColor]::White,
				[System.ConsoleColor]$FillColor = [System.ConsoleColor]::White
			)
			
			$fillWidth = $Width - 2
			Write-Buffer -X $X -Y $Y -Text $LeftChar -FG $BorderColor
			Write-Buffer -Text ($FillChar * $fillWidth) -FG $FillColor
			Write-Buffer -Text $RightChar -FG $BorderColor
		}
