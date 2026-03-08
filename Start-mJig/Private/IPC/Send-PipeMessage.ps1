		function Send-PipeMessage {
			param(
				[System.IO.StreamWriter]$Writer,
				[hashtable]$Message
			)
			$json = $Message | ConvertTo-Json -Compress -Depth 3
			$Writer.WriteLine($json)
			$Writer.Flush()
		}
