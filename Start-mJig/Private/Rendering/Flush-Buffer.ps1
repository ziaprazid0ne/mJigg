		function Flush-Buffer {
			param([switch]$ClearFirst)
			if ($script:RenderQueue.Count -eq 0) { return }
			$csi          = $script:CSI
			$frameBuilder = $script:FrameBuilder
			[void]$frameBuilder.Clear()
			[void]$frameBuilder.Append($csi).Append('?25l')
			if ($ClearFirst) { [void]$frameBuilder.Append($csi).Append('2J').Append($csi).Append('3J') }
			$lastFG = -1
			$lastBG = -1
		foreach ($segment in $script:RenderQueue) {
			if ($segment[5]) { [void]$frameBuilder.Append($csi).Append('?7l') }
			if ($segment[0] -ge 0 -and $segment[1] -ge 0) {
				[void]$frameBuilder.Append($csi).Append($segment[1] + 1).Append(';').Append($segment[0] + 1).Append('H')
			}
			if ($segment[3] -ne $lastFG -or $segment[4] -ne $lastBG) {
				[void]$frameBuilder.Append($csi).Append($segment[3]).Append(';').Append($segment[4]).Append('m')
				$lastFG = $segment[3]
				$lastBG = $segment[4]
			}
			[void]$frameBuilder.Append($segment[2])
			if ($segment[5]) { [void]$frameBuilder.Append($csi).Append('?7h') }
		}
			[void]$frameBuilder.Append($csi).Append('0m')
			if ($script:CursorVisible) { [void]$frameBuilder.Append($csi).Append('?25h') }
			[Console]::Write($frameBuilder.ToString())
			$script:RenderQueue.Clear()
		}
