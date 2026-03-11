		function Read-PipeMessage {
			param(
				[System.IO.StreamReader]$Reader,
				[ref]$PendingTask
			)
			try {
				if ($null -eq $PendingTask.Value) {
					$PendingTask.Value = $Reader.ReadLineAsync()
				}
				if (-not $PendingTask.Value.IsCompleted) {
					return $null
				}
				$line = $PendingTask.Value.GetAwaiter().GetResult()
				$PendingTask.Value = $null
				if ($null -ne $line -and $line.Length -gt 0) {
					$json = Unprotect-PipeMessage -CipherText $line -Key $script:PipeEncryptionKey
					return $json | ConvertFrom-Json
				}
			} catch {
				$PendingTask.Value = $null
				throw
			}
			return $null
		}
