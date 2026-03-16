	function Set-ThemeProfile {
		param(
			[Parameter(Mandatory = $true)]
			[string]$Name
		)

		$themeEntry = $script:ThemeProfiles | Where-Object { $_.Name -eq $Name } | Select-Object -First 1
		if ($null -eq $themeEntry) { return $false }

		& $themeEntry.Apply

		$script:CurrentThemeName  = $Name
		$script:CurrentThemeIndex = [array]::IndexOf(
			($script:ThemeProfiles | ForEach-Object { $_.Name }),
			$Name
		)
		return $true
	}
