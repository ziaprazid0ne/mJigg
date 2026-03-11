		function Get-SessionIdentifier {
			$bytes = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Windows').ShutdownTime
			$shutdownTime = [DateTime]::FromFileTime([BitConverter]::ToInt64($bytes, 0))
			$seed = "$env:COMPUTERNAME|$env:USERNAME|$($shutdownTime.ToString('yyyyMMddHHmmssfffffff'))"
			$hashBytes = [System.Security.Cryptography.SHA256]::Create().ComputeHash(
				[System.Text.Encoding]::UTF8.GetBytes($seed)
			)
			return @{
				PipeName  = -join ($hashBytes[0..7] | ForEach-Object { '{0:x2}' -f $_ })
				AesKey    = [byte[]]$hashBytes[8..23]
				AuthToken = -join ($hashBytes[24..31] | ForEach-Object { '{0:x2}' -f $_ })
			}
		}
