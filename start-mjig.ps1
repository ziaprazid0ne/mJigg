function Start-mJig {

	#############################################################
	## mJig - An overly complex powershell mouse jiggling tool ##
	#############################################################

	<#    _                       __
		/   \                  /      \
	   '      \              /          \
	  |       |Oo          o|            |
	  `    \  |OOOo......oOO|   /        |
	   `    \\OOOOOOOOOOOOOOO\//        /
		 \ _o\OOOOOOOOOOOOOOOO//. ___ /
	 ______OOOOOOOOOOOOOOOOOOOOOOOo.___
	  --- OO'* `OOOOOOOOOO'*  `OOOOO--
		  OO.   OOOOOOOOO'    .OOOOO o
		  `OOOooOOOOOOOOOooooOOOOOO'OOOo
		.OO "OOOOOOOOOOOOOOOOOOOO"OOOOOOOo
	__ OOOOOO`OOOOOOOOOOOOOOOO"OOOOOOOOOOOOo
	___OOOOOOOO_"OOOOOOOOOOO"_OOOOOOOOOOOOOOOO
	 OOOOO^OOOO0`(____)/"OOOOOOOOOOOOO^OOOOOO
	 OOOOO OO000/00||00\000000OOOOOOOO OOOOOO
	 OOOOO O0000000000000000 ppppoooooOOOOOO
	 `OOOOO 0000000000000000 QQQQ "OOOOOOO"
	  o"OOOO 000000000000000oooooOOoooooooO'
	  OOo"OOOO.00000000000000000OOOOOOOO'
	 OOOOOO QQQQ 0000000000000000000OOOOOOO
	OOOOOO00eeee00000000000000000000OOOOOOOO.
	OOOOOOOO000000000000000000000000OOOOOOOOOO
	OOOOOOOOO00000000000000000000000OOOOOOOOOO
	`OOOOOOOOO000000000000000000000OOOOOOOOOOO
	 "OOOOOOOO0000000000000000000OOOOOOOOOOO'
	   "OOOOOOO00000000000000000OOOOOOOOOO"
	.ooooOOOOOOOo"OOOOOOO000000000000OOOOOOOOOOO"
	.OOO"""""""""".oOOOOOOOOOOOOOOOOOOOOOOOOOOOOo
	OOO         QQQQO"'                     `"QQQQ
	OOO
	`OOo.
	`"OOOOOOOOOOOOoooooooo#>

    ###################
	## Ideas & Notes ##
	###################

	# Need More inconography in output.
	# Propper hidden option
	# stealth toggle for hiding ui (to be seperate from hidden option).
	# Add a routine to determine the direction the cursor moved and add a corosponding arrow emoji to the log. https://unicode.org/emoji/charts/full-emoji-list.html
	# Add indecator for current output mode in top bar

	param(
		[Parameter(Mandatory = $false)] 
		[string]$endTime = "2400",
		[Parameter(Mandatory = $false)] 
		[string]$Output = "full"
	)

	############
	## Config ## 
	############
	
	$defualtEndTime = 1807 # 4-digit 24 hour format ie. 1807=(6:07 PM). If no end time is provided this default time will be used
	$defualtEndMaxVariance = 15 # A defualt max tolerance in Minutes. Randomly adds or sutracts a set number of minutes from the defaultEndTime to avoid overly consistant end times. (Does not apply if end time is specified.)

	$intervalSeconds = 10 # sets the base interval time between refreshes
	$intervalVariance = 2 # Sets the maximum random plus and minus variance in seconds each refresh

	############
	## Preparing ##
	############ 

	# Initialize Variables
	$lastPos = $null
	$oldBufferSize = $null
	$oldWindowSize = $null
	$rows = 0
	$oldRows = 0
	$skipUpdate = $false
	$posUpdate = $false
	$time = $false
	$logArray = @()
	$hostWidth = 0
	$hostHeight = 0
	$Outputline = 0
	$lastMovementTime = $null

	# Prep the Host Console
	[Console]::CursorVisible = $false
	if ($Output -ne "hidden") {
		Clear-Host
	}
	
	# Capture Initial Buffer & Window Sizes (needed even for hidden mode)
	$pshost = Get-Host
	$pswindow = $pshost.UI.RawUI
	$newBufferSize = $pswindow.BufferSize
	$newWindowSize = $pswindow.WindowSize
	$oldBufferSize = $newBufferSize
	$oldWindowSize = $newWindowSize
	$hostWidth = $newBufferSize.Width
	$hostHeight = $newBufferSize.Height

	# Initialize the Output Array
	if ($Output -ne "hidden") {
		$logArray = @()
	}

	###############################
	## Calculating the End Times ##
	###############################
	
	# Convert endTime to string and pad if needed
	$endTimeStr = $endTime.ToString().PadLeft(4, '0')
	
	# If default value (2400) was provided, use default time logic
	if ($endTimeStr -eq "2400") {
		$endTimeInt = $defualtEndTime
		$endTimeStr = $endTimeInt.ToString().PadLeft(4, '0')
	} else {
		# Try to parse as integer for validation
		try {
			$endTimeInt = [int]$endTimeStr
		} catch {
			Write-Host "Error: Invalid endTime format: $endTime" -ForegroundColor Red
			return
		}
	}
	
	# Validate the time format
	if ($endTimeStr.Length -eq 4 -and $endTimeInt -ge 0 -and $endTimeInt -le 2400) {
		Add-Type -AssemblyName System.Windows.Forms
		
		# Add Windows API for system-wide keyboard detection and key sending
		try {
			Add-Type -TypeDefinition @"
				using System;
				using System.Runtime.InteropServices;
				public class Keyboard {
					[DllImport("user32.dll")]
					public static extern short GetAsyncKeyState(int vKey);
					
					[DllImport("user32.dll", CharSet = CharSet.Auto, CallingConvention = CallingConvention.StdCall)]
					public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, int dwExtraInfo);
					
					public const uint KEYEVENTF_KEYUP = 0x0002;
					public const int VK_RMENU = 0xA5;  // Right Alt key (modifier, won't type anything)
				}
"@ -ErrorAction SilentlyContinue
		} catch {
			# Type already exists, try to remove and re-add
			try {
				Remove-Type -TypeName Keyboard -ErrorAction SilentlyContinue
			} catch {}
			try {
				Add-Type -TypeDefinition @"
					using System;
					using System.Runtime.InteropServices;
					public class Keyboard {
						[DllImport("user32.dll")]
						public static extern short GetAsyncKeyState(int vKey);
						
						[DllImport("user32.dll", CharSet = CharSet.Auto, CallingConvention = CallingConvention.StdCall)]
						public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, int dwExtraInfo);
						
						public const uint KEYEVENTF_KEYUP = 0x0002;
						public const int VK_RMENU = 0xA5;  // Right Alt key (modifier, won't type anything)
					}
"@ -ErrorAction Stop
			} catch {
				Write-Host "Warning: Could not load keyboard API. Keyboard input simulation disabled." -ForegroundColor Yellow
			}
		}
		
		# Apply variance if using default time
		if ($endTimeInt -eq $defualtEndTime) {
			$ras = Get-Random -Maximum 3 -Minimum 1
			if ($ras -eq 1) {
				$endTimeInt = ($defualtEndTime - (Get-Random -Maximum $defualtEndMaxVariance))
			} else {
				$endTimeInt = ($defualtEndTime + (Get-Random -Maximum $defualtEndMaxVariance))
			}
			$endTimeStr = $endTimeInt.ToString().PadLeft(4, '0')
		}
		
		$currentTime = Get-Date -Format "HHmm"
		if ($endTimeInt -le [int]$currentTime) {
			$tommorow = (Get-Date).AddDays(1)
			$endDate = Get-Date $tommorow -Format "MMdd"
		} else {
			$endDate = Get-Date -Format "MMdd"
		}
		$end = "$endDate$endTimeStr"
		$time = $false

		# Initialize lastPos for mouse detection
		if ($null -eq $lastPos) {
			$lastPos = [System.Windows.Forms.Cursor]::Position
		}

		# Track start time for runtime calculation
		$scriptStartTime = Get-Date

		# Main Processing Loop
		:process do {
			# Reset state for this iteration
			$userInputDetected = $false
			$waitExecuted = $false
			$interval = 0
			$math = 0
			$date = Get-Date
			$currentTime = Get-Date -Format "HHmm"
			$forceRedraw = $false
			$automatedMovementPos = $null  # Track position after automated movement
			
			# Calculate interval and wait BEFORE doing movement (skip on first run or if forceRedraw)
			if ($null -ne $lastMovementTime -and -not $forceRedraw) {
				# Calculate random interval with variance
				# Variance can be any number, even larger than base interval
				# Get-Random -Maximum returns 0 to (max-1), so we need to add 1 to get 0 to max
				$varianceAmount = Get-Random -Minimum 0 -Maximum ($intervalVariance + 1)
				$ras = Get-Random -Maximum 2 -Minimum 0
				if ($ras -eq 0) {
					# Subtract variance
					$interval = ($intervalSeconds - $varianceAmount)
				} else {
					# Add variance
					$interval = ($intervalSeconds + $varianceAmount) 
				}
				
				# Ensure minimum interval of 1 second (variance can be larger than base interval)
				if ($interval -lt 1) {
					$interval = 1
				}
				
				# Calculate number of 200ms iterations needed (1000ms / 200ms = 5 iterations per second)
				$math = [math]::Max(1, [math]::Floor($interval * 5))
				
				$waitExecuted = $true
				$mousePosAtStart = [System.Windows.Forms.Cursor]::Position
				
				# Wait Loop - Monitor for user input during interval
				$x = 0
				:waitLoop do {
					# Check for keyboard input (system-wide)
					# Skip checking Right Alt (key code 0xA5) since we use it for automated input
					for ($keyCode = 0; $keyCode -le 255; $keyCode++) {
						# Skip Right Alt key (VK_RMENU = 0xA5) to avoid detecting our own key presses
						# Right Alt is a modifier key that won't type anything or interfere
						if ($keyCode -eq 0xA5) {
							continue
						}
						$currentKeyState = [Keyboard]::GetAsyncKeyState($keyCode)
						if (($currentKeyState -band 0x8000) -ne 0) {
							$userInputDetected = $true
							break
						}
					}
					
					# Check for console keyboard input (for menu hotkeys)
					if ($Host.UI.RawUI.KeyAvailable) {
						$keyInfo = $Host.UI.RawUI.ReadKey("IncludeKeyup,NoEcho")
						$keyPress = $keyInfo.Character
						$userInputDetected = $true
						
						if ($keyPress -eq "q") {
							# Clear screen before showing quit message
							Clear-Host
							
							# Calculate runtime
							$runtime = (Get-Date) - $scriptStartTime
							$hours = [math]::Floor($runtime.TotalHours)
							$minutes = $runtime.Minutes
							$seconds = $runtime.Seconds
							
							# Format runtime string
							$runtimeStr = ""
							if ($hours -gt 0) {
								$runtimeStr = "$hours hour"
								if ($hours -ne 1) { $runtimeStr += "s" }
								$runtimeStr += ", $minutes minute"
								if ($minutes -ne 1) { $runtimeStr += "s" }
							} elseif ($minutes -gt 0) {
								$runtimeStr = "$minutes minute"
								if ($minutes -ne 1) { $runtimeStr += "s" }
								$runtimeStr += ", $seconds second"
								if ($seconds -ne 1) { $runtimeStr += "s" }
							} else {
								$runtimeStr = "$seconds second"
								if ($seconds -ne 1) { $runtimeStr += "s" }
							}
							
							Write-Host ""
							Write-Host "  mJig(`u{1F400}) " -NoNewline -ForegroundColor Magenta
							Write-Host "Stopped" -ForegroundColor Red
							Write-Host ""
							Write-Host "  Runtime: " -NoNewline -ForegroundColor Yellow
							Write-Host $runtimeStr -ForegroundColor Green
							Write-Host ""
							return
						} elseif ($keyPress -eq "t") {
							if ($Output -eq "full") {
								$Output = "min"
							} else {
								$Output = "full"
							}
							$skipUpdate = $true
							$forceRedraw = $true
							clear-host
							# Break out of wait loop to immediately redraw
							break
						} elseif ($keyPress -eq "h") {
							if ($Output -eq "hidden") {
								$Output = "full"
							} else {
								$Output = "hidden"
							}
							$skipUpdate = $true
							$forceRedraw = $true
							clear-host
							# Break out of wait loop to immediately redraw
							break
						}
					}
					
					# Check for mouse movement (user activity)
					# Only detect as user input if it's different from our automated movement position
					$currentMousePos = [System.Windows.Forms.Cursor]::Position
					# Compare X and Y properties directly (Point objects may not compare correctly with -ne)
					if ($mousePosAtStart.X -ne $currentMousePos.X -or $mousePosAtStart.Y -ne $currentMousePos.Y) {
						# Check if this movement is from our automated movement
						if ($null -eq $automatedMovementPos -or 
							$currentMousePos.X -ne $automatedMovementPos.X -or 
							$currentMousePos.Y -ne $automatedMovementPos.Y) {
							# This is actual user movement, not our automated movement
							$userInputDetected = $true
							$lastPos = $currentMousePos
							$automatedMovementPos = $null  # Clear automated position since user moved
						}
						# If it matches our automated position, ignore it (it's from our movement)
					}
					
					# Check for window size changes
					if ($Output -ne "hidden") {
						$pshost = Get-Host
						$pswindow = $pshost.UI.RawUI
						$newBufferSize = $pswindow.BufferSize
						$newWindowSize = $pswindow.WindowSize
						if (($newBufferSize -ne $oldBufferSize) -or ($newWindowSize -ne $oldWindowSize)) {
							$oldBufferSize = $newBufferSize
							$oldWindowSize = $newWindowSize
							$hostWidth = $newBufferSize.Width
							$hostHeight = $newBufferSize.Height
							$skipUpdate = $true
							$forceRedraw = $true
							$waitExecuted = $false  # Mark that wait was interrupted, don't log this
							clear-host
							# Break out of wait loop to immediately redraw
							break
						}
					}
					
					$x++
					start-sleep -m 200
				} until ($x -ge $math)
			}
			
			# Check for window size changes (also check outside wait loop for immediate detection)
			# Only check if we haven't already detected a resize in this iteration
			if ($Output -ne "hidden" -and -not $forceRedraw) {
				$pshost = Get-Host
				$pswindow = $pshost.UI.RawUI
				$newBufferSize = $pswindow.BufferSize
				$newWindowSize = $pswindow.WindowSize
				if (($newBufferSize -ne $oldBufferSize) -or ($newWindowSize -ne $oldWindowSize)) {
					$oldBufferSize = $newBufferSize
					$oldWindowSize = $newWindowSize
					$hostWidth = $newBufferSize.Width
					$hostHeight = $newBufferSize.Height
					$skipUpdate = $true
					$forceRedraw = $true
					clear-host
				}
			}
			
			# Determine if we should skip the update based on user input
			if ($userInputDetected) {
				$skipUpdate = $true
			} elseif (-not $forceRedraw) {
				# Only set skipUpdate to false if we're not forcing a redraw
				$skipUpdate = $false
			}
			
			# Prepare UI dimensions
			$outputline = 0
			$oldRows = $rows
			$rows = $hostHeight - 6
			
			# Save current log array BEFORE building new one (this preserves the previous iteration's logs)
			$tempOldLogArray = $logArray.Clone()
			
			# Handle log array resizing when window height changes
			if ($oldRows -ne $rows) {
				if ($oldRows -lt $rows) {
					# Window got taller - add empty entries at the beginning
					$insertArray = @()
					$row = [PSCustomObject]@{
						logRow = $true
						components = @()
					}
					for ($i = 0; $i -lt ($rows - $oldRows); $i++) {
						$insertArray += $row
					}
					$tempOldLogArray = $insertArray + $tempOldLogArray
				} else {
					# Window got shorter - trim old entries from the beginning
					$trimCount = $oldRows - $rows
					if ($tempOldLogArray.Count -gt $trimCount) {
						$tempOldLogArray = $tempOldLogArray[$trimCount..($tempOldLogArray.Count - 1)]
					} else {
						$tempOldLogArray = @()
					}
				}
			}
			
			# Build new log array: take all entries from old array (they scroll up)
			# The old array already has the previous logs, we just need to keep them
			$logArray = @()
			
			# Copy all old log entries (they will scroll up by one position)
			# We keep up to (rows - 1) entries from the old array
			$maxOldEntries = $rows - 1
			$startIndex = [math]::Max(0, $tempOldLogArray.Count - $maxOldEntries)
			
			for ($i = $startIndex; $i -lt $tempOldLogArray.Count; $i++) {
				# Preserve components if they exist, otherwise create empty entry
				if ($tempOldLogArray[$i].components) {
					$logArray += [PSCustomObject]@{
						logRow = $true
						components = $tempOldLogArray[$i].components
					}
				} else {
					# Legacy format - convert to components if needed
					if ($tempOldLogArray[$i].value) {
						$logArray += [PSCustomObject]@{
							logRow = $true
							components = @(@{
								priority = 1
								text = $tempOldLogArray[$i].value
								shortText = $tempOldLogArray[$i].value
							})
						}
					} else {
						$logArray += [PSCustomObject]@{
							logRow = $true
							components = @()
						}
					}
				}
			}
			
			# Fill remaining slots with empty entries if we don't have enough old entries
			while ($logArray.Count -lt ($rows - 1)) {
				$logArray += [PSCustomObject]@{
					logRow = $true
					components = @()
				}
			}
			
			# Check current mouse position to detect user movement
			# Only check if we haven't already detected user input during the wait loop
			$currentPos = [System.Windows.Forms.Cursor]::Position
			$posUpdate = $false
			$x = 0
			$y = 0
			
			# Only check for mouse movement if we haven't already detected user input
			# and the current position is different from our last automated movement
			# Compare X and Y properties directly (Point objects may not compare correctly with -ne)
			if (-not $userInputDetected -and $null -ne $lastPos) {
				$posChanged = ($currentPos.X -ne $lastPos.X -or $currentPos.Y -ne $lastPos.Y)
				if ($posChanged) {
					# Check if this is different from our automated movement position
					$isAutomatedPos = ($null -ne $automatedMovementPos -and 
									   $currentPos.X -eq $automatedMovementPos.X -and 
									   $currentPos.Y -eq $automatedMovementPos.Y)
					if (-not $isAutomatedPos) {
						# User moved mouse - skip automated movement
						$skipUpdate = $true
						$posUpdate = $false
						$lastPos = $currentPos
						$automatedMovementPos = $null  # Clear automated position since user moved
					}
					# If it matches our automated position, ignore it (it's from our movement)
				}
			}
			
			if ($skipUpdate -ne $true) {
				# No user movement detected - perform automated movement
				$pos = [System.Windows.Forms.Cursor]::Position
				$posUpdate = $true
				$rx = Get-Random -Maximum 300
				$ry = Get-Random -Maximum 300
				$rasX = Get-Random -Maximum 2
				$rasY = Get-Random -Maximum 2
				
				if ($rasX -eq 1) {
					$x = $pos.X + $rx
				} else {
					$x = $pos.X - $rx
				}
				if ($rasY -eq 1) {
					$y = $pos.Y + $ry
				} else {
					$y = $pos.Y - $ry
				}
				
				[System.Windows.Forms.Cursor]::Position = New-Object System.Drawing.Point ($x,$y)
				$lastPos = [System.Windows.Forms.Cursor]::Position
				$automatedMovementPos = $lastPos  # Track this as our automated movement position
				
				# Send Right Alt key press (modifier key - won't type anything or interfere with apps)
				# This is needed for apps like Slack/Skype that check for keyboard activity
				# Using Right Alt specifically to avoid conflicts with Left Alt shortcuts
				try {
					$vkCode = [byte]0xA5  # VK_RMENU (Right Alt)
					[Keyboard]::keybd_event($vkCode, [byte]0, [uint32]0, [int]0)  # Key down
					Start-Sleep -Milliseconds 10
					[Keyboard]::keybd_event($vkCode, [byte]0, [uint32]0x0002, [int]0)  # Key up (KEYEVENTF_KEYUP = 0x0002)
					Start-Sleep -Milliseconds 50  # Small delay to let key state clear before next check
				} catch {
					# If keybd_event fails, continue without keyboard input
					# Mouse movement alone should still work for most cases
				}
				Start-Sleep -Milliseconds 50  # Small delay to let key state clear before next check
				
				$lastMovementTime = Get-Date
			} else {
				# skipUpdate was set - just update tracking
				$posUpdate = $false
				$lastPos = $currentPos
				if ($null -eq $lastMovementTime) {
					$lastMovementTime = Get-Date
				}
			}
			
			# Only create log entry when we complete a wait interval AND do something
			# Don't create log entries for window resize events
			$shouldCreateLogEntry = $false
			
			# If this is just a window resize (forceRedraw set), don't create log entry
			if ($forceRedraw -and -not $waitExecuted -and -not $posUpdate) {
				# This is just a window resize redraw - skip log entry completely
				$shouldCreateLogEntry = $false
			} elseif ($posUpdate) {
				# We did a movement - always log this
				$shouldCreateLogEntry = $true
			} elseif ($null -eq $lastMovementTime) {
				# First run - log this
				$shouldCreateLogEntry = $true
			} elseif ($waitExecuted -and -not $forceRedraw) {
				# We completed a wait interval (and it wasn't interrupted by resize) - log this
				$shouldCreateLogEntry = $true
			}
			
			if ($shouldCreateLogEntry) {
				# Create log message components for this iteration
				$debugInfo = ""
				if ($waitExecuted) {
					# Format: [Wait: 11s] - shorter and clearer
					$debugInfo = " [Wait: ${interval}s]"
				} else {
					$debugInfo = " [First run]"
				}
				if ($userInputDetected) {
					$debugInfo += " [KB:YES]"
				}
				
				# Build log entry components array (priority order: timestamp, message, coordinates, debug)
				$logComponents = @()
				
				# Component 1: Timestamp (full format)
				$logComponents += @{
					priority = 1
					text = $date.ToString()
					shortText = $date.ToString("HH:mm:ss")
				}
				
				# Component 2: Main message
				if ($skipUpdate -ne $true) {
					if ($posUpdate) {
						$logComponents += @{
							priority = 2
							text = " - Coordinates updated"
							shortText = " - Updated"
						}
						# Component 3: Coordinates
						$logComponents += @{
							priority = 3
							text = " x$x/y$y"
							shortText = " x$x/y$y"
						}
					} else {
						$logComponents += @{
							priority = 2
							text = " - Input detected, skipping update"
							shortText = " - Input detected"
						}
					}
				} else {
					$logComponents += @{
						priority = 2
						text = " - Update skipped"
						shortText = " - Skipped"
					}
				}
				
				# Component 4: Debug info (lowest priority)
				if ($debugInfo) {
					$logComponents += @{
						priority = 4
						text = $debugInfo
						shortText = $debugInfo
					}
				}
				
				# Add current log entry to array with components
				$logArray += [PSCustomObject]@{
					logRow = $true
					components = $logComponents
				}
			}

			# Output Handling
			if ($Output -ne "hidden") {
				# Output blank line
				$t = $true
				try {
					[Console]::SetCursorPosition(0, $Outputline)
				} catch {
					clear-host
					$t = $false
				} finally {
					if ($t) {
						for ($i = $Host.UI.RawUI.CursorPosition.x; $i -lt $hostWidth; $i++) {
							write-host " " -NoNewline
						}
					}
				}
				$Outputline++

				# Output header
				$t = $true
				try {
					[Console]::SetCursorPosition(0, $Outputline)
				} catch {
					$t = $false
				} finally {
					if ($t) {
						Write-Host "  mJig(`u{1F400})" -NoNewline -ForegroundColor Magenta
						Write-Host " ➢  " -NoNewline
						Write-Host "End`u{23F3}/" -NoNewline -ForegroundColor yellow
						Write-Host "$endTimeStr" -NoNewline -ForegroundColor Green
						Write-Host " ➣  " -NoNewline
						Write-Host "Current`u{23F3}/" -NoNewline -ForegroundColor Yellow
						Write-Host "$currentTime" -ForegroundColor Green -NoNewline
						if ($Output -eq "dib") {
							write-host " (DiB)" -ForeGroundColor Magenta -NoNewline
						} elseif ($Output -eq "full") {
							write-host " (Ful)" -ForeGroundColor Magenta -NoNewline
						} else {
							write-host " (Min)" -ForeGroundColor Magenta -NoNewline
						}
						for ($i = $Host.UI.RawUI.CursorPosition.x; $i -lt $hostWidth; $i++) {
							write-host " " -NoNewline
						}
					}
				}
				$Outputline++

				# Output Line Spacer
				$t = $true
				try {
					[Console]::SetCursorPosition(0, $Outputline)
				} catch {
					$t = $false
				} finally {
					if ($t) {
						for ($i = $Host.UI.RawUI.CursorPosition.x; $i -lt $hostWidth; $i++) {
							Write-Host " " -NoNewLine
							write-host ("─" * ($hostWidth - 2)) -ForegroundColor White -NoNewline
							for ($i = $Host.UI.RawUI.CursorPosition.x; $i -lt $hostWidth; $i++) {
								write-host " " -NoNewline
							}
						}
					}
				}
				$outputLine++

				# Output log entries
				if ($output -ne "min") {
					for ($i = 0; $i -lt $rows; $i++) {
						$t = $true
						try {
							[Console]::SetCursorPosition(0, $Outputline)
						} catch {
							$t = $false
						} finally {
							if ($t) {
								if ($i -lt $logArray.Count -and $logArray[$i].components) {
									# Format log line based on available width with priority
									$availableWidth = $hostWidth
									$formattedLine = ""
									$useShortTimestamp = $false
									
									# Calculate total length with full components
									$fullLength = 0
									foreach ($component in $logArray[$i].components) {
										$fullLength += $component.text.Length
									}
									
									# If full length exceeds width, start using shortened timestamp
									if ($fullLength -gt $availableWidth) {
										$useShortTimestamp = $true
										# Recalculate with short timestamp
										$shortLength = 0
										foreach ($component in $logArray[$i].components) {
											if ($component.priority -eq 1) {
												$shortLength += $component.shortText.Length
											} else {
												$shortLength += $component.text.Length
											}
										}
										$fullLength = $shortLength
									}
									
									# Build line with priority-based truncation
									$remainingWidth = $availableWidth
									foreach ($component in $logArray[$i].components | Sort-Object priority) {
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
									# Pad with spaces to clear any leftover characters
									$paddedLine = $formattedLine.PadRight($availableWidth)
									write-host $paddedLine -NoNewline
									# Move to next line
									write-host ""
								} else {
									# Clear the line with spaces
									write-host (" " * $availableWidth) -NoNewline
									write-host ""
								}
							}
						}
						$outputLine++
					}
				}
			}

			# Output bottom separator
			if ($Output -ne "hidden") {
				$t = $true
				try {
					[Console]::SetCursorPosition(0, $Outputline)
				} catch {
					$t = $false
				} finally {
					if ($t) {
						for ($i = $Host.UI.RawUI.CursorPosition.x; $i -lt $hostWidth; $i++) {
							Write-Host " " -NoNewLine
							write-host ("─" * ($hostWidth - 2)) -ForegroundColor White -NoNewline
							for ($i = $Host.UI.RawUI.CursorPosition.x; $i -lt $hostWidth; $i++) {
								write-host " " -NoNewline
							}
						}
					}
				}
				$outputLine++

				## Menu Options ##
				$t = $true
				try {
					[Console]::SetCursorPosition(0, $Outputline)
				} catch {
					$t = $false
				} finally {
					if ($t) {
						write-host "  " -NoNewLine
						write-host "`u{1F39A}`u{FE0F}" -NoNewLine
						write-host "(" -NoNewline -ForegroundColor White
						write-host "t" -ForegroundColor Yellow -NoNewline
						write-host ")" -NoNewLine  -ForegroundColor White
						write-host "oggle_output " -ForegroundColor Green -nonewline
						write-host "`u{1FAE3}" -NoNewline
						write-host "(" -NoNewLine  -ForegroundColor White
						write-host "h" -ForegroundColor Yellow -NoNewline
						write-host ")" -ForegroundColor White -NoNewline
						write-host "ide_output" -ForegroundColor Green -NoNewline
						write-host (" " * ($hostWidth - 46)) -NoNewLine
						write-host "`u{1F400}" -NoNewline
						write-host "(" -NoNewLine  -ForegroundColor White
						write-host "q" -ForegroundColor Yellow -NoNewline
						write-host ")" -NoNewLine
						write-host "uit" -ForegroundColor Green -NoNewline
						for ($i = $Host.UI.RawUI.CursorPosition.x; $i -lt $hostWidth; $i++) {
							write-host " " -NoNewline
						}
					}
				}
				$Outputline++
			}
			
			# Check if end time reached
			$current = Get-Date -Format "MMddHHmm"
			if ($current -ge $end) {
				$time = $true
			}
		} until ($time -eq $true)
		
		# End message
		if ($output -ne "hidden") {
			[Console]::SetCursorPosition(0, $Outputline)
			Write-Host "       END TIME REACHED: " -NoNewline -ForegroundColor Red
			Write-Host "Stopping " -NoNewline
			Write-Host "mJig"
			write-host
		}
	} else {
		Write-Host "use 4-digit 24hour time format"
		Write-Host
	}
}

# Uncomment the line below to run the function when script is executed directly
# Start-mJig -Output dib
