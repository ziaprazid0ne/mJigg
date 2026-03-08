		function Get-Padding {
			param(
				[int]$usedWidth,
				[int]$totalWidth
			)
			return [Math]::Max(0, $totalWidth - $usedWidth)
		}
