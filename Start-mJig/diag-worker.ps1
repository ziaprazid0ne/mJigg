#Requires -Version 5.1
<#
.SYNOPSIS
    Diagnostic script for mJig IPC background worker.
    Tests each layer independently: mutex, pipe, worker spawn, viewer connect.
.NOTES
    Run from an elevated PowerShell 7 prompt:
        pwsh -NoProfile -File .\Start-mJig\diag-worker.ps1
#>
param(
    [string]$PipeName = 'mJig_IPC',
    [string]$MutexName = 'Global\mJig_SingleInstance'
)

$ErrorActionPreference = 'Continue'
$script:PassCount = 0
$script:FailCount = 0
$script:WarnCount = 0

function Write-Step  { param([string]$Text) Write-Host "`n--- $Text ---" -ForegroundColor Cyan }
function Write-Pass  { param([string]$Text) $script:PassCount++; Write-Host "  [PASS] $Text" -ForegroundColor Green }
function Write-Fail  { param([string]$Text) $script:FailCount++; Write-Host "  [FAIL] $Text" -ForegroundColor Red }
function Write-Warn  { param([string]$Text) $script:WarnCount++; Write-Host "  [WARN] $Text" -ForegroundColor Yellow }
function Write-Info  { param([string]$Text) Write-Host "  [INFO] $Text" -ForegroundColor Gray }

Write-Host "============================================" -ForegroundColor White
Write-Host "  mJig Worker Diagnostic" -ForegroundColor White
Write-Host "  $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Gray
Write-Host "============================================" -ForegroundColor White

# ---- 1. Environment ----
Write-Step "1. Environment"
Write-Info "PSVersion       : $($PSVersionTable.PSVersion)"
Write-Info "PSEdition       : $($PSVersionTable.PSEdition)"
Write-Info "OS              : $($PSVersionTable.OS)"
Write-Info "Current exe     : $((Get-Process -Id $PID).Path)"
Write-Info "PID             : $PID"
Write-Info "Is Admin        : $([Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator))"

$pwshPath = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
$psPath   = (Get-Command powershell.exe -ErrorAction SilentlyContinue).Source
Write-Info "pwsh.exe        : $(if ($pwshPath) { $pwshPath } else { '(not found)' })"
Write-Info "powershell.exe  : $(if ($psPath) { $psPath } else { '(not found)' })"

if ($psPath) {
    $ps5ver = & powershell.exe -NoProfile -Command '$PSVersionTable.PSVersion.ToString()' 2>&1
    Write-Info "PS 5.1 version  : $ps5ver"
} else {
    Write-Warn "powershell.exe not found — worker spawn would fail"
}

# ---- 2. Module import test ----
Write-Step "2. Module import (powershell.exe vs pwsh.exe)"
$modPath = Join-Path $PSScriptRoot 'Start-mJig.psm1'
if (-not (Test-Path $modPath)) {
    Write-Fail "Module not found at: $modPath"
} else {
    Write-Pass "Module exists: $modPath"

    # Test import in pwsh
    Write-Info "Testing Import-Module in pwsh..."
    $pwshResult = & pwsh -NoProfile -Command "try { Import-Module '$modPath' -ErrorAction Stop; Write-Output 'OK' } catch { Write-Output `"ERROR: `$(`$_.Exception.Message)`" }" 2>&1
    if ($pwshResult -like 'OK*') {
        Write-Pass "Import-Module in pwsh: OK"
    } else {
        Write-Fail "Import-Module in pwsh: $pwshResult"
    }

    # Test import in powershell.exe (5.1)
    if ($psPath) {
        Write-Info "Testing Import-Module in powershell.exe (5.1)..."
        $ps5Result = & powershell.exe -NoProfile -Command "try { Import-Module '$modPath' -ErrorAction Stop; Write-Output 'OK' } catch { Write-Output `"ERROR: `$(`$_.Exception.Message)`" }" 2>&1
        if ($ps5Result -like 'OK*') {
            Write-Pass "Import-Module in powershell.exe: OK"
        } else {
            Write-Fail "Import-Module in powershell.exe: $ps5Result"
            Write-Info "  Output: $($ps5Result | Out-String)"
            Write-Warn "This is the executable used by worker spawn (line 6069)!"
        }
    }
}

