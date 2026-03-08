		function Get-TimeSinceMs {
			param($startTime)
			if ($null -eq $startTime) { return [double]::MaxValue }
			return ((Get-Date) - [DateTime]$startTime).TotalMilliseconds
		}
