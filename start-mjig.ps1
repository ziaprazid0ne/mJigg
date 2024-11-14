function Start-mJig {
    param ([Parameter(Mandatory=$false)][string]$endTime=2400,[Parameter(Mandatory=$false)][int]$waitSeconds=7,[Parameter(Mandatory=$false)][bool]$output=$true)
    $defualtEndTime = 1807 # 4-digit 24 hour format ie. 1807=(6:07 PM). If no end time is provided this default time will be used +/- 15 minutes
    if($endTime -ge 0000 -and $endTime -le 2400 -and $endTime.Length -eq 4) {
        add-Type -AssemblyName System.Windows.Forms
        $WShell = New-Object -com "Wscript.Shell"
        if($endTime -eq 2400){$ras=Get-Random -Maximum 3 -Minimum 1;if($ras -eq 1){$endTime=($DefualtEndTime-(Get-Random -Minimum 0 -Maximum 15))}else{$endTime=($DefualtEndTime+(Get-Random -Minimum 0 -Maximum 15))}}
        $currentTime = Get-Date -Format "HHmm";if($EndTime -le $currentTime){$tommorow=(Get-date).AddDays(1);$endDate=Get-Date $tommorow -Format "MMdd"}else{$endDate=Get-Date -Format "MMdd"};$end="$endDate$endTime"; $time=$false
        while ($time -eq $false) {
            $Pos=[System.Windows.Forms.Cursor]::Position
            if($Pos -eq $LastPos){
                $posUpdate=$true
                $rx,$ry,$rasX,$rasy=(Get-Random -Maximum 6),(Get-Random -Maximum 6),(Get-Random -Maximum 2),(Get-Random -Maximum 2)
                if($rasX -eq 1){$x=$pos.X+$rx}else{$x=$pos.X-$rx};if($rasY -eq 1){$y=$pos.Y+$ry}else{$y=$pos.Y-$ry}
                $WShell.sendkeys("{SCROLLLOCK}");Start-Sleep -Milliseconds 100;$WShell.sendkeys("{SCROLLLOCK}")
                [System.Windows.Forms.Cursor]::Position=New-Object System.Drawing.Point($x,$y)
            }else{$posUpdate = $false}
            $LastPos = [System.Windows.Forms.Cursor]::Position
            clear-host
            if($output -eq $true){
                write-host; write-host " ---------------------------------------------"
                write-host  "  mJig" -NoNewline -ForegroundColor Magenta;write-host " - " -NoNewline;write-host "RunningUntil/" -NoNewline -ForegroundColor yellow
                Write-Host "$endTime" -NoNewline -ForegroundColor Green;Write-Host " - " -NoNewline;write-host "CurrentTime/" -NoNewline -ForegroundColor Yellow
                Write-Host "$currentTime" -ForegroundColor Green; write-host " ---------------------------------------------"
                $log9,$log8,$log7,$log6,$log5,$log4,$log3,$log2,$log1=$log8,$log7,$log6,$log5,$log4,$log3,$log2,$log1,$log0
                $logTime=Get-Date -Format "HH:mm:ss";if($posUpdate -eq $false){$logOutput="Usr.Inp.Detect: skipped update"}else{$logOutput="cooridinates update x$x/y$y"};$log0="    $logTime $logOutput"
                $log9,$log8,$log7,$log6,$log5,$log4,$log3,$log2,$log1,$log0|write-host;write-host " ---------------------------------------------"}
            Start-Sleep -Seconds $waitSeconds
            $currentTime=Get-Date -Format "HHmm";$current=Get-Date -Format "MMddHHmm";if($current -ge $end){$time=$true}
        }
        if($output -eq $true){
        Write-Host "       END TIME REACHED: " -NoNewline -ForegroundColor Red;write-host "Stopping " -NoNewline;write-host "mJig" -ForegroundColor Magenta;write-host}
    } else {write-host "use 4-digit 24hour time format";write-host}
}

Start-mJig