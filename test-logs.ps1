:loop do {
    $loop = 0
    Clear-host
    $pshost = Get-Host
    $pswindow = $pshost.UI.RawUI
    $newBufferSize = $pswindow.BufferSize
    $hostHeight = $newBufferSize.Height
    $rows = $hostHeight - 5
    $oldOutputTable = $outputTable
    $outputTable = @()
    $date = get-date
    if ($oldRows -ne $rows) {
        if ($oldRows -lt $rows) {
            for ($i = $rows; $i -ge $oldRows; $i--) {
                $row = [PSCustomObject]@{
                    logRow = "$i"
                    value = $null
                }
                $outputtable += $row
            }
        } else {
            for ($i = $oldRows; $i -ge $rows; $i--) {
                $outputtable.remove[0]
            }
        }
    }
    for ($i = $rows; $i -ge 1; $i--) {
        if ($i -ne 1) {
            $row = [PSCustomObject]@{
                logRow = "$i"
                value = $oldOutputTable[$rows-$i+1].value
            }
        } else {
            $row = [PSCustomObject]@{
                logRow = "$i"
                value = $date
            }
        }
        $outputtable += $row
        write-host $outputTable[$rows-$i].value
    }
    $oldRows = $rows
    $loop++
    Start-Sleep -seconds 2
} until ($loop -eq 50)