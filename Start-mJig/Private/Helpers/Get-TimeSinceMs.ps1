		function Get-TimeSinceMs {
			param($StartTime)
			if ($null -eq $StartTime) { return [double]::MaxValue }
			return ((Get-Date) - [DateTime]$StartTime).TotalMilliseconds
		}
