function Start-mJig {
	param([Parameter(Mandatory = $false)] [string]$endTime = 2400,[Parameter(Mandatory = $false)] [string]$Output = "full")


	###########
	## IDEAS ##
	###########

	# Need More inconography in output.
	# propper hidden oiption
	# stealth toggle for hiding ui (to be seperate from hidden option).
	# Add a routine to determine the direction the cursor moved and add a corosponding arrow emoji to the log. https://unicode.org/emoji/charts/full-emoji-list.html
	# Add indecator for current output mode in top bar

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

		if ($Output -ne "off") {
			$newWidth = 48
			$newHeight = 16
			$pshost = Get-Host
			$pswindow = $pshost.UI.RawUI
			$newBufferSize = $pswindow.BufferSize
			$newBufferSize.Width = $newWidth
			$newBufferSize.Height = $newHeight
			$pswindow.BufferSize = $newBufferSize
			$newWindowSize = $pswindow.WindowSize
			$newWindowSize.Width = $newWidth
			$newWindowSize.Height = $newHeight
			$pswindow.WindowSize = $newWindowSize
		}
		$endTime = $defualtEndTime
		if ($endTime -ge 0000 -and $endTime -le 2400 -and $endTime.Length -eq 4) {
			Add-Type -AssemblyName System.Windows.Forms
			$WShell = New-Object -com "Wscript.Shell"
			if ($endTime -eq 2400) { $ras = Get-Random -Maximum 3 -Minimum 1; if ($ras -eq 1) { $endTime = ($DefualtEndTime - (Get-Random -Maximum $defualtEndMaxVariance)) } else { $endTime = ($DefualtEndTime + (Get-Random -Maximum $defualtEndVariance)) } }
			$currentTime = Get-Date -Format "HHmm"; if ($endTime -le $currentTime) { $tommorow = (Get-Date).AddDays(1); $endDate = Get-Date $tommorow -Format "MMdd" } else { $endDate = Get-Date -Format "MMdd" }; $end = "$endDate$endTime"; $time = $false
			Clear-Host
			[Console]::CursorVisible = $false
			:process do {
				$Outputline = 0
				# Clear-Host
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
				if ($Output -ne "hide") {
					[Console]::SetCursorPosition(0,$Outputline); Write-Host; $Outputline++
					[Console]::SetCursorPosition(0,$Outputline); Write-Host "  mJig(`u{1F400})" -NoNewline -ForegroundColor Magenta; Write-Host " ➢ " -NoNewline; Write-Host "End`u{23F3}/" -NoNewline -ForegroundColor yellow; Write-Host "$endTime" -NoNewline -ForegroundColor Green; Write-Host " ➣ " -NoNewline; Write-Host "Current`u{23F3}/" -NoNewline -ForegroundColor Yellow; Write-Host "$currentTime" -ForegroundColor Green -NoNewline;if($Output -eq "dib"){ write-host " (DiB)" -ForeGroundColor Magenta}elseif($Output -eq "full"){ write-host " (Ful)" -ForeGroundColor Magenta}else{ write-host " (Min)" -ForeGroundColor Magenta}for($i = $Host.UI.RawUI.CursorPosition.x;$i -lt 47;$i++){write-host " " -NoNewline}; $Outputline++
					[Console]::SetCursorPosition(0,$Outputline); Write-Host " ──────────────────────────────────────────────" -ForegroundColor White -NoNewline; for($i = $Host.UI.RawUI.CursorPosition.x; $i -lt 47; $i++){write-host " " -NoNewline}; $Outputline++
				}
				if ($Output -ne "no") {
					if ($skipUpdate -ne $true) {
						$log9,$log8,$log7,$log6,$log5,$log4,$log3,$log2,$log1 = $log8,$log7,$log6,$log5,$log4,$log3,$log2,$log1,$log0
						$logTime = Get-Date -Format "HH:mm:ss"
						if ($posUpdate -eq $false) {
							$logOutput = "input detected, skipping update"
						} else {
							$logOutput = "cooridinates update x$x/y$y"
						}
						$log0 = "   $logTime $logOutput"
					}
					if ($output -ne "min") {
						foreach ($log in $log9,$log8,$log7,$log6,$log5,$log4,$log3,$log2,$log1,$log0) {
							if ($log -notlike "*input detected*") {
								[Console]::SetCursorPosition(0,$Outputline); Write-Host "$log" -NoNewline; for($i = $Host.UI.RawUI.CursorPosition.x; $i -lt 47; $i++){write-host " " -NoNewline}; $Outputline++
							} else {
								[Console]::SetCursorPosition(0,$Outputline); Write-Host "$log" -ForegroundColor DarkGray -NoNewline; for($i = $Host.UI.RawUI.CursorPosition.x; $i -lt 47; $i++){write-host " " -NoNewline}; $Outputline++
							}
						}
					}
					[Console]::SetCursorPosition(0,$Outputline); Write-Host " ──────────────────────────────────────────────" -ForegroundColor White -NoNewline; for($i = $Host.UI.RawUI.CursorPosition.x; $i -lt 47; $i++){write-host " " -NoNewline}; $Outputline++
				}	
				if ($Output -ne "no") {
					## Menu Options ##
					[Console]::SetCursorPosition(0,$Outputline); write-host "  " -NoNewLine ; write-host "`u{1F400}" -NoNewLine; write-host "❲" -NoNewline; write-host "t" -ForegroundColor Yellow -NoNewline; write-host "❳" -NoNewLine; write-host "oggle_output  " -ForegroundColor Green -nonewline; write-host "`u{1F400}❲" -NoNewline ; write-host "h" -ForegroundColor Yellow -NoNewline; write-host "❳" -NoNewline; write-host "ide_output  " -ForegroundColor Green -NoNewline; write-host "`u{1F400}❲" -NoNewline; write-host "q" -ForegroundColor Yellow -NoNewline; write-host "❳" -NoNewLine; write-host "uit" -ForegroundColor Green -NoNewline; for($i = $Host.UI.RawUI.CursorPosition.x; $i -lt 47; $i++){write-host " " -NoNewline}; $Outputline++
					if ($skipUpdate -eq $true) {
						for($h = $Outputline; $h -lt 15; $h++) {
							for($i=$Host.UI.RawUI.CursorPosition.x;$i -lt 47;$i++){write-host " " -NoNewline}; $Outputline++; write-host
						}
						
					}
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
							$Outputline--
							[Console]::SetCursorPosition(0,$Outputline); Write-Host " " -nonewline; Write-Host "force quit" -BackgroundColor DarkRed -NoNewline; for($i = $Host.UI.RawUI.CursorPosition.x; $i -lt 47; $i++){write-host " " -NoNewline}; write-host; write-host
							return;
						} elseif ($keyPress -eq "t") {
							if ($Output -eq "full") {
								$Output = "min"
							} else {
								$Output = "full"
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
				[Console]::SetCursorPosition(0,$Outputline); Write-Host "       END TIME REACHED: " -NoNewline -ForegroundColor Red; Write-Host "Stopping " -NoNewline; Write-Host "mJig"; write-host
			}
		} else {
			Write-Host "use 4-digit 24hour time format"; Write-Host
		}
}
Start-mJig -Output dib