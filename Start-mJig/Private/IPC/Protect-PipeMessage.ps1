		function Protect-PipeMessage {
			param([string]$PlainText, [byte[]]$Key)
			$aes = [System.Security.Cryptography.Aes]::Create()
			$aes.Key = $Key
			$aes.GenerateIV()
			$encryptor = $aes.CreateEncryptor()
			$plainBytes = [System.Text.Encoding]::UTF8.GetBytes($PlainText)
			$cipherBytes = $encryptor.TransformFinalBlock($plainBytes, 0, $plainBytes.Length)
			$result = [byte[]]::new($aes.IV.Length + $cipherBytes.Length)
			[Array]::Copy($aes.IV, 0, $result, 0, $aes.IV.Length)
			[Array]::Copy($cipherBytes, 0, $result, $aes.IV.Length, $cipherBytes.Length)
			$aes.Dispose()
			return [Convert]::ToBase64String($result)
		}

		function Unprotect-PipeMessage {
			param([string]$CipherText, [byte[]]$Key)
			$data = [Convert]::FromBase64String($CipherText)
			$aes = [System.Security.Cryptography.Aes]::Create()
			$aes.Key = $Key
			$aes.IV = $data[0..15]
			$decryptor = $aes.CreateDecryptor()
			$plainBytes = $decryptor.TransformFinalBlock($data, 16, $data.Length - 16)
			$aes.Dispose()
			return [System.Text.Encoding]::UTF8.GetString($plainBytes)
		}
