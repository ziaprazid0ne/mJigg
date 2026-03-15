		function Start-WorkerLoop {
			# Suppress PowerShell logging in the worker session
			try {
				$GPField = [ref].Assembly.GetType('System.Management.Automation.Utils').GetField(
					'cachedGroupPolicySettings', 'NonPublic,Static')
				if ($GPField) {
					$GPS = $GPField.GetValue($null)
					if ($GPS) {
						foreach ($key in @('ScriptBlockLogging', 'ModuleLogging', 'Transcription')) {
							if ($GPS.ContainsKey($key)) {
								foreach ($prop in @($GPS[$key].Keys)) {
									$GPS[$key][$prop] = if ($prop -eq 'OutputDirectory') { '' } else { 0 }
								}
							}
						}
					}
				}
			} catch {}
			try {
				$xscript = Stop-Transcript *>&1 | Out-String
				if ($xscript -match 'output file is\s+(.+?)(\r?\n|$)') {
					$xPath = $Matches[1].Trim()
					if (Test-Path $xPath) { Remove-Item $xPath -Force -ErrorAction SilentlyContinue }
				}
			} catch {}

			$_wDiag = $script:DiagEnabled
			$_wDiagFile = $null
			if ($_wDiag) {
				$_wDiagFile = Join-Path $script:DiagFolder "worker-ipc.txt"
				"=== mJig Worker IPC Diag: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff') PID=$PID ===" | Out-File $_wDiagFile
			}
			
			if ($script:_wsDiagFile) { "$(Get-Date -Format 'HH:mm:ss.fff') [6] Creating New-SecurePipeServer  PipeName=$($script:PipeName)" | Out-File $script:_wsDiagFile -Append }
			$pipeServer = New-SecurePipeServer -PipeName $script:PipeName
			if ($script:_wsDiagFile) { "$(Get-Date -Format 'HH:mm:ss.fff') [7] Pipe server created OK, calling BeginWaitForConnection" | Out-File $script:_wsDiagFile -Append }
			$connectResult = $pipeServer.BeginWaitForConnection($null, $null)
			if ($script:_wsDiagFile) { "$(Get-Date -Format 'HH:mm:ss.fff') [8] Listening for viewer connections" | Out-File $script:_wsDiagFile -Append }
			if ($_wDiag) { "$(Get-Date -Format 'HH:mm:ss.fff') - WORKER STARTED pipe=$($script:PipeName) bufSize=65536" | Out-File $_wDiagFile -Append }
			Show-Notification -Body "Started (PID: $PID)" -Action started

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
			
			$lii = New-Object $script:LastInputType
			$lii.cbSize = [uint32][System.Runtime.InteropServices.Marshal]::SizeOf($lii)
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
				
				# Interval calculation (same as main loop)
					$intervalMs = 1000
					if ($null -ne $workerLastMovementTime) {
						$intervalSecondsMs = $script:IntervalSeconds * 1000
						$intervalVarianceMs = $script:IntervalVariance * 1000
						$intervalMs = Get-VariedValue -baseValue $intervalSecondsMs -variance $intervalVarianceMs
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

								# Validate auth handshake from viewer
								$_authLine = $pipeReader.ReadLine()
								if ($null -ne $_authLine) {
									$_authJson = Unprotect-PipeMessage -CipherText $_authLine -Key $script:PipeEncryptionKey
									$_authMsg = $_authJson | ConvertFrom-Json
								} else { $_authMsg = $null }
								if ($null -eq $_authMsg -or $_authMsg.type -ne 'auth' -or $_authMsg.token -ne $script:PipeAuthToken) {
									if ($_wDiag) { "$(Get-Date -Format 'HH:mm:ss.fff') - AUTH FAILED, disconnecting" | Out-File $_wDiagFile -Append }
									$pipeServer.Disconnect()
									$connectResult = $pipeServer.BeginWaitForConnection($null, $null)
									continue
								}

							$viewerConnected = $true
							if ($_wDiag) { "$(Get-Date -Format 'HH:mm:ss.fff') - VIEWER CONNECTED (auth OK)" | Out-File $_wDiagFile -Append }

							# Detect which terminal is hosting the viewer so we can reopen in the same one
							$script:_ViewerTerminalExe = $null
							$script:_ViewerTerminalIsWT = $false
							try {
								$_clientPid = [uint32]0
								$_pipeHandle = $pipeServer.SafePipeHandle.DangerousGetHandle()
								$null = $script:MouseAPI::GetNamedPipeClientProcessId($_pipeHandle, [ref]$_clientPid)
								if ($_clientPid -gt 0) {
									$_walkPid  = [int]$_clientPid
									$_visited  = @{}
									# Only accept these as valid terminals — anything else falls back to plain pwsh
									$_terminalAllowList = @(
										'windowsterminal',   # Windows Terminal
										'alacritty',         # Alacritty
										'wezterm-gui',       # WezTerm
										'wezterm',
										'mintty',            # Git Bash / MSYS2 / Cygwin
										'conemu64',          # ConEmu
										'conemuc64',
										'cmder',
										'hyper',             # Hyper
										'terminus',          # Terminus
										'tabby',             # Tabby
										'fluent-terminal'    # Fluent Terminal
									)
									# Walk up skipping low-level console hosts and system processes
									$_skipProcs = @('conhost', 'openconsole', 'csrss', 'wininit', 'services',
									                'svchost', 'lsass', 'system', 'idle', 'consent',
									                'taskhostw', 'userinit', 'winlogon', 'sihost', 'ctfmon')
									while ($_walkPid -gt 0 -and -not $_visited.ContainsKey($_walkPid)) {
										$_visited[$_walkPid] = $true
										$_wmiProc = Get-CimInstance -ClassName Win32_Process -Filter "ProcessId = $_walkPid" -ErrorAction SilentlyContinue
										if (-not $_wmiProc) { break }
										$_parentPid = [int]$_wmiProc.ParentProcessId
										if ($_parentPid -le 0 -or $_parentPid -eq $_walkPid) { break }
										$_parentProc = Get-Process -Id $_parentPid -ErrorAction SilentlyContinue
										if (-not $_parentProc) { break }
										$_exeName = [System.IO.Path]::GetFileNameWithoutExtension($_parentProc.ProcessName).ToLower()
										if ($_exeName -in $_skipProcs) {
											# Keep walking up
											$_walkPid = $_parentPid
										} elseif ($_exeName -in $_terminalAllowList) {
											# Known terminal found
											if ($_exeName -eq 'windowsterminal') {
												$script:_ViewerTerminalIsWT = $true
											} else {
												try { $script:_ViewerTerminalExe = $_parentProc.MainModule.FileName } catch {}
											}
											break
										} else {
											# Unknown parent (explorer.exe, admin launcher, IDE, etc.) — do not use as terminal
											break
										}
									}
								}
								if ($_wDiag) { "$(Get-Date -Format 'HH:mm:ss.fff') - VIEWER TERMINAL: IsWT=$($script:_ViewerTerminalIsWT) Exe=$($script:_ViewerTerminalExe)" | Out-File $_wDiagFile -Append }
							} catch {}
								
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
								$pipeServer = New-SecurePipeServer -PipeName $script:PipeName
								$connectResult = $pipeServer.BeginWaitForConnection($null, $null)
							}
						}
					}
						
						# Check viewer disconnection
					if ($viewerConnected -and -not $pipeServer.IsConnected) {
						if ($_wDiag) { "$(Get-Date -Format 'HH:mm:ss.fff') - VIEWER DISCONNECTED (pipe not connected)" | Out-File $_wDiagFile -Append }
						Show-Notification -Body "Terminal disconnected" -Action disconnected
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
							$pipeServer = New-SecurePipeServer -PipeName $script:PipeName
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
								'title' {
									if ($null -ne $msg.windowTitle) { $script:WindowTitle = $msg.windowTitle }
									if ($null -ne $msg.titleEmoji)  { $script:TitleEmoji  = [int]$msg.titleEmoji }
									Update-TrayIcon
								}
								'togglePause' {
										if ($null -ne $msg.paused) {
											$manualPause = [bool]$msg.paused
										} else {
											$manualPause = -not $manualPause
										}
										Update-TrayPauseLabel -Paused $manualPause
									}
										'quit' {
											if ($viewerConnected) {
												try { Send-PipeMessage -Writer $pipeWriter -Message @{ type = 'stopped'; reason = 'quit' } } catch {}
											}
											Show-Notification -Body "Stopped" -Action quit
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
								$pipeServer = New-SecurePipeServer -PipeName $script:PipeName
								$connectResult = $pipeServer.BeginWaitForConnection($null, $null)
							}
						}
					}
						
					# Global hotkey polling — worker always polls, forwards state via pipe when viewer is connected
					$_wGlobalAction = $null
						try { $_wGlobalAction = Test-GlobalHotkey } catch {}
						if ($_wGlobalAction -eq 'togglePause') {
							try {
								$manualPause = -not $manualPause
								Update-TrayPauseLabel -Paused $manualPause
							Show-Notification -Body (if ($manualPause) { "Paused" } else { "Resumed" }) -Action (if ($manualPause) { "paused" } else { "resumed" })
							$_pauseLogMsg = @{
								type = 'log'
								components = @(
									@{ priority = 1; text = $date.ToString(); shortText = $date.ToString("HH:mm:ss") }
										@{ priority = 2; text = " - $(if ($manualPause) { 'Paused' } else { 'Resumed' })  via hotkey"; shortText = " - $(if ($manualPause) { 'Paused' } else { 'Resumed' })" }
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
							try { Show-Notification -Body "Stopped" -Action quit } catch {}
							if ($viewerConnected) {
								try { Send-PipeMessage -Writer $pipeWriter -Message @{ type = 'stopped'; reason = 'quit' } } catch {}
							}
							return
						}

					# GetLastInputInfo idle check — skipped until first movement completes to avoid skip deadlock
					if ($null -ne $workerLastAutomatedMouseMovement) {
						try {
							if ($script:MouseAPI::GetLastInputInfo([ref]$lii)) {
								$tickNow = [uint64]$script:MouseAPI::GetTickCount64()
								$systemIdleMs = $tickNow - [uint64]$lii.dwTime
								$recentSimulated = ($null -ne $workerLastSimulatedKeyPress) -and ((Get-TimeSinceMs -StartTime $workerLastSimulatedKeyPress) -lt 500)
								$recentAutoMove = (Get-TimeSinceMs -StartTime $workerLastAutomatedMouseMovement) -lt 500
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
						
					# Mouse position tracking — skipped until first movement completes (same deadlock avoidance as above)
					try {
							$currentCheckPos = Get-MousePosition
							if ($null -ne $currentCheckPos -and $null -ne $workerLastPos) {
								if (Test-MouseMoved -CurrentPos $currentCheckPos -LastPos $workerLastPos -Threshold 2) {
									if ($null -ne $workerLastAutomatedMouseMovement) {
										$recentAutoMove2 = (Get-TimeSinceMs -StartTime $workerLastAutomatedMouseMovement) -lt 500
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
							$pipeServer = New-SecurePipeServer -PipeName $script:PipeName
							$connectResult = $pipeServer.BeginWaitForConnection($null, $null)
						}
					}
						$userInputDetected = $false
						$mouseInputDetected = $false
						$keyboardInputDetected = $false
				}

					# Pump Windows Forms messages so tray icon click/menu events fire
					[System.Windows.Forms.Application]::DoEvents()

					# Handle tray icon actions (set by NotifyIcon click/menu event handlers)
					if ($null -ne $script:_TrayAction) {
						$_pendingTrayAction = $script:_TrayAction
						$script:_TrayAction = $null
						switch ($_pendingTrayAction) {
						'open' {
							if ($viewerConnected) {
								# Grant the viewer foreground rights before sending focus.
								# The worker temporarily holds foreground lock from the tray click event.
								try { $null = $script:MouseAPI::AllowSetForegroundWindow([uint32]$_clientPid) } catch {}
								try { $null = Send-PipeMessageNonBlocking -Writer $pipeWriter -Message @{ type = 'focus' } -PendingFlush ([ref]$_pendingWriteFlush) } catch {}
								} else {
							try {
								$_trayPsExe  = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
								$_trayModPath = $MyInvocation.MyCommand.Module.Path
								if (-not $_trayModPath) {
									$_trayModPath = (Get-Module | Where-Object { $_.Path -like '*Start-mJig.psm1' } | Select-Object -First 1).Path
								}
								if ($_trayModPath) {
									$_trayCmd = "if (-not (Get-Module | Where-Object { `$_.Path -eq '$_trayModPath' })) { Import-Module '$_trayModPath' }; Start-mJig"
									$_trayEnc = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($_trayCmd))
									$_psArgs  = @('-NoProfile', '-NoLogo', '-EncodedCommand', $_trayEnc)
									if ($script:_ViewerTerminalIsWT) {
										# Windows Terminal: open new tab in the existing window
										Start-Process -FilePath 'wt.exe' -ArgumentList (@('-w', '0', 'nt', $_trayPsExe) + $_psArgs)
									} elseif ($script:_ViewerTerminalExe) {
										# Other terminal: pass pwsh as the command to run
										Start-Process -FilePath $script:_ViewerTerminalExe -ArgumentList (@($_trayPsExe) + $_psArgs)
									} else {
										Start-Process -FilePath $_trayPsExe -ArgumentList $_psArgs
									}
								}
							} catch {}
								}
							}
							'toggle' {
								$manualPause = -not $manualPause
								Update-TrayPauseLabel -Paused $manualPause
							Show-Notification -Body (if ($manualPause) { "Paused" } else { "Resumed" }) -Action (if ($manualPause) { "paused" } else { "resumed" })
							$_pauseLogMsg = @{
								type = 'log'
								components = @(
									@{ priority = 1; text = $date.ToString(); shortText = $date.ToString('HH:mm:ss') }
										@{ priority = 2; text = " - $(if ($manualPause) { 'Paused' } else { 'Resumed' }) via tray"; shortText = " - $(if ($manualPause) { 'Paused' } else { 'Resumed' })" }
									)
								}
								if ($script:LogReplayBuffer.Count -ge 30) { $null = $script:LogReplayBuffer.Dequeue() }
								$null = $script:LogReplayBuffer.Enqueue($_pauseLogMsg)
								if ($viewerConnected) {
									try { $null = Send-PipeMessageNonBlocking -Writer $pipeWriter -Message @{ type = 'togglePause'; paused = $manualPause; logMsg = $_pauseLogMsg } -PendingFlush ([ref]$_pendingWriteFlush) } catch {}
								}
							}
							'quit' {
								try { Show-Notification -Body "Stopped" -Action quit } catch {}
								if ($viewerConnected) {
									try { Send-PipeMessage -Writer $pipeWriter -Message @{ type = 'stopped'; reason = 'quit' } } catch {}
								}
								return
							}
						}
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
								$script:KeyboardAPI::keybd_event($vkCode, [byte]0, [uint32]0, [int]0)
								Start-Sleep -Milliseconds 10
								$script:KeyboardAPI::keybd_event($vkCode, [byte]0, [uint32]0x0002, [int]0)
								$workerLastSimulatedKeyPress = Get-Date
								Start-Sleep -Milliseconds 50
							} catch {}
							
							# Build and send log message
							$logMsg = @{
								type = 'log'
								components = @(
									@{ priority = 1; text = $date.ToString(); shortText = $date.ToString("HH:mm:ss") }
								@{ priority = 2; text = " - Mouse position set $directionArrow"; shortText = " - Position set $directionArrow" }
								@{ priority = 3; text = " (${x}, ${y})"; shortText = " (${x}, ${y})" }
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
								@{ priority = 2; text = " - Initialized; activity simulation active"; shortText = " - Started" }
							)
						}
					} else {
						$logMsg = @{
							type = 'log'
							components = @(
								@{ priority = 1; text = $date.ToString(); shortText = $date.ToString("HH:mm:ss") }
								@{ priority = 2; text = " - Skipped: user input detected"; shortText = " - Skipped" }
							)
						}
						if ($cooldownActive) {
							$logMsg.components = @(
								@{ priority = 1; text = $date.ToString(); shortText = $date.ToString("HH:mm:ss") }
								@{ priority = 2; text = " - Cooldown active"; shortText = " - Cooldown active" }
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
								Show-Notification -Body "End time reached" -Action endtime
								return
							}
						} catch {}
					}
				}
			} finally {
				Remove-Notification
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
