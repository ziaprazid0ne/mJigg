		function Invoke-DialogCleanup {
			param(
				[int]$DialogX,
				[int]$DialogY,
				[int]$DialogWidth,
				[int]$DialogHeight,
				[bool]$SavedCursorVisible,
				[switch]$ClearShadow,
				[switch]$IncludeBorderRow
			)
			if ($ClearShadow) {
				Clear-DialogShadow -dialogX $DialogX -dialogY $DialogY -dialogWidth $DialogWidth -dialogHeight $DialogHeight
			}
			$rowLimit = if ($IncludeBorderRow) { $DialogHeight } else { $DialogHeight - 1 }
			for ($i = 0; $i -le $rowLimit; $i++) {
				Write-Buffer -X $DialogX -Y ($DialogY + $i) -Text (" " * $DialogWidth)
			}
			Flush-Buffer
			$script:CursorVisible = $SavedCursorVisible
			if ($script:CursorVisible) { [Console]::Write("$($script:ESC)[?25h") } else { [Console]::Write("$($script:ESC)[?25l") }
			$script:DialogButtonBounds = $null
			$script:DialogButtonClick = $null
			$script:CurrentScreenState = if ($Output -eq "hidden") { "hidden" } else { "main" }
		}
