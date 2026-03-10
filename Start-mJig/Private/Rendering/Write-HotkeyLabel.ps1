function Write-HotkeyLabel {
	param(
		[string]$Text,
		[string]$FG,
		[string]$HotkeyFG,
		[string]$BG,
		[bool]$ShowParens = $script:MenuButtonShowHotkeyParens
	)
	$textParts = $Text -split "([()])"
	for ($j = 0; $j -lt $textParts.Count; $j++) {
		$part = $textParts[$j]
		if ($part -eq "(" -and $j + 2 -lt $textParts.Count -and $textParts[$j + 1] -match "^[a-z]$" -and $textParts[$j + 2] -eq ")") {
			if ($ShowParens) { Write-Buffer -Text "(" -FG $FG -BG $BG }
			Write-Buffer -Text $textParts[$j + 1] -FG $HotkeyFG -BG $BG
			if ($ShowParens) { Write-Buffer -Text ")" -FG $FG -BG $BG }
			$j += 2
		} elseif ($part -ne "") {
			Write-Buffer -Text $part -FG $FG -BG $BG
		}
	}
}
