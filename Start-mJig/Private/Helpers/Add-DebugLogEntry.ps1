		function Add-DebugLogEntry {
			param(
				$LogArray,
				[string]$Message,
				[string]$ShortMessage,
				$Date = $null
			)
			if ($null -eq $Date) { $Date = Get-Date }
			if ([string]::IsNullOrEmpty($ShortMessage)) { $ShortMessage = $Message }
			$ts = $Date.ToString("HH:mm:ss")
			$null = $LogArray.Add([PSCustomObject]@{
				logRow = $true
				components = @(
					@{ priority = 1; text = $ts; shortText = $ts },
					@{ priority = 2; text = " - [DEBUG] $Message"; shortText = " - [DEBUG] $ShortMessage" }
				)
			})
		}
