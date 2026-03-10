		function Draw-DialogShadow {
			param(
				[int]$dialogX,
				[int]$dialogY,
				[int]$dialogWidth,
				[int]$dialogHeight,
				[string]$shadowColor = "DarkGray",
				[switch]$Clear
			)
			
			if ($Clear) {
				for ($i = 1; $i -le $dialogHeight; $i++) {
					Write-Buffer -X ($dialogX + $dialogWidth) -Y ($dialogY + $i) -Text " "
				}
				for ($i = 1; $i -le $dialogWidth; $i++) {
					Write-Buffer -X ($dialogX + $i) -Y ($dialogY + $dialogHeight + 1) -Text " "
				}
				Write-Buffer -X ($dialogX + $dialogWidth) -Y ($dialogY + $dialogHeight + 1) -Text " "
			} else {
				$shadowChar = [char]0x2591
				for ($i = 1; $i -le $dialogHeight; $i++) {
					Write-Buffer -X ($dialogX + $dialogWidth) -Y ($dialogY + $i) -Text "$shadowChar" -FG $shadowColor
				}
				for ($i = 1; $i -le $dialogWidth; $i++) {
					Write-Buffer -X ($dialogX + $i) -Y ($dialogY + $dialogHeight + 1) -Text "$shadowChar" -FG $shadowColor
				}
				Write-Buffer -X ($dialogX + $dialogWidth) -Y ($dialogY + $dialogHeight + 1) -Text "$shadowChar" -FG $shadowColor
			}
		}
