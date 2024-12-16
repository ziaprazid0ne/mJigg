clear-host
$hostHeight = 15
$rows = $hostHeight - 5
$oldOutputTable = $outputTable
$outputTable = @()
if ($oldRows -ne $rows) {
    write-host test
    for ($i = $rows; $i -ge $oldRows; $i--) {
        $row = [PSCustomObject]@{
            logRow = "$i"
            value = $null
        }
        $outputtable += $row
    }
}
$date = get-date
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