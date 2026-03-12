		function Flush-Buffer {
			param([switch]$ClearFirst)
			if ($script:RenderQueue.Count -eq 0) { return }
			$c = $script:CSI
			$sb = $script:FrameBuilder
			[void]$sb.Clear()
			[void]$sb.Append($c).Append('?25l')
			if ($ClearFirst) { [void]$sb.Append($c).Append('2J').Append($c).Append('3J') }
			$lastFG = -1
			$lastBG = -1
		foreach ($seg in $script:RenderQueue) {
			if ($seg[5]) { [void]$sb.Append($c).Append('?7l') }
			if ($seg[0] -ge 0 -and $seg[1] -ge 0) {
				[void]$sb.Append($c).Append($seg[1] + 1).Append(';').Append($seg[0] + 1).Append('H')
			}
			if ($seg[3] -ne $lastFG -or $seg[4] -ne $lastBG) {
				[void]$sb.Append($c).Append($seg[3]).Append(';').Append($seg[4]).Append('m')
				$lastFG = $seg[3]
				$lastBG = $seg[4]
			}
			[void]$sb.Append($seg[2])
			if ($seg[5]) { [void]$sb.Append($c).Append('?7h') }
		}
			[void]$sb.Append($c).Append('0m')
			if ($script:CursorVisible) { [void]$sb.Append($c).Append('?25h') }
			[Console]::Write($sb.ToString())
			$script:RenderQueue.Clear()
		}
