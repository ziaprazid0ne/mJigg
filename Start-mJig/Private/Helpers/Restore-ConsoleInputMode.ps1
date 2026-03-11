	function Restore-ConsoleInputMode {
		try {
			$hConsole = $script:MouseAPI::GetStdHandle(-10)  # STD_INPUT_HANDLE
			$mode = [uint32]0
			if ($script:MouseAPI::GetConsoleMode($hConsole, [ref]$mode)) {
				$ENABLE_QUICK_EDIT_MODE = 0x0040
				$ENABLE_MOUSE_INPUT     = 0x0010
				$newMode = ($mode -band (-bnot $ENABLE_QUICK_EDIT_MODE)) -bor $ENABLE_MOUSE_INPUT
				$script:MouseAPI::SetConsoleMode($hConsole, $newMode) | Out-Null
			}
		} catch { }
	}
