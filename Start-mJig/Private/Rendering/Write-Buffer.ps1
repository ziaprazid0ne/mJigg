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
		$nw = $NoWrap.IsPresent
		$rq = $script:RenderQueue
		if (-not $nw -and $X -eq -1 -and $Y -eq -1 -and $rq.Count -gt 0) {
			$prev = $rq[$rq.Count - 1]
			if ($prev[3] -eq $fgCode -and $prev[4] -eq $bgCode -and -not $prev[5]) {
				$prev[2] = $prev[2] + $Text
				return
			}
		}
		$rq.Add([object[]]@($X, $Y, $Text, $fgCode, $bgCode, $nw))
		}
