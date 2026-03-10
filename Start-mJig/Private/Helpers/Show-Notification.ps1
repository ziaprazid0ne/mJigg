		function Show-Notification {
			param(
				[Parameter(Mandatory)][string]$Title,
				[Parameter(Mandatory)][string]$Body,
				[ValidateSet('Info','Warning','Error')]
				[string]$Icon = 'Info',
				[int]$DurationMs = 2000
			)
			try {
				if ($null -eq $script:_NotifyIcon) {
					$script:_NotifyIcon = New-Object System.Windows.Forms.NotifyIcon
					$script:_NotifyIcon.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon(
						(Get-Process -Id $PID).Path
					)
					$script:_NotifyIcon.Visible = $true
				}
				$tipIcon = [System.Windows.Forms.ToolTipIcon]::$Icon
				$script:_NotifyIcon.ShowBalloonTip($DurationMs, $Title, $Body, $tipIcon)
			} catch {}
		}

		function Dispose-Notification {
			if ($null -ne $script:_NotifyIcon) {
				try {
					$script:_NotifyIcon.Visible = $false
					$script:_NotifyIcon.Dispose()
				} catch {}
				$script:_NotifyIcon = $null
			}
		}
