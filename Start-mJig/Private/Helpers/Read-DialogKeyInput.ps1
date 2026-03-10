		function Read-DialogKeyInput {
			while ($Host.UI.RawUI.KeyAvailable) {
				$keyInfo = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyup,AllowCtrlC")
				$isKeyDown = $false
				if ($null -ne $keyInfo.KeyDown) { $isKeyDown = $keyInfo.KeyDown }
				if (-not $isKeyDown) {
					return $keyInfo
				}
			}
			return $null
		}
