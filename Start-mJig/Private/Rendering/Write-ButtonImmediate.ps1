		function Write-ButtonImmediate {
			param($btn, $fg, $bg, $hotkeyFg, $pipeFg = $null, $bracketFg = $null, $bracketBg = $null)
			$text   = $btn.displayText
			$startX = $btn.startX
			$y      = $btn.y
			$rPipeFg    = if ($null -ne $pipeFg)    { $pipeFg }    else { $script:MenuButtonSeparatorFg }
			$rBracketFg = if ($null -ne $bracketFg) { $bracketFg } else { $script:MenuButtonBracketFg }
			$rBracketBg = if ($null -ne $bracketBg) { $bracketBg } else { $script:MenuButtonBracketBg }
			# ? help button: single character rendered entirely in hotkey color, with optional brackets
			if ($btn.isHelpButton -eq $true) {
				$hContentX = $startX
				if ($script:MenuButtonShowBrackets) {
					Write-Buffer -X $hContentX -Y $y -Text "[" -FG $rBracketFg -BG $rBracketBg
					$hContentX += 1
				}
				Write-Buffer -X $hContentX -Y $y -Text "?" -FG $hotkeyFg -BG $bg
				if ($script:MenuButtonShowBrackets) {
					Write-Buffer -Text "]" -FG $rBracketFg -BG $rBracketBg
				}
				Flush-Buffer
				return
			}
			if ($btn.format -eq 0) {
				# Emoji format: "emoji|label (k) text"
				$parts = $text -split "\|", 2
				if ($parts.Count -eq 2) {
					$contentX = $startX
					if ($script:MenuButtonShowBrackets) {
						Write-Buffer -X $contentX -Y $y -Text "[" -FG $rBracketFg -BG $rBracketBg
						$contentX += 1
					}
					if ($script:MenuButtonShowIcon) {
						Write-Buffer -X $contentX -Y $y -Text $parts[0] -BG $bg -Wide
						$sepX = $contentX + 2
						Write-Buffer -X $sepX -Y $y -Text $script:MenuButtonSeparator -FG $rPipeFg -BG $bg
					} else {
						Write-Buffer -X $contentX -Y $y -Text "" -BG $bg
					}
			Write-HotkeyLabel -Text $parts[1] -FG $fg -HotkeyFG $hotkeyFg -BG $bg
				if ($script:MenuButtonShowBrackets) {
					Write-Buffer -Text "]" -FG $rBracketFg -BG $rBracketBg
				}
			}
		} else {
			# Text-only formats (noIcons / short)
			Write-Buffer -X $startX -Y $y -Text "" -BG $bg
		Write-HotkeyLabel -Text $text -FG $fg -HotkeyFG $hotkeyFg -BG $bg
		}
			Flush-Buffer
		}
