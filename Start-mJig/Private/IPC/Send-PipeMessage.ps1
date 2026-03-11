		function Send-PipeMessage {
			param(
				[System.IO.StreamWriter]$Writer,
				[hashtable]$Message
			)
			$json = $Message | ConvertTo-Json -Compress -Depth 3
			$encrypted = Protect-PipeMessage -PlainText $json -Key $script:PipeEncryptionKey
			$Writer.WriteLine($encrypted)
			$Writer.Flush()
		}
