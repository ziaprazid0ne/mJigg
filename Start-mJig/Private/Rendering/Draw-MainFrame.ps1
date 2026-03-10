	function Draw-MainFrame {
	param(
		[switch]$ClearFirst,
		[switch]$Force,
		[switch]$NoFlush,
		$Date = $null
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

			# Output Handling
			# Skip console updates if mouse movement was recently detected (every 50ms check) to prevent stutter
			# This prevents blocking console operations from interfering with Windows mouse message processing
			$skipConsoleUpdate = if ($_isViewerMode) { $false } else { (Get-TimeSinceMs -startTime $script:LastMouseMovementTime) -lt 200 }
			# Force parameter overrides skipConsoleUpdate
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

			# Output header
		# Refresh current time. The hourly ClearCachedData() call earlier in the loop
		# ensures timezone changes are picked up without invalidating the cache every frame.
		$currentTime = $date.ToString("HHmm")
			# Calculate widths for centering times between mJig title and view tag
			# Left part: "mJig(`u{1F400})" = 5 + 2 + 1 = 8 (content only; $_bpH+2 left margin handled separately)
			$headerLeftWidth = 5 + 2 + 1  # "mJig(" + emoji + ")"
				# Add DEBUGMODE text width if in debug mode
				if ($DebugMode) {
					$headerLeftWidth += 13  # " - DEBUGMODE" = 13 chars
				}
				
				# Time section: "Current`u{23F3}/" + time + " ➣  " + "End`u{23F3}/" + time (or "none")
				# Components: "Current" (7) + emoji (2) + "/" (1) + time + " ➣  " (4) + "End" (3) + emoji (2) + "/" (1) + time
				$timeSectionBaseWidth = 7 + 2 + 1 + 4 + 3 + 2 + 1  # Fixed text parts
				# Determine end time display text
				if ($endTimeInt -eq -1 -or [string]::IsNullOrEmpty($endTimeStr)) {
					$endTimeDisplay = "none"
				} else {
					$endTimeDisplay = $endTimeStr
				}
				$timeSectionTimeWidth = $currentTime.Length + $endTimeDisplay.Length
				$timeSectionWidth = $timeSectionBaseWidth + $timeSectionTimeWidth
				
		# Right part: output button (clickable, right-aligned)
		# Format: [(o)utput]|Full — button is just [(o)utput], separator and mode name are plain trailing text
		# Separator char uses $script:MenuButtonSeparator but is not part of the clickable button.
	$modeName = if ($Output -eq "full") { "Full" } else { " Min" }  # pad Min to match Full width
	$modeBracketWidth = if ($script:MenuButtonShowBrackets) { 2 } else { 0 }
	$hotkeyParenAdj = if ($script:MenuButtonShowHotkeyParens) { 0 } else { -2 }
	$modeButtonOnlyWidth = $modeBracketWidth + 8 + $hotkeyParenAdj   # brackets + "(o)utput"
		# Total display width: button + " " + separator + " " + modeName
		$modeButtonWidth = $modeButtonOnlyWidth + 1 + $script:MenuButtonSeparator.Length + 1 + $modeName.Length
			$rightMarginWidth = 0  # inner right padding handled by inset writes

			# Calculate spacing to center times between left and right parts
			$totalUsedWidth = $headerLeftWidth + $timeSectionWidth + $modeButtonWidth + $rightMarginWidth
				$remainingSpace = $HostWidth - 2 * ($_bpH + 2) - $totalUsedWidth
				$spacingBeforeTimes = [math]::Max(1, [math]::Floor($remainingSpace / 2))
				$spacingAfterTimes = [math]::Max(1, $remainingSpace - $spacingBeforeTimes)
				
		$mouseEmoji = $script:MouseEmoji
		$hourglassEmoji = $script:HourglassEmoji
	Write-Buffer -X ($_bpH + 2) -Y $Outputline -Text "mJig(" -FG $script:HeaderAppName -BG $_hrBg
	$curX = $_bpH + 2 + 5  # content starts at bpH+2; "mJig(" = 5 chars
			Write-Buffer -Text $mouseEmoji -FG $script:HeaderIcon -BG $_hrBg
		Write-Buffer -X ($curX + 2) -Y $Outputline -Text ")" -FG $script:HeaderAppName -BG $_hrBg
		$curX = $curX + 2 + 1  # emoji (2) + ")" (1)
		$script:HeaderLogoBounds = @{ y = $Outputline; startX = ($_bpH + 2); endX = ($curX - 1) }
		# Add DEBUGMODE indicator if in debug mode
		if ($DebugMode) {
			Write-Buffer -Text " - DEBUGMODE" -FG $script:TextError -BG $_hrBg
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
		$arrowTriangle = [char]0x27A3  # ➣
		Write-Buffer -Text " $arrowTriangle  " -BG $_hrBg
		$curX += 4  # " ➣  " = 4 display chars
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
		# Render mode button (clickable) then separator + mode name (plain, non-clickable)
	$modeButtonStartX = $curX
	if ($script:MenuButtonShowBrackets) {
		Write-Buffer -X $modeButtonStartX -Y $Outputline -Text "[" -FG $script:MenuButtonBracketFg -BG $script:MenuButtonBracketBg
		if ($script:MenuButtonShowHotkeyParens) { Write-Buffer -Text "(" -FG $script:MenuButtonText -BG $script:MenuButtonBg } else { Write-Buffer -Text "" -BG $script:MenuButtonBg }
	} else {
		if ($script:MenuButtonShowHotkeyParens) { Write-Buffer -X $modeButtonStartX -Y $Outputline -Text "(" -FG $script:MenuButtonText -BG $script:MenuButtonBg } else { Write-Buffer -X $modeButtonStartX -Y $Outputline -Text "" -BG $script:MenuButtonBg }
	}
	Write-Buffer -Text "o" -FG $script:MenuButtonHotkey -BG $script:MenuButtonBg
	if ($script:MenuButtonShowHotkeyParens) { Write-Buffer -Text ")" -FG $script:MenuButtonText -BG $script:MenuButtonBg }
	Write-Buffer -Text "utput" -FG $script:MenuButtonText -BG $script:MenuButtonBg
	if ($script:MenuButtonShowBrackets) {
		Write-Buffer -Text "]" -FG $script:MenuButtonBracketFg -BG $script:MenuButtonBracketBg
	}
	# Separator and mode name are plain header text — not part of the clickable area
	Write-Buffer -Text " $($script:MenuButtonSeparator)" -FG $script:MenuButtonSeparatorFg -BG $_hrBg
	Write-Buffer -Text " $modeName" -FG $script:HeaderViewTag -BG $_hrBg
		$curX += $modeButtonWidth
		$script:ModeButtonBounds = @{
			y      = $Outputline
			startX = $modeButtonStartX
			endX   = $modeButtonStartX + $modeButtonOnlyWidth - 1
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
			$boxWidth = 50  # Width for stats box
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
									# Truncate this component if it's the last one and we have some room
									if ($remainingWidth -gt 3) {
										$formattedLine += $componentText.Substring(0, $remainingWidth - 3) + "..."
									}
									break
								}
							}
							
							# Clear the line first, then write the new content
							# Pad with spaces to clear any leftover characters and ensure exact width
							# Truncate if longer, pad if shorter to ensure exactly $availableWidth characters
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
							
							# Draw stats box in full view (with padding so it doesn't touch white lines)
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
									$boxHeader = "Stats"
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
									Write-Buffer -Text "Detected Inputs:".PadRight($boxWidth - 2) -FG $script:StatsBoxTitle
									Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
								} elseif ($i -eq $Rows - 3) {
									if ($PreviousIntervalKeys.Count -gt 0) {
										Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
										Write-Buffer -Text $keysFirstLine.PadRight($boxWidth - 2) -FG $script:StatsBoxValue
										Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
									} else {
										Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
										Write-Buffer -Text "(none)".PadRight($boxWidth - 2) -FG $script:TextMuted
										Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
									}
								} elseif ($i -eq $Rows - 2) {
									if ($PreviousIntervalKeys.Count -gt 0 -and $keysSecondLine -ne "") {
										Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
										Write-Buffer -Text $keysSecondLine.PadRight($boxWidth - 2) -FG $script:StatsBoxValue
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
									Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
									Write-Buffer -Text (" " * ($boxWidth - 2))
									Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
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
									Write-Buffer -Text "Stats".PadRight($boxWidth - 2) -FG $script:StatsBoxTitle
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
									Write-Buffer -Text "Detected Inputs:".PadRight($boxWidth - 2) -FG $script:StatsBoxTitle
									Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
								} elseif ($i -eq $Rows - 3) {
									if ($PreviousIntervalKeys.Count -gt 0) {
										Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
										Write-Buffer -Text $keysFirstLine.PadRight($boxWidth - 2) -FG $script:StatsBoxValue
										Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
									} else {
										Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
										Write-Buffer -Text "(none)".PadRight($boxWidth - 2) -FG $script:TextMuted
										Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
									}
								} elseif ($i -eq $Rows - 2) {
									if ($PreviousIntervalKeys.Count -gt 0 -and $keysSecondLine -ne "") {
										Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
										Write-Buffer -Text $keysSecondLine.PadRight($boxWidth - 2) -FG $script:StatsBoxValue
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
									Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
									Write-Buffer -Text (" " * ($boxWidth - 2))
									Write-Buffer -Text "$($script:BoxVertical)" -FG $script:StatsBoxBorder
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
		$emojiLock = $script:LockEmoji
		$emojiGear = $script:GearEmoji
			$emojiRedX = $script:RedXEmoji
				
			$menuItemsList = @(
				@{
					full            = "$emojiGear|(s)ettings"
					noIcons         = "(s)ettings"
					short           = "(s)et"
					isSettingsButton = $true
				},
			@{
				full    = "$emojiLock|(i)ncognito"
				noIcons = "(i)ncognito"
				short   = "(i)nc"
			}
			)

			$menuItemsList += @{
				full    = "$emojiRedX|(q)uit"
				noIcons = "(q)uit"
				short   = "(q)uit"
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
				
			# Restore pressed-button highlight when appropriate:
			# - Immediate actions (toggle, hide): clear on the very first render after the click (no dialog opened)
			# - Popup actions (dialogs): the dialog is blocking so this render only runs after it closes — clear then too
			# - While a dialog IS open: skip this block so the button stays highlighted throughout the dialog
			if ($script:PendingDialogCheck -and $null -ne $script:PressedMenuButton) {
				if ($null -eq $script:DialogButtonBounds) {
					# No dialog is open: either the action was immediate or the dialog just closed — clear now
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
	Write-HotkeyLabel -Text $text -FG $btnFg -HotkeyFG $btnHkFg -BG $btnBg
		if ($script:MenuButtonShowBrackets) {
			Write-Buffer -Text "]" -FG $btnBracketFg -BG $btnBracketBg
		}
	}
} else {
			Write-Buffer -X $itemStartX -Y $menuY -Text "" -BG $btnBg
			Write-HotkeyLabel -Text $itemText -FG $btnFg -HotkeyFG $btnHkFg -BG $btnBg
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
	Write-HotkeyLabel -Text $text -FG $qBtnFg -HotkeyFG $qBtnHkFg -BG $qBtnBg
	if ($script:MenuButtonShowBrackets) {
		Write-Buffer -Text "]" -FG $qBtnBracketFg -BG $qBtnBracketBg
	}
}
} else {
		Write-Buffer -X $quitStartX -Y $menuY -Text "" -BG $qBtnBg
		Write-HotkeyLabel -Text $itemText -FG $qBtnFg -HotkeyFG $qBtnHkFg -BG $qBtnBg
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
		# For bpV=1 the reserved row (Y=$HostHeight-1) is the 1-minimum footer blank.
		# NoWrap disables auto-wrap so writing the last cell doesn't trigger a console scroll.
		# bpV=1: handle transparency based on $_bpH; apply NoWrap to the last segment.
		if ($_bpH -gt 1) {
			Write-Buffer -X 0                    -Y $Outputline -Text (" " * ($_bpH - 1))                             # transparent left
			Write-Buffer -X ($_bpH - 1)          -Y $Outputline -Text (" " * ($HostWidth - 2*$_bpH + 2)) -BG $_fBg   # group-bg centre
			Write-Buffer -X ($HostWidth-$_bpH+1) -Y $Outputline -Text (" " * ($_bpH - 1)) -NoWrap                    # transparent right (NoWrap on last)
		} else {
			Write-Buffer -X 0 -Y $Outputline -Text (" " * $HostWidth) -BG $_fBg -NoWrap
		}
		# Do NOT increment $Outputline — reserved row is the scroll guard.
	} else {
		# For bpV≥2 write the 1-minimum FooterBg blank (transparent outer, group-bg inner)
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
		# Flush entire UI to console in one operation
		# Use ClearFirst on forced redraws (startup transition, resize, re-open after dialog)
		# to atomically clear stale content and paint the new frame in one write.
		if (-not $NoFlush) { if ($ClearFirst) { Flush-Buffer -ClearFirst } else { Flush-Buffer } }
		if ($script:DiagEnabled -and $_isViewerMode -and $script:LoopIteration -le 5) {
			"$(Get-Date -Format 'HH:mm:ss.fff') - VIEWER RENDER FLUSHED iter=$($script:LoopIteration) ClearFirst=$ClearFirst Rows=$Rows HostWidth=$HostWidth RenderQueue=$($script:RenderQueue.Count)" | Out-File $script:IpcDiagFile -Append
		}
	} elseif ($Output -eq "hidden") {
		$script:ModeButtonBounds        = $null  # Header not rendered in hidden mode
		$script:HeaderEndTimeBounds     = $null
		$script:HeaderCurrentTimeBounds = $null
		$script:HeaderLogoBounds        = $null
		if (-not $skipConsoleUpdate) {
			# Use live window dimensions for layout so the (h) button is always correctly
				# positioned even while a resize is in progress. The outer resize path (above)
				# handles updating $HostWidth/$HostHeight and firing Send-ResizeExitWakeKey
				# once the window has been stable for $ResizeThrottleMs.
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
	} # end Draw-MainFrame
