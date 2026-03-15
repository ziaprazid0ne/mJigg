		function Reset-PostDialogState {
			param(
				[ref]$SkipUpdateRef,
				[ref]$ForceRedrawRef,
				$OldWindowSizeRef = $null,
				$OldBufferSizeRef = $null
			)
			$SkipUpdateRef.Value = $true
			$ForceRedrawRef.Value = $true
			if ($null -ne $OldWindowSizeRef -and $OldWindowSizeRef -is [ref]) {
				$OldWindowSizeRef.Value = (Get-Host).UI.RawUI.WindowSize
			}
			if ($null -ne $OldBufferSizeRef -and $OldBufferSizeRef -is [ref]) {
				$OldBufferSizeRef.Value = (Get-Host).UI.RawUI.BufferSize
			}
		}
