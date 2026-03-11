		function Send-PipeMessageNonBlocking {
			param(
				[System.IO.StreamWriter]$Writer,
				[hashtable]$Message,
				[ref]$PendingFlush
			)
			if ($null -ne $PendingFlush.Value) {
				if (-not $PendingFlush.Value.IsCompleted) {
					return $false
				}
				if ($PendingFlush.Value.IsFaulted) {
					$ex = $PendingFlush.Value.Exception
					$PendingFlush.Value = $null
					throw $ex
				}
				$PendingFlush.Value = $null
			}
			$json = $Message | ConvertTo-Json -Compress -Depth 3
			$encrypted = Protect-PipeMessage -PlainText $json -Key $script:PipeEncryptionKey
			$Writer.WriteLine($encrypted)
			$PendingFlush.Value = $Writer.FlushAsync()
			return $true
		}
