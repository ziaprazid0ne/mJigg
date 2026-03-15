		function Get-MousePosition {
			if ($null -eq $script:_ReusableApiPoint) {
				$script:_ReusableApiPoint = New-Object $script:PointType
				$script:_ReusableDrawPoint = New-Object System.Drawing.Point
			}
			$mouseType = $script:MouseAPI
			$getCursorPosMethod = Get-CachedMethod -type $mouseType -MethodName "GetCursorPos"
			if ($null -ne $getCursorPosMethod -and $script:MouseAPI::GetCursorPos([ref]$script:_ReusableApiPoint)) {
				$script:_ReusableDrawPoint.X = $script:_ReusableApiPoint.X
				$script:_ReusableDrawPoint.Y = $script:_ReusableApiPoint.Y
				return $script:_ReusableDrawPoint
			}
			return $null
		}
