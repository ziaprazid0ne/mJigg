	function Show-StartupComplete {
		param([bool]$HasParams)

		$endTimeDisplay    = if ($EndTime -and $EndTime -ne "0") { $EndTime } else { "none" }
		$autoResumeDisplay = if ($script:AutoResumeDelaySeconds -gt 0) { "$($script:AutoResumeDelaySeconds)s" } else { "off" }

		function drawCompleteScreen {
			param([string]$PromptText)

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

			$vertGap = [Math]::Max(0, [Math]::Floor($sh / 2) - 10)
			try { [Console]::Clear() } catch {}
			for ($i = 0; $i -lt $vertGap; $i++) { Write-Host "" }

			Write-Host "$pad$top"  -ForegroundColor Cyan
			Write-Host "$pad$($script:BoxVertical)$("  mJig  |  Initialization Complete".PadRight($inner))$($script:BoxVertical)" -ForegroundColor Cyan
			Write-Host "$pad$div"  -ForegroundColor Cyan
			Write-Host "$pad$blank" -ForegroundColor Cyan
			Write-Host "$pad$($script:BoxVertical)$("  Initialization complete".PadRight($inner))$($script:BoxVertical)" -ForegroundColor Green
			Write-Host "$pad$($script:BoxVertical)$("  Version:     $($script:Version)".PadRight($inner))$($script:BoxVertical)" -ForegroundColor White
			Write-Host "$pad$blank" -ForegroundColor Cyan
			Write-Host "$pad$($script:BoxVertical)$("  Output:      $Output".PadRight($inner))$($script:BoxVertical)"  -ForegroundColor White
			Write-Host "$pad$($script:BoxVertical)$("  Interval:    $($script:IntervalSeconds)s  (variance: +-$($script:IntervalVariance)s)".PadRight($inner))$($script:BoxVertical)" -ForegroundColor White
			Write-Host "$pad$($script:BoxVertical)$("  Distance:    $($script:TravelDistance)px  (variance: +-$($script:TravelVariance)px)".PadRight($inner))$($script:BoxVertical)" -ForegroundColor White
			Write-Host "$pad$($script:BoxVertical)$("  Move speed:  $($script:MoveSpeed)s  (variance: +-$($script:MoveVariance)s)".PadRight($inner))$($script:BoxVertical)" -ForegroundColor White
			Write-Host "$pad$($script:BoxVertical)$("  End time:    $endTimeDisplay".PadRight($inner))$($script:BoxVertical)" -ForegroundColor White
			Write-Host "$pad$($script:BoxVertical)$("  Auto-resume: $autoResumeDisplay".PadRight($inner))$($script:BoxVertical)" -ForegroundColor White
			Write-Host "$pad$blank" -ForegroundColor Cyan
			Write-Host "$pad$div"   -ForegroundColor Cyan
			Write-Host "$pad$blank" -ForegroundColor Cyan
			Write-Host "$pad$($script:BoxVertical)$("  $PromptText".PadRight($inner))$($script:BoxVertical)" -ForegroundColor Yellow
			Write-Host "$pad$blank" -ForegroundColor Cyan
			Write-Host "$pad$bot"   -ForegroundColor Cyan
		}

		function getSize { @{ W = $Host.UI.RawUI.WindowSize.Width; H = $Host.UI.RawUI.WindowSize.Height } }

	if (-not $HasParams) {
		# Wait for key-up; check for resize every 50ms while polling
		drawCompleteScreen "Press any key to continue..."
		$lastSize   = getSize
		$hIn        = $script:MouseAPI::GetStdHandle(-10)
		$peekBuf    = New-Object "$($script:_ApiNamespace).INPUT_RECORD[]" 32
		$peekEvts   = [uint32]0
		# Drain events buffered before the prompt appeared (e.g. Enter key-up from launch)
		try { $Host.UI.RawUI.FlushInputBuffer() } catch {}
		$detected   = $false
		$resizeTick = 0
		while (-not $detected) {
			Start-Sleep -Milliseconds 5
			$resizeTick++
			if ($resizeTick -ge 10) {
				$resizeTick = 0
				$curSize = getSize
				if ($curSize.W -ne $lastSize.W -or $curSize.H -ne $lastSize.H) {
					$null = Invoke-ResizeHandler
					drawCompleteScreen "Press any key to continue..."
					$lastSize = getSize
				}
			}
			try {
				if ($script:MouseAPI::PeekConsoleInput($hIn, $peekBuf, 32, [ref]$peekEvts) -and $peekEvts -gt 0) {
					for ($e = 0; $e -lt [int]$peekEvts; $e++) {
						if ($peekBuf[$e].EventType -eq 0x0001 -and $peekBuf[$e].KeyEvent.bKeyDown -eq 0 -and
						    $peekBuf[$e].KeyEvent.wVirtualKeyCode -notin $modifierVKs) {
							$detected = $true; break
						}
					}
					if ($detected) {
						$flushBuf = New-Object "$($script:_ApiNamespace).INPUT_RECORD[]" $peekEvts
						$flushed  = [uint32]0
						$script:MouseAPI::ReadConsoleInput($hIn, $flushBuf, $peekEvts, [ref]$flushed) | Out-Null
					}
				}
			} catch {
				if ($Host.UI.RawUI.KeyAvailable) {
					try { $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown,IncludeKeyUp,AllowCtrlC") } catch {}
					$detected = $true
				}
			}
		}
	} else {
		# Countdown: 7 seconds, 1s per tick, key-up skips immediately
		$lastSize = getSize
		$hIn      = $script:MouseAPI::GetStdHandle(-10)
		$peekBuf  = New-Object "$($script:_ApiNamespace).INPUT_RECORD[]" 32
		$peekEvts = [uint32]0
		# Drain events buffered before the prompt appeared (e.g. Enter key-up from launch)
		try { $Host.UI.RawUI.FlushInputBuffer() } catch {}
		$detected = $false
		for ($i = 7; $i -gt 0 -and -not $detected; $i--) {
			$secs = if ($i -eq 1) { "second" } else { "seconds" }
			drawCompleteScreen "Starting in $i $secs...  (any key to skip)"
			$lastSize  = getSize
			$secStart  = [DateTime]::UtcNow
			$resizeTick = 0
			while (-not $detected -and ([DateTime]::UtcNow - $secStart).TotalMilliseconds -lt 1000) {
				Start-Sleep -Milliseconds 5
				$resizeTick++
				if ($resizeTick -ge 10) {
					$resizeTick = 0
					$curSize = getSize
					if ($curSize.W -ne $lastSize.W -or $curSize.H -ne $lastSize.H) {
						$null = Invoke-ResizeHandler
						drawCompleteScreen "Starting in $i $secs...  (any key to skip)"
						$lastSize = getSize
					}
				}
				try {
					if ($script:MouseAPI::PeekConsoleInput($hIn, $peekBuf, 32, [ref]$peekEvts) -and $peekEvts -gt 0) {
						for ($e = 0; $e -lt [int]$peekEvts; $e++) {
							if ($peekBuf[$e].EventType -eq 0x0001 -and $peekBuf[$e].KeyEvent.bKeyDown -eq 0 -and
							    $peekBuf[$e].KeyEvent.wVirtualKeyCode -notin $modifierVKs) {
								$detected = $true; break
							}
						}
						if ($detected) {
							$flushBuf = New-Object "$($script:_ApiNamespace).INPUT_RECORD[]" $peekEvts
							$flushed  = [uint32]0
							$script:MouseAPI::ReadConsoleInput($hIn, $flushBuf, $peekEvts, [ref]$flushed) | Out-Null
						}
					}
				} catch {
					if ($Host.UI.RawUI.KeyAvailable) {
						try { $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown,IncludeKeyUp,AllowCtrlC") } catch {}
						$detected = $true
					}
				}
			}
		}
	}
	}
