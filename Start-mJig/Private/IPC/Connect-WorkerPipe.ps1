		function Connect-WorkerPipe {
			param(
				[string]$PipeName,
				[int]$ConnectTimeoutMs = 5000
			)
			
			$pipeClient = $null
			$pipeReader = $null
			$pipeWriter = $null
			
			$connectDeadline = (Get-Date).AddMilliseconds($ConnectTimeoutMs)
			$connected = $false
			while (-not $connected -and (Get-Date) -lt $connectDeadline) {
				try {
					$pipeClient = New-Object System.IO.Pipes.NamedPipeClientStream(
						'.', $PipeName,
						[System.IO.Pipes.PipeDirection]::InOut,
						[System.IO.Pipes.PipeOptions]::Asynchronous
					)
					$remainingMs = [int][Math]::Max(500, ($connectDeadline - (Get-Date)).TotalMilliseconds)
					$pipeClient.Connect($remainingMs)
					$connected = $true
				} catch {
					if ($null -ne $pipeClient) { try { $pipeClient.Dispose() } catch {} }
					$pipeClient = $null
					if ((Get-Date) -ge $connectDeadline) { break }
					Start-Sleep -Milliseconds 500
				}
			}
			
			if (-not $connected) {
				Write-Host ""
				Write-Host "ERROR: Could not connect to mJig worker process." -ForegroundColor $script:TextError
				Write-Host "  Pipe: $PipeName  (timed out after $($ConnectTimeoutMs)ms)" -ForegroundColor $script:TextWarning
				Write-Host ""
				return $null
			}
			
			try {
				$pipeReader = New-Object System.IO.StreamReader($pipeClient, [System.Text.Encoding]::UTF8)
				$pipeWriter = New-Object System.IO.StreamWriter($pipeClient, [System.Text.Encoding]::UTF8)
			} catch {
				Write-Host ""
				Write-Host "ERROR: Connected to pipe but failed to create streams." -ForegroundColor $script:TextError
				Write-Host "  $($_.Exception.Message)" -ForegroundColor Gray
				Write-Host ""
				if ($null -ne $pipeClient) { try { $pipeClient.Dispose() } catch {} }
				return $null
			}
			
			# Send encrypted auth handshake
			try {
				Send-PipeMessage -Writer $pipeWriter -Message @{ type = 'auth'; token = $script:PipeAuthToken }
			} catch {
				Write-Host "ERROR: Failed to send auth handshake." -ForegroundColor $script:TextError
				try { $pipeClient.Dispose() } catch {}
				return $null
			}
			
			$welcome = $null
			try {
				$welcomeLine = $pipeReader.ReadLine()
				if ($null -ne $welcomeLine -and $welcomeLine.Length -gt 0) {
					$json = Unprotect-PipeMessage -CipherText $welcomeLine -Key $script:PipeEncryptionKey
					$welcome = $json | ConvertFrom-Json
				}
			} catch {}
			if ($null -eq $welcome -or $welcome.type -ne 'welcome') {
				Write-Host "ERROR: Invalid response from worker." -ForegroundColor $script:TextError
				try { $pipeClient.Dispose() } catch {}
				return $null
			}
			
			return @{
				Client    = $pipeClient
				Reader    = $pipeReader
				Writer    = $pipeWriter
				WorkerPid = $welcome.pid
			}
		}
