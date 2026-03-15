		function Set-CoordinateBounds {
			param([ref]$X, [ref]$Y)
			$X.Value = [Math]::Max(0, [Math]::Min($X.Value, $script:ScreenWidth - 1))
			$Y.Value = [Math]::Max(0, [Math]::Min($Y.Value, $script:ScreenHeight - 1))
		}
