		function Clear-DialogShadow {
			param(
				[int]$dialogX,
				[int]$dialogY,
				[int]$dialogWidth,
				[int]$dialogHeight
			)
			
			for ($i = 1; $i -le $dialogHeight; $i++) {
				Write-Buffer -X ($dialogX + $dialogWidth) -Y ($dialogY + $i) -Text " "
			}
			for ($i = 1; $i -le $dialogWidth; $i++) {
				Write-Buffer -X ($dialogX + $i) -Y ($dialogY + $dialogHeight + 1) -Text " "
			}
			Write-Buffer -X ($dialogX + $dialogWidth) -Y ($dialogY + $dialogHeight + 1) -Text " "
		}
