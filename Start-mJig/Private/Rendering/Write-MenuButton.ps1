		function Write-MenuButton {
			param($Button, $FG, $BG, $HotkeyFg, $PipeFg = $null, $BracketFg = $null, $BracketBg = $null)
			$text   = $Button.displayText
			$startX = $Button.startX
			$y      = $Button.y
			$resolvedPipeFg    = if ($null -ne $PipeFg)    { $PipeFg }    else { $script:MenuButtonSeparatorFg }
			$resolvedBracketFg = if ($null -ne $BracketFg) { $BracketFg } else { $script:MenuButtonBracketFg }
			$resolvedBracketBg = if ($null -ne $BracketBg) { $BracketBg } else { $script:MenuButtonBracketBg }
			# Help button: single character rendered in hotkey color, with optional brackets
			if ($Button.isHelpButton -eq $true) {
				$hContentX = $startX
				if ($script:MenuButtonShowBrackets) {
					Write-Buffer -X $hContentX -Y $y -Text "[" -FG $resolvedBracketFg -BG $resolvedBracketBg
					$hContentX += 1
				}
				Write-Buffer -X $hContentX -Y $y -Text "?" -FG $HotkeyFg -BG $BG
				if ($script:MenuButtonShowBrackets) {
					Write-Buffer -Text "]" -FG $resolvedBracketFg -BG $resolvedBracketBg
				}
				Flush-Buffer
				return
			}
			if ($Button.format -eq 0) {
				# Emoji format: "emoji|label (k) text"
				$parts = $text -split "\|", 2
				if ($parts.Count -eq 2) {
					$contentX = $startX
					if ($script:MenuButtonShowBrackets) {
						Write-Buffer -X $contentX -Y $y -Text "[" -FG $resolvedBracketFg -BG $resolvedBracketBg
						$contentX += 1
					}
					if ($script:MenuButtonShowIcon) {
						Write-Buffer -X $contentX -Y $y -Text $parts[0] -BG $BG -Wide
						$sepX = $contentX + 2
						Write-Buffer -X $sepX -Y $y -Text $script:MenuButtonSeparator -FG $resolvedPipeFg -BG $BG
					} else {
						Write-Buffer -X $contentX -Y $y -Text "" -BG $BG
					}
		Write-HotkeyLabel -Text $parts[1] -FG $FG -HotkeyFg $HotkeyFg -BG $BG
			if ($script:MenuButtonShowBrackets) {
				Write-Buffer -Text "]" -FG $resolvedBracketFg -BG $resolvedBracketBg
			}
		}
	} else {
		# Text-only formats (noIcons / short)
		Write-Buffer -X $startX -Y $y -Text "" -BG $BG
	Write-HotkeyLabel -Text $text -FG $FG -HotkeyFg $HotkeyFg -BG $BG
		}
			Flush-Buffer
		}
