		function Get-DialogMouseClick {
			param([array]$PeekBuffer)
			try {
				$peekEvts = [uint32]0
				$hIn = $script:MouseAPI::GetStdHandle(-10)
				if ($script:MouseAPI::PeekConsoleInput($hIn, $PeekBuffer, $PeekBuffer.Length, [ref]$peekEvts) -and $peekEvts -gt 0) {
					$lastClickIdx = -1
					$clickX = -1; $clickY = -1
					for ($e = 0; $e -lt $peekEvts; $e++) {
						if ($PeekBuffer[$e].EventType -eq 0x0002 -and $PeekBuffer[$e].MouseEvent.dwEventFlags -eq 0 -and ($PeekBuffer[$e].MouseEvent.dwButtonState -band 0x0001) -ne 0) {
							$clickX = $PeekBuffer[$e].MouseEvent.dwMousePosition.X
							$clickY = $PeekBuffer[$e].MouseEvent.dwMousePosition.Y
							$lastClickIdx = $e
						}
					}
					if ($lastClickIdx -ge 0) {
						$consumeCount = [uint32]($lastClickIdx + 1)
						$flushed = [uint32]0
						$script:MouseAPI::ReadConsoleInput($hIn, $PeekBuffer, $consumeCount, [ref]$flushed) | Out-Null
						return @{ X = $clickX; Y = $clickY }
					}
				}
			} catch { }
			return $null
		}
