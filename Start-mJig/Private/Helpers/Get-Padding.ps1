		function Get-Padding {
			param(
				[int]$UsedWidth,
				[int]$TotalWidth
			)
			return [Math]::Max(0, $TotalWidth - $UsedWidth)
		}
