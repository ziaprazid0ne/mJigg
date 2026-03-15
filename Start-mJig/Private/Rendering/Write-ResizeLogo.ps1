	function Write-ResizeLogo {
			param(
				[switch]$ClearFirst,
				[object]$WindowSize = $null
			)
			try {
				$rawUI = $Host.UI.RawUI
				$winSize = if ($null -ne $WindowSize) { $WindowSize } else { $rawUI.WindowSize }
				$winWidth = $winSize.Width
				$winHeight = $winSize.Height

		# Lock height to suppress ±1 transient row fluctuations during width-only resize
		if ($null -ne $WindowSize) {
			if ($null -eq $script:ResizeLogoLockedHeight) {
				$script:ResizeLogoLockedHeight = $winHeight
			} elseif ([math]::Abs($winHeight - $script:ResizeLogoLockedHeight) -gt 1) {
				$script:ResizeLogoLockedHeight = $winHeight
			}
			$winHeight = $script:ResizeLogoLockedHeight
		}
				
				# Only draw if window is large enough
				if ($winWidth -lt 16 -or $winHeight -lt 14) {
					return
				}
				
				# Select a random quote if we do not have one yet
				if ($null -eq $script:CurrentResizeQuote) {
					$script:CurrentResizeQuote = $script:ResizeQuotes | Get-Random
				}
				
			$boxTL = $script:BoxTopLeft
			$boxTR = $script:BoxTopRight
			$boxBL = $script:BoxBottomLeft
			$boxBR = $script:BoxBottomRight
			$boxH = $script:BoxHorizontal
			$boxV = $script:BoxVertical
				
				# Logo display width: mJig( (5) + emoji (2) + ) (1) = 8
				$logoDisplayWidth = 8
				
				# Calculate center position for logo
				$centerX = [math]::Floor(($winWidth - $logoDisplayWidth) / 2)
				$centerY = [math]::Floor($winHeight / 2)
				
			# Box dimensions: 42% of available space as padding, minimum 3 rows/cols
			$minPadding = 3
			$availableH = [math]::Min($centerX - 1, $winWidth - $centerX - $logoDisplayWidth - 1)
			$availableV = [math]::Min($centerY - 1, $winHeight - $centerY - 2)
			$boxPaddingH = [math]::Max($minPadding * 2, [math]::Floor($availableH * 0.42))
				$boxPaddingV = [math]::Max($minPadding, [math]::Floor($availableV * 0.42))
				$boxLeft = $centerX - $boxPaddingH - 1
				$boxRight = $centerX + $logoDisplayWidth + $boxPaddingH
				$boxTop = $centerY - $boxPaddingV - 1
				$boxBottom = $centerY + $boxPaddingV + 1
				$boxInnerWidth = $boxRight - $boxLeft - 1
				
				# Build horizontal line string once
				$hLine = [string]::new($boxH, $boxInnerWidth)
				
				Write-Buffer -X $boxLeft -Y $boxTop -Text "$boxTL$hLine$boxTR"
				for ($y = $boxTop + 1; $y -lt $boxBottom; $y++) {
					Write-Buffer -X $boxLeft -Y $y -Text "$boxV"
					Write-Buffer -X $boxRight -Y $y -Text "$boxV"
				}
				Write-Buffer -X $boxLeft -Y $boxBottom -Text "$boxBL$hLine$boxBR"
				
				$emojiX = $centerX + 5
				Write-Buffer -X $centerX -Y $centerY -Text "mJig(" -FG $script:ResizeLogoName
				Write-Buffer -X $emojiX -Y $centerY -Text ([char]::ConvertFromUtf32(0x1F400)) -FG $script:ResizeLogoIcon
				Write-Buffer -X ($emojiX + 2) -Y $centerY -Text ")" -FG $script:ResizeLogoName
				
				$quoteY = $centerY + 2
				if ($quoteY -lt $boxBottom -and $null -ne $script:CurrentResizeQuote) {
					$quote = $script:CurrentResizeQuote
					$maxQuoteWidth = $boxInnerWidth - 2
					if ($quote.Length -gt $maxQuoteWidth) {
						$quote = $quote.Substring(0, $maxQuoteWidth - 3) + "..."
					}
					$quoteX = [math]::Floor(($winWidth - $quote.Length) / 2)
					Write-Buffer -X $quoteX -Y $quoteY -Text $quote -FG $script:ResizeQuoteText
				}
				if ($ClearFirst) { Flush-Buffer -ClearFirst } else { Flush-Buffer }
				
			} catch {
				try {
					$winSize = $Host.UI.RawUI.WindowSize
					$centerX = [math]::Max(0, [math]::Floor(($winSize.Width - 8) / 2))
					$centerY = [math]::Max(0, [math]::Floor($winSize.Height / 2))
					Write-Buffer -X $centerX -Y $centerY -Text "mJig(" -FG $script:ResizeLogoName
					Write-Buffer -Text ([char]::ConvertFromUtf32(0x1F400)) -FG $script:ResizeLogoIcon
					Write-Buffer -Text ")" -FG $script:ResizeLogoName
					if ($ClearFirst) { Flush-Buffer -ClearFirst } else { Flush-Buffer }
				} catch { }
			}
		}
