		function Test-GlobalHotkey {
			$shift = ([mJiggAPI.Mouse]::GetAsyncKeyState(0x10) -band 0x8000) -ne 0
			if (-not $shift) { $script:_HotkeyDebounce = $false; return $null }

			$mKey = ([mJiggAPI.Mouse]::GetAsyncKeyState(0x4D) -band 0x8000) -ne 0
			if (-not $mKey) { $script:_HotkeyDebounce = $false; return $null }

			if ($script:_HotkeyDebounce) { return $null }

			$pKey = ([mJiggAPI.Mouse]::GetAsyncKeyState(0x50) -band 0x8000) -ne 0
			$qKey = ([mJiggAPI.Mouse]::GetAsyncKeyState(0x51) -band 0x8000) -ne 0

			if ($pKey) { $script:_HotkeyDebounce = $true; return 'togglePause' }
			if ($qKey) { $script:_HotkeyDebounce = $true; return 'quit' }

			return $null
		}
