:loop do {
    $loop = 0
    Clear-host
    $pshost = Get-Host
    $pswindow = $pshost.UI.RawUI
    $newBufferSize = $pswindow.BufferSize
    $hostHeight = $newBufferSize.Height
    $rows = $hostHeight - 5
    $oldLogArray = $LogArray
    $LogArray = @()
    $date = get-date
    if ($oldRows -ne $rows) {
        if ($oldRows -lt $rows) {
            $insertArray=@()
            $row = [PSCustomObject]@{
                logRow = "insert"
                value = $null
            }
            for ($i = $rows; $i -gt $oldRows; $i--) {
                $insertArray += $row
            }
            $oldLogArray = $insertArray + $oldLogArray
        } else {
            #for ($i = $oldRows; $i -le $rows; $i--) {
            #    $oldLogArray = $oldLogArray | Select-Object -skip 1
            #}
            $oldLogArray = $oldLogArray[-($oldRows-($oldRows-$rows))..-1]
        }
    }
    for ($i = $rows; $i -ge 1; $i--) {
        if ($i -ne 1) {
            $row = [PSCustomObject]@{
                logRow = "$i"
                value = $oldLogArray[$rows-$i+1].value
            }
        } else {
            $row = [PSCustomObject]@{
                logRow = "$i"
                value = $date
            }
        }
        $LogArray += $row

    }
    $oldLogArray | format-table # [$rows-$i].value
    $oldRows = $rows
    $loop++
    Start-Sleep -seconds .2
} until ($loop -eq 200)