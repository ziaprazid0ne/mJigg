		function Get-CachedMethod {
			param(
				$Type,
				[string]$MethodName
			)
			$cacheKey = "$($Type.FullName).$MethodName"
			if (-not $script:MethodCache.ContainsKey($cacheKey)) {
				$script:MethodCache[$cacheKey] = $Type.GetMethod($MethodName)
			}
			return $script:MethodCache[$cacheKey]
		}
