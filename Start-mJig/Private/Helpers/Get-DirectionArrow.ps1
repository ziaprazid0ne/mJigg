		function Get-DirectionArrow {
			param(
				[int]$deltaX,
				[int]$deltaY,
				[string]$style = "simple"  # "arrows", "text", or "simple"
			)
			
		$arrowRight = [char]::ConvertFromUtf32(0x27A1)  # U+27A1
			$arrowLeft = [char]::ConvertFromUtf32(0x2B05)   # U+2B05
			$arrowDown = [char]::ConvertFromUtf32(0x2B07)   # U+2B07
			$arrowUp = [char]::ConvertFromUtf32(0x2B06)     # U+2B06
			$arrowSE = [char]::ConvertFromUtf32(0x2198)     # U+2198
			$arrowNE = [char]::ConvertFromUtf32(0x2197)     # U+2197
			$arrowSW = [char]::ConvertFromUtf32(0x2199)     # U+2199
			$arrowNW = [char]::ConvertFromUtf32(0x2196)     # U+2196
			
		$simpleRight = [char]0x2192  # U+2192
			$simpleLeft = [char]0x2190   # U+2190
			$simpleDown = [char]0x2193   # U+2193
			$simpleUp = [char]0x2191     # U+2191
			$simpleSE = [char]0x2198     # U+2198
			$simpleNE = [char]0x2197     # U+2197
			$simpleSW = [char]0x2199     # U+2199
			$simpleNW = [char]0x2196     # U+2196
			
		$absX = [Math]::Abs($deltaX)
		$absY = [Math]::Abs($deltaY)

		if ($absX -lt 5 -and $absY -lt 5) {
				return ""
			}
			
		if ($absX -gt $absY * 2) {
				# Primarily horizontal
				if ($style -eq "text") {
					if ($deltaX -gt 0) { return "E" } else { return "W" }
				} elseif ($style -eq "arrows") {
					if ($deltaX -gt 0) { return $arrowRight } else { return $arrowLeft }
				} else {
					# simple style
					if ($deltaX -gt 0) { return $simpleRight } else { return $simpleLeft }
				}
			} elseif ($absY -gt $absX * 2) {
				# Primarily vertical
				if ($style -eq "text") {
					if ($deltaY -gt 0) { return "S" } else { return "N" }
				} elseif ($style -eq "arrows") {
					if ($deltaY -gt 0) { return $arrowDown } else { return $arrowUp }
				} else {
					# simple style
					if ($deltaY -gt 0) { return $simpleDown } else { return $simpleUp }
				}
			} else {
				# Diagonal movement
				if ($style -eq "text") {
					if ($deltaX -gt 0 -and $deltaY -gt 0) {
						return "SE"
					} elseif ($deltaX -gt 0 -and $deltaY -lt 0) {
						return "NE"
					} elseif ($deltaX -lt 0 -and $deltaY -gt 0) {
						return "SW"
					} else {
						return "NW"
					}
				} elseif ($style -eq "arrows") {
					if ($deltaX -gt 0 -and $deltaY -gt 0) {
						return $arrowSE
					} elseif ($deltaX -gt 0 -and $deltaY -lt 0) {
						return $arrowNE
					} elseif ($deltaX -lt 0 -and $deltaY -gt 0) {
						return $arrowSW
					} else {
						return $arrowNW
					}
				} else {
					# simple style
					if ($deltaX -gt 0 -and $deltaY -gt 0) {
						return $simpleSE
					} elseif ($deltaX -gt 0 -and $deltaY -lt 0) {
						return $simpleNE
					} elseif ($deltaX -lt 0 -and $deltaY -gt 0) {
						return $simpleSW
					} else {
						return $simpleNW
					}
				}
			}
		}
