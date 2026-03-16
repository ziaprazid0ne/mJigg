		function Update-TrayIcon {
			$_trayPath = Join-Path ([System.IO.Path]::GetTempPath()) 'mjig_tray_icon.png'
			$script:_TrayIconPath = $_trayPath  # always set so AUMID IconUri is always title emoji

			if ($script:_NotifyIconEmoji -ne $script:TitleEmoji) {
				$_trayEmojiStr = [char]::ConvertFromUtf32($script:TitleEmoji)
				$_rendered = $false
				if ($null -ne $script:ToastAPI) {
					try {
						$script:ToastAPI::RenderEmojiToPng($_trayEmojiStr, $_trayPath, 64)
						$_rendered = $true
					} catch {
						if ($script:DiagEnabled -and $script:NotifyDiagFile) {
							"$(Get-Date -Format 'HH:mm:ss.fff') [RENDER-TRAY] $($_.Exception.GetType().Name): $($_.Exception.Message)" | Out-File $script:NotifyDiagFile -Append
						}
					}
				}
				if (-not $_rendered) {
					$_bmp = New-Object System.Drawing.Bitmap(64, 64)
					$_gfx = [System.Drawing.Graphics]::FromImage($_bmp)
					$_gfx.Clear([System.Drawing.Color]::FromArgb(40, 40, 40))
					$_emojiFont = New-Object System.Drawing.Font('Segoe UI Emoji', 36)
					$_rect = New-Object System.Drawing.Rectangle(0, 0, 64, 64)
					$_tflags = [System.Windows.Forms.TextFormatFlags]::HorizontalCenter -bor
					           [System.Windows.Forms.TextFormatFlags]::VerticalCenter -bor
					           [System.Windows.Forms.TextFormatFlags]::NoPadding
					[System.Windows.Forms.TextRenderer]::DrawText(
						$_gfx, $_trayEmojiStr, $_emojiFont, $_rect,
						[System.Drawing.Color]::White, $_tflags)
					$_gfx.Dispose()
					$_emojiFont.Dispose()
					$_bmp.Save($_trayPath, [System.Drawing.Imaging.ImageFormat]::Png)
					$_bmp.Dispose()
				}

				# Create and update NotifyIcon (worker only — viewer skips tray entry)
				if (-not $script:_SkipTrayIcon) {
					if ($null -eq $script:_NotifyIcon) {
						$script:_NotifyIcon = New-Object System.Windows.Forms.NotifyIcon

						$script:_TrayOpenItem  = New-Object System.Windows.Forms.ToolStripMenuItem
						$script:_TrayPauseItem = New-Object System.Windows.Forms.ToolStripMenuItem
						$script:_TrayPauseItem.Text = 'Pause'
						$_quitItem = New-Object System.Windows.Forms.ToolStripMenuItem
						$_quitItem.Text = 'Quit'

						$null = $script:_TrayOpenItem.Add_Click({ $script:_TrayAction = 'open' })
						$null = $script:_TrayPauseItem.Add_Click({ $script:_TrayAction = 'toggle' })
						$null = $_quitItem.Add_Click({ $script:_TrayAction = 'quit' })

						$script:_TrayContextMenu = New-Object System.Windows.Forms.ContextMenuStrip
						$null = $script:_TrayContextMenu.Items.Add($script:_TrayOpenItem)
						$null = $script:_TrayContextMenu.Items.Add($script:_TrayPauseItem)
						$null = $script:_TrayContextMenu.Items.Add($_quitItem)
						$script:_NotifyIcon.ContextMenuStrip = $script:_TrayContextMenu

						$null = $script:_NotifyIcon.Add_MouseClick({
							if ($_.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
								$script:_TrayAction = 'open'
							}
						})

						$script:_NotifyIcon.Visible = $true
					}

					$_trayBmp = New-Object System.Drawing.Bitmap($_trayPath)
					$script:_NotifyIcon.Icon = [System.Drawing.Icon]::FromHandle($_trayBmp.GetHicon())
					$_trayBmp.Dispose()
				}

				$script:_NotifyIconEmoji = $script:TitleEmoji
			}

			# Sync tooltip and Open menu label (no-op in viewer mode since _NotifyIcon is null)
			if ($null -ne $script:_NotifyIcon) {
				$script:_NotifyIcon.Text = $script:WindowTitle
			}
			if ($null -ne $script:_TrayOpenItem) {
				$script:_TrayOpenItem.Text = "Open '$($script:WindowTitle)'"
			}
		}

		function Update-TrayPauseLabel {
			param([bool]$Paused)
			if ($null -ne $script:_TrayPauseItem) {
				$script:_TrayPauseItem.Text = if ($Paused) { 'Resume' } else { 'Pause' }
			}
		}

		function Show-Notification {
			param(
				[Parameter(Mandatory)][string]$Body,
				[Parameter(Mandatory)]
				[ValidateSet('started','paused','resumed','quit','disconnected','endtime')]
				[string]$Action,
				[ValidateSet('Info','Warning','Error','None')]
				[string]$Icon = 'None',
				[int]$DurationMs = 2000
			)
			if (-not $script:NotificationsEnabled) { return }
			if ($script:DiagEnabled -and $script:NotifyDiagFile) {
				"$(Get-Date -Format 'HH:mm:ss.fff') [ENTRY] Action=$Action Body='$Body' ToastAPI=$($null -ne $script:ToastAPI)" | Out-File $script:NotifyDiagFile -Append
			}

			$_actionEmojiMap = @{
				started      = 0x1F680  # rocket
				paused       = 0x23F8   # pause button
				resumed      = 0x25B6   # play button
				quit         = 0x1F6D1  # stop sign
				disconnected = 0x1F50C  # electric plug
				endtime      = 0x23F0   # alarm clock
			}

			try {
				if ($null -eq $script:_ActionIconCache) { $script:_ActionIconCache = @{} }

				# --- Tray icon: title emoji (worker only, viewer skips) ---
				Update-TrayIcon

				# --- Action icon: per-action emoji for toast image ---
				$actionCodepoint = $_actionEmojiMap[$Action]
				if (-not $script:_ActionIconCache.ContainsKey($Action)) {
					$actionEmojiStr = [char]::ConvertFromUtf32($actionCodepoint)
					$actionIconPath = Join-Path ([System.IO.Path]::GetTempPath()) "mjig_notify_$Action.png"

					$rendered = $false
					if ($null -ne $script:ToastAPI) {
						try {
							$script:ToastAPI::RenderEmojiToPng($actionEmojiStr, $actionIconPath, 64)
							$rendered = $true
						} catch {
							if ($script:DiagEnabled -and $script:NotifyDiagFile) {
								"$(Get-Date -Format 'HH:mm:ss.fff') [RENDER-ACTION] action=$Action $($_.Exception.GetType().Name): $($_.Exception.Message)" | Out-File $script:NotifyDiagFile -Append
							}
						}
					}
					if (-not $rendered) {
						$bmp = New-Object System.Drawing.Bitmap(64, 64)
						$gfx = [System.Drawing.Graphics]::FromImage($bmp)
						$gfx.Clear([System.Drawing.Color]::FromArgb(40, 40, 40))
						$emojiFont = New-Object System.Drawing.Font("Segoe UI Emoji", 36)
						$rect = New-Object System.Drawing.Rectangle(0, 0, 64, 64)
						$tflags = [System.Windows.Forms.TextFormatFlags]::HorizontalCenter -bor
						          [System.Windows.Forms.TextFormatFlags]::VerticalCenter -bor
						          [System.Windows.Forms.TextFormatFlags]::NoPadding
						[System.Windows.Forms.TextRenderer]::DrawText(
							$gfx, $actionEmojiStr, $emojiFont, $rect,
							[System.Drawing.Color]::White, $tflags)
						$gfx.Dispose()
						$emojiFont.Dispose()
						$bmp.Save($actionIconPath, [System.Drawing.Imaging.ImageFormat]::Png)
						$bmp.Dispose()
					}
					$script:_ActionIconCache[$Action] = $actionIconPath
				}
				$toastImgPath = $script:_ActionIconCache[$Action]

				# --- Build and show toast ---
				if ($null -eq $script:_NotifyAumidSeq) {
					$script:_NotifyAumidSeq = 0
					$_aumidRoot = "HKCU:\Software\Classes\AppUserModelId"
					try {
						Get-ChildItem -Path $_aumidRoot -ErrorAction SilentlyContinue |
							Where-Object { $_.PSChildName -like "svc_$($script:PipeName)_*" } |
							ForEach-Object { Remove-Item -Path $_.PSPath -Force -ErrorAction SilentlyContinue }
					} catch {}
				}
				$script:_NotifyAumidSeq++
				$aumid  = "svc_$($script:PipeName)_${PID}_$($script:_NotifyAumidSeq)"
				$regKey = "HKCU:\Software\Classes\AppUserModelId\$aumid"

			# AUMID icon = title emoji (always set by Update-TrayIcon above); toast appLogoOverride = action emoji
			$aumidIconPath = $script:_TrayIconPath

			$escapedBody  = [System.Security.SecurityElement]::Escape($Body)
			$imgSrc  = $toastImgPath.Replace('\', '/')
			$toastXml = "<toast duration=`"short`"><visual><binding template=`"ToastGeneric`">" +
			            "<text>$escapedBody</text>" +
			            "<image placement=`"appLogoOverride`" src=`"file:///$imgSrc`"/>" +
			            "</binding></visual></toast>"

			$toastShown = $false
			if ($null -ne $script:ToastAPI -and $script:_Tier1NotifyFailed -ne $true) {
				try {
					$null = New-Item -Path $regKey -Force
					$null = New-ItemProperty -Path $regKey -Name 'DisplayName' -Value $script:WindowTitle -PropertyType ExpandString -Force
					$null = New-ItemProperty -Path $regKey -Name 'IconUri' -Value $aumidIconPath -PropertyType ExpandString -Force
					try {
						$script:_Tier1NotifyFailed = $true
						$script:ToastAPI::ShowToast($toastXml, $aumid)
						$toastShown = $true
						$script:_Tier1NotifyFailed = $false
						if ($script:DiagEnabled -and $script:NotifyDiagFile) {
							"$(Get-Date -Format 'HH:mm:ss.fff') [TIER1-OK] action=$Action aumid=$aumid" | Out-File $script:NotifyDiagFile -Append
						}
						Start-Sleep -Milliseconds 50
					} finally {
						Remove-Item -Path $regKey -Force -ErrorAction SilentlyContinue
					}
				} catch {
					if ($script:DiagEnabled -and $script:NotifyDiagFile) {
						"$(Get-Date -Format 'HH:mm:ss.fff') [TIER1-COM] $($_.Exception.GetType().Name): $($_.Exception.Message)" | Out-File $script:NotifyDiagFile -Append
					}
				}
			} elseif ($script:DiagEnabled -and $script:NotifyDiagFile) {
				"$(Get-Date -Format 'HH:mm:ss.fff') [TIER1-SKIP] ToastAPI=$($null -ne $script:ToastAPI) Tier1Failed=$($script:_Tier1NotifyFailed)" | Out-File $script:NotifyDiagFile -Append
			}

			if (-not $toastShown) {
				$safeBody  = $Body.Replace("'", "''")
				$safeImg   = $imgSrc.Replace("'", "''")
				$safeAumid = $aumid.Replace("'", "''")
				$toastCmd  = '[void][Windows.UI.Notifications.ToastNotificationManager,Windows.UI.Notifications,ContentType=WindowsRuntime];' +
				             '[void][Windows.Data.Xml.Dom.XmlDocument,Windows.Data.Xml.Dom,ContentType=WindowsRuntime];' +
				             '$x=New-Object Windows.Data.Xml.Dom.XmlDocument;' +
				             '$x.LoadXml(''<toast duration="short"><visual><binding template="ToastGeneric">' +
				             "<text>$safeBody</text>" +
				             "<image placement=""appLogoOverride"" src=""file:///$safeImg""/>" +
				             '</binding></visual></toast>'');' +
				             '$t=[Windows.UI.Notifications.ToastNotification]::new($x);' +
				             "[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('$safeAumid').Show(" + '$t)'
				try {
					$null = New-Item -Path $regKey -Force
					$null = New-ItemProperty -Path $regKey -Name 'DisplayName' -Value $script:WindowTitle -PropertyType ExpandString -Force
					$null = New-ItemProperty -Path $regKey -Name 'IconUri' -Value $aumidIconPath -PropertyType ExpandString -Force
					Start-Process powershell.exe -ArgumentList '-NoProfile','-WindowStyle','Hidden','-Command',$toastCmd -WindowStyle Hidden
					$toastShown = $true
					if ($script:DiagEnabled -and $script:NotifyDiagFile) {
						"$(Get-Date -Format 'HH:mm:ss.fff') [TIER2-OK] action=$Action aumid=$safeAumid" | Out-File $script:NotifyDiagFile -Append
					}
				} catch {
					if ($script:DiagEnabled -and $script:NotifyDiagFile) {
						"$(Get-Date -Format 'HH:mm:ss.fff') [TIER2-PS51] $($_.Exception.GetType().Name): $($_.Exception.Message)" | Out-File $script:NotifyDiagFile -Append
					}
					Remove-Item -Path $regKey -Force -ErrorAction SilentlyContinue
				}
			}

			if (-not $toastShown) {
				$tipIcon = [System.Windows.Forms.ToolTipIcon]::$Icon
				$script:_NotifyIcon.ShowBalloonTip($DurationMs, $script:WindowTitle, $Body, $tipIcon)
					if ($script:DiagEnabled -and $script:NotifyDiagFile) {
						"$(Get-Date -Format 'HH:mm:ss.fff') [TIER3-BALLOON] action=$Action" | Out-File $script:NotifyDiagFile -Append
					}
				}
		} catch {
			$script:_Tier1NotifyFailed = $true
			if ($script:DiagEnabled -and $script:NotifyDiagFile) {
				"$(Get-Date -Format 'HH:mm:ss.fff') [ERROR] $($_.Exception.GetType().Name): $($_.Exception.Message)`n$($_.ScriptStackTrace)" | Out-File $script:NotifyDiagFile -Append
			}
		}
		}

		function Remove-Notification {
			if ($null -ne $script:_NotifyIcon) {
				try {
					$script:_NotifyIcon.Visible = $false
					$script:_NotifyIcon.Dispose()
				} catch {}
				$script:_NotifyIcon     = $null
				$script:_NotifyIconEmoji = $null
			}
			if ($null -ne $script:_TrayContextMenu) {
				try { $script:_TrayContextMenu.Dispose() } catch {}
				$script:_TrayContextMenu = $null
				$script:_TrayOpenItem    = $null
				$script:_TrayPauseItem   = $null
			}
			if ($null -ne $script:_ActionIconCache) {
				foreach ($path in $script:_ActionIconCache.Values) {
					try { Remove-Item -Path $path -Force -ErrorAction SilentlyContinue } catch {}
				}
				$script:_ActionIconCache = $null
			}
			$trayPath = Join-Path ([System.IO.Path]::GetTempPath()) "mjig_tray_icon.png"
			if (Test-Path $trayPath) {
				try { Remove-Item -Path $trayPath -Force -ErrorAction SilentlyContinue } catch {}
			}
			if ($null -ne $script:_NotifyAumidSeq -and $script:_NotifyAumidSeq -gt 0) {
				for ($i = 1; $i -le $script:_NotifyAumidSeq; $i++) {
					$staleKey = "HKCU:\Software\Classes\AppUserModelId\svc_$($script:PipeName)_${PID}_$i"
					try { Remove-Item -Path $staleKey -Force -ErrorAction SilentlyContinue } catch {}
				}
				$script:_NotifyAumidSeq = $null
			}
		}
