function Show-DiagnosticFiles {
	if (-not $script:DiagEnabled -or -not $script:DiagFolder) { return }

	$diagFiles = @(
		@{ Name = 'startup.txt';        Color = 'Cyan' }
		@{ Name = 'settle.txt';         Color = 'Yellow' }
		@{ Name = 'input.txt';          Color = 'Green' }
		@{ Name = 'ipc.txt';            Color = 'Magenta' }
		@{ Name = 'notify.txt';         Color = 'Blue' }
		@{ Name = 'worker-startup.txt'; Color = 'DarkYellow' }
		@{ Name = 'worker-ipc.txt';     Color = 'DarkCyan' }
	)

	$existingFiles = @()
	foreach ($f in $diagFiles) {
		$path = Join-Path $script:DiagFolder $f.Name
		if (Test-Path $path) {
			$lineCount = @(Get-Content -Path $path -ErrorAction SilentlyContinue).Count
			if ($lineCount -gt 0) {
				$existingFiles += @{ Name = $f.Name; Path = $path; Color = $f.Color; Lines = $lineCount }
			}
		}
	}

	if ($existingFiles.Count -eq 0) { return }

	try { [Console]::Write("$([char]27)[?25h") } catch {}

	Write-Host ""
	Write-Host "  Diagnostic files available ($($existingFiles.Count) files in $script:DiagFolder):" -ForegroundColor White
	foreach ($f in $existingFiles) {
		Write-Host "    - $($f.Name) ($($f.Lines) lines)" -ForegroundColor $f.Color
	}
	Write-Host ""

	$timeout = 15
	$deadline = (Get-Date).AddSeconds($timeout)
	$userChoice = $null

	while ([Console]::KeyAvailable) { $null = [Console]::ReadKey($true) }

	while ((Get-Date) -lt $deadline -and $null -eq $userChoice) {
		$remaining = [math]::Ceiling(($deadline - (Get-Date)).TotalSeconds)
		if ($remaining -lt 0) { $remaining = 0 }
		$prompt = "`r  Print diagnostics to console? [Y/N] (auto-skip in ${remaining}s)  "
		Write-Host $prompt -NoNewline -ForegroundColor DarkGray

		if ([Console]::KeyAvailable) {
			$key = [Console]::ReadKey($true)
			if ($key.Key -eq 'Y') { $userChoice = 'Y' }
			elseif ($key.Key -eq 'N' -or $key.Key -eq 'Enter' -or $key.Key -eq 'Escape') { $userChoice = 'N' }
		}

		if ($null -eq $userChoice) { Start-Sleep -Milliseconds 250 }
	}

	Write-Host ""

	if ($userChoice -ne 'Y') {
		Write-Host "  Skipped. Diagnostics saved in: $script:DiagFolder" -ForegroundColor DarkGray
		Write-Host ""
		return
	}

	$maxRows = 100

	foreach ($file in $existingFiles) {
		$lines = @(Get-Content -Path $file.Path -ErrorAction SilentlyContinue)
		if ($lines.Count -eq 0) { continue }

		$totalLines = $lines.Count
		$linesToShow = [math]::Min($totalLines, $maxRows)

		Write-Host ""
		Write-Host ("  " + ("=" * 60)) -ForegroundColor $file.Color
		Write-Host "  $($file.Name)  ($totalLines lines)" -ForegroundColor $file.Color
		Write-Host ("  " + ("=" * 60)) -ForegroundColor $file.Color

		for ($i = 0; $i -lt $linesToShow; $i++) {
			Write-Host "  $($lines[$i])" -ForegroundColor $file.Color
		}

		if ($totalLines -gt $maxRows) {
			Write-Host ""
			Write-Host "  ... limited to $maxRows of $totalLines rows. See full file: $($file.Path)" -ForegroundColor DarkGray
		}
	}

	Write-Host ""
	Write-Host "  Diagnostics folder: $script:DiagFolder" -ForegroundColor DarkGray
	Write-Host ""
}
