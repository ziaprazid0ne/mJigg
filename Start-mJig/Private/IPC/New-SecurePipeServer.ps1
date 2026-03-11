		function New-SecurePipeServer {
			param([string]$PipeName)
			try {
				$security = New-Object System.IO.Pipes.PipeSecurity
				$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
				$rule = New-Object System.IO.Pipes.PipeAccessRule(
					$currentUser, 'FullControl', 'Allow'
				)
				$security.AddAccessRule($rule)
				return New-Object System.IO.Pipes.NamedPipeServerStream(
					$PipeName,
					[System.IO.Pipes.PipeDirection]::InOut, 1,
					[System.IO.Pipes.PipeTransmissionMode]::Byte,
					[System.IO.Pipes.PipeOptions]::Asynchronous,
					65536, 65536, $security
				)
			} catch {
				return New-Object System.IO.Pipes.NamedPipeServerStream(
					$PipeName,
					[System.IO.Pipes.PipeDirection]::InOut, 1,
					[System.IO.Pipes.PipeTransmissionMode]::Byte,
					[System.IO.Pipes.PipeOptions]::Asynchronous,
					65536, 65536
				)
			}
		}
