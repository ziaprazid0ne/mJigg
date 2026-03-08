		function Set-CoordinateBounds {
			param([ref]$x, [ref]$y)
			$x.Value = [Math]::Max(0, [Math]::Min($x.Value, $script:ScreenWidth - 1))
			$y.Value = [Math]::Max(0, [Math]::Min($y.Value, $script:ScreenHeight - 1))
		}