# ---- 3. Mutex ----
Write-Step "3. Mutex ($MutexName)"
$testMutex = $null
$mutexOwned = $false
try {
    $testMutex = New-Object System.Threading.Mutex($false, $MutexName)
    $mutexOwned = $testMutex.WaitOne(0)
    if ($mutexOwned) {
        Write-Pass "Mutex acquired (no other instance running)"
    } else {
        Write-Warn "Mutex NOT acquired — another process holds it"
        # Try to find who holds it
        $allPwsh = Get-Process pwsh, powershell -ErrorAction SilentlyContinue
        if ($allPwsh) {
            Write-Info "Running PowerShell processes:"
            foreach ($p in $allPwsh) {
                $cmdLine = try { (Get-CimInstance Win32_Process -Filter "ProcessId=$($p.Id)" -ErrorAction SilentlyContinue).CommandLine } catch { '(access denied)' }
                $hidden = if ($p.MainWindowHandle -eq 0) { ' [HIDDEN]' } else { '' }
                Write-Info "  PID $($p.Id)$hidden - Started $($p.StartTime) - $cmdLine"
            }
        }
    }
} catch [System.Threading.AbandonedMutexException] {
    $mutexOwned = $true
    Write-Warn "Mutex was ABANDONED (previous owner crashed) — acquired it"
} catch {
    Write-Fail "Mutex error: $($_.Exception.Message)"
} finally {
    if ($mutexOwned -and $null -ne $testMutex) {
        try { $testMutex.ReleaseMutex() } catch {}
    }
    if ($null -ne $testMutex) { $testMutex.Dispose() }
}

# ---- 4. Named Pipe (standalone) ----
Write-Step "4. Named Pipe — standalone create + connect"
$pipeServer = $null
$pipeClient = $null
try {
    $pipeServer = New-Object System.IO.Pipes.NamedPipeServerStream(
        'mJig_IPC_DIAG',
        [System.IO.Pipes.PipeDirection]::InOut,
        1,
        [System.IO.Pipes.PipeTransmissionMode]::Byte,
        [System.IO.Pipes.PipeOptions]::Asynchronous
    )
    Write-Pass "Pipe server created (mJig_IPC_DIAG)"

    $asyncResult = $pipeServer.BeginWaitForConnection($null, $null)
    Write-Pass "BeginWaitForConnection started"

    $pipeClient = New-Object System.IO.Pipes.NamedPipeClientStream(
        '.', 'mJig_IPC_DIAG',
        [System.IO.Pipes.PipeDirection]::InOut,
        [System.IO.Pipes.PipeOptions]::Asynchronous
    )
    $pipeClient.Connect(3000)
    Write-Pass "Client connected to pipe"

    $pipeServer.EndWaitForConnection($asyncResult)
    Write-Pass "Server accepted connection"

    $writer = New-Object System.IO.StreamWriter($pipeServer, [System.Text.Encoding]::UTF8)
    $reader = New-Object System.IO.StreamReader($pipeClient, [System.Text.Encoding]::UTF8)

    $testMsg = @{ type = 'test'; data = 'hello from diag' } | ConvertTo-Json -Compress
    $writer.WriteLine($testMsg)
    $writer.Flush()

    $received = $reader.ReadLine()
    if ($received -eq $testMsg) {
        Write-Pass "Message round-trip: OK"
    } else {
        Write-Fail "Message mismatch: sent=$testMsg received=$received"
    }

    $reader.Dispose()
    $writer.Dispose()
} catch {
    Write-Fail "Pipe test error: $($_.Exception.GetType().Name): $($_.Exception.Message)"
} finally {
    if ($null -ne $pipeClient) { try { $pipeClient.Dispose() } catch {} }
    if ($null -ne $pipeServer) { try { $pipeServer.Dispose() } catch {} }
}

# ---- 5. Check if mJig_IPC pipe already exists ----
Write-Step "5. Check for existing '$PipeName' pipe"
$existingPipe = $null
try {
    $existingPipe = New-Object System.IO.Pipes.NamedPipeClientStream(
        '.', $PipeName,
        [System.IO.Pipes.PipeDirection]::InOut,
        [System.IO.Pipes.PipeOptions]::Asynchronous
    )
    $existingPipe.Connect(1000)
    Write-Pass "Connected to existing $PipeName pipe — a worker IS listening"
    # Try to read welcome
    $r = New-Object System.IO.StreamReader($existingPipe, [System.Text.Encoding]::UTF8)
    $line = $r.ReadLine()
    if ($null -ne $line) {
        $msg = $line | ConvertFrom-Json
        Write-Info "  Received: type=$($msg.type)  pid=$($msg.pid)  version=$($msg.version)"
    }
    $r.Dispose()
} catch [System.TimeoutException] {
    Write-Info "No existing $PipeName pipe found (expected if no worker is running)"
} catch {
    $innerMsg = $_.Exception.InnerException.Message
    if ($innerMsg) {
        Write-Info "No existing pipe: $innerMsg"
    } else {
        Write-Info "No existing pipe: $($_.Exception.Message)"
    }
} finally {
    if ($null -ne $existingPipe) { try { $existingPipe.Dispose() } catch {} }
}

