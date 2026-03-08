	function Get-LatestVersionInfo {
		param([switch]$Force)
		if (-not $Force -and $null -ne $script:VersionCheckCache) {
			return $script:VersionCheckCache
		}
		$ProgressPreference = 'SilentlyContinue'
		try {
			$response   = Invoke-RestMethod -Uri "https://api.github.com/repos/ziaprazid0ne/mJig/releases/latest" -TimeoutSec 5 -UseBasicParsing
			$latestTag  = $response.tag_name -replace '^v', ''
			$isNewer    = $false
			try { $isNewer = ([version]$latestTag -gt [version]$script:Version) } catch {}
			$result = @{ latest = $latestTag; url = $response.html_url; isNewer = $isNewer; error = $null }
		} catch {
			$result = @{ latest = $null; url = $null; isNewer = $false; error = "Could not connect" }
		}
		$script:VersionCheckCache = $result
		return $result
	}
