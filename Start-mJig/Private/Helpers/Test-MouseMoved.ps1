		function Test-MouseMoved {
			param(
				[System.Drawing.Point]$currentPos,
				[System.Drawing.Point]$lastPos,
				[int]$threshold = 2
			)
			if ($null -eq $lastPos) { return $false }
			$deltaX = [Math]::Abs($currentPos.X - $lastPos.X)
			$deltaY = [Math]::Abs($currentPos.Y - $lastPos.Y)
			return ($deltaX -gt $threshold -or $deltaY -gt $threshold)
		}