# ---- 6. Spawn worker (visible) and try to connect ----
Write-Step "6. Spawn worker VISIBLE and connect"
Write-Info "Building worker command..."

$workerCmd = "Import-Module '$modPath'; Start-mJig -_WorkerMode -_InModuleRunspace -_PipeName '$PipeName'"
Write-Info "Worker command: $workerCmd"

# Determine the correct executable
$spawnExe = if ($PSVersionTable.PSEdition -eq 'Core') {
    (Get-Process -Id $PID).Path  # use same pwsh that's running this diag
} else {
    'powershell.exe'
}
Write-Info "Spawn executable: $spawnExe"
Write-Info "NOTE: The actual Start-mJig code uses 'powershell.exe' (5.1) — see line 6069"

# First, grab the mutex so we can release it for the worker
$spawnMutex = $null
$spawnMutexOwned = $false
try {
    $spawnMutex = New-Object System.Threading.Mutex($false, $MutexName)
    $spawnMutexOwned = $spawnMutex.WaitOne(0)
} catch [System.Threading.AbandonedMutexException] {
    $spawnMutexOwned = $true
} catch {}

if (-not $spawnMutexOwned) {
    Write-Warn "Cannot acquire mutex for spawn test — another instance holds it"
    Write-Info "Kill stale processes first, then re-run this diagnostic"
} else {
    # Release it so the worker can acquire it
    try { $spawnMutex.ReleaseMutex() } catch {}
    $spawnMutex.Dispose()
    $spawnMutex = $null

    Write-Info "Spawning worker with VISIBLE window for debugging..."

    # Test 6a: spawn with powershell.exe (what the real code does)
    Write-Info ""
    Write-Info "=== Test 6a: using powershell.exe (what Start-mJig actually uses) ==="
    $workerArgs51 = @('-NoProfile', '-NoLogo', '-Command', $workerCmd)
    $workerProc51 = $null
    try {
        $workerProc51 = Start-Process -FilePath 'powershell.exe' -ArgumentList $workerArgs51 -PassThru
        Write-Pass "Worker spawned with powershell.exe (PID: $($workerProc51.Id))"

        # Wait for pipe to become available
        Write-Info "Waiting for pipe to become available (up to 15s)..."
        $deadline = (Get-Date).AddSeconds(15)
        $pipeFound = $false
        $attempt = 0
        while ((Get-Date) -lt $deadline) {
            $attempt++
            $testClient = $null
            try {
                $testClient = New-Object System.IO.Pipes.NamedPipeClientStream(
                    '.', $PipeName,
                    [System.IO.Pipes.PipeDirection]::InOut,
                    [System.IO.Pipes.PipeOptions]::Asynchronous
                )
                $testClient.Connect(1000)
                $pipeFound = $true
                Write-Pass "Connected to worker pipe on attempt $attempt (elapsed: $([int]((Get-Date) - $deadline.AddSeconds(-15)).TotalMilliseconds)ms)"

                $tr = New-Object System.IO.StreamReader($testClient, [System.Text.Encoding]::UTF8)
                $line = $tr.ReadLine()
                if ($null -ne $line) {
                    $welcomeMsg = $line | ConvertFrom-Json
                    Write-Pass "Welcome message: type=$($welcomeMsg.type) pid=$($welcomeMsg.pid) version=$($welcomeMsg.version)"
                } else {
                    Write-Fail "No welcome message received (ReadLine returned null)"
                }
                $tr.Dispose()
                break
            } catch {
                if ($null -ne $testClient) { try { $testClient.Dispose() } catch {} }
                $testClient = $null

                # Check if worker process exited
                if ($workerProc51.HasExited) {
                    Write-Fail "Worker process EXITED with code $($workerProc51.ExitCode) before pipe was available (attempt $attempt)"
                    break
                }

                Start-Sleep -Milliseconds 500
            } finally {
                if ($null -ne $testClient) { try { $testClient.Dispose() } catch {} }
            }
        }

        if (-not $pipeFound -and -not $workerProc51.HasExited) {
            Write-Fail "Pipe never became available (15s timeout, $attempt attempts)"
            Write-Info "Worker process is still running (PID: $($workerProc51.Id)) — check its window for errors"
        }
    } catch {
        Write-Fail "Failed to spawn worker: $($_.Exception.Message)"
    } finally {
        if ($null -ne $workerProc51 -and -not $workerProc51.HasExited) {
            Write-Info "Stopping worker process (PID: $($workerProc51.Id))..."
            try { $workerProc51.Kill() } catch {}
            $workerProc51.WaitForExit(3000)
            Write-Info "Worker stopped"
        }
    }

    # Small delay to let mutex release
    Start-Sleep -Milliseconds 500

    # Test 6b: spawn with pwsh.exe (what it should probably use)
    if ($pwshPath) {
        Write-Info ""
        Write-Info "=== Test 6b: using pwsh.exe (PowerShell 7) ==="
        $workerArgsPwsh = @('-NoProfile', '-NoLogo', '-Command', $workerCmd)
        $workerProcPwsh = $null
        try {
            $workerProcPwsh = Start-Process -FilePath $pwshPath -ArgumentList $workerArgsPwsh -PassThru
            Write-Pass "Worker spawned with pwsh.exe (PID: $($workerProcPwsh.Id))"

            Write-Info "Waiting for pipe to become available (up to 15s)..."
            $deadline = (Get-Date).AddSeconds(15)
            $pipeFound = $false
            $attempt = 0
            while ((Get-Date) -lt $deadline) {
                $attempt++
                $testClient = $null
                try {
                    $testClient = New-Object System.IO.Pipes.NamedPipeClientStream(
                        '.', $PipeName,
                        [System.IO.Pipes.PipeDirection]::InOut,
                        [System.IO.Pipes.PipeOptions]::Asynchronous
                    )
                    $testClient.Connect(1000)
                    $pipeFound = $true
                    Write-Pass "Connected to worker pipe on attempt $attempt (elapsed: $([int]((Get-Date) - $deadline.AddSeconds(-15)).TotalMilliseconds)ms)"

                    $tr = New-Object System.IO.StreamReader($testClient, [System.Text.Encoding]::UTF8)
                    $line = $tr.ReadLine()
                    if ($null -ne $line) {
                        $welcomeMsg = $line | ConvertFrom-Json
                        Write-Pass "Welcome message: type=$($welcomeMsg.type) pid=$($welcomeMsg.pid) version=$($welcomeMsg.version)"
                    } else {
                        Write-Fail "No welcome message received (ReadLine returned null)"
                    }
                    $tr.Dispose()
                    break
                } catch {
                    if ($null -ne $testClient) { try { $testClient.Dispose() } catch {} }
                    $testClient = $null

                    if ($workerProcPwsh.HasExited) {
                        Write-Fail "Worker process EXITED with code $($workerProcPwsh.ExitCode) before pipe was available (attempt $attempt)"
                        break
                    }

                    Start-Sleep -Milliseconds 500
                } finally {
                    if ($null -ne $testClient) { try { $testClient.Dispose() } catch {} }
                }
            }

            if (-not $pipeFound -and -not $workerProcPwsh.HasExited) {
                Write-Fail "Pipe never became available (15s timeout, $attempt attempts)"
                Write-Info "Worker process is still running (PID: $($workerProcPwsh.Id)) — check its window for errors"
            }
        } catch {
            Write-Fail "Failed to spawn worker: $($_.Exception.Message)"
        } finally {
            if ($null -ne $workerProcPwsh -and -not $workerProcPwsh.HasExited) {
                Write-Info "Stopping worker process (PID: $($workerProcPwsh.Id))..."
                try { $workerProcPwsh.Kill() } catch {}
                $workerProcPwsh.WaitForExit(3000)
                Write-Info "Worker stopped"
            }
        }
    }
}

# ---- Summary ----
Write-Host "`n============================================" -ForegroundColor White
Write-Host "  Results: $script:PassCount passed, $script:FailCount failed, $script:WarnCount warnings" -ForegroundColor $(
    if ($script:FailCount -gt 0) { 'Red' } elseif ($script:WarnCount -gt 0) { 'Yellow' } else { 'Green' }
)
Write-Host "============================================" -ForegroundColor White

if ($script:FailCount -gt 0) {
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "  - If powershell.exe import FAILED but pwsh import PASSED:" -ForegroundColor Gray
    Write-Host "      Fix: change 'powershell.exe' to 'pwsh.exe' at line 6069 of Start-mJig.psm1" -ForegroundColor Gray
    Write-Host "  - If mutex is held by another process:" -ForegroundColor Gray
    Write-Host "      Fix: kill stale mJig processes, then re-run" -ForegroundColor Gray
    Write-Host "  - If worker exits immediately:" -ForegroundColor Gray
    Write-Host "      Check the visible worker window for error messages" -ForegroundColor Gray
}
