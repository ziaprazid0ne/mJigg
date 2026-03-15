	function Write-Buffer {
		param(
			[int]$X = -1,
			[int]$Y = -1,
			[string]$Text,
			[object]$FG = $null,
			[object]$BG = $null,
			[switch]$Wide,
			[switch]$NoWrap
		)
		if ($Wide -and $null -ne $BG) { $Text = $Text + " " }
		$fgCode = if ($null -ne $FG) { $script:AnsiFG[[ConsoleColor]$FG] } else { 39 }
		$bgCode = if ($null -ne $BG) { $script:AnsiBG[[ConsoleColor]$BG] } else { 49 }
		$isNoWrap    = $NoWrap.IsPresent
		$renderQueue = $script:RenderQueue
		if (-not $isNoWrap -and $X -eq -1 -and $Y -eq -1 -and $renderQueue.Count -gt 0) {
			$prevSegment = $renderQueue[$renderQueue.Count - 1]
			if ($prevSegment[3] -eq $fgCode -and $prevSegment[4] -eq $bgCode -and -not $prevSegment[5]) {
				$prevSegment[2] = $prevSegment[2] + $Text
				return
			}
		}
		$segment = [object[]]::new(6)
	$segment[0] = $X; $segment[1] = $Y; $segment[2] = $Text; $segment[3] = $fgCode; $segment[4] = $bgCode; $segment[5] = $isNoWrap
	$renderQueue.Add($segment)
		}
