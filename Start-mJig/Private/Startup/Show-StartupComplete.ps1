	function Show-StartupComplete {
		param([bool]$HasParams)

		$endTimeDisplay    = if ($EndTime -and $EndTime -ne "0") { $EndTime } else { "none" }
		$autoResumeDisplay = if ($script:AutoResumeDelaySeconds -gt 0) { "$($script:AutoResumeDelaySeconds)s" } else { "off" }

		function DrawCompleteScreen {
			param([string]$PromptText)

			$windowWidth  = try { $Host.UI.RawUI.WindowSize.Width  } catch { 80 }
			$windowHeight = try { $Host.UI.RawUI.WindowSize.Height } catch { 24 }
			$boxWidth  = [Math]::Min(58, $windowWidth - 4)
			$pad   = " " * [Math]::Max(0, [Math]::Floor(($windowWidth - $boxWidth) / 2))
			$inner = $boxWidth - 2
			$horizontalLine = [string]$script:BoxHorizontal
			$top   = $script:BoxTopLeft  + ($horizontalLine * ($boxWidth - 2)) + $script:BoxTopRight
			$divider   = $script:BoxVerticalRight + ($horizontalLine * ($boxWidth - 2)) + $script:BoxVerticalLeft
			$bottomLine   = $script:BoxBottomLeft + ($horizontalLine * ($boxWidth - 2)) + $script:BoxBottomRight
			$blank = $script:BoxVertical + (" " * $inner) + $script:BoxVertical

			$verticalGap = [Math]::Max(0, [Math]::Floor($windowHeight / 2) - 10)
			try { [Console]::Clear() } catch {}
			for ($i = 0; $i -lt $verticalGap; $i++) { Write-Host "" }

			Write-Host "$pad$top"  -ForegroundColor Cyan
			Write-Host "$pad$($script:BoxVertical)$("  mJig  |  Initialization Complete".PadRight($inner))$($script:BoxVertical)" -ForegroundColor Cyan
			Write-Host "$pad$divider"  -ForegroundColor Cyan
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
			Write-Host "$pad$divider"   -ForegroundColor Cyan
			Write-Host "$pad$blank" -ForegroundColor Cyan
			Write-Host "$pad$($script:BoxVertical)$("  $PromptText".PadRight($inner))$($script:BoxVertical)" -ForegroundColor Yellow
			Write-Host "$pad$blank" -ForegroundColor Cyan
			Write-Host "$pad$bottomLine"   -ForegroundColor Cyan
		}

		function GetSize { @{ W = $Host.UI.RawUI.WindowSize.Width; H = $Host.UI.RawUI.WindowSize.Height } }

	if (-not $HasParams) {
		# Wait for key-up; check for resize every 50ms while polling
		DrawCompleteScreen "Press any key to continue..."
		$lastSize     = GetSize
		$inputHandle  = $script:MouseAPI::GetStdHandle(-10)
		$peekBuffer   = New-Object "$($script:_ApiNamespace).INPUT_RECORD[]" 32
		$peekEventCount = [uint32]0
		# Drain events buffered before the prompt appeared (e.g. Enter key-up from launch)
		try { $Host.UI.RawUI.FlushInputBuffer() } catch {}
		$detected   = $false
		$resizeTick = 0
		while (-not $detected) {
			Start-Sleep -Milliseconds 5
			$resizeTick++
			if ($resizeTick -ge 10) {
				$resizeTick = 0
				$currentSize = GetSize
				if ($currentSize.W -ne $lastSize.W -or $currentSize.H -ne $lastSize.H) {
					$null = Invoke-ResizeHandler
					DrawCompleteScreen "Press any key to continue..."
					$lastSize = GetSize
				}
			}
			try {
				if ($script:MouseAPI::PeekConsoleInput($inputHandle, $peekBuffer, 32, [ref]$peekEventCount) -and $peekEventCount -gt 0) {
					for ($e = 0; $e -lt [int]$peekEventCount; $e++) {
						if ($peekBuffer[$e].EventType -eq 0x0001 -and $peekBuffer[$e].KeyEvent.bKeyDown -eq 0 -and
						    $peekBuffer[$e].KeyEvent.wVirtualKeyCode -notin $modifierVKs) {
							$detected = $true; break
						}
					}
					if ($detected) {
						$consumeBuffer = New-Object "$($script:_ApiNamespace).INPUT_RECORD[]" $peekEventCount
						$eventsRead  = [uint32]0
						$script:MouseAPI::ReadConsoleInput($inputHandle, $consumeBuffer, $peekEventCount, [ref]$eventsRead) | Out-Null
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
		$lastSize       = GetSize
		$inputHandle    = $script:MouseAPI::GetStdHandle(-10)
		$peekBuffer     = New-Object "$($script:_ApiNamespace).INPUT_RECORD[]" 32
		$peekEventCount = [uint32]0
		# Drain events buffered before the prompt appeared (e.g. Enter key-up from launch)
		try { $Host.UI.RawUI.FlushInputBuffer() } catch {}
		$detected = $false
		for ($i = 7; $i -gt 0 -and -not $detected; $i--) {
			$secs = if ($i -eq 1) { "second" } else { "seconds" }
			DrawCompleteScreen "Starting in $i $secs...  (any key to skip)"
			$lastSize   = GetSize
			$tickStart  = [DateTime]::UtcNow
			$resizeTick = 0
			while (-not $detected -and ([DateTime]::UtcNow - $tickStart).TotalMilliseconds -lt 1000) {
				Start-Sleep -Milliseconds 5
				$resizeTick++
				if ($resizeTick -ge 10) {
					$resizeTick = 0
					$currentSize = GetSize
					if ($currentSize.W -ne $lastSize.W -or $currentSize.H -ne $lastSize.H) {
						$null = Invoke-ResizeHandler
						DrawCompleteScreen "Starting in $i $secs...  (any key to skip)"
						$lastSize = GetSize
					}
				}
				try {
					if ($script:MouseAPI::PeekConsoleInput($inputHandle, $peekBuffer, 32, [ref]$peekEventCount) -and $peekEventCount -gt 0) {
						for ($e = 0; $e -lt [int]$peekEventCount; $e++) {
							if ($peekBuffer[$e].EventType -eq 0x0001 -and $peekBuffer[$e].KeyEvent.bKeyDown -eq 0 -and
							    $peekBuffer[$e].KeyEvent.wVirtualKeyCode -notin $modifierVKs) {
								$detected = $true; break
							}
						}
						if ($detected) {
							$consumeBuffer = New-Object "$($script:_ApiNamespace).INPUT_RECORD[]" $peekEventCount
							$eventsRead  = [uint32]0
							$script:MouseAPI::ReadConsoleInput($inputHandle, $consumeBuffer, $peekEventCount, [ref]$eventsRead) | Out-Null
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
