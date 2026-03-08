		function Get-MousePosition {
			$point = New-Object mJiggAPI.POINT
			$mouseType = [mJiggAPI.Mouse]
			$getCursorPosMethod = Get-CachedMethod -type $mouseType -methodName "GetCursorPos"
			if ($null -ne $getCursorPosMethod -and [mJiggAPI.Mouse]::GetCursorPos([ref]$point)) {
				return New-Object System.Drawing.Point($point.X, $point.Y)
			}
			return $null
		}
