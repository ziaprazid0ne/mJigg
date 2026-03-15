	function Show-StartupScreen {
		[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
		try { [Console]::Clear() } catch {}

		$windowWidth  = try { $Host.UI.RawUI.WindowSize.Width  } catch { 80 }
		$windowHeight = try { $Host.UI.RawUI.WindowSize.Height } catch { 24 }
		$boxWidth  = [Math]::Min(58, $windowWidth - 4)
		$pad       = " " * [Math]::Max(0, [Math]::Floor(($windowWidth - $boxWidth) / 2))
		$inner     = $boxWidth - 2
		$horizontalLine = [string]$script:BoxHorizontal
		$top     = $script:BoxTopLeft  + ($horizontalLine * ($boxWidth - 2)) + $script:BoxTopRight
		$divider = $script:BoxVerticalRight + ($horizontalLine * ($boxWidth - 2)) + $script:BoxVerticalLeft
		$bottomLine = $script:BoxBottomLeft + ($horizontalLine * ($boxWidth - 2)) + $script:BoxBottomRight
		$blank   = $script:BoxVertical + (" " * $inner) + $script:BoxVertical

		$verticalGap = [Math]::Max(0, [Math]::Floor($windowHeight / 2) - 5)
		for ($i = 0; $i -lt $verticalGap; $i++) { Write-Host "" }

		Write-Host "$pad$top"  -ForegroundColor Cyan
		Write-Host "$pad$($script:BoxVertical)$("  mJig  |  Initializing".PadRight($inner))$($script:BoxVertical)" -ForegroundColor Cyan
		Write-Host "$pad$divider"  -ForegroundColor Cyan
		Write-Host "$pad$blank" -ForegroundColor Cyan
		Write-Host "$pad$($script:BoxVertical)$("  Initializing...".PadRight($inner))$($script:BoxVertical)" -ForegroundColor White
		Write-Host "$pad$blank" -ForegroundColor Cyan
		Write-Host "$pad$bottomLine"  -ForegroundColor Cyan
	}
