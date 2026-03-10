		function Start-WorkerLoop {
			$_wDiag = $script:DiagEnabled
			$_wDiagFile = $null
			if ($_wDiag) {
				$_wDiagFile = Join-Path $script:DiagFolder "worker-ipc.txt"
				"=== mJig Worker IPC Diag: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff') PID=$PID ===" | Out-File $_wDiagFile
			}
			
			$pipeServer = New-Object System.IO.Pipes.NamedPipeServerStream(
				$script:PipeName,
				[System.IO.Pipes.PipeDirection]::InOut,
				1,
				[System.IO.Pipes.PipeTransmissionMode]::Byte,
				[System.IO.Pipes.PipeOptions]::Asynchronous,
				65536, 65536
			)
			$connectResult = $pipeServer.BeginWaitForConnection($null, $null)
			if ($_wDiag) { "$(Get-Date -Format 'HH:mm:ss.fff') - WORKER STARTED pipe=$($script:PipeName) bufSize=65536" | Out-File $_wDiagFile -Append }
			Show-Notification -Title 'mJig' -Body "Worker started (PID: $PID)"

			$pipeReader = $null
			$pipeWriter = $null
			$viewerConnected = $false
			
			$script:LogReplayBuffer = New-Object 'System.Collections.Generic.Queue[hashtable]' 30
			
			$workerLastPos = Get-MousePosition
			$workerLastMovementTime = $null
			$workerLastMovementDurationMs = 0
			$workerLastSimulatedKeyPress = $null
			$workerLastAutomatedMouseMovement = $null
			$workerLastUserInputTime = $null
			$workerLoopIteration = 0
			$workerStateTicks = 0
			$_writeSkipCount = 0
			
			$lii = New-Object mJiggAPI.LASTINPUTINFO
			$lii.cbSize = [uint32][System.Runtime.InteropServices.Marshal]::SizeOf([type][mJiggAPI.LASTINPUTINFO])
			$_workerReadTask = $null
			$_pendingWriteFlush = $null
			$_workerSettingsEpoch = 0
			$manualPause = $false
			$script:_HotkeyDebounce = $false

			try {
				:workerLoop while ($true) {
					$workerLoopIteration++
					$script:LoopIteration = $workerLoopIteration
					
					$userInputDetected = $false
					$mouseInputDetected = $false
					$keyboardInputDetected = $false
					$_anyInputThisIteration = $false
					$cooldownActive = $false
					$secondsRemaining = 0
					$date = Get-Date
					$currentTime = $date.ToString("HHmm")
					
					# Interval calculation (same as main loop)
					$intervalMs = 1000
					if ($null -ne $workerLastMovementTime) {
						$intervalSecondsMs = $script:IntervalSeconds * 1000
						$intervalVarianceMs = $script:IntervalVariance * 1000
						$intervalMs = Get-ValueWithVariance -baseValue $intervalSecondsMs -variance $intervalVarianceMs
						$intervalMs = $intervalMs - $workerLastMovementDurationMs
						if ($intervalMs -lt 1000) { $intervalMs = 1000 }
					}
				$tickCount = [math]::Max(1, [math]::Floor($intervalMs / 50))
				$workerLastPos = Get-MousePosition
				
				# Wait loop - 50ms ticks
				for ($tick = 0; $tick -lt $tickCount; $tick++) {
						$date = Get-Date
						
						# Check for new viewer connection
						if (-not $viewerConnected -and $connectResult.IsCompleted) {
							try {
								$pipeServer.EndWaitForConnection($connectResult)
								$pipeReader = New-Object System.IO.StreamReader($pipeServer, [System.Text.Encoding]::UTF8)
								$pipeWriter = New-Object System.IO.StreamWriter($pipeServer, [System.Text.Encoding]::UTF8)
								$_pendingWriteFlush = $null
								$viewerConnected = $true
								if ($_wDiag) { "$(Get-Date -Format 'HH:mm:ss.fff') - VIEWER CONNECTED" | Out-File $_wDiagFile -Append }
								
								Send-PipeMessage -Writer $pipeWriter -Message @{
									type = 'welcome'
									pid = $PID
									version = $script:Version
								}
							Send-PipeMessage -Writer $pipeWriter -Message @{
								type = 'state'
								epoch = $_workerSettingsEpoch
								intervalSeconds = $script:IntervalSeconds
								intervalVariance = $script:IntervalVariance
								moveSpeed = $script:MoveSpeed
								moveVariance = $script:MoveVariance
								travelDistance = $script:TravelDistance
								travelVariance = $script:TravelVariance
								autoResumeDelaySeconds = $script:AutoResumeDelaySeconds
								loopIteration = $workerLoopIteration
								cooldownActive = $cooldownActive
								cooldownRemaining = $secondsRemaining
								endTimeStr = $endTimeStr
								endTimeInt = $endTimeInt
								end = $end
								output = $script:Output
								mouseInputDetected = $mouseInputDetected
								keyboardInputDetected = $keyboardInputDetected
								userInputDetected = $userInputDetected
							}
						foreach ($replayMsg in $script:LogReplayBuffer) {
								Send-PipeMessage -Writer $pipeWriter -Message $replayMsg
							}
						} catch {
							$viewerConnected = $false
							$_pendingWriteFlush = $null
							try { $pipeServer.Disconnect() } catch {}
							try {
								$connectResult = $pipeServer.BeginWaitForConnection($null, $null)
							} catch {
								try { $pipeServer.Dispose() } catch {}
								$pipeServer = New-Object System.IO.Pipes.NamedPipeServerStream(
									$script:PipeName, [System.IO.Pipes.PipeDirection]::InOut, 1,
									[System.IO.Pipes.PipeTransmissionMode]::Byte, [System.IO.Pipes.PipeOptions]::Asynchronous, 65536, 65536)
								$connectResult = $pipeServer.BeginWaitForConnection($null, $null)
							}
						}
					}
						
						# Check viewer disconnection
					if ($viewerConnected -and -not $pipeServer.IsConnected) {
						if ($_wDiag) { "$(Get-Date -Format 'HH:mm:ss.fff') - VIEWER DISCONNECTED (pipe not connected)" | Out-File $_wDiagFile -Append }
						Show-Notification -Title 'mJig' -Body 'Viewer disconnected'
						$_workerReadTask = $null
						$_pendingWriteFlush = $null
						$viewerConnected = $false
						if ($null -ne $pipeReader) { try { $pipeReader.Dispose() } catch {} }
						if ($null -ne $pipeWriter) { try { $pipeWriter.Dispose() } catch {} }
						$pipeReader = $null
						$pipeWriter = $null
						try { $pipeServer.Disconnect() } catch {}
						try {
							$connectResult = $pipeServer.BeginWaitForConnection($null, $null)
						} catch {
							try { $pipeServer.Dispose() } catch {}
							$pipeServer = New-Object System.IO.Pipes.NamedPipeServerStream(
								$script:PipeName, [System.IO.Pipes.PipeDirection]::InOut, 1,
								[System.IO.Pipes.PipeTransmissionMode]::Byte, [System.IO.Pipes.PipeOptions]::Asynchronous, 65536, 65536)
							$connectResult = $pipeServer.BeginWaitForConnection($null, $null)
						}
						}
						
						# Read viewer commands
						if ($viewerConnected) {
							try {
								$msg = Read-PipeMessage -Reader $pipeReader -PendingTask ([ref]$_workerReadTask)
								while ($null -ne $msg) {
									if ($_wDiag) { "$(Get-Date -Format 'HH:mm:ss.fff') - WORKER RECV type=$($msg.type)" | Out-File $_wDiagFile -Append }
									switch ($msg.type) {
										'settings' {
											if ($null -ne $msg.epoch) { $_workerSettingsEpoch = [int]$msg.epoch }
											if ($null -ne $msg.intervalSeconds) { $script:IntervalSeconds = [double]$msg.intervalSeconds }
											if ($null -ne $msg.intervalVariance) { $script:IntervalVariance = [double]$msg.intervalVariance }
											if ($null -ne $msg.moveSpeed) { $script:MoveSpeed = [double]$msg.moveSpeed }
											if ($null -ne $msg.moveVariance) { $script:MoveVariance = [double]$msg.moveVariance }
											if ($null -ne $msg.travelDistance) { $script:TravelDistance = [double]$msg.travelDistance }
											if ($null -ne $msg.travelVariance) { $script:TravelVariance = [double]$msg.travelVariance }
											if ($null -ne $msg.autoResumeDelaySeconds) { $script:AutoResumeDelaySeconds = [double]$msg.autoResumeDelaySeconds }
										}
										'endtime' {
											if ($null -ne $msg.epoch) { $_workerSettingsEpoch = [int]$msg.epoch }
											if ($null -ne $msg.endTime) {
												$endTimeInt = [int]$msg.endTime
												$endTimeStr = $endTimeInt.ToString().PadLeft(4, '0')
												if ($null -ne $msg.endVariance) { $script:EndVariance = [int]$msg.endVariance }
												if ($endTimeInt -ne -1) {
													$ct = Get-Date -Format "HHmm"
													if ($endTimeInt -le [int]$ct) {
														$endDate = Get-Date (Get-Date).AddDays(1) -Format "MMdd"
													} else {
														$endDate = Get-Date -Format "MMdd"
													}
													$end = "$endDate$endTimeStr"
												} else {
													$end = ""
												}
											}
										}
										'output' {
											if ($null -ne $msg.epoch) { $_workerSettingsEpoch = [int]$msg.epoch }
											if ($null -ne $msg.mode) { $script:Output = $msg.mode }
										}
										'togglePause' {
											if ($null -ne $msg.paused) {
												$manualPause = [bool]$msg.paused
											} else {
												$manualPause = -not $manualPause
											}
										}
										'quit' {
											if ($viewerConnected) {
												try { Send-PipeMessage -Writer $pipeWriter -Message @{ type = 'stopped'; reason = 'quit' } } catch {}
											}
											Show-Notification -Title 'mJig' -Body 'Worker quit'
											return
										}
									}
									$msg = Read-PipeMessage -Reader $pipeReader -PendingTask ([ref]$_workerReadTask)
								}
						} catch {
							$_workerReadTask = $null
							$_pendingWriteFlush = $null
							$viewerConnected = $false
							try { $pipeReader.Dispose() } catch {}
							try { $pipeWriter.Dispose() } catch {}
							$pipeReader = $null
							$pipeWriter = $null
							try { $pipeServer.Disconnect() } catch {}
							try {
								$connectResult = $pipeServer.BeginWaitForConnection($null, $null)
							} catch {
								try { $pipeServer.Dispose() } catch {}
								$pipeServer = New-Object System.IO.Pipes.NamedPipeServerStream(
									$script:PipeName, [System.IO.Pipes.PipeDirection]::InOut, 1,
									[System.IO.Pipes.PipeTransmissionMode]::Byte, [System.IO.Pipes.PipeOptions]::Asynchronous, 65536, 65536)
								$connectResult = $pipeServer.BeginWaitForConnection($null, $null)
							}
						}
					}
						
						# Global hotkey polling (Shift+M+P / Shift+M+Q)
						# The worker always handles detection (fast 50ms tick loop).
						# When a viewer is connected, it forwards the state via pipe.
						$_wGlobalAction = $null
						try { $_wGlobalAction = Test-GlobalHotkey } catch {}
						if ($_wGlobalAction -eq 'togglePause') {
							try {
								$manualPause = -not $manualPause
								Show-Notification -Title 'mJig' -Body $(if ($manualPause) { 'Paused' } else { 'Resumed' })
								$_pauseLogMsg = @{
									type = 'log'
									components = @(
										@{ priority = 1; text = $date.ToString(); shortText = $date.ToString("HH:mm:ss") }
										@{ priority = 2; text = " - $(if ($manualPause) { 'Paused' } else { 'Resumed' }) (hotkey)"; shortText = " - $(if ($manualPause) { 'Paused' } else { 'Resumed' })" }
									)
								}
								if ($script:LogReplayBuffer.Count -ge 30) { $null = $script:LogReplayBuffer.Dequeue() }
								$null = $script:LogReplayBuffer.Enqueue($_pauseLogMsg)
								if ($viewerConnected) {
									try { $null = Send-PipeMessageNonBlocking -Writer $pipeWriter -Message @{ type = 'togglePause'; paused = $manualPause; logMsg = $_pauseLogMsg } -PendingFlush ([ref]$_pendingWriteFlush) } catch {}
								}
							} catch {}
						}
						if ($_wGlobalAction -eq 'quit') {
							try { Show-Notification -Title 'mJig' -Body 'Worker quit' } catch {}
							if ($viewerConnected) {
								try { Send-PipeMessage -Writer $pipeWriter -Message @{ type = 'stopped'; reason = 'quit' } } catch {}
							}
							return
						}

						# GetLastInputInfo idle check (system-wide)
						# Only check after the first movement completes — before that,
						# we have no baseline to distinguish real user input from system noise,
						# and the null simulated/autoMove filters cause a permanent skip deadlock.
						if ($null -ne $workerLastAutomatedMouseMovement) {
						try {
							if ([mJiggAPI.Mouse]::GetLastInputInfo([ref]$lii)) {
								$tickNow = [uint64][mJiggAPI.Mouse]::GetTickCount64()
								$systemIdleMs = $tickNow - [uint64]$lii.dwTime
								$recentSimulated = ($null -ne $workerLastSimulatedKeyPress) -and ((Get-TimeSinceMs -startTime $workerLastSimulatedKeyPress) -lt 500)
								$recentAutoMove = (Get-TimeSinceMs -startTime $workerLastAutomatedMouseMovement) -lt 500
								if ($systemIdleMs -lt 300 -and -not $recentSimulated -and -not $recentAutoMove) {
									$userInputDetected = $true
									$_anyInputThisIteration = $true
									if ($script:AutoResumeDelaySeconds -gt 0) {
										$workerLastUserInputTime = Get-Date
									}
								}
							}
						} catch {}
						}
						
						# Mouse position tracking for auto-resume
						# Only flag as user input after the first movement completes
						# (same deadlock avoidance as GetLastInputInfo above).
						try {
							$currentCheckPos = Get-MousePosition
							if ($null -ne $currentCheckPos -and $null -ne $workerLastPos) {
								if (Test-MouseMoved -currentPos $currentCheckPos -lastPos $workerLastPos -threshold 2) {
									if ($null -ne $workerLastAutomatedMouseMovement) {
										$recentAutoMove2 = (Get-TimeSinceMs -startTime $workerLastAutomatedMouseMovement) -lt 500
										if (-not $recentAutoMove2) {
											$mouseInputDetected = $true
											$userInputDetected = $true
											$_anyInputThisIteration = $true
											if ($script:AutoResumeDelaySeconds -gt 0) {
												$workerLastUserInputTime = Get-Date
											}
										}
									}
									$workerLastPos = $currentCheckPos
								}
							}
						} catch {}
						
						# Send state every 500ms (every 10th tick)
						$workerStateTicks++
						if ($viewerConnected -and ($workerStateTicks % 10) -eq 0) {
							if ($userInputDetected -and -not $mouseInputDetected) {
								$keyboardInputDetected = $true
							}
							try {
							$_stateCooldown = $false
								$_stateCooldownSecs = 0
								if ($script:AutoResumeDelaySeconds -gt 0 -and $null -ne $workerLastUserInputTime) {
									$_sinceInput = ((Get-Date) - $workerLastUserInputTime).TotalSeconds
									if ($_sinceInput -lt $script:AutoResumeDelaySeconds) {
										$_stateCooldown = $true
										$_stateCooldownSecs = [Math]::Ceiling($script:AutoResumeDelaySeconds - $_sinceInput)
									}
								}
							$_sendResult = Send-PipeMessageNonBlocking -Writer $pipeWriter -Message @{
							type = 'state'
							epoch = $_workerSettingsEpoch
							intervalSeconds = $script:IntervalSeconds
							intervalVariance = $script:IntervalVariance
							moveSpeed = $script:MoveSpeed
							moveVariance = $script:MoveVariance
							travelDistance = $script:TravelDistance
							travelVariance = $script:TravelVariance
							autoResumeDelaySeconds = $script:AutoResumeDelaySeconds
							loopIteration = $workerLoopIteration
							cooldownActive = $_stateCooldown
							cooldownRemaining = $_stateCooldownSecs
							endTimeStr = $endTimeStr
							endTimeInt = $endTimeInt
							end = $end
							output = $script:Output
							mouseInputDetected = $mouseInputDetected
							keyboardInputDetected = $keyboardInputDetected
							keyboardInferred = $keyboardInputDetected
							userInputDetected = $userInputDetected
						} -PendingFlush ([ref]$_pendingWriteFlush)
								if (-not $_sendResult) {
									$_writeSkipCount++
									if ($_wDiag) { "$(Get-Date -Format 'HH:mm:ss.fff') - WORKER STATE SKIPPED (flush pending) skipCount=$_writeSkipCount" | Out-File $_wDiagFile -Append }
								} else {
									if ($_writeSkipCount -gt 0 -and $_wDiag) { "$(Get-Date -Format 'HH:mm:ss.fff') - WORKER STATE SENT (resumed after $_writeSkipCount skips)" | Out-File $_wDiagFile -Append }
									$_writeSkipCount = 0
								}
					} catch {
						$_pendingWriteFlush = $null
						$viewerConnected = $false
						try { $pipeServer.Disconnect() } catch {}
						try {
							$connectResult = $pipeServer.BeginWaitForConnection($null, $null)
						} catch {
							try { $pipeServer.Dispose() } catch {}
							$pipeServer = New-Object System.IO.Pipes.NamedPipeServerStream(
								$script:PipeName, [System.IO.Pipes.PipeDirection]::InOut, 1,
								[System.IO.Pipes.PipeTransmissionMode]::Byte, [System.IO.Pipes.PipeOptions]::Asynchronous, 65536, 65536)
							$connectResult = $pipeServer.BeginWaitForConnection($null, $null)
						}
					}
							$userInputDetected = $false
							$mouseInputDetected = $false
							$keyboardInputDetected = $false
					}
						
						Start-Sleep -Milliseconds 50
					}
					
					# Auto-resume delay check
					if ($script:AutoResumeDelaySeconds -gt 0 -and $null -ne $workerLastUserInputTime) {
						$timeSinceInput = ((Get-Date) - $workerLastUserInputTime).TotalSeconds
						if ($timeSinceInput -lt $script:AutoResumeDelaySeconds) {
							$cooldownActive = $true
							$secondsRemaining = [Math]::Ceiling($script:AutoResumeDelaySeconds - $timeSinceInput)
						}
					}
					
				$_isFirstWorkerRun = ($workerLoopIteration -eq 1)
				$SkipUpdate = $_anyInputThisIteration -or $cooldownActive -or $_isFirstWorkerRun -or $manualPause
				
				if (-not $SkipUpdate) {
					# Movement execution (same logic as main loop)
						$pos = Get-MousePosition
						if ($null -eq $pos) { $pos = $workerLastPos }
						
						$baseDistance = $script:TravelDistance
						$varianceAmount = Get-Random -Minimum 0.0 -Maximum ($script:TravelVariance + 0.0001)
						if ((Get-Random -Maximum 2) -eq 0) {
							$distance = $baseDistance - $varianceAmount
						} else {
							$distance = $baseDistance + $varianceAmount
						}
						if ($distance -lt 1) { $distance = 1 }
						
						$angle = Get-Random -Minimum 0 -Maximum ([Math]::PI * 2)
						$x = [Math]::Round($pos.X + ($distance * [Math]::Cos($angle)))
						$y = [Math]::Round($pos.Y + ($distance * [Math]::Sin($angle)))
						
						$vScreen = $script:_VirtualScreen
						$sLeft   = $vScreen.Left
						$sTop    = $vScreen.Top
						$sRight  = $vScreen.Right  - 1
						$sBottom = $vScreen.Bottom - 1
						if ($x -lt $sLeft)   { $x = $sLeft   + ($sLeft   - $x) }
						if ($x -gt $sRight)  { $x = $sRight  - ($x - $sRight)  }
						if ($y -lt $sTop)    { $y = $sTop    + ($sTop    - $y)  }
						if ($y -gt $sBottom) { $y = $sBottom - ($y - $sBottom)  }
						$x = [Math]::Max($sLeft, [Math]::Min($x, $sRight))
						$y = [Math]::Max($sTop,  [Math]::Min($y, $sBottom))
						
						$deltaX = $x - $pos.X
						$deltaY = $y - $pos.Y
						$directionArrow = Get-DirectionArrow -deltaX $deltaX -deltaY $deltaY -style "simple"
						
						$movementPath = Get-SmoothMovementPath -startX $pos.X -startY $pos.Y -endX $x -endY $y -baseSpeedSeconds $script:MoveSpeed -varianceSeconds $script:MoveVariance
						$movementPoints = $movementPath.Points
						$workerLastMovementDurationMs = $movementPath.TotalTimeMs
						
					$_moveResult = Invoke-CursorMovement -Points $movementPoints -FallbackX $x -FallbackY $y
					$movementAborted = $_moveResult.Aborted
					if ($movementAborted) { $workerLastPos = $_moveResult.ActualPosition }
						
						if (-not $movementAborted) {
							$newPos = Get-MousePosition
							if ($null -ne $newPos) { $workerLastPos = $newPos }
							$workerLastAutomatedMouseMovement = Get-Date
							
							# Simulate Right Alt keypress
							try {
								$vkCode = [byte]0xA5
								[mJiggAPI.Keyboard]::keybd_event($vkCode, [byte]0, [uint32]0, [int]0)
								Start-Sleep -Milliseconds 10
								[mJiggAPI.Keyboard]::keybd_event($vkCode, [byte]0, [uint32]0x0002, [int]0)
								$workerLastSimulatedKeyPress = Get-Date
								Start-Sleep -Milliseconds 50
							} catch {}
							
							# Build and send log message
							$logMsg = @{
								type = 'log'
								components = @(
									@{ priority = 1; text = $date.ToString(); shortText = $date.ToString("HH:mm:ss") }
									@{ priority = 2; text = " - Coordinates updated $directionArrow"; shortText = " - Updated $directionArrow" }
									@{ priority = 3; text = " x${x}/y${y}"; shortText = " x${x}/y${y}" }
								)
							}
							if ($script:LogReplayBuffer.Count -ge 30) { $null = $script:LogReplayBuffer.Dequeue() }
							$null = $script:LogReplayBuffer.Enqueue($logMsg)
							if ($viewerConnected) {
								try { $null = Send-PipeMessageNonBlocking -Writer $pipeWriter -Message $logMsg -PendingFlush ([ref]$_pendingWriteFlush) } catch {}
							}
						}
						
						$workerLastMovementTime = Get-Date
				} else {
					if ($_isFirstWorkerRun) {
						$logMsg = @{
							type = 'log'
							components = @(
								@{ priority = 1; text = $date.ToString(); shortText = $date.ToString("HH:mm:ss") }
								@{ priority = 2; text = " - Initialization complete, mJig started"; shortText = " - Started" }
							)
						}
					} else {
						$logMsg = @{
							type = 'log'
							components = @(
								@{ priority = 1; text = $date.ToString(); shortText = $date.ToString("HH:mm:ss") }
								@{ priority = 2; text = " - User input skip"; shortText = " - Skipped" }
							)
						}
						if ($cooldownActive) {
							$logMsg.components = @(
								@{ priority = 1; text = $date.ToString(); shortText = $date.ToString("HH:mm:ss") }
								@{ priority = 2; text = " - Auto-Resume Delay"; shortText = " - Auto-Resume Delay" }
								@{ priority = 4; text = " [Resume: ${secondsRemaining}s]"; shortText = " [R: ${secondsRemaining}s]" }
							)
						}
					}
					if ($manualPause -and -not $_isFirstWorkerRun) { $logMsg = $null }
					if ($null -ne $logMsg) {
						if ($script:LogReplayBuffer.Count -ge 30) { $null = $script:LogReplayBuffer.Dequeue() }
						$null = $script:LogReplayBuffer.Enqueue($logMsg)
						if ($viewerConnected) {
							try { $null = Send-PipeMessageNonBlocking -Writer $pipeWriter -Message $logMsg -PendingFlush ([ref]$_pendingWriteFlush) } catch {}
						}
					}
					
					if ($null -eq $workerLastMovementTime) { $workerLastMovementTime = Get-Date }
				}
					
					# End time check
					if ($endTimeInt -ne -1 -and -not [string]::IsNullOrEmpty($end)) {
						try {
							$currentDateTimeInt = [int]($date.ToString("MMddHHmm"))
							$endDateTimeInt = [int]$end
							if ($currentDateTimeInt -ge $endDateTimeInt) {
								if ($viewerConnected) {
									try { Send-PipeMessage -Writer $pipeWriter -Message @{ type = 'stopped'; reason = 'endtime' } } catch {}
								}
								Show-Notification -Title 'mJig' -Body 'End time reached -- worker quit'
								return
							}
						} catch {}
					}
				}
			} finally {
				Dispose-Notification
				if ($null -ne $pipeReader) { try { $pipeReader.Dispose() } catch {} }
				if ($null -ne $pipeWriter) { try { $pipeWriter.Dispose() } catch {} }
				if ($null -ne $pipeServer) { try { $pipeServer.Dispose() } catch {} }
				if ($null -ne $script:InstanceMutex) {
					try { $script:InstanceMutex.ReleaseMutex() } catch {}
					$script:InstanceMutex.Dispose()
					$script:InstanceMutex = $null
				}
			}
		}
