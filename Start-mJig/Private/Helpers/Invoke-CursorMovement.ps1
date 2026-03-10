function Invoke-CursorMovement {
	param(
		[System.Collections.Generic.List[System.Drawing.Point]]$Points,
		[int]$FallbackX,
		[int]$FallbackY,
		[int]$StepIntervalMs = 5,
		[int]$DriftThreshold = 3
	)

	if ($Points.Count -gt 1) {
		Start-Sleep -Milliseconds 1
		for ($i = 1; $i -lt $Points.Count; $i++) {
			$point = $Points[$i]
			$script:_MovementPoint.X = $point.X; $script:_MovementPoint.Y = $point.Y
			[System.Windows.Forms.Cursor]::Position = $script:_MovementPoint
			if ($i -lt $Points.Count - 1) {
				Start-Sleep -Milliseconds $StepIntervalMs
				$actualPos = Get-MousePosition
				if ($null -ne $actualPos) {
					$driftX = [Math]::Abs($actualPos.X - $point.X)
					$driftY = [Math]::Abs($actualPos.Y - $point.Y)
					if ($driftX -gt $DriftThreshold -or $driftY -gt $DriftThreshold) {
						return @{ Aborted = $true; Step = $i; TotalSteps = $Points.Count; ActualPosition = $actualPos; DriftX = $driftX; DriftY = $driftY }
					}
				}
			}
		}
	} else {
		$script:_MovementPoint.X = $FallbackX; $script:_MovementPoint.Y = $FallbackY
		[System.Windows.Forms.Cursor]::Position = $script:_MovementPoint
	}

	return @{ Aborted = $false }
}
