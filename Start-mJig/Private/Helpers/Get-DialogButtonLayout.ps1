		function Get-DialogButtonLayout {
			return @{
				IconWidth    = if ($script:DialogButtonShowIcon)         { 2 + $script:DialogButtonSeparator.Length } else { 0 }
				BracketWidth = if ($script:DialogButtonShowBrackets)     { 2 } else { 0 }
				ParenAdj     = if ($script:DialogButtonShowHotkeyParens) { 0 } else { -2 }
			}
		}
