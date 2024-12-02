function Start-mJig {
	param([Parameter(Mandatory = $false)] [string]$endTime = 2400,[Parameter(Mandatory = $false)] [string]$Output = "yes")

	############
	## CONFIG ## 
	############
	
		$defualtEndTime = 1807 # 4-digit 24 hour format ie. 1807=(6:07 PM). If no end time is provided this default time will be used
		$defualtEndMaxVariance = 15 # A defualt max tolerance in Minutes. Randomly adds or sutracts a set number of minutes from the defaultEndTime to avoid overly consistant end times. (Does not apply if end time is specified.)

		$intervalSeconds = 5 # sets the base interval time between refreshes
		$intervalVariance = 2 # Sets the maximum random plus and minus variance in seconds each refresh

	############
	## SCRIPT ##
	############ 

		$skipUpdate -eq $true
		if ($Output -eq "yes") {
			$pshost = Get-Host; $pswindow = $pshost.UI.RawUI
			$newsize = $pswindow.BufferSize; $newsize.width = 50; $newsize.height = 20; $pswindow.BufferSize = $newsize
			$newsize = $pswindow.windowsize; $newsize.width = 50; $newsize.height = 20; $pswindow.windowsize = $newsize
		}
		$endTime = $defualtEndTime
		if ($endTime -ge 0000 -and $endTime -le 2400 -and $endTime.Length -eq 4) {
			Add-Type -AssemblyName System.Windows.Forms
			$WShell = New-Object -com "Wscript.Shell"
			if ($endTime -eq 2400) { $ras = Get-Random -Maximum 3 -Minimum 1; if ($ras -eq 1) { $endTime = ($DefualtEndTime - (Get-Random -Maximum $defualtEndMaxVariance)) } else { $endTime = ($DefualtEndTime + (Get-Random -Maximum $defualtEndVariance)) } }
			$currentTime = Get-Date -Format "HHmm"; if ($endTime -le $currentTime) { $tommorow = (Get-Date).AddDays(1); $endDate = Get-Date $tommorow -Format "MMdd" } else { $endDate = Get-Date -Format "MMdd" }; $end = "$endDate$endTime"; $time = $false
			:process do {
				$Outputline = 0
				Clear-Host
				if ($skipUpdate -eq $true) {
					[Console]::SetCursorPosition(0,$Outputline); write-host " DEBUG: Update Skipped"; $Outputline++
					[Console]::SetCursorPosition(0,$Outputline); write-host " ---------------------------------------------"; $Outputline++
				}
				if ($skipUpdate -ne $true) {
					$pos = [System.Windows.Forms.Cursor]::Position
					if ($pos -eq $lastPos) {
						$posUpdate = $true
						$rx,$ry,$rasX,$rasy = (Get-Random -Maximum 6),(Get-Random -Maximum 6),(Get-Random -Maximum 2),(Get-Random -Maximum 2)
						if ($rasX -eq 1) { $x = $pos.X + $rx } else { $x = $pos.X - $rx }; if ($rasY -eq 1) { $y = $pos.Y + $ry } else { $y = $pos.Y - $ry }
						$WShell.sendkeys("{SCROLLLOCK}"); Start-Sleep -Milliseconds 100; $WShell.sendkeys("{SCROLLLOCK}")
						[System.Windows.Forms.Cursor]::Position = New-Object System.Drawing.Point ($x,$y)
					} else {
						$posUpdate = $false
					}
					$lastPos = [System.Windows.Forms.Cursor]::Position
				}
				# Clear-Host
				if ($Output -ne "no") {
					[Console]::SetCursorPosition(0,$Outputline); Write-Host "  mJig" -NoNewline -ForegroundColor Magenta; Write-Host " - " -NoNewline; Write-Host "RunningUntil/" -NoNewline -ForegroundColor yellow; Write-Host "$endTime" -NoNewline -ForegroundColor Green; Write-Host " - " -NoNewline; Write-Host "CurrentTime/" -NoNewline -ForegroundColor Yellow; Write-Host "$currentTime" -ForegroundColor Green; $Outputline++
					[Console]::SetCursorPosition(0,$Outputline); Write-Host " ---------------------------------------------"; $Outputline++
				}
				if ($Output -eq "dib") {
					if ($skipUpdate -ne $true) {
						$log9,$log8,$log7,$log6,$log5,$log4,$log3,$log2,$log1 = $log8,$log7,$log6,$log5,$log4,$log3,$log2,$log1,$log0
						$logTime = Get-Date -Format "HH:mm:ss"; if ($posUpdate -eq $false) { $logOutput = "user input detected" } else { $logOutput = "cooridinates update x$x/y$y" }; $log0 = "    $logTime $logOutput"
					}
					foreach ($log in $log9,$log8,$log7,$log6,$log5,$log4,$log3,$log2,$log1,$log0) {
						[Console]::SetCursorPosition(0,$Outputline); Write-Host "$log"; $Outputline++
					}
					[Console]::SetCursorPosition(0,$Outputline); Write-Host " ---------------------------------------------"; $Outputline++
				}	
				if ($Output -ne "no") {
					## Menu Options ##
					write-host " (" -NoNewline; write-host "t" -ForegroundColor Magenta -NoNewline; write-host ")" -NoNewLine; write-host "oggle output  " -ForegroundColor Green -nonewline
					write-host "(" -NoNewline; write-host "q" -ForegroundColor Magenta -NoNewline; write-host ")" -NoNewLine; write-host "uit" -ForegroundColor Green
				}
				$ras = Get-Random -Maximum 3 -Minimum 1; if ($ras -eq 1) { $interval = ($intervalSeconds - (Get-Random -Maximum $intervalVariance)) } else { $interval = ($intervalSeconds + (Get-Random -Maximum $intervalVariance)) }
				$currentTime = Get-Date -Format "HHmm"; $current = Get-Date -Format "MMddHHmm"; if ($current -ge $end) { $time = $true }
				## Menu/Hotkey Loop ##
				$math = $interval * 2
				$x = 0
				$skipUpdate = $false
				:menu do {
					if ($Host.UI.RawUI.KeyAvailable) {
						$keyPress = $Host.UI.RawUI.ReadKey("IncludeKeyup,NoEcho").Character
						if ($keyPress -eq "q") {
							write-host " ---------------------------------------------"
							write-host " DEBUG: key detected"
							write-host " ---------------------------------------------"
							write-Host " " -nonewline
							Write-Host "force quit" -BackgroundColor DarkRed
							return 0;
						} elseif ($keyPress -eq "t") {
							write-host " ---------------------------------------------"
							write-host " DEBUG: key detected"
							if ($Output -eq "dib") {
								$Output = "on"
							} else {
								$Output = "dib"
							}
							$skipUpdate = $true
							continue process
						}
					}
					$x++
					start-sleep -m 500
				} until ($x -eq $math)
			} until ($time -eq $true)
			if ($output -ne "no") {
				Write-Host "       END TIME REACHED: " -NoNewline -ForegroundColor Red; Write-Host "Stopping " -NoNewline; Write-Host "mJig" -ForegroundColor Magenta; Write-Host }
		} else { Write-Host "use 4-digit 24hour time format"; Write-Host }
}
Start-mJig -Output dib