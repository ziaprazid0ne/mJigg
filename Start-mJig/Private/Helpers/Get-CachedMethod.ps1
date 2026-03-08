		function Get-CachedMethod {
			param(
				$type,
				[string]$methodName
			)
			$cacheKey = "$($type.FullName).$methodName"
			if (-not $script:MethodCache.ContainsKey($cacheKey)) {
				$script:MethodCache[$cacheKey] = $type.GetMethod($methodName)
			}
			return $script:MethodCache[$cacheKey]
		}
