		function Show-Notification {
			param(
				[Parameter(Mandatory)][string]$Title,
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
				"$(Get-Date -Format 'HH:mm:ss.fff') [ENTRY] Action=$Action Title='$Title' Body='$Body' ToastAPI=$($null -ne $script:ToastAPI)" | Out-File $script:NotifyDiagFile -Append
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

				# --- Tray icon: title emoji (unchanged) ---
				if ($script:_NotifyIconEmoji -ne $script:TitleEmoji) {
					$trayEmojiStr = [char]::ConvertFromUtf32($script:TitleEmoji)
					$trayIconPath = Join-Path ([System.IO.Path]::GetTempPath()) "mjig_tray_icon.png"

					$rendered = $false
					if ($null -ne $script:ToastAPI) {
						try {
							$script:ToastAPI::RenderEmojiToPng($trayEmojiStr, $trayIconPath, 64)
							$rendered = $true
						} catch {
							if ($script:DiagEnabled -and $script:NotifyDiagFile) {
								"$(Get-Date -Format 'HH:mm:ss.fff') [RENDER-TRAY] $($_.Exception.GetType().Name): $($_.Exception.Message)" | Out-File $script:NotifyDiagFile -Append
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
							$gfx, $trayEmojiStr, $emojiFont, $rect,
							[System.Drawing.Color]::White, $tflags)
						$gfx.Dispose()
						$emojiFont.Dispose()
						$bmp.Save($trayIconPath, [System.Drawing.Imaging.ImageFormat]::Png)
						$bmp.Dispose()
					}

					if ($null -ne $script:_NotifyIcon) {
						$script:_NotifyIcon.Visible = $false
						$script:_NotifyIcon.Dispose()
					}
					$script:_NotifyIcon = New-Object System.Windows.Forms.NotifyIcon
					$trayBmp = New-Object System.Drawing.Bitmap($trayIconPath)
					$script:_NotifyIcon.Icon = [System.Drawing.Icon]::FromHandle($trayBmp.GetHicon())
					$trayBmp.Dispose()
					$script:_NotifyIcon.Visible = $true

					$script:_NotifyIconEmoji = $script:TitleEmoji
				}
				$script:_NotifyIcon.Text = $script:WindowTitle

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

				$escapedTitle = [System.Security.SecurityElement]::Escape($Title)
				$escapedBody  = [System.Security.SecurityElement]::Escape($Body)
				$imgSrc  = $toastImgPath.Replace('\', '/')
				$toastXml = "<toast duration=`"short`"><visual><binding template=`"ToastGeneric`">" +
				            "<text>$escapedTitle</text><text>$escapedBody</text>" +
				            "<image placement=`"appLogoOverride`" src=`"file:///$imgSrc`"/>" +
				            "</binding></visual></toast>"

				$toastShown = $false
				if ($null -ne $script:ToastAPI) {
					try {
						$null = New-Item -Path $regKey -Force
						$null = New-ItemProperty -Path $regKey -Name 'DisplayName' -Value $script:WindowTitle -PropertyType ExpandString -Force
						$null = New-ItemProperty -Path $regKey -Name 'IconUri' -Value $toastImgPath -PropertyType ExpandString -Force
						try {
							$script:ToastAPI::ShowToast($toastXml, $aumid)
							$toastShown = $true
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
					"$(Get-Date -Format 'HH:mm:ss.fff') [TIER1-SKIP] ToastAPI is null" | Out-File $script:NotifyDiagFile -Append
				}

				if (-not $toastShown) {
					try {
						$null = New-Item -Path $regKey -Force
						$null = New-ItemProperty -Path $regKey -Name 'DisplayName' -Value $script:WindowTitle -PropertyType ExpandString -Force
						$null = New-ItemProperty -Path $regKey -Name 'IconUri' -Value $toastImgPath -PropertyType ExpandString -Force
						$safeTitle = $Title.Replace("'", "''")
						$safeBody  = $Body.Replace("'", "''")
						$safeImg   = $imgSrc.Replace("'", "''")
						$safeAumid = $aumid.Replace("'", "''")
						$toastCmd  = '[void][Windows.UI.Notifications.ToastNotificationManager,Windows.UI.Notifications,ContentType=WindowsRuntime];' +
						             '[void][Windows.Data.Xml.Dom.XmlDocument,Windows.Data.Xml.Dom,ContentType=WindowsRuntime];' +
						             '$x=New-Object Windows.Data.Xml.Dom.XmlDocument;' +
						             '$x.LoadXml(''<toast duration="short"><visual><binding template="ToastGeneric">' +
						             "<text>$safeTitle</text><text>$safeBody</text>" +
						             "<image placement=""appLogoOverride"" src=""file:///$safeImg""/>" +
						             '</binding></visual></toast>'');' +
						             '$t=[Windows.UI.Notifications.ToastNotification]::new($x);' +
						             "[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('$safeAumid').Show(" + '$t)'
						Start-Process powershell.exe -ArgumentList '-NoProfile','-WindowStyle','Hidden','-Command',$toastCmd -WindowStyle Hidden
						Start-Sleep -Milliseconds 500
						$toastShown = $true
						if ($script:DiagEnabled -and $script:NotifyDiagFile) {
							"$(Get-Date -Format 'HH:mm:ss.fff') [TIER2-OK] action=$Action aumid=$safeAumid" | Out-File $script:NotifyDiagFile -Append
						}
					} catch {
						if ($script:DiagEnabled -and $script:NotifyDiagFile) {
							"$(Get-Date -Format 'HH:mm:ss.fff') [TIER2-PS51] $($_.Exception.GetType().Name): $($_.Exception.Message)" | Out-File $script:NotifyDiagFile -Append
						}
					} finally {
						Remove-Item -Path $regKey -Force -ErrorAction SilentlyContinue
					}
				}

				if (-not $toastShown) {
					$tipIcon = [System.Windows.Forms.ToolTipIcon]::$Icon
					$script:_NotifyIcon.ShowBalloonTip($DurationMs, $Title, $Body, $tipIcon)
					if ($script:DiagEnabled -and $script:NotifyDiagFile) {
						"$(Get-Date -Format 'HH:mm:ss.fff') [TIER3-BALLOON] action=$Action" | Out-File $script:NotifyDiagFile -Append
					}
				}
			} catch {
				if ($script:DiagEnabled -and $script:NotifyDiagFile) {
					"$(Get-Date -Format 'HH:mm:ss.fff') [ERROR] $($_.Exception.GetType().Name): $($_.Exception.Message)`n$($_.ScriptStackTrace)" | Out-File $script:NotifyDiagFile -Append
				}
			}
		}

		function Dispose-Notification {
			if ($null -ne $script:_NotifyIcon) {
				try {
					$script:_NotifyIcon.Visible = $false
					$script:_NotifyIcon.Dispose()
				} catch {}
				$script:_NotifyIcon     = $null
				$script:_NotifyIconEmoji = $null
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
