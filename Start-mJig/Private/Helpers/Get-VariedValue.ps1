		function Get-VariedValue {
			param([double]$baseValue, [double]$variance)
			$varianceAmount = Get-Random -Minimum 0.0 -Maximum ($variance + 0.0001)
			if ((Get-Random -Maximum 2) -eq 0) {
				return $baseValue - $varianceAmount
			} else {
				return $baseValue + $varianceAmount
			}
		}
