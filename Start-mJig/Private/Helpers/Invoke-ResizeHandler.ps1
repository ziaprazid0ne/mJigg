	function Invoke-ResizeHandler {
		param([string]$PreviousScreenState = $script:CurrentScreenState)
		$script:LastResizePreviousState = $PreviousScreenState
		$psw       = (Get-Host).UI.RawUI
		$drawCount = 0
		$script:CurrentResizeQuote     = $null
		$script:ResizeLogoLockedHeight = $null
		$pendingSize  = $psw.WindowSize
		$lastDetected = Get-Date

		if ($Output -eq "hidden") {
			[Console]::Clear()
			Restore-ConsoleInputMode
		} else {
			Draw-ResizeLogo -ClearFirst -WindowSize $pendingSize
		}

		while ($true) {
			Start-Sleep -Milliseconds 1
			$newSize   = $psw.WindowSize
			$isNewSize = ($newSize.Width -ne $pendingSize.Width -or $newSize.Height -ne $pendingSize.Height)

			if ($isNewSize) {
				$pendingSize  = $newSize
				$lastDetected = Get-Date
				if ($Output -ne "hidden") {
					$drawCount++
					if ($drawCount % 50 -eq 0) { [Console]::Clear(); Restore-ConsoleInputMode }
					Draw-ResizeLogo -ClearFirst -WindowSize $newSize
				}
			}

			# Stability + LMB gate: only exit once size is stable AND mouse is released
			$elapsed = ((Get-Date) - $lastDetected).TotalMilliseconds
			if ($elapsed -ge $ResizeThrottleMs) {
				$lmbHeld = ([mJiggAPI.Mouse]::GetAsyncKeyState(0x01) -band 0x8000) -ne 0
				if (-not $lmbHeld) {
					[Console]::Clear()
					Restore-ConsoleInputMode
					Send-ResizeExitWakeKey
					return $pendingSize
				}
			}
		}
	}
