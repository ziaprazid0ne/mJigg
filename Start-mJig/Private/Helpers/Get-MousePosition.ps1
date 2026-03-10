		function Get-MousePosition {
			if ($null -eq $script:_ReusableApiPoint) {
				$script:_ReusableApiPoint = New-Object mJiggAPI.POINT
				$script:_ReusableDrawPoint = New-Object System.Drawing.Point
			}
			$mouseType = [mJiggAPI.Mouse]
			$getCursorPosMethod = Get-CachedMethod -type $mouseType -methodName "GetCursorPos"
			if ($null -ne $getCursorPosMethod -and [mJiggAPI.Mouse]::GetCursorPos([ref]$script:_ReusableApiPoint)) {
				$script:_ReusableDrawPoint.X = $script:_ReusableApiPoint.X
				$script:_ReusableDrawPoint.Y = $script:_ReusableApiPoint.Y
				return $script:_ReusableDrawPoint
			}
			return $null
		}
