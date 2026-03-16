	function Write-MainFrame {
	param(
		[switch]$ClearFirst,
		[switch]$Force,
		[switch]$NoFlush,
		$Date = $null,
		[double]$CurveRevealFraction = -1.0
	)

		# Compute UI dimensions fresh (allows calling from any context)
		$Outputline = 0
		$_bpV  = [math]::Max(1, $script:BorderPadV)
		$_bpH  = [math]::Max(1, $script:BorderPadH)
		$_hBg  = $script:HeaderBg
		$_hrBg = $script:HeaderRowBg
		$_fBg  = $script:FooterBg
		$_mrBg = $script:MenuRowBg
		$Rows = [math]::Max(1, $HostHeight - 4 - 2 * $_bpV)

		# Safety: ensure LogArray has exactly $Rows entries
		while ($LogArray.Count -lt $Rows) { $LogArray.Insert(0, [PSCustomObject]@{ logRow = $true; components = @() }) }
		while ($LogArray.Count -gt $Rows) { $LogArray.RemoveAt(0) }

	$date = if ($null -ne $Date) { $Date } else { Get-Date }

		# Track screen state
		$script:CurrentScreenState = if ($Output -eq "hidden") { "hidden" } else { "main" }

		# Skip render when mouse recently moved to prevent stutter; -Force overrides
		$skipConsoleUpdate = if ($_isViewerMode) { $false } else { (Get-TimeSinceMs -StartTime $script:LastMouseMovementTime) -lt 200 }
		if ($Force) {
				$skipConsoleUpdate = $false
			}
			
		if ($Output -ne "hidden" -and -not $skipConsoleUpdate) {
		# Extra plain blank lines above the header background strip (beyond the 1-minimum)
		for ($__bpi = 0; $__bpi -lt ($_bpV - 1); $__bpi++) {
				Write-Buffer -X 0 -Y $Outputline -Text (" " * $HostWidth)
				$Outputline++
			}
		# The 1-minimum blank immediately before the header carries the header background (transparent outer, group-bg inner)
		if ($_bpH -gt 1) { Write-Buffer -X 0                   -Y $Outputline -Text (" " * ($_bpH - 1)) }                         # transparent left
		Write-Buffer -X ($_bpH - 1) -Y $Outputline -Text (" " * ($HostWidth - 2 * $_bpH + 2)) -BG $_hBg                           # group-bg centre
		if ($_bpH -gt 1) { Write-Buffer -X ($HostWidth-$_bpH+1) -Y $Outputline -Text (" " * ($_bpH - 1)) }                        # transparent right
		$Outputline++

		# Render header row
	$currentTime = $date.ToString("HHmm")
			# Calculate widths for centering times between title and view tag
			# Left part: "Title(emoji)" = title.Length + 1 + 2 + 1 (content only; $_bpH+2 left margin handled separately)
			$headerLeftWidth = $script:WindowTitle.Length + 1 + 2 + 1  # title + "(" + emoji + ")"
				# Add Debug Mode text width if in debug mode
			if ($DebugMode) {
				$headerLeftWidth += 13  # " - Debug Mode" = 13 chars
			}
				
			# Header time section layout: "Current" (7) + emoji (2) + "/" (1) + time + " → " (4) + "End" (3) + emoji (2) + "/" (1) + time
			$timeSectionBaseWidth = 7 + 2 + 1 + 4 + 3 + 2 + 1  # Fixed text parts
			if ($endTimeInt -eq -1 -or [string]::IsNullOrEmpty($endTimeStr)) {
				$endTimeDisplay = [char]0x2014  # em-dash when no end time set
			} else {
					$endTimeDisplay = $endTimeStr
				}
				$timeSectionTimeWidth = $currentTime.Length + $endTimeDisplay.Length
				$timeSectionWidth = $timeSectionBaseWidth + $timeSectionTimeWidth
				
		# Right part: pause/resume symbol (clickable) + separator + clickable mode label
		# Format: pause | Full — pause symbol is clickable (toggles pause), mode label is clickable (toggles output)
	$modeName = if ($Output -eq "full") { "Full" } else { " Min" }
	$pauseSymbolWidth = 2  # wide emoji: pause or play
		$modeButtonWidth = $pauseSymbolWidth + 1 + $script:MenuButtonSeparator.Length + 1 + $modeName.Length
			$rightMarginWidth = 0  # inner right padding handled by inset writes

			# Calculate spacing to center times between left and right parts
			$totalUsedWidth = $headerLeftWidth + $timeSectionWidth + $modeButtonWidth + $rightMarginWidth
				$remainingSpace = $HostWidth - 2 * ($_bpH + 2) - $totalUsedWidth
				$spacingBeforeTimes = [math]::Max(1, [math]::Floor($remainingSpace / 2))
				$spacingAfterTimes = [math]::Max(1, $remainingSpace - $spacingBeforeTimes)
				
		$titleEmoji = [char]::ConvertFromUtf32($script:TitleEmoji)
		$hourglassEmoji = $script:HourglassEmoji
		$titleText = "$($script:WindowTitle)("
		$titleTextLen = $script:WindowTitle.Length + 1
	Write-Buffer -X ($_bpH + 2) -Y $Outputline -Text $titleText -FG $script:HeaderAppName -BG $_hrBg
	$curX = $_bpH + 2 + $titleTextLen
			Write-Buffer -Text $titleEmoji -FG $script:HeaderIcon -BG $_hrBg -Wide
		Write-Buffer -X ($curX + 2) -Y $Outputline -Text ")" -FG $script:HeaderAppName -BG $_hrBg
		$curX = $curX + 2 + 1  # emoji (2) + ")" (1)
		$script:HeaderLogoBounds = @{ y = $Outputline; startX = ($_bpH + 2); endX = ($curX - 1) }
	# Add Debug Mode indicator if in debug mode
	if ($DebugMode) {
		Write-Buffer -Text " - Debug Mode" -FG $script:TextError -BG $_hrBg
		$curX += 12
	}
			
			# Add spacing before times
			Write-Buffer -Text (" " * $spacingBeforeTimes) -BG $_hrBg
			$curX += $spacingBeforeTimes
			
		# Write times (Current first, then End) — hidden click regions track each section
		$currentTimeSectionStartX = $curX
		Write-Buffer -Text "Current" -FG $script:HeaderTimeLabel -BG $_hrBg
		$hourglassX1 = $curX + 7  # "Current" = 7 chars
		Write-Buffer -Text $hourglassEmoji -FG $script:HeaderIcon -BG $_hrBg
		Write-Buffer -X ($hourglassX1 + 2) -Y $Outputline -Text "/" -FG $script:TextDefault -BG $_hrBg
		$curX = $hourglassX1 + 2 + 1  # emoji (2) + "/" (1)
		Write-Buffer -Text "$currentTime" -FG $script:HeaderTimeValue -BG $_hrBg
		$curX += $currentTime.Length
		$script:HeaderCurrentTimeBounds = @{ y = $Outputline; startX = $currentTimeSectionStartX; endX = $curX - 1 }
		$arrowTriangle = [char]0x27A3  # arrow (U+27A3)
		Write-Buffer -Text " $arrowTriangle  " -BG $_hrBg
		$curX += 4  # " arrow " = 4 display chars
		$endTimeSectionStartX = $curX
		Write-Buffer -Text "End" -FG $script:HeaderTimeLabel -BG $_hrBg
		$hourglassX2 = $curX + 3  # "End" = 3 chars
		Write-Buffer -Text $hourglassEmoji -FG $script:HeaderIcon -BG $_hrBg
		Write-Buffer -X ($hourglassX2 + 2) -Y $Outputline -Text "/" -FG $script:TextDefault -BG $_hrBg
		$curX = $hourglassX2 + 2 + 1  # emoji (2) + "/" (1)
		Write-Buffer -Text "$endTimeDisplay" -FG $script:HeaderTimeValue -BG $_hrBg
		$curX += $endTimeDisplay.Length
		$script:HeaderEndTimeBounds = @{ y = $Outputline; startX = $endTimeSectionStartX; endX = $curX - 1 }
			
			# Add spacing after times and write view tag aligned to the right
			Write-Buffer -Text (" " * $spacingAfterTimes) -BG $_hrBg
			$curX += $spacingAfterTimes
		# Render pause/resume symbol (clickable) then separator + mode label (clickable)
	$pauseBtnStartX = $curX
	if ($script:ManualPause) {
		Write-Buffer -X $pauseBtnStartX -Y $Outputline -Text $script:PlayEmoji -FG $script:HeaderPauseButton -BG $_hrBg -Wide
	} else {
		Write-Buffer -X $pauseBtnStartX -Y $Outputline -Text $script:PauseEmoji -FG $script:HeaderPauseButton -BG $_hrBg
	}
	Write-Buffer -X ($pauseBtnStartX + 2) -Y $Outputline -Text " $($script:MenuButtonSeparator) " -FG $script:MenuButtonSeparatorFg -BG $_hrBg
	$modeLabelStartX = $pauseBtnStartX + 2 + 1 + $script:MenuButtonSeparator.Length + 1
	Write-Buffer -X $modeLabelStartX -Y $Outputline -Text $modeName -FG $script:HeaderViewTag -BG $_hrBg
		$curX += $modeButtonWidth
		$script:ModeButtonBounds = @{
			y      = $Outputline
			startX = $pauseBtnStartX
			endX   = $pauseBtnStartX + 1
		}
		$_modeTextOffset = $modeName.Length - $modeName.TrimStart().Length
		$script:ModeLabelBounds = @{
			y      = $Outputline
			startX = $modeLabelStartX + $_modeTextOffset
			endX   = $modeLabelStartX + $modeName.Length - 1
		}

		# Clear any remaining characters on the line
			if ($curX -lt $HostWidth) {
				Write-Buffer -Text (" " * ($HostWidth - $curX)) -BG $_hrBg
			}
		# Outer transparent padding (bpH-1), then 1 group-bg, then 2 inner row-bg on each side
		if ($_bpH -gt 1) { Write-Buffer -X 0                     -Y $Outputline -Text (" " * ($_bpH - 1)) }  # transparent left outer
		Write-Buffer -X ($_bpH - 1)           -Y $Outputline -Text " "            -BG $_hBg                   # 1 group-bg left
		Write-Buffer -X $_bpH                 -Y $Outputline -Text "  "           -BG $_hrBg                  # 2 inner left  (row bg)
		Write-Buffer -X ($HostWidth-$_bpH-2)  -Y $Outputline -Text "  "           -BG $_hrBg                  # 2 inner right (row bg)
		Write-Buffer -X ($HostWidth-$_bpH)    -Y $Outputline -Text " "            -BG $_hBg                   # 1 group-bg right
		if ($_bpH -gt 1) { Write-Buffer -X ($HostWidth-$_bpH+1) -Y $Outputline -Text (" " * ($_bpH - 1)) }  # transparent right outer
			$Outputline++

		# Output Line Spacer
		if ($_bpH -gt 1) { Write-Buffer -X 0            -Y $Outputline -Text (" " * ($_bpH - 1)) }          # transparent left outer
		Write-Buffer -X ($_bpH - 1) -Y $Outputline -Text " " -BG $_hBg                                       # 1 group-bg left
		Write-Buffer -Text ("$($script:BoxHorizontal)" * ($HostWidth - 2 * $_bpH)) -FG $script:HeaderSeparator -BG $_hBg
		Write-Buffer -X ($HostWidth - $_bpH) -Y $Outputline -Text " " -BG $_hBg                              # 1 group-bg right
		if ($_bpH -gt 1) { Write-Buffer -X ($HostWidth-$_bpH+1) -Y $Outputline -Text (" " * ($_bpH - 1)) }  # transparent right outer
			$outputLine++

			# Only render console if not skipping updates (prevents stutter during mouse movement)
			if (-not $skipConsoleUpdate) {
			# Calculate view-dependent variables INSIDE the skip check to ensure they use current $Output value
			# This prevents stale view calculations when console updates resume after mouse movement
			$boxWidth = 60  # Width for stats box
			$boxPadding = 2  # Padding around box (1 space on each side)
			$verticalSeparatorWidth = 3  # " $($script:BoxVertical) " = 3 characters
		$showStatsBox = ($Output -eq "full" -and $HostWidth -ge ($boxWidth + $boxPadding + $verticalSeparatorWidth + 50 + 2 * $_bpH))  # Need at least 50 chars for logs + padding
		$logWidth = if ($showStatsBox) { $HostWidth - 2 * $_bpH - $boxWidth - $boxPadding - $verticalSeparatorWidth + 1 } else { $HostWidth - 2 * $_bpH + 1 }  # +1 extends right boundary to group-bg char
			
		# Pre-calculate key text splitting for full view
				$keysFirstLine = ""
				$keysSecondLine = ""
				if ($showStatsBox) {
					if ($PreviousIntervalKeys.Count -gt 0) {
						# Filter out empty/null values to prevent leading commas
						$filteredKeys = $PreviousIntervalKeys | Where-Object { $_ -and $_.ToString().Trim() -ne "" }
						$keysText = if ($filteredKeys.Count -gt 0) { ($filteredKeys -join ", ") } else { "" }
						# Split into two lines if needed (only if we have text)
						if ($keysText -and $keysText.Length -gt ($boxWidth - 2)) {
							# Try to split at a comma
							$splitPos = $keysText.LastIndexOf(", ", ($boxWidth - 2))
							if ($splitPos -gt 0) {
								$keysFirstLine = $keysText.Substring(0, $splitPos)
								$keysSecondLine = $keysText.Substring($splitPos + 2)
								# Truncate second line if still too long
								if ($keysSecondLine.Length -gt ($boxWidth - 2)) {
									$keysSecondLine = $keysSecondLine.Substring(0, ($boxWidth - 5)) + "..."
								}
							} else {
								# No comma found, just truncate
								$keysFirstLine = $keysText.Substring(0, ($boxWidth - 5)) + "..."
								$keysSecondLine = ""
							}
						} elseif ($keysText) {
							$keysFirstLine = $keysText
							$keysSecondLine = ""
						}
					}
				}
				
			# ---- Pre-compute stats box middle rows (rows 3 to $Rows-6) ------------------
			$_sbRows    = $null   # List[object] of row descriptors
			$_sbCurveCanvas    = $null   # List[char[]] — pre-rendered curve diagram rows
			$_sbCurveCenterRow = -1      # center row index inside the canvas
			$_sbCurveInnerW    = $boxWidth - 7   # 43 for boxWidth=50 (1 space + border + content + border + 2 spaces)
			$_sbCurveEq1       = ""
			$_sbCurveEq2       = ""
			$_sbDiagramRows    = 0

			if ($showStatsBox) {
				$_sbMiddleStart = 3
				$_sbMiddleEnd   = $Rows - 6
				$_sbAvail       = $_sbMiddleEnd - $_sbMiddleStart + 1

				if ($_sbAvail -gt 0) {
					$_sbRows = [System.Collections.Generic.List[object]]::new()

				# Section 1 — Session (6 rows, always shown first)
			if ($_sbAvail -ge 6) {
				$null = $_sbRows.Add(@{ type='text'; text=" Session"; fg=$script:StatsSessionTitle })
				if ($script:StatsRunningTimeStr -ne "") {
					$_rtStr = $script:StatsRunningTimeStr
				} else {
					$_rt = (Get-Date) - $ScriptStartTime
					$_rtStr = "$([int][math]::Floor($_rt.TotalHours))h $($_rt.Minutes.ToString('D2'))m $($_rt.Seconds.ToString('D2'))s"
				}
				$null = $_sbRows.Add(@{ type='segments'; segments=@(
					@{ text=" Running Time:"; fg=$script:StatsSessionLabel },
					@{ text=" $_rtStr";       fg=$script:StatsSessionValue }
				)})
				$null = $_sbRows.Add(@{ type='segments'; segments=@(
					@{ text=" Start Time:"; fg=$script:StatsSessionLabel },
					@{ text=" $($ScriptStartTime.ToString('HH:mm:ss'))"; fg=$script:StatsSessionValue }
				)})
				$_sbTotal = $script:StatsMoveCount + $script:StatsSkipCount
				$_sbPct   = if ($_sbTotal -gt 0) { [int]($script:StatsMoveCount * 100 / $_sbTotal) } else { 0 }
				$null = $_sbRows.Add(@{ type='segments'; segments=@(
					@{ text=" Moves:";    fg=$script:StatsSessionLabel },
					@{ text=" $($script:StatsMoveCount)"; fg=$script:StatsSessionValue },
					@{ text="  Skipped:"; fg=$script:StatsSessionLabel },
					@{ text=" $($script:StatsSkipCount)"; fg=$script:StatsSessionValue },
					@{ text="  (${_sbPct}%)"; fg=$script:StatsSessionValue }
				)})
				$_sbStrSign = if ($script:StatsCurrentStreak -ge 0) { "+" } else { "" }
				$null = $_sbRows.Add(@{ type='segments'; segments=@(
					@{ text=" Streak:"; fg=$script:StatsSessionLabel },
					@{ text=" ${_sbStrSign}$($script:StatsCurrentStreak)"; fg=$script:StatsSessionValue },
					@{ text="  Best:"; fg=$script:StatsSessionLabel },
					@{ text=" +$($script:StatsLongestStreak)"; fg=$script:StatsSessionValue }
				)})
				$null = $_sbRows.Add(@{ type='blank' })
			}

		# Section 2 — Movement (5 rows)
		if (($_sbAvail - $_sbRows.Count) -ge 5) {
				$null = $_sbRows.Add(@{ type='text'; text=" Movement"; fg=$script:StatsMovementTitle })
				if ($null -ne $LastMovementTime -and $script:StatsMoveCount -gt 0) {
					$_sbSince = [int]((Get-Date) - $LastMovementTime).TotalSeconds
					$_sbSinceStr = if ($_sbSince -lt 60) { "${_sbSince}s ago" } elseif ($_sbSince -lt 3600) { "$([int]($_sbSince/60))m ago" } else { "$([int]($_sbSince/3600))h ago" }
					$_sbAvgDist = if ($script:StatsMoveCount -gt 0) { [int]($script:StatsTotalDistancePx / $script:StatsMoveCount) } else { 0 }
					$null = $_sbRows.Add(@{ type='segments'; segments=@(
						@{ text=" Last Move:"; fg=$script:StatsMovementLabel },
						@{ text=" $([int]$script:StatsLastMoveDist)px"; fg=$script:StatsMovementValue },
						@{ text="  $([int]$LastMovementDurationMs)ms"; fg=$script:StatsMovementValue },
						@{ text="  $_sbSinceStr"; fg=$script:StatsMovementValue }
					)})
					$null = $_sbRows.Add(@{ type='segments'; segments=@(
						@{ text=" Total Dist:"; fg=$script:StatsMovementLabel },
						@{ text=" $([int]$script:StatsTotalDistancePx)px"; fg=$script:StatsMovementValue },
						@{ text="  Avg:"; fg=$script:StatsMovementLabel },
						@{ text=" ${_sbAvgDist}px"; fg=$script:StatsMovementValue }
					)})
					$_sbMinD = if ($script:StatsMinMoveDist -lt [double]::MaxValue) { [int]$script:StatsMinMoveDist } else { 0 }
					$null = $_sbRows.Add(@{ type='segments'; segments=@(
						@{ text=" Range: Min"; fg=$script:StatsMovementLabel },
						@{ text=" ${_sbMinD}px"; fg=$script:StatsMovementValue },
						@{ text="  Max"; fg=$script:StatsMovementLabel },
						@{ text=" $([int]$script:StatsMaxMoveDist)px"; fg=$script:StatsMovementValue }
					)})
				} else {
					$null = $_sbRows.Add(@{ type='segments'; segments=@(
						@{ text=" Last Move:"; fg=$script:StatsMovementLabel },
						@{ text=" $([char]0x2014)"; fg=$script:TextMuted }
					)})
					$null = $_sbRows.Add(@{ type='segments'; segments=@(
						@{ text=" Total Dist:"; fg=$script:StatsMovementLabel },
						@{ text=" 0px"; fg=$script:StatsMovementValue },
						@{ text="  Avg:"; fg=$script:StatsMovementLabel },
						@{ text=" 0px"; fg=$script:StatsMovementValue }
					)})
					$null = $_sbRows.Add(@{ type='segments'; segments=@(
						@{ text=" Range:"; fg=$script:StatsMovementLabel },
						@{ text=" $([char]0x2014)"; fg=$script:TextMuted }
					)})
				}
				$null = $_sbRows.Add(@{ type='blank' })
			}

		# Section 3 — Performance (5 rows)
		if (($_sbAvail - $_sbRows.Count) -ge 5) {
				$null = $_sbRows.Add(@{ type='text'; text=" Performance"; fg=$script:StatsPerformanceTitle })
				$_sbAvgInt = if ($script:StatsAvgActualIntervalSecs -gt 0) { "$([math]::Round($script:StatsAvgActualIntervalSecs,1))s" } else { "$([char]0x2014)" }
			$null = $_sbRows.Add(@{ type='segments'; segments=@(
				@{ text=" Interrupts: KB"; fg=$script:StatsPerformanceLabel },
				@{ text=" $($script:StatsKbInterruptCount)"; fg=$script:StatsPerformanceValue },
				@{ text="  Mouse"; fg=$script:StatsPerformanceLabel },
				@{ text=" $($script:StatsMsInterruptCount)"; fg=$script:StatsPerformanceValue },
				@{ text="  Clean best"; fg=$script:StatsPerformanceLabel },
				@{ text=" $($script:StatsLongestCleanStreak)"; fg=$script:StatsPerformanceValue }
			)})
			$null = $_sbRows.Add(@{ type='segments'; segments=@(
				@{ text=" Interval: Set"; fg=$script:StatsPerformanceLabel },
				@{ text=" $([math]::Round($script:IntervalSeconds,1))s"; fg=$script:StatsPerformanceValue },
				@{ text="  Actual avg"; fg=$script:StatsPerformanceLabel },
				@{ text=" $_sbAvgInt"; fg=$script:StatsPerformanceValue }
			)})
			$_sbAvgDur = if ($script:StatsAvgDurationMs -gt 0) { "$([int]$script:StatsAvgDurationMs)ms" } else { "$([char]0x2014)" }
			$_sbMinDur = if ($script:StatsMinDurationMs -lt [int]::MaxValue) { "$($script:StatsMinDurationMs)ms" } else { "$([char]0x2014)" }
			$null = $_sbRows.Add(@{ type='segments'; segments=@(
				@{ text=" Animation: Avg"; fg=$script:StatsPerformanceLabel },
				@{ text=" $_sbAvgDur"; fg=$script:StatsPerformanceValue },
				@{ text="  Min"; fg=$script:StatsPerformanceLabel },
				@{ text=" $_sbMinDur"; fg=$script:StatsPerformanceValue },
				@{ text="  Max"; fg=$script:StatsPerformanceLabel },
				@{ text=" $($script:StatsMaxDurationMs)ms"; fg=$script:StatsPerformanceValue }
			)})
			$null = $_sbRows.Add(@{ type='blank' })
			}

		# Section 4 — Travel Distance (4 rows)
		if (($_sbAvail - $_sbRows.Count) -ge 4) {
				$_dc = $script:StatsDirectionCounts
				$_dcRight = [int]($_dc.E + $_dc.NE + $_dc.SE)
				$_dcLeft  = [int]($_dc.W + $_dc.NW + $_dc.SW)
				$_dcUp    = [int]($_dc.N + $_dc.NE + $_dc.NW)
				$_dcDown  = [int]($_dc.S + $_dc.SE + $_dc.SW)
				$null = $_sbRows.Add(@{ type='text'; text=" Travel Distance"; fg=$script:StatsTravelTitle })
				$null = $_sbRows.Add(@{ type='segments'; segments=@(
					@{ text=" $([char]0x2192)"; fg=$script:StatsTravelLabel },
					@{ text=" ${_dcRight}px"; fg=$script:StatsTravelValue },
					@{ text="  $([char]0x2190)"; fg=$script:StatsTravelLabel },
					@{ text=" ${_dcLeft}px"; fg=$script:StatsTravelValue },
					@{ text="  $([char]0x2191)"; fg=$script:StatsTravelLabel },
					@{ text=" ${_dcUp}px"; fg=$script:StatsTravelValue },
					@{ text="  $([char]0x2193)"; fg=$script:StatsTravelLabel },
					@{ text=" ${_dcDown}px"; fg=$script:StatsTravelValue }
				)})
				$null = $_sbRows.Add(@{ type='segments'; segments=@(
					@{ text=" Total:"; fg=$script:StatsTravelLabel },
					@{ text=" $([int]$script:StatsTotalDistancePx)px"; fg=$script:StatsTravelValue }
				)})
				$null = $_sbRows.Add(@{ type='blank' })
			}

			# Section 5 — Settings Snapshot (4 rows)
			if (($_sbAvail - $_sbRows.Count) -ge 4) {
					$_sbResumeStr = if ($script:AutoResumeDelaySeconds -gt 0) { "$([math]::Round($script:AutoResumeDelaySeconds,1))s" } else { "No resume" }
					$null = $_sbRows.Add(@{ type='text'; text=" Settings"; fg=$script:StatsSettingsTitle })
					$null = $_sbRows.Add(@{ type='segments'; segments=@(
						@{ text=" Interval:"; fg=$script:StatsSettingsLabel },
						@{ text=" $([math]::Round($script:IntervalSeconds,1)) $([char]0x00B1)$([math]::Round($script:IntervalVariance,1))s"; fg=$script:StatsSettingsValue },
						@{ text="  Dist:"; fg=$script:StatsSettingsLabel },
						@{ text=" $([int]$script:TravelDistance) $([char]0x00B1)$([int]$script:TravelVariance)px"; fg=$script:StatsSettingsValue }
					)})
					$null = $_sbRows.Add(@{ type='segments'; segments=@(
						@{ text=" Speed:"; fg=$script:StatsSettingsLabel },
						@{ text=" $([math]::Round($script:MoveSpeed,1)) $([char]0x00B1)$([math]::Round($script:MoveVariance,2))s"; fg=$script:StatsSettingsValue },
						@{ text="  Resume:"; fg=$script:StatsSettingsLabel },
						@{ text=" $_sbResumeStr"; fg=$script:StatsSettingsValue }
					)})
					$null = $_sbRows.Add(@{ type='blank' })
				}

				# Curve section — fixed height (1 header + 1 top + 10 diagram + 2 eq + 1 bottom = 15); first section removed when space is tight
				$_sbCurveFixedHeight = 15
				if (($_sbAvail - $_sbRows.Count) -ge $_sbCurveFixedHeight) {
						# Build equation strings
						$_sbCurveEq1 = " ease(t) = 4t$([char]0x00B3)  /  1$([char]0x2212)(2$([char]0x2212)2t)$([char]0x00B3)/2"
						if ($null -ne $script:StatsLastCurveParams -and $script:StatsLastCurveParams.Distance -gt 0) {
							$_sbCp = $script:StatsLastCurveParams
							$_sbEqParts = @()
							if ($_sbCp.StartArcAmt -gt 0) {
								$_sbArcPct  = [int]($_sbCp.StartArcAmt / $_sbCp.Distance * 100)
								$_sbArcSign = if ($_sbCp.StartArcSign -eq 1) { "" } else { "$([char]0x2212)" }
								$_sbEqParts += "${_sbArcSign}D$([char]0x00B7)${_sbArcPct}%$([char]0x00B7)sin($([char]0x03C0)t/0.3)"
							}
							if ($_sbCp.BodyCurveAmt -gt 0) {
								$_sbBdyPct  = [int]($_sbCp.BodyCurveAmt / $_sbCp.Distance * 100)
								$_sbBdySign = if ($_sbCp.BodyCurveSign -eq 1) { "" } else { "$([char]0x2212)" }
							$_sbBdyType = if ($_sbCp.BodyCurveType -eq 0) {
								"sin$([char]0x00B2)($([char]0x03C0)t)"
							} else {
								"sin(2$([char]0x03C0)t)$([char]0x00B7)sin($([char]0x03C0)t)"
							}
								$_sbEqParts += "${_sbBdySign}D$([char]0x00B7)${_sbBdyPct}%$([char]0x00B7)${_sbBdyType}"
							}
							$_sbCurveEq2 = if ($_sbEqParts.Count -gt 0) { " L(t) = $($_sbEqParts -join '  ')" } else { " L(t) = 0" }
						} else {
							$_sbCurveEq2 = " L(t) = $([char]0x2014)"
						}

					# Canvas dimensions: fixed total height; 10 diagram rows (header + top + 10 + eq1 + eq2 + bottom = 15)
					$_sbDiagramRows = $_sbCurveFixedHeight - 5
						$_sbCurveCenterRow = [int]($_sbDiagramRows / 2)

						# Build curve canvas (List of char[])
						$_sbCurveCanvas = [System.Collections.Generic.List[char[]]]::new()
						for ($_sbR = 0; $_sbR -lt $_sbDiagramRows; $_sbR++) {
							$_sbRow = [char[]](' ' * $_sbCurveInnerW)
							if ($_sbR -eq $_sbCurveCenterRow) {
								for ($_sbC = 0; $_sbC -lt $_sbCurveInnerW; $_sbC++) { $_sbRow[$_sbC] = $script:BoxHorizontal }
							}
							$null = $_sbCurveCanvas.Add($_sbRow)
						}

						# Plot path points onto canvas
						if ($null -ne $script:StatsLastCurveParams -and $script:StatsLastCurveParams.Distance -gt 0) {
							$_sbCp = $script:StatsLastCurveParams
							$_sbNS = [math]::Max(200, $_sbCurveInnerW * 4)
							$_sbMaxLat = 0.0
							$_sbPtA = [double[]]::new($_sbNS + 1)
							$_sbPtL = [double[]]::new($_sbNS + 1)
							for ($_sbSi = 0; $_sbSi -le $_sbNS; $_sbSi++) {
								$_sbt = $_sbSi / $_sbNS
								$_sbet = if ($_sbt -lt 0.5) { 4*$_sbt*$_sbt*$_sbt } else { 1 - [Math]::Pow(-2*$_sbt+2,3)/2 }
								$_sblat = 0.0
								if ($_sbCp.StartArcAmt -gt 0 -and $_sbt -le 0.3) {
									$_sblat += $_sbCp.StartArcSign * $_sbCp.StartArcAmt * [Math]::Sin([Math]::PI * $_sbt / 0.3)
								}
								if ($_sbCp.BodyCurveAmt -gt 0 -and $_sbt -ge 0.3) {
									$_sbbt = ($_sbt - 0.3) / 0.7
									$_sbsb = [Math]::Sin([Math]::PI * $_sbbt)
									$_sblat += if ($_sbCp.BodyCurveType -eq 0) {
										$_sbCp.BodyCurveSign * $_sbCp.BodyCurveAmt * $_sbsb * $_sbsb
									} else {
										$_sbCp.BodyCurveSign * $_sbCp.BodyCurveAmt * [Math]::Sin(2*[Math]::PI*$_sbbt) * $_sbsb
									}
								}
								$_sbPtA[$_sbSi] = $_sbet
								$_sbPtL[$_sbSi] = $_sblat
								$_sbAbsLat = [Math]::Abs($_sblat)
								if ($_sbAbsLat -gt $_sbMaxLat) { $_sbMaxLat = $_sbAbsLat }
							}
						if ($_sbMaxLat -lt 1) { $_sbMaxLat = 1 }

						# Cache path data for fast partial re-renders during animation
						if ($CurveRevealFraction -ge 0) {
							$script:_CurveAnimPtA       = $_sbPtA
							$script:_CurveAnimPtL       = $_sbPtL
							$script:_CurveAnimMaxLat    = $_sbMaxLat
							$script:_CurveAnimNS        = $_sbNS
							$script:_CurveAnimInnerW    = $_sbCurveInnerW
							$script:_CurveAnimCenterRow = $_sbCurveCenterRow
							$script:_CurveAnimDiagRows  = $_sbDiagramRows
							$script:_CurveAnimBoxInnerX = $_bpH + $logWidth + 7
							$script:_CurveAnimHostWidth = $HostWidth
							$script:_CurveAnimHostHeight = $HostHeight
						}

					for ($_sbSi = 0; $_sbSi -le $_sbNS; $_sbSi++) {
						if ($CurveRevealFraction -ge 0 -and $_sbPtA[$_sbSi] -gt $CurveRevealFraction) { continue }
						$_sbCol = [int]($_sbPtA[$_sbSi] * ($_sbCurveInnerW - 1))
						$_sbCol = [math]::Max(0, [math]::Min($_sbCurveInnerW - 1, $_sbCol))
						$_sbRO  = [int]($_sbPtL[$_sbSi] / $_sbMaxLat * $_sbCurveCenterRow)
						$_sbPR  = $_sbCurveCenterRow - $_sbRO
						$_sbPR  = [math]::Max(0, [math]::Min($_sbDiagramRows - 1, $_sbPR))
						$_sbCurveCanvas[$_sbPR][$_sbCol] = [char]0x25CF  # ●
					}
					}

				# Push curve to bottom of stats section by padding with blank rows
				$_sbFillerRows = $_sbAvail - $_sbRows.Count - $_sbCurveFixedHeight
					for ($_sbFr = 0; $_sbFr -lt $_sbFillerRows; $_sbFr++) { $null = $_sbRows.Add(@{ type='blank' }) }

				# Add row descriptors
				$null = $_sbRows.Add(@{ type='curve-header' })
					$null = $_sbRows.Add(@{ type='curve-box-top' })
					for ($_sbDr = 0; $_sbDr -lt $_sbDiagramRows; $_sbDr++) {
						$null = $_sbRows.Add(@{ type='curve-diagram'; rowIndex=$_sbDr })
					}
					$null = $_sbRows.Add(@{ type='curve-eq1' })
					$null = $_sbRows.Add(@{ type='curve-eq2' })
					$null = $_sbRows.Add(@{ type='curve-box-bottom' })

					# Store the diagram start Y for partial-render animation frames
					if ($CurveRevealFraction -ge 0) {
						$_sbFirstDiagIdx = $_sbRows.Count - $_sbCurveFixedHeight + 2
						$script:_CurveAnimDiagramStartY = $Outputline + 3 + $_sbFirstDiagIdx
					}
					}
				}
			}
			# ---- End stats pre-computation ----------------------------------------------

			for ($i = 0; $i -lt $Rows; $i++) {
			$rowY = $Outputline + $i
		$logStartX      = [math]::Max(0, $_bpH - 2)
		$availableWidth = [math]::Min($logWidth + 2, $HostWidth - $logStartX)
					
					$hasLogEntry = ($i -lt $LogArray.Count -and $null -ne $LogArray[$i] -and $null -ne $LogArray[$i].components)
					$hasContent = ($hasLogEntry -and $LogArray[$i].components.Count -gt 0)
					
					if ($hasContent) {
							# Format log line based on available width with priority
							$formattedLine = ""
							$useShortTimestamp = $false
							
							# Calculate total length with full components (accounting for 2-space indent)
							$fullLength = 2  # Start with 2 for leading spaces
							foreach ($component in $LogArray[$i].components) {
								$fullLength += $component.text.Length
							}
							
							# If full length exceeds width, start using shortened timestamp
							if ($fullLength -gt $availableWidth) {
								$useShortTimestamp = $true
								# Recalculate with short timestamp
								$shortLength = 2  # Start with 2 for leading spaces
								foreach ($component in $LogArray[$i].components) {
									if ($component.priority -eq 1) {
										$shortLength += $component.shortText.Length
									} else {
										$shortLength += $component.text.Length
									}
								}
								$fullLength = $shortLength
							}
							
							# Build line with priority-based truncation (accounting for 2-space indent)
							$formattedLine = "  "  # Add 2 leading spaces
							$remainingWidth = $availableWidth - 2  # Subtract 2 for leading spaces
							# Sort components by priority (ascending) - lower priority numbers appear first
							$sortedComponents = $LogArray[$i].components | Sort-Object { [int]$_.priority }
							foreach ($component in $sortedComponents) {
								$componentText = if ($component.priority -eq 1 -and $useShortTimestamp) {
									$component.shortText
								} else {
									$component.text
								}
								
								# Check if we have room for this component
								if ($componentText.Length -le $remainingWidth) {
									$formattedLine += $componentText
									$remainingWidth -= $componentText.Length
								} else {
									# Truncate this component if it is the last one and we have some room
									if ($remainingWidth -gt 3) {
										$formattedLine += $componentText.Substring(0, $remainingWidth - 3) + "..."
									}
									break
								}
							}
							
						# Truncate or pad to exactly $availableWidth characters
						$truncatedLine = if ($formattedLine.Length -gt $availableWidth) {
								$formattedLine.Substring(0, $availableWidth)
							} else {
								$formattedLine
							}
					$paddedLine = $truncatedLine.PadRight($availableWidth)
					Write-Buffer -X $logStartX -Y $rowY -Text $paddedLine
						
						if ($showStatsBox) {
							Write-Buffer -X ($_bpH + $logWidth) -Y $rowY -Text " $($script:BoxVertical) " -FG $script:StatsBoxBorder
						}
							
							# Draw stats box in full view (with padding so it does not touch white lines)
							if ($showStatsBox) {
								Write-Buffer -Text " "
								
								# Draw box content
								if ($i -eq 0) {
									# Top border
									Write-Buffer -Text "$($script:BoxTopLeft)" -FG $script:StatsBoxBorder
									Write-Buffer -Text ("$($script:BoxHorizontal)" * ($boxWidth - 2)) -FG $script:StatsBoxBorder
									Write-Buffer -Text "$($script:BoxTopRight)" -FG $script:StatsBoxBorder
								} elseif ($i -eq 1) {
									# Header row
									$boxHeader = "Stats:"
									Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
									Write-Buffer -Text $boxHeader.PadRight($boxWidth - 2) -FG $script:StatsBoxTitle
									Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
								} elseif ($i -eq 2) {
									# Separator row
									Write-Buffer -Text "$($script:BoxVerticalRight)" -FG $script:StatsBoxBorder
									Write-Buffer -Text ("$($script:BoxHorizontal)" * ($boxWidth - 2)) -FG $script:StatsBoxBorder
									Write-Buffer -Text "$($script:BoxVerticalLeft)" -FG $script:StatsBoxBorder
								} elseif ($i -eq $Rows - 5) {
									Write-Buffer -Text "$($script:BoxVerticalRight)" -FG $script:StatsBoxBorder
									Write-Buffer -Text ("$($script:BoxHorizontal)" * ($boxWidth - 2)) -FG $script:StatsBoxBorder
									Write-Buffer -Text "$($script:BoxVerticalLeft)" -FG $script:StatsBoxBorder
							} elseif ($i -eq $Rows - 4) {
								Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
								Write-Buffer -Text "Detected Inputs:".PadRight($boxWidth - 2) -FG $script:StatsInputsTitle
								Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
							} elseif ($i -eq $Rows - 3) {
								if ($PreviousIntervalKeys.Count -gt 0) {
									Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
									Write-Buffer -Text $keysFirstLine.PadRight($boxWidth - 2) -FG $script:StatsInputsValue
									Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
								} else {
									Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
									Write-Buffer -Text "$([char]0x2014)".PadRight($boxWidth - 2) -FG $script:TextMuted
									Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
								}
							} elseif ($i -eq $Rows - 2) {
								if ($PreviousIntervalKeys.Count -gt 0 -and $keysSecondLine -ne "") {
									Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
									Write-Buffer -Text $keysSecondLine.PadRight($boxWidth - 2) -FG $script:StatsInputsValue
									Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
								} else {
									Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
									Write-Buffer -Text (" " * ($boxWidth - 2))
									Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
								}
							} elseif ($i -eq $Rows - 1) {
								Write-Buffer -Text "$($script:BoxBottomLeft)" -FG $script:StatsBoxBorder
								Write-Buffer -Text ("$($script:BoxHorizontal)" * ($boxWidth - 2)) -FG $script:StatsBoxBorder
								Write-Buffer -Text "$($script:BoxBottomRight)" -FG $script:StatsBoxBorder
							} else {
								# Stats content rows (rows 3 to $Rows-6)
								$_sbIdx = $i - 3
								if ($null -ne $_sbRows -and $_sbIdx -ge 0 -and $_sbIdx -lt $_sbRows.Count) {
									$_sbSr = $_sbRows[$_sbIdx]
								Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
								switch ($_sbSr.type) {
									'text'  { Write-Buffer -Text $_sbSr.text.PadRight($boxWidth - 2) -FG $_sbSr.fg }
									'blank' { Write-Buffer -Text (" " * ($boxWidth - 2)) }
									'segments' {
										$_segRemain = $boxWidth - 2
										for ($_ssi = 0; $_ssi -lt $_sbSr.segments.Count; $_ssi++) {
											$_seg = $_sbSr.segments[$_ssi]
											if ($_ssi -eq $_sbSr.segments.Count - 1) {
												Write-Buffer -Text $_seg.text.PadRight($_segRemain) -FG $_seg.fg
											} else {
												Write-Buffer -Text $_seg.text -FG $_seg.fg
												$_segRemain -= $_seg.text.Length
											}
										}
									}
									'curve-header' { Write-Buffer -Text " Last Movement's Curve".PadRight($boxWidth - 2) -FG $script:StatsCurveHeader }
									'curve-box-top' {
										Write-Buffer -Text " $($script:BoxTopLeft)" -FG $script:StatsCurveBorder
										Write-Buffer -Text ("$($script:BoxHorizontal)" * $_sbCurveInnerW) -FG $script:StatsCurveBorder
										Write-Buffer -Text "$($script:BoxTopRight)  " -FG $script:StatsCurveBorder
									}
									'curve-diagram' {
										Write-Buffer -Text " $($script:BoxVertical)" -FG $script:StatsCurveBorder
										if ($null -ne $_sbCurveCanvas -and $_sbSr.rowIndex -lt $_sbCurveCanvas.Count) {
											foreach ($_sbCh in $_sbCurveCanvas[$_sbSr.rowIndex]) {
												if    ($_sbCh -eq [char]0x25CF)           { Write-Buffer -Text $_sbCh -FG $script:StatsCurveDots }
												elseif($_sbCh -eq $script:BoxHorizontal)  { Write-Buffer -Text $_sbCh -FG $script:StatsCurveLine }
												else                                       { Write-Buffer -Text " " }
											}
										} else {
											Write-Buffer -Text (" " * $_sbCurveInnerW)
										}
										Write-Buffer -Text "$($script:BoxVertical)  " -FG $script:StatsCurveBorder
									}
									'curve-eq1' {
										Write-Buffer -Text " $($script:BoxVertical)" -FG $script:StatsCurveBorder
										Write-Buffer -Text $_sbCurveEq1.PadRight($_sbCurveInnerW) -FG $script:StatsCurveEq1
										Write-Buffer -Text "$($script:BoxVertical)  " -FG $script:StatsCurveBorder
									}
									'curve-eq2' {
										Write-Buffer -Text " $($script:BoxVertical)" -FG $script:StatsCurveBorder
										Write-Buffer -Text $_sbCurveEq2.PadRight($_sbCurveInnerW) -FG $script:StatsCurveEq2
										Write-Buffer -Text "$($script:BoxVertical)  " -FG $script:StatsCurveBorder
									}
									'curve-box-bottom' {
										Write-Buffer -Text " $($script:BoxBottomLeft)" -FG $script:StatsCurveBorder
										Write-Buffer -Text ("$($script:BoxHorizontal)" * $_sbCurveInnerW) -FG $script:StatsCurveBorder
										Write-Buffer -Text "$($script:BoxBottomRight)  " -FG $script:StatsCurveBorder
									}
									default { Write-Buffer -Text (" " * ($boxWidth - 2)) }
								}
								Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
							} else {
								Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
								Write-Buffer -Text (" " * ($boxWidth - 2))
								Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
							}
						}
						
						Write-Buffer -Text " "
					}
			} else {
			$emptyLine = "".PadRight($availableWidth)
				Write-Buffer -X $logStartX -Y $rowY -Text $emptyLine
					
					if ($showStatsBox) {
						Write-Buffer -X ($_bpH + $logWidth) -Y $rowY -Text " $($script:BoxVertical) " -FG $script:StatsBoxBorder
					}
						
						if ($showStatsBox) {
							Write-Buffer -Text " "
							if ($i -eq 0) {
								Write-Buffer -Text "$($script:BoxTopLeft)" -FG $script:StatsBoxBorder
								Write-Buffer -Text ("$($script:BoxHorizontal)" * ($boxWidth - 2)) -FG $script:StatsBoxBorder
								Write-Buffer -Text "$($script:BoxTopRight)" -FG $script:StatsBoxBorder
							} elseif ($i -eq 1) {
								Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
								Write-Buffer -Text "Stats:".PadRight($boxWidth - 2) -FG $script:StatsBoxTitle
								Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
							} elseif ($i -eq 2) {
								Write-Buffer -Text "$($script:BoxVerticalRight)" -FG $script:StatsBoxBorder
								Write-Buffer -Text ("$($script:BoxHorizontal)" * ($boxWidth - 2)) -FG $script:StatsBoxBorder
								Write-Buffer -Text "$($script:BoxVerticalLeft)" -FG $script:StatsBoxBorder
							} elseif ($i -eq $Rows - 5) {
								Write-Buffer -Text "$($script:BoxVerticalRight)" -FG $script:StatsBoxBorder
								Write-Buffer -Text ("$($script:BoxHorizontal)" * ($boxWidth - 2)) -FG $script:StatsBoxBorder
								Write-Buffer -Text "$($script:BoxVerticalLeft)" -FG $script:StatsBoxBorder
							} elseif ($i -eq $Rows - 4) {
								Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
								Write-Buffer -Text "Detected Inputs:".PadRight($boxWidth - 2) -FG $script:StatsInputsTitle
								Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
							} elseif ($i -eq $Rows - 3) {
								if ($PreviousIntervalKeys.Count -gt 0) {
									Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
									Write-Buffer -Text $keysFirstLine.PadRight($boxWidth - 2) -FG $script:StatsInputsValue
									Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
								} else {
									Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
									Write-Buffer -Text "$([char]0x2014)".PadRight($boxWidth - 2) -FG $script:TextMuted
									Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
								}
							} elseif ($i -eq $Rows - 2) {
								if ($PreviousIntervalKeys.Count -gt 0 -and $keysSecondLine -ne "") {
									Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
									Write-Buffer -Text $keysSecondLine.PadRight($boxWidth - 2) -FG $script:StatsInputsValue
									Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
								} else {
									Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
									Write-Buffer -Text (" " * ($boxWidth - 2))
									Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
								}
						} elseif ($i -eq $Rows - 1) {
							Write-Buffer -Text "$($script:BoxBottomLeft)" -FG $script:StatsBoxBorder
							Write-Buffer -Text ("$($script:BoxHorizontal)" * ($boxWidth - 2)) -FG $script:StatsBoxBorder
							Write-Buffer -Text "$($script:BoxBottomRight)" -FG $script:StatsBoxBorder
						} else {
							# Stats content rows (rows 3 to $Rows-6)
							$_sbIdx = $i - 3
							if ($null -ne $_sbRows -and $_sbIdx -ge 0 -and $_sbIdx -lt $_sbRows.Count) {
								$_sbSr = $_sbRows[$_sbIdx]
								Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
								switch ($_sbSr.type) {
									'text'  { Write-Buffer -Text $_sbSr.text.PadRight($boxWidth - 2) -FG $_sbSr.fg }
									'blank' { Write-Buffer -Text (" " * ($boxWidth - 2)) }
									'segments' {
										$_segRemain = $boxWidth - 2
										for ($_ssi = 0; $_ssi -lt $_sbSr.segments.Count; $_ssi++) {
											$_seg = $_sbSr.segments[$_ssi]
											if ($_ssi -eq $_sbSr.segments.Count - 1) {
												Write-Buffer -Text $_seg.text.PadRight($_segRemain) -FG $_seg.fg
											} else {
												Write-Buffer -Text $_seg.text -FG $_seg.fg
												$_segRemain -= $_seg.text.Length
											}
										}
									}
									'curve-header' { Write-Buffer -Text " Last Movement's Curve".PadRight($boxWidth - 2) -FG $script:StatsCurveHeader }
									'curve-box-top' {
										Write-Buffer -Text " $($script:BoxTopLeft)" -FG $script:StatsCurveBorder
										Write-Buffer -Text ("$($script:BoxHorizontal)" * $_sbCurveInnerW) -FG $script:StatsCurveBorder
										Write-Buffer -Text "$($script:BoxTopRight)  " -FG $script:StatsCurveBorder
									}
									'curve-diagram' {
										Write-Buffer -Text " $($script:BoxVertical)" -FG $script:StatsCurveBorder
										if ($null -ne $_sbCurveCanvas -and $_sbSr.rowIndex -lt $_sbCurveCanvas.Count) {
											foreach ($_sbCh in $_sbCurveCanvas[$_sbSr.rowIndex]) {
												if    ($_sbCh -eq [char]0x25CF)           { Write-Buffer -Text $_sbCh -FG $script:StatsCurveDots }
												elseif($_sbCh -eq $script:BoxHorizontal)  { Write-Buffer -Text $_sbCh -FG $script:StatsCurveLine }
												else                                       { Write-Buffer -Text " " }
											}
										} else {
											Write-Buffer -Text (" " * $_sbCurveInnerW)
										}
										Write-Buffer -Text "$($script:BoxVertical)  " -FG $script:StatsCurveBorder
									}
									'curve-eq1' {
										Write-Buffer -Text " $($script:BoxVertical)" -FG $script:StatsCurveBorder
										Write-Buffer -Text $_sbCurveEq1.PadRight($_sbCurveInnerW) -FG $script:StatsCurveEq1
										Write-Buffer -Text "$($script:BoxVertical)  " -FG $script:StatsCurveBorder
									}
									'curve-eq2' {
										Write-Buffer -Text " $($script:BoxVertical)" -FG $script:StatsCurveBorder
										Write-Buffer -Text $_sbCurveEq2.PadRight($_sbCurveInnerW) -FG $script:StatsCurveEq2
										Write-Buffer -Text "$($script:BoxVertical)  " -FG $script:StatsCurveBorder
									}
									'curve-box-bottom' {
										Write-Buffer -Text " $($script:BoxBottomLeft)" -FG $script:StatsCurveBorder
										Write-Buffer -Text ("$($script:BoxHorizontal)" * $_sbCurveInnerW) -FG $script:StatsCurveBorder
										Write-Buffer -Text "$($script:BoxBottomRight)  " -FG $script:StatsCurveBorder
									}
									default { Write-Buffer -Text (" " * ($boxWidth - 2)) }
								}
								Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
							} else {
								Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
								Write-Buffer -Text (" " * ($boxWidth - 2))
								Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
							}
						}
						Write-Buffer -Text " "
					}
				}
		}
			$outputLine += $Rows
			}
			}  # End of skipConsoleUpdate check

			# Output bottom separator (only if not skipping console updates)
			if ($Output -ne "hidden" -and -not $skipConsoleUpdate) {
			
		# Bottom separator line
		if ($_bpH -gt 1) { Write-Buffer -X 0            -Y $Outputline -Text (" " * ($_bpH - 1)) }          # transparent left outer
		Write-Buffer -X ($_bpH - 1) -Y $Outputline -Text " " -BG $_fBg                                       # 1 group-bg left
		Write-Buffer -Text ("$($script:BoxHorizontal)" * ($HostWidth - 2 * $_bpH)) -FG $script:HeaderSeparator -BG $_fBg
		Write-Buffer -X ($HostWidth - $_bpH) -Y $Outputline -Text " " -BG $_fBg                              # 1 group-bg right
		if ($_bpH -gt 1) { Write-Buffer -X ($HostWidth-$_bpH+1) -Y $Outputline -Text (" " * ($_bpH - 1)) }  # transparent right outer
			$outputLine++

			## Menu Options ##
	$emojiLock    = $script:LockEmoji
	$emojiGear    = $script:GearEmoji
	$emojiRedX    = $script:RedXEmoji
			
	$menuItemsList = @(
		@{
			full             = "$emojiGear|(S)ettings"
			noIcons          = "(S)ettings"
			short            = "(S)et"
			isSettingsButton = $true
		},
		@{
			full    = "$emojiLock|(I)ncognito"
			noIcons = "(I)ncognito"
			short   = "(I)nc"
		}
	)

		$menuItemsList += @{
			full    = "$emojiRedX|(Q)uit"
			noIcons = "(Q)uit"
			short   = "(Q)uit"
		}

			$menuItems = $menuItemsList
				
		# Calculate widths for each format (emojis = 2 display chars)
		$menuIconWidth    = if ($script:MenuButtonShowIcon)    { 2 + $script:MenuButtonSeparator.Length } else { 0 }
		$menuBracketWidth = if ($script:MenuButtonShowBrackets) { 2 } else { 0 }
		$hotkeyParenAdj   = if ($script:MenuButtonShowHotkeyParens) { 0 } else { -2 }
		$format0Width = 2  # Leading spaces
		$format1Width = 2
		$format2Width = 2
		
		foreach ($item in $menuItems) {
			$textPart = $item.full -replace "^.+\|", ""
			$format0Width += $menuIconWidth + $textPart.Length + $hotkeyParenAdj + $menuBracketWidth + 2
			$format1Width += $item.noIcons.Length + $hotkeyParenAdj + 2
			$format2Width += $item.short.Length + $hotkeyParenAdj + 1
		}
			
			$format0Width += 2
			$format1Width += 2
			$format2Width += 2

			# ? help button contributes to format 0 and 1 only (hidden in format 2 / short mode)
			$helpButtonWidth = 0
			if ($Output -eq "full") {
				$helpButtonWidth = $menuBracketWidth + 1  # "?" char + optional brackets
				$format0Width += $helpButtonWidth + 2    # +2 for trailing spaces
				$format1Width += $helpButtonWidth + 2
			}

			$menuFormat = 0
			if ($HostWidth -lt $format0Width) {
				if ($HostWidth -lt $format1Width) {
					$menuFormat = 2
				} else {
					$menuFormat = 1
				}
			}
			
		$quitItem = $menuItems[$menuItems.Count - 1]
		if ($menuFormat -eq 0) {
			$textPart = $quitItem.full -replace "^.+\|", ""
			$quitWidth = $menuIconWidth + $textPart.Length + $hotkeyParenAdj + $menuBracketWidth
			} elseif ($menuFormat -eq 1) {
				$quitWidth = $quitItem.noIcons.Length + $hotkeyParenAdj
			} else {
				$quitWidth = $quitItem.short.Length + $hotkeyParenAdj
			}
				
		# Clear pressed-button state after action (immediate or after dialog close; skip while dialog is open)
		if ($script:PendingDialogCheck -and $null -ne $script:PressedMenuButton) {
			if ($null -eq $script:DialogButtonBounds) {
				$script:PressedMenuButton  = $null
				$script:ButtonClickedAt    = $null
				$script:PendingDialogCheck = $false
			}
				# If DialogButtonBounds is non-null a dialog is open; leave everything in place until it closes
			}

		# Write menu items via buffer with static position tracking
		$menuY = $Outputline
		$script:MenuBarY = $menuY  # stored for quit dialog positioning
	$currentMenuX = $_bpH + 2  # Start after group-bg + 2-char inner padding

	$script:MenuItemsBounds.Clear()
				$itemsBeforeQuit = $menuItems.Count - 1
				for ($mi = 0; $mi -lt $itemsBeforeQuit; $mi++) {
					$item = $menuItems[$mi]
					$itemStartX = $currentMenuX
					
					if ($menuFormat -eq 0) {
						$itemText = $item.full
					} elseif ($menuFormat -eq 1) {
						$itemText = $item.noIcons
					} else {
						$itemText = $item.short
					}
					
			# Calculate item display width statically (emoji = 2 display cells)
			$itemDisplayWidth = 0
			if ($menuFormat -eq 0) {
				$parts = $itemText -split "\|", 2
				if ($parts.Count -eq 2) {
					$itemDisplayWidth = $menuIconWidth + $parts[1].Length + $hotkeyParenAdj + $menuBracketWidth
				}
			} else {
					$itemDisplayWidth = $itemText.Length + $hotkeyParenAdj
				}
					
		# Resolve hotkey and pressed-state colors before rendering
		$hotkeyMatch = $itemText -match "\(([a-z])\)"
		$hotkey = if ($hotkeyMatch) { $matches[1] } else { $null }
		$isPressed = ($null -ne $script:PressedMenuButton -and $script:PressedMenuButton -eq $hotkey)
		if ($item.isSettingsButton -eq $true) {
			# Settings button uses its own dedicated color variables
			$btnFg        = if ($isPressed) { $script:SettingsButtonOnClickFg }          else { $script:SettingsButtonText }
			$btnBg        = if ($isPressed) { $script:SettingsButtonOnClickBg }          else { $script:SettingsButtonBg }
			$btnHkFg      = if ($isPressed) { $script:SettingsButtonOnClickHotkey }      else { $script:SettingsButtonHotkey }
			$btnPipeFg    = if ($isPressed) { $script:SettingsButtonOnClickSeparatorFg } else { $script:SettingsButtonSeparatorFg }
			$btnBracketFg = if ($isPressed) { $script:SettingsButtonOnClickBracketFg }   else { $script:SettingsButtonBracketFg }
			$btnBracketBg = if ($isPressed) { $script:SettingsButtonOnClickBracketBg }   else { $script:SettingsButtonBracketBg }
	} else {
			$btnFg        = if ($isPressed) { $script:MenuButtonOnClickFg }         else { $script:MenuButtonText }
			$btnBg        = if ($isPressed) { $script:MenuButtonOnClickBg }         else { $script:MenuButtonBg }
			$btnHkFg      = if ($isPressed) { $script:MenuButtonOnClickHotkey }     else { $script:MenuButtonHotkey }
			$btnPipeFg    = if ($isPressed) { $script:MenuButtonOnClickSeparatorFg } else { $script:MenuButtonSeparatorFg }
			$btnBracketFg = if ($isPressed) { $script:MenuButtonOnClickBracketFg }  else { $script:MenuButtonBracketFg }
			$btnBracketBg = if ($isPressed) { $script:MenuButtonOnClickBracketBg }  else { $script:MenuButtonBracketBg }
		}

		# Render the menu item
		if ($menuFormat -eq 0) {
			$parts = $itemText -split "\|", 2
			if ($parts.Count -eq 2) {
				$emoji = $parts[0]
				$text = $parts[1]
				$contentX = $itemStartX
				if ($script:MenuButtonShowBrackets) {
					Write-Buffer -X $contentX -Y $menuY -Text "[" -FG $btnBracketFg -BG $btnBracketBg
					$contentX += 1
				}
				if ($script:MenuButtonShowIcon) {
					Write-Buffer -X $contentX -Y $menuY -Text $emoji -BG $btnBg -Wide
					$sepX = $contentX + 2
					Write-Buffer -X $sepX -Y $menuY -Text $script:MenuButtonSeparator -FG $btnPipeFg -BG $btnBg
				} else {
					Write-Buffer -X $contentX -Y $menuY -Text "" -BG $btnBg
				}
	Write-HotkeyLabel -Text $text -FG $btnFg -HotkeyFg $btnHkFg -BG $btnBg
		if ($script:MenuButtonShowBrackets) {
			Write-Buffer -Text "]" -FG $btnBracketFg -BG $btnBracketBg
		}
	}
} else {
			Write-Buffer -X $itemStartX -Y $menuY -Text "" -BG $btnBg
			Write-HotkeyLabel -Text $itemText -FG $btnFg -HotkeyFg $btnHkFg -BG $btnBg
		}
				
	# Store menu item bounds (computed statically)
	$itemEndX = $itemStartX + $itemDisplayWidth - 1
	if ($item.isSettingsButton -eq $true) {
		$script:SettingsButtonStartX = $itemStartX   # for dialog positioning
		$script:SettingsButtonEndX   = $itemEndX     # for close-on-reclick detection
	$null = $script:MenuItemsBounds.Add(@{
		startX           = $itemStartX
		endX             = $itemEndX
		y                = $menuY
		hotkey           = $hotkey
		isSettingsButton = $true
		index            = $mi
		displayText      = $itemText
		format           = $menuFormat
		fg               = $script:SettingsButtonText
		bg               = $script:SettingsButtonBg
		hotkeyFg         = $script:SettingsButtonHotkey
		pipeFg           = $script:SettingsButtonSeparatorFg
		bracketFg        = $script:SettingsButtonBracketFg
		bracketBg        = $script:SettingsButtonBracketBg
		onClickFg        = $script:SettingsButtonOnClickFg
		onClickBg        = $script:SettingsButtonOnClickBg
		onClickHotkeyFg  = $script:SettingsButtonOnClickHotkey
		onClickPipeFg    = $script:SettingsButtonOnClickSeparatorFg
		onClickBracketFg = $script:SettingsButtonOnClickBracketFg
		onClickBracketBg = $script:SettingsButtonOnClickBracketBg
	})
} else {
	$null = $script:MenuItemsBounds.Add(@{
			startX      = $itemStartX
			endX        = $itemEndX
			y           = $menuY
			hotkey      = $hotkey
			index       = $mi
			displayText = $itemText
			format      = $menuFormat
			fg          = $script:MenuButtonText
			bg          = $script:MenuButtonBg
			hotkeyFg    = $script:MenuButtonHotkey
			pipeFg      = $script:MenuButtonSeparatorFg
			bracketFg   = $script:MenuButtonBracketFg
			bracketBg   = $script:MenuButtonBracketBg
			onClickFg          = $script:MenuButtonOnClickFg
			onClickBg          = $script:MenuButtonOnClickBg
			onClickHotkeyFg    = $script:MenuButtonOnClickHotkey
			onClickPipeFg      = $script:MenuButtonOnClickSeparatorFg
		onClickBracketFg   = $script:MenuButtonOnClickBracketFg
		onClickBracketBg   = $script:MenuButtonOnClickBracketBg
	})
}
				
				# Advance position statically
					$currentMenuX = $itemStartX + $itemDisplayWidth
					
				if ($menuFormat -eq 2) {
					Write-Buffer -Text " " -BG $_mrBg
					$currentMenuX += 1
				} else {
					Write-Buffer -Text "  " -BG $_mrBg
					$currentMenuX += 2
				}
				}
				
				# Add spacing before right-side cluster (right-align quit; ? button sits just left of quit)
			if ($menuFormat -lt 2) {
				$desiredQuitX = $HostWidth - $_bpH - 2 - $quitWidth  # leave room for inner right padding + group bg
				# In full mode, gap ends at the ? button start; otherwise gap ends at quit start
				$gapTarget = if ($Output -eq "full") { $desiredQuitX - 2 - $helpButtonWidth } else { $desiredQuitX }
			$spacing = [math]::Max(1, $gapTarget - $currentMenuX)
			Write-Buffer -Text (" " * $spacing) -BG $_mrBg
			$currentMenuX += $spacing
			}

			# Render ? help button (full mode only; hidden in format 2 / short mode)
			if ($Output -eq "full" -and $menuFormat -lt 2) {
				$helpStartX  = $currentMenuX
				$helpHotkey  = "?"
				$hIsPressed  = ($null -ne $script:PressedMenuButton -and $script:PressedMenuButton -eq $helpHotkey)
				$hBtnBg      = if ($hIsPressed) { $script:MenuButtonOnClickBg }        else { $script:MenuButtonBg }
				$hBtnHkFg    = if ($hIsPressed) { $script:MenuButtonOnClickHotkey }    else { $script:MenuButtonHotkey }
				$hBracketFg  = if ($hIsPressed) { $script:MenuButtonOnClickBracketFg } else { $script:MenuButtonBracketFg }
				$hBracketBg  = if ($hIsPressed) { $script:MenuButtonOnClickBracketBg } else { $script:MenuButtonBracketBg }
				if ($script:MenuButtonShowBrackets) {
					Write-Buffer -X $helpStartX -Y $menuY -Text "[" -FG $hBracketFg -BG $hBracketBg
				}
				$hContentX = $helpStartX + [int]$script:MenuButtonShowBrackets
				Write-Buffer -X $hContentX -Y $menuY -Text "?" -FG $hBtnHkFg -BG $hBtnBg
				if ($script:MenuButtonShowBrackets) {
					Write-Buffer -Text "]" -FG $hBracketFg -BG $hBracketBg
				}
				$helpEndX = $helpStartX + $helpButtonWidth - 1
			$null = $script:MenuItemsBounds.Add(@{
				startX           = $helpStartX
				endX             = $helpEndX
				y                = $menuY
				hotkey           = $helpHotkey
				isHelpButton     = $true
				index            = -1
				displayText      = "?"
					format           = $menuFormat
					fg               = $script:MenuButtonText
					bg               = $script:MenuButtonBg
					hotkeyFg         = $script:MenuButtonHotkey
					pipeFg           = $script:MenuButtonSeparatorFg
					bracketFg        = $script:MenuButtonBracketFg
					bracketBg        = $script:MenuButtonBracketBg
					onClickFg        = $script:MenuButtonOnClickFg
					onClickBg        = $script:MenuButtonOnClickBg
					onClickHotkeyFg  = $script:MenuButtonOnClickHotkey
					onClickPipeFg    = $script:MenuButtonOnClickSeparatorFg
				onClickBracketFg = $script:MenuButtonOnClickBracketFg
				onClickBracketBg = $script:MenuButtonOnClickBracketBg
			})
		$currentMenuX = $helpStartX + $helpButtonWidth
			Write-Buffer -Text "  " -BG $_mrBg
			$currentMenuX += 2
		}
				
				# Write quit item
				$quitStartX = $currentMenuX
				if ($menuFormat -eq 0) {
					$itemText = $quitItem.full
				} elseif ($menuFormat -eq 1) {
					$itemText = $quitItem.noIcons
				} else {
					$itemText = $quitItem.short
				}
				
	# Resolve hotkey and pressed-state colors for quit button
	$quitHotkeyMatch = $itemText -match "\(([a-z])\)"
	$quitHotkey = if ($quitHotkeyMatch) { $matches[1] } else { $null }
	$qIsPressed      = ($null -ne $script:PressedMenuButton -and $script:PressedMenuButton -eq $quitHotkey)
	$qBtnFg          = if ($qIsPressed) { $script:QuitButtonOnClickFg }         else { $script:QuitButtonText }
	$qBtnBg          = if ($qIsPressed) { $script:QuitButtonOnClickBg }         else { $script:QuitButtonBg }
	$qBtnHkFg        = if ($qIsPressed) { $script:QuitButtonOnClickHotkey }     else { $script:QuitButtonHotkey }
	$qBtnPipeFg      = if ($qIsPressed) { $script:QuitButtonOnClickSeparatorFg } else { $script:QuitButtonSeparatorFg }
	$qBtnBracketFg   = if ($qIsPressed) { $script:QuitButtonOnClickBracketFg }  else { $script:QuitButtonBracketFg }
	$qBtnBracketBg   = if ($qIsPressed) { $script:QuitButtonOnClickBracketBg }  else { $script:QuitButtonBracketBg }

	if ($menuFormat -eq 0) {
		$parts = $itemText -split "\|", 2
		if ($parts.Count -eq 2) {
			$emoji = $parts[0]
			$text = $parts[1]
			$contentX = $quitStartX
			if ($script:MenuButtonShowBrackets) {
				Write-Buffer -X $contentX -Y $menuY -Text "[" -FG $qBtnBracketFg -BG $qBtnBracketBg
				$contentX += 1
			}
			if ($script:MenuButtonShowIcon) {
				Write-Buffer -X $contentX -Y $menuY -Text $emoji -BG $qBtnBg -Wide
				$sepX = $contentX + 2
				Write-Buffer -X $sepX -Y $menuY -Text $script:MenuButtonSeparator -FG $qBtnPipeFg -BG $qBtnBg
			} else {
				Write-Buffer -X $contentX -Y $menuY -Text "" -BG $qBtnBg
			}
	Write-HotkeyLabel -Text $text -FG $qBtnFg -HotkeyFg $qBtnHkFg -BG $qBtnBg
	if ($script:MenuButtonShowBrackets) {
		Write-Buffer -Text "]" -FG $qBtnBracketFg -BG $qBtnBracketBg
	}
}
} else {
		Write-Buffer -X $quitStartX -Y $menuY -Text "" -BG $qBtnBg
		Write-HotkeyLabel -Text $itemText -FG $qBtnFg -HotkeyFg $qBtnHkFg -BG $qBtnBg
	}
			
	# Store quit item bounds (computed statically)
	$quitEndX = $quitStartX + $quitWidth - 1
	$null = $script:MenuItemsBounds.Add(@{
	startX      = $quitStartX
	endX        = $quitEndX
	y           = $menuY
	hotkey      = $quitHotkey
	index       = $menuItems.Count - 1
	displayText = $itemText
	format      = $menuFormat
	fg          = $script:QuitButtonText
	bg          = $script:QuitButtonBg
	hotkeyFg    = $script:QuitButtonHotkey
	pipeFg      = $script:QuitButtonSeparatorFg
	bracketFg   = $script:QuitButtonBracketFg
	bracketBg   = $script:QuitButtonBracketBg
	onClickFg          = $script:QuitButtonOnClickFg
	onClickBg          = $script:QuitButtonOnClickBg
	onClickHotkeyFg    = $script:QuitButtonOnClickHotkey
	onClickPipeFg      = $script:QuitButtonOnClickSeparatorFg
	onClickBracketFg   = $script:QuitButtonOnClickBracketFg
	onClickBracketBg   = $script:QuitButtonOnClickBracketBg
	})
				
		# Clear remaining (inner right padding + group-bg handled by inset writes below)
		$menuEndX = $quitStartX + $quitWidth
	if ($menuEndX -lt $HostWidth) {
			Write-Buffer -Text (" " * ($HostWidth - $menuEndX)) -BG $_mrBg
		}
		# Outer transparent padding (bpH-1), then 1 group-bg, then 2 inner row-bg on each side
		if ($_bpH -gt 1) { Write-Buffer -X 0                     -Y $menuY -Text (" " * ($_bpH - 1)) }  # transparent left outer
		Write-Buffer -X ($_bpH - 1)           -Y $menuY -Text " "            -BG $_fBg                   # 1 group-bg left
		Write-Buffer -X $_bpH                 -Y $menuY -Text "  "           -BG $_mrBg                  # 2 inner left  (row bg)
		Write-Buffer -X ($HostWidth-$_bpH-2)  -Y $menuY -Text "  "           -BG $_mrBg                  # 2 inner right (row bg)
		Write-Buffer -X ($HostWidth-$_bpH)    -Y $menuY -Text " "            -BG $_fBg                   # 1 group-bg right
		if ($_bpH -gt 1) { Write-Buffer -X ($HostWidth-$_bpH+1) -Y $menuY -Text (" " * ($_bpH - 1)) }  # transparent right outer
		$Outputline++
				
if ($_bpV -eq 1) {
	# Last row: -NoWrap prevents console scroll when writing the final cell
	if ($_bpH -gt 1) {
			Write-Buffer -X 0                    -Y $Outputline -Text (" " * ($_bpH - 1))                             # transparent left
			Write-Buffer -X ($_bpH - 1)          -Y $Outputline -Text (" " * ($HostWidth - 2*$_bpH + 2)) -BG $_fBg   # group-bg centre
			Write-Buffer -X ($HostWidth-$_bpH+1) -Y $Outputline -Text (" " * ($_bpH - 1)) -NoWrap                    # transparent right (NoWrap on last)
		} else {
			Write-Buffer -X 0 -Y $Outputline -Text (" " * $HostWidth) -BG $_fBg -NoWrap
		}
		# Do NOT increment $Outputline — reserved row is the scroll guard.
	} else {
		# For bpV>=2 write the 1-minimum FooterBg blank (transparent outer, group-bg inner)
		if ($_bpH -gt 1) { Write-Buffer -X 0                    -Y $Outputline -Text (" " * ($_bpH - 1)) }                           # transparent left
		Write-Buffer -X ($_bpH - 1)          -Y $Outputline -Text (" " * ($HostWidth - 2*$_bpH + 2)) -BG $_fBg                       # group-bg centre
		if ($_bpH -gt 1) { Write-Buffer -X ($HostWidth-$_bpH+1) -Y $Outputline -Text (" " * ($_bpH - 1)) }                           # transparent right
		$Outputline++
		# ... then any extra plain blanks (bpV-2 rows).
		# The reserved row at $HostHeight-1 acts as the final extra plain blank.
		for ($__bpi = 0; $__bpi -lt ($_bpV - 2); $__bpi++) {
			Write-Buffer -X 0 -Y $Outputline -Text (" " * $HostWidth)
			$Outputline++
		}
	}
	# Atomic flush — ClearFirst on forced redraws to eliminate stale content
	if (-not $NoFlush) { if ($ClearFirst) { Flush-Buffer -ClearFirst } else { Flush-Buffer } }
		if ($script:DiagEnabled -and $_isViewerMode -and $script:LoopIteration -le 5) {
			"$(Get-Date -Format 'HH:mm:ss.fff') - VIEWER RENDER FLUSHED iter=$($script:LoopIteration) ClearFirst=$ClearFirst Rows=$Rows HostWidth=$HostWidth RenderQueue=$($script:RenderQueue.Count)" | Out-File $script:IpcDiagFile -Append
		}
	} elseif ($Output -eq "hidden") {
		$script:ModeButtonBounds        = $null  # Header not rendered in hidden mode
		$script:ModeLabelBounds         = $null
		$script:HeaderEndTimeBounds     = $null
		$script:HeaderCurrentTimeBounds = $null
		$script:HeaderLogoBounds        = $null
		if (-not $skipConsoleUpdate) {
			# Use live window dimensions so the incognito button stays correctly placed during resize
			$pswindow = (Get-Host).UI.RawUI
				$newW = $pswindow.WindowSize.Width
				$newH = $pswindow.WindowSize.Height
				
				$timeStr = $date.ToString("HH:mm:ss")
				$statusLine = "$timeStr | running..."
				
				Write-Buffer -X 0 -Y 0 -Text $statusLine.PadRight($newW)
				
			$hBtnY = [math]::Max(1, $newH - 2)
			$hBtnX = [math]::Max(0, $newW - 4)
	$hIsPressed = ($script:PressedMenuButton -eq "i")
	$hBtnFg   = if ($hIsPressed) { $script:MenuButtonOnClickFg }     else { $script:MenuButtonText }
	$hBtnBg   = if ($hIsPressed) { $script:MenuButtonOnClickBg }     else { $script:MenuButtonBg }
	$hBtnHkFg = if ($hIsPressed) { $script:MenuButtonOnClickHotkey } else { $script:MenuButtonHotkey }
	Write-Buffer -X $hBtnX -Y $hBtnY -Text "(" -FG $hBtnFg -BG $hBtnBg
	Write-Buffer -Text "i" -FG $hBtnHkFg -BG $hBtnBg
	Write-Buffer -Text ")" -FG $hBtnFg -BG $hBtnBg
			
			if (-not $NoFlush) { if ($ClearFirst) { Flush-Buffer -ClearFirst } else { Flush-Buffer } }
			
	$script:MenuItemsBounds.Clear()
	$null = $script:MenuItemsBounds.Add(@{
		startX      = $hBtnX
		endX        = $hBtnX + 2
		y           = $hBtnY
	hotkey      = "i"
	index       = 0
	displayText = "(i)"
			format      = 1
			fg          = $script:MenuButtonText
			bg          = $script:MenuButtonBg
			hotkeyFg    = $script:MenuButtonHotkey
			pipeFg      = $script:MenuButtonSeparatorFg
			bracketFg   = $script:MenuButtonBracketFg
			bracketBg   = $script:MenuButtonBracketBg
			onClickFg          = $script:MenuButtonOnClickFg
			onClickBg          = $script:MenuButtonOnClickBg
			onClickHotkeyFg    = $script:MenuButtonOnClickHotkey
			onClickPipeFg      = $script:MenuButtonOnClickSeparatorFg
			onClickBracketFg   = $script:MenuButtonOnClickBracketFg
			onClickBracketBg   = $script:MenuButtonOnClickBracketBg
		})
			}
		}
	} # end Write-MainFrame
