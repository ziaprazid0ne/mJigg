		function Test-MouseMoved {
			param(
				[System.Drawing.Point]$CurrentPos,
				[System.Drawing.Point]$LastPos,
				[int]$Threshold = 2
			)
			if ($null -eq $LastPos) { return $false }
			$deltaX = [Math]::Abs($CurrentPos.X - $LastPos.X)
			$deltaY = [Math]::Abs($CurrentPos.Y - $LastPos.Y)
			return ($deltaX -gt $Threshold -or $deltaY -gt $Threshold)
		}
