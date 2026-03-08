	function Show-StartupScreen {
		[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
		try { [Console]::Clear() } catch {}

		$sw    = try { $Host.UI.RawUI.WindowSize.Width  } catch { 80 }
		$sh    = try { $Host.UI.RawUI.WindowSize.Height } catch { 24 }
		$boxW  = [Math]::Min(58, $sw - 4)
		$pad   = " " * [Math]::Max(0, [Math]::Floor(($sw - $boxW) / 2))
		$inner = $boxW - 2
		$hLine = [string]$script:BoxHorizontal
		$top   = $script:BoxTopLeft  + ($hLine * ($boxW - 2)) + $script:BoxTopRight
		$div   = $script:BoxVerticalRight + ($hLine * ($boxW - 2)) + $script:BoxVerticalLeft
		$bot   = $script:BoxBottomLeft + ($hLine * ($boxW - 2)) + $script:BoxBottomRight
		$blank = $script:BoxVertical + (" " * $inner) + $script:BoxVertical

		$vertGap = [Math]::Max(0, [Math]::Floor($sh / 2) - 5)
		for ($i = 0; $i -lt $vertGap; $i++) { Write-Host "" }

		Write-Host "$pad$top"  -ForegroundColor Cyan
		Write-Host "$pad$($script:BoxVertical)$("  mJig  |  Initializing".PadRight($inner))$($script:BoxVertical)" -ForegroundColor Cyan
		Write-Host "$pad$div"  -ForegroundColor Cyan
		Write-Host "$pad$blank" -ForegroundColor Cyan
		Write-Host "$pad$($script:BoxVertical)$("  Initializing...".PadRight($inner))$($script:BoxVertical)" -ForegroundColor White
		Write-Host "$pad$blank" -ForegroundColor Cyan
		Write-Host "$pad$bot"  -ForegroundColor Cyan
	}
