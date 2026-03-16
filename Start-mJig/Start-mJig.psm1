function Start-mJig {

	<############################################################
	## mJig - An overly complex powershell mouse jiggling tool ##
	#############################################################
	   '      \              /          \
	  |       |Oo          o|            |
	  `    \  |OOOo......oOO|   /        |
	   `    \\OOOOOOOOOOOOOOO\//        /
		 \ _o\OOOOOOOOOOOOOOOO//. ___ /
	 ______OOOOOOOOOOOOOOOOOOOOOOOo.___
	  --- OO'* `OOOOOOOOOO'*  `OOOOO--
		  OO.   OOOOOOOOO'    .OOOOO o
		  `-OOooOOOOOOOOOooooOOOOOO_OOOo
		.OO "-OOOOOOOOOOOOOOOOO-"OOOOOOOo
	 __OOOOO`_OOOOOOOOOOOOOOO"-OOOOOOOOOOOo-
	 _0OOOOOOOO_"OOOOOOOOOOO"_OOOOOOOOOOOOOOO_
	 OOOOO^OOOO0`(____)/"OOOOOOOOOOOOO^OOOOOO
	 OOOOO OO000/00||00\000000OOOOOOOO OOOOOO-
	 OOOOO O0000000000000000 ppppoooooOOOOOO
	 `OOOOO 0000000000000000 QQQQ "OOOOOOO"
	  o"OOOO 000000000000000oooooOOoooooooO'
	  OOo"OOOO.00000000000000000OOOOOOOO'
	 OOOOOO QQQQ 0000000000000000000OOOOOOO
	OOOOOO00eeee00000000000000000000OOOOOOOO.
	OOOOOOOO000000000000000000000000OOOOOOOOOO
	OOOOOOOOO00000000000000000000000OOOOOOOOOO-
	`OOOOOOOOO000000000000000000000OOOOOOOOOOO.
	 "OOOOOOOO0000000000000000000OOOOOOOOOOO'
	   "OOOOOOO00000000000000000OOOOOOOOOO"
	.ooooOOOOOOOo"OOOOOOO000000000000OOOOOOOOOOO"
	.OOO"""""""""".oOOOOOOOOOOOOOOOOOOOOOOOOOOOOo
	OOO         QQQQO"'                     `"QQQQ
	OOO
	`OOo.
	`"wigglejiggleoooooooo#>

	param(
		[Parameter(Mandatory = $false)] 
		[ValidateSet("min", "full", "hidden")]
		[string]$Output = "min",
		[Parameter(Mandatory = $false)]
		[switch]$DebugMode,
		[Parameter(Mandatory = $false)]
		[switch]$Diag,
		[Parameter(Mandatory = $false)] 
		[string]$EndTime = "0",  # 0 = no end time, otherwise 4-digit 24 hour format (e.g., 1807 = 6:07 PM)
		[Parameter(Mandatory = $false)]
		[int]$EndVariance = 0,  # Variance in minutes to randomly add/subtract from EndTime to avoid overly consistent end times. Only applies if EndTime is specified (not 0).
		[Parameter(Mandatory = $false)]
		[double]$IntervalSeconds = 5,   # sets the base interval time between refreshes
		[Parameter(Mandatory = $false)]
		[double]$IntervalVariance = 3,  # Sets the maximum random plus and minus variance in seconds each refresh
		[Parameter(Mandatory = $false)]
		[double]$MoveSpeed = 0.5,  # Base movement speed in seconds (time to complete movement)
		[Parameter(Mandatory = $false)]
		[double]$MoveVariance = 0.2,  # Maximum random variance in movement speed (in seconds)
		[Parameter(Mandatory = $false)]
		[double]$TravelDistance = 400,  # Base travel distance in pixels
		[Parameter(Mandatory = $false)]
		[double]$TravelVariance = 365,  # Maximum random variance in travel distance (in pixels)
		[Parameter(Mandatory = $false)]
		[double]$AutoResumeDelaySeconds = 0,  # Timer in seconds that resets on user input detection. When > 0, coordinate updates and simulated key presses are skipped.
		[Parameter(Mandatory = $false)]
		[string]$Title = "",  # Custom window title override (e.g. "Windows Update")
		[Parameter(Mandatory = $false)]
		[string]$Theme = "",  # Theme profile name to apply at startup (e.g. "default", "debug")
		[Parameter(Mandatory = $false)]
		[switch]$Headless,  # Fire-and-forget mode: spawn worker then exit (no TUI)
		[Parameter(Mandatory = $false)]
		[switch]$Inline,  # Run without background worker (legacy single-process mode)
		[Parameter(Mandatory = $false, DontShow = $true)]
		[switch]$_WorkerMode,  # Internal: background worker entry point
		[Parameter(Mandatory = $false, DontShow = $true)]
		[string]$_PipeName = 'mJig_IPC',  # Internal: named pipe identifier
		[Parameter(Mandatory = $false, DontShow = $true)]
		[switch]$_InModuleRunspace  # Internal: set by the provisioner on re-entry. Never passed by users.
	)

	# ---- Module Runspace Provisioner ------------------------------------------------
	# Runs Start-mJig in a fresh, isolated runspace — separate from the caller's session.
	if (-not $_InModuleRunspace) {
		$_modPath = Join-Path $PSScriptRoot 'Start-mJig.psm1'

		# Save process-global console state (restored on exit)
		$_savedTitle = try { $Host.UI.RawUI.WindowTitle } catch { $null }
		$_k32Loaded = $false
		try {
			try { [void][_mJigProv._K32] } catch {
				Add-Type -Name '_K32' -Namespace '_mJigProv' -ErrorAction Stop -MemberDefinition @'
[DllImport("kernel32.dll")] public static extern IntPtr GetStdHandle(int n);
[DllImport("kernel32.dll")] public static extern bool GetConsoleMode(IntPtr h, out uint m);
[DllImport("kernel32.dll")] public static extern bool SetConsoleMode(IntPtr h, uint m);
'@
			}
			$_hIn  = [_mJigProv._K32]::GetStdHandle(-10)
			$_hOut = [_mJigProv._K32]::GetStdHandle(-11)
			$_savedInMode = [uint32]0; $_savedOutMode = [uint32]0
			$null = [_mJigProv._K32]::GetConsoleMode($_hIn,  [ref]$_savedInMode)
			$null = [_mJigProv._K32]::GetConsoleMode($_hOut, [ref]$_savedOutMode)
			$_k32Loaded = $true
		} catch { }

		# Minimal InitialSessionState — no profiles, no snap-ins, no Format-Table overhead
		$_iss = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault2()
		$_iss.Formats.Clear()
		$_iss.ThrowOnRunspaceOpenError = $true

		$_rs  = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace($Host, $_iss)
		$_rs.ApartmentState = [System.Threading.ApartmentState]::STA
		$_rs.Open()
		$_ps = [System.Management.Automation.PowerShell]::Create()
		$_ps.Runspace = $_rs

		if ($DebugMode) {
			$_parentRsId = if ([System.Management.Automation.Runspaces.Runspace]::DefaultRunspace) {
				[System.Management.Automation.Runspaces.Runspace]::DefaultRunspace.Id } else { '(none)' }
			Write-Host "[RUNSPACE] Provisioner: launching isolated child" -ForegroundColor Cyan
			Write-Host "  Parent Runspace  : ID $_parentRsId"  -ForegroundColor Gray
			Write-Host "  Child  Runspace  : ID $($_rs.Id)"    -ForegroundColor Gray
			Write-Host "  Thread           : $([System.Threading.Thread]::CurrentThread.ManagedThreadId)" -ForegroundColor Gray
			Write-Host "  ApartmentState   : $($_rs.ApartmentState)" -ForegroundColor Gray
			Write-Host "  ISS base         : CreateDefault2 (Core + Utility + Management)" -ForegroundColor Gray
			Write-Host "  ISS Formats      : $($_iss.Formats.Count) (cleared)" -ForegroundColor Gray
			Write-Host "  Console IN mode  : 0x$($_savedInMode.ToString('X4'))  $(if ($_k32Loaded) {'(saved)'} else {'(save failed)'})" -ForegroundColor Gray
			Write-Host "  Console OUT mode : 0x$($_savedOutMode.ToString('X4'))  $(if ($_k32Loaded) {'(saved)'} else {'(save failed)'})" -ForegroundColor Gray
			Write-Host "  Window title     : $_savedTitle (saved)" -ForegroundColor Gray
			Write-Host ""
		}

		# Instant terminal-close handler — fires on CTRL_CLOSE_EVENT before PS grace period
		try { [void][_mJigCloseHandlerX] } catch {
			Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public class _mJigCloseHandlerX {
    public delegate bool HandlerDelegate(uint ctrlType);
    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool SetConsoleCtrlHandler(HandlerDelegate h, bool add);
    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern bool TerminateProcess(IntPtr hProcess, uint exitCode);
    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern IntPtr GetCurrentProcess();
    private static HandlerDelegate _delegate;
    public static void Register() {
        _delegate = new HandlerDelegate(OnClose);
        SetConsoleCtrlHandler(_delegate, true);
    }
    public static void Unregister() {
        if (_delegate != null) { SetConsoleCtrlHandler(_delegate, false); _delegate = null; }
    }
    private static bool OnClose(uint t) {
        if (t == 2 || t == 5 || t == 6) { TerminateProcess(GetCurrentProcess(), 0); }
        return false;
    }
}
'@ -ErrorAction SilentlyContinue
		}
		$_closeHandlerRegistered = $false
		try { [_mJigCloseHandlerX]::Register(); $_closeHandlerRegistered = $true } catch {}

		try {
			$null = $_ps.AddScript("Import-Module '$_modPath'")
			$null = $_ps.AddStatement().AddCommand('Start-mJig')
			$null = $_ps.AddParameter('_InModuleRunspace', $true)
			foreach ($_kvp in $PSBoundParameters.GetEnumerator()) {
				$null = $_ps.AddParameter($_kvp.Key, $_kvp.Value)
			}
			# BeginInvoke + poll — keeps outer thread interruptible for instant close
			$_asyncResult = $_ps.BeginInvoke()
			while (-not $_asyncResult.IsCompleted) {
				Start-Sleep -Milliseconds 50
			}
			try { $null = $_ps.EndInvoke($_asyncResult) } catch {}
			if ($_ps.HadErrors -and $DebugMode) {
				$_errStream = $_ps.Streams.Error
				if ($_errStream.Count -gt 0) {
					$_uniqueErrors = @{}
					foreach ($_err in $_errStream) {
						$_key = "$($_err.Exception.Message)|$($_err.InvocationInfo.ScriptLineNumber)"
						if (-not $_uniqueErrors.ContainsKey($_key)) {
							$_uniqueErrors[$_key] = @{ Error = $_err; Count = 1 }
						} else {
							$_uniqueErrors[$_key].Count++
						}
					}
					Write-Host ""
					Write-Host "[RUNSPACE] $($_errStream.Count) non-terminating error(s) in child ($($_uniqueErrors.Count) unique):" -ForegroundColor DarkYellow
					foreach ($_entry in $_uniqueErrors.Values) {
						$_e = $_entry.Error
						$_c = $_entry.Count
						$_line = if ($_e.InvocationInfo) { $_e.InvocationInfo.ScriptLineNumber } else { '?' }
						Write-Host "  Line $_line (x$_c): $($_e.Exception.Message)" -ForegroundColor DarkYellow
					}
				}
			}
		} finally {
			if ($_closeHandlerRegistered) { try { [_mJigCloseHandlerX]::Unregister() } catch {} }
			# Stop + EndInvoke: waits for BatchInvocationWorkItem thread to fully exit
			if ($null -ne $_asyncResult -and -not $_asyncResult.IsCompleted) {
				try { $null = $_ps.Stop() } catch {}
			}
			if ($null -ne $_asyncResult) {
				try { $null = $_ps.EndInvoke($_asyncResult) } catch {}
			}
			$_ps.Dispose()
			$_rs.Close()
			$_rs.Dispose()

			# Restore process-global console state (VT100, mode flags, title)
			try { [Console]::Write("$([char]27)[?25h$([char]27)[?7h$([char]27)[0m") } catch {}
			if ($_k32Loaded) {
				try { $null = [_mJigProv._K32]::SetConsoleMode($_hIn,  $_savedInMode)  } catch {}
				try { $null = [_mJigProv._K32]::SetConsoleMode($_hOut, $_savedOutMode) } catch {}
			}
			if ($null -ne $_savedTitle) {
				try { $Host.UI.RawUI.WindowTitle = $_savedTitle } catch {}
			}
			# In debug mode, pause before clearing so any errors or init output can be read.
			if ($DebugMode) {
				Write-Host ""
				Write-Host "Press any key to exit..." -ForegroundColor Yellow
				try {
					$Host.UI.RawUI.FlushInputBuffer()
					while ($true) {
						Start-Sleep -Milliseconds 50
						if ($Host.UI.RawUI.KeyAvailable) {
							try { $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown,IncludeKeyUp,AllowCtrlC") } catch {}
							break
						}
					}
				} catch {}
			}
			try { [Console]::Clear() } catch {}
			if ($DebugMode) {
				Write-Host ""
				Write-Host "[RUNSPACE] Child exited - console state restored" -ForegroundColor Cyan
				if ($_k32Loaded) {
					$_finalIn = [uint32]0; $_finalOut = [uint32]0
					$null = [_mJigProv._K32]::GetConsoleMode($_hIn,  [ref]$_finalIn)
					$null = [_mJigProv._K32]::GetConsoleMode($_hOut, [ref]$_finalOut)
					Write-Host "  Console IN mode  : 0x$($_finalIn.ToString('X4'))"  -ForegroundColor Gray
					Write-Host "  Console OUT mode : 0x$($_finalOut.ToString('X4'))" -ForegroundColor Gray
				}
				Write-Host "  Window title     : $($Host.UI.RawUI.WindowTitle)" -ForegroundColor Gray
			}
		}
		return
	}
	# ---- End Module Runspace Provisioner --------------------------------------------

	# Worker startup diagnostics — traces hidden-process initialization when -Diag is set
	if ($_WorkerMode -and $Diag) {
		$script:_wsDiagFolder = Join-Path $PSScriptRoot "_diag"
		if (-not (Test-Path $script:_wsDiagFolder)) { New-Item -ItemType Directory -Path $script:_wsDiagFolder -Force | Out-Null }
		$script:_wsDiagFile = Join-Path $script:_wsDiagFolder "worker-startup.txt"
		"=== Worker Startup Diag: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff') PID=$PID ===" | Out-File $script:_wsDiagFile
		"$(Get-Date -Format 'HH:mm:ss.fff') [1] Process alive  PSVersion=$($PSVersionTable.PSVersion)  _PipeName=$_PipeName  _WorkerMode=$_WorkerMode  _InModuleRunspace=$_InModuleRunspace" | Out-File $script:_wsDiagFile -Append
	}

	# ---- Suppress PowerShell Logging ------------------------------------------------
	# Disable Group Policy logging cache (reflection) and stop any active transcript
	try {
		$groupPolicySettingsField = [ref].Assembly.GetType('System.Management.Automation.Utils').GetField(
			'cachedGroupPolicySettings', 'NonPublic,Static')
		if ($groupPolicySettingsField) {
			$groupPolicySettings = $groupPolicySettingsField.GetValue($null)
			if ($groupPolicySettings) {
				foreach ($key in @('ScriptBlockLogging', 'ModuleLogging', 'Transcription')) {
					if ($groupPolicySettings.ContainsKey($key)) {
						foreach ($prop in @($groupPolicySettings[$key].Keys)) {
							$groupPolicySettings[$key][$prop] = if ($prop -eq 'OutputDirectory') { '' } else { 0 }
						}
					}
				}
				if ($script:DebugMode) { Add-DebugLogEntry "GP logging cache neutralized" }
			}
		}
	} catch {}

	# Stop active transcript
	try {
		$transcriptOutput = Stop-Transcript *>&1 | Out-String
		if ($transcriptOutput -match 'output file is\s+(.+?)(\r?\n|$)') {
			$transcriptPath = $Matches[1].Trim()
			if (Test-Path $transcriptPath) {
				Remove-Item $transcriptPath -Force -ErrorAction SilentlyContinue
			}
		}
	} catch {}
	# ---- End Suppress PowerShell Logging -------------------------------------------

	############
	## Preparing ##
	############ 

	# Copy parameters to script-scoped variables so they can be modified at runtime
	$script:IntervalSeconds = $IntervalSeconds
	$script:IntervalVariance = $IntervalVariance
	$script:MoveSpeed = $MoveSpeed
	$script:MoveVariance = $MoveVariance
	$script:TravelDistance = $TravelDistance
	$script:TravelVariance = $TravelVariance
	$script:AutoResumeDelaySeconds = $AutoResumeDelaySeconds
	$script:EndVariance = $EndVariance
	$script:Output = $Output
	$script:DebugMode = [bool]$DebugMode

	# Derive stealth session identifier for pipe/mutex/encryption names
	. "$PSScriptRoot\Private\Helpers\Get-SessionIdentifier.ps1"
	$script:SessionId = Get-SessionIdentifier
	$script:PipeEncryptionKey = $script:SessionId.AesKey
	$script:PipeAuthToken = $script:SessionId.AuthToken
	if ($_PipeName -eq 'mJig_IPC') {
		$script:PipeName = $script:SessionId.PipeName
	} else {
		$script:PipeName = $_PipeName
	}
	if ($_WorkerMode -and $script:_wsDiagFile) {
		"$(Get-Date -Format 'HH:mm:ss.fff') [2] Session derived  PipeName=$($script:PipeName)  KeyLen=$($script:PipeEncryptionKey.Length)  TokenLen=$($script:PipeAuthToken.Length)" | Out-File $script:_wsDiagFile -Append
	}

	# Initialize Variables
	$LastPos = $null
	$OldBufferSize = $null
	$OldWindowSize = $null
	$Rows = 0
	$SkipUpdate = $false
	$script:PendingForceRedraw = $false
	$script:CurrentScreenState = "startup"
	$PreviousView = $null  # Store the view before hiding to restore it later
	$PosUpdate = $false
	$LogArray = New-Object 'System.Collections.Generic.List[object]'
	$HostWidth = 0
	$HostHeight = 0
	$LastMovementTime = $null
	$LastMovementDurationMs = 0  # Track duration of last movement in milliseconds
	$LastSimulatedKeyPress = $null  # Track when we last sent a simulated key press
	$LastAutomatedMouseMovement = $null  # Track when we last performed automated mouse movement
	$LastUserInputTime = $null  # Track when user input was last detected (for auto-resume delay timer)

	# Stats tracking — cumulative counters updated every move/skip cycle
	$script:StatsMoveCount             = 0
	$script:StatsSkipCount             = 0
	$script:StatsCurrentStreak         = 0
	$script:StatsLongestStreak         = 0
	$script:StatsTotalDistancePx       = 0.0
	$script:StatsLastMoveDist          = 0.0
	$script:StatsMinMoveDist           = [double]::MaxValue
	$script:StatsMaxMoveDist           = 0.0
	$script:StatsKbInterruptCount      = 0
	$script:StatsMsInterruptCount      = 0
	$script:StatsLongestCleanStreak    = 0
	$script:StatsCleanStreak           = 0
	$script:StatsAvgActualIntervalSecs = 0.0
	$script:StatsLastMoveTick          = $null
	$script:StatsAvgDurationMs         = 0.0
	$script:StatsMinDurationMs         = [int]::MaxValue
	$script:StatsMaxDurationMs         = 0
	$script:StatsDirectionCounts       = @{ N = 0.0; NE = 0.0; E = 0.0; SE = 0.0; S = 0.0; SW = 0.0; W = 0.0; NW = 0.0 }
	$script:StatsLastCurveParams       = $null

	# Curve animation — pending flag set whenever new curve params arrive; cleared by animation loop
	$script:StatsCurveAnimPending  = $false
	$script:_LastCurveParamKey     = ""

	$script:PreviousIntervalKeys = @()
	$script:ResizeThrottleMs = 100
	$script:LoopIteration = 0  # Track loop iterations for diagnostics
	$script:LastInputCheckTime = $null  # Track when we last logged input check (for debug mode)
	$script:DialogButtonClick = $null  # Track dialog button clicks detected from main loop ("Update" or "Cancel")
	$script:ManualPause = $false
	$script:_HotkeyDebounce = $false
	
	# Performance: Cache for reflection method lookups
	$script:MethodCache = @{}
	
	# Note: Screen bounds are cached later after System.Windows.Forms is loaded
	$script:ScreenWidth = $null
	$script:ScreenHeight = $null
	$script:DialogButtonBounds = $null  # Store dialog button bounds when dialog is open {buttonRowY, updateStartX, updateEndX, cancelStartX, cancelEndX}
	$script:LastClickLogTime = $null  # Track when we last logged a click to prevent duplicate logs
	$script:TitlePresets = @(
		@{ Name = "mJig";                 Emoji = 0x1F400 }
		@{ Name = "Windows Update";       Emoji = 0x1F504 }
		@{ Name = "System Health Check";  Emoji = 0x1FA7A }
		@{ Name = "Background Services";  Emoji = 0x2699  }
		@{ Name = "Windows Defender Scan"; Emoji = 0x1F6E1 }
		@{ Name = "Performance Monitor";  Emoji = 0x1F4CA }
	)
	$script:TitlePresetIndex = 0
	$script:NotificationsEnabled = $true
	if ($Title.Length -gt 0) {
		$script:WindowTitle = $Title
		$script:TitleEmoji  = 0x1F400
		if ($script:TitlePresets[0].Name -ne $Title) {
			$script:TitlePresets = @(@{ Name = $Title; Emoji = 0x1F400 }) + $script:TitlePresets
		}
	} else {
		$script:WindowTitle = "mJig"
		$script:TitleEmoji  = 0x1F400
	}
	$script:MenuClickHotkey = $null  # Menu item hotkey triggered by mouse click
	$script:ModeButtonBounds           = $null  # Header pause/resume button click bounds {y, startX, endX}
	$script:ModeLabelBounds            = $null  # Header "Full"/"Min" label click bounds {y, startX, endX}
	$script:HeaderEndTimeBounds        = $null  # Header "End(hourglass)/..." hidden click region {y, startX, endX}
	$script:HeaderCurrentTimeBounds    = $null  # Header "Current(hourglass)/..." hidden click region {y, startX, endX}
	$script:HeaderLogoBounds           = $null  # Header "mJig(mouse)" logo click region {y, startX, endX}
	$script:Version                    = "1.0.0"  # Current application version
	$script:VersionCheckCache          = $null  # Cached result of GitHub release check {latest, url, isNewer, error}
	$script:PressedMenuButton  = $null   # hotkey of the menu button currently held down (LMB pressed, not yet released)
	$script:ButtonClickedAt   = $null   # timestamp of confirmed click (LMB UP over button); used to time color restoration
	$script:PendingDialogCheck = $false  # set on confirmed click; render loop uses it to decide whether to clear pressed state
	$script:LButtonWasDown    = $false   # tracks previous LMB state from console events for UP-transition detection
	$script:RenderQueue = New-Object 'System.Collections.Generic.List[object[]]'
	$script:FrameBuilder = New-Object System.Text.StringBuilder (8192)
	$script:MenuItemsBounds = New-Object 'System.Collections.Generic.List[hashtable]'
	
	# Box-drawing characters (using Unicode code points to avoid encoding issues)
	$script:BoxTopLeft = [char]0x250C      # top-left corner
	$script:BoxTopRight = [char]0x2510     # top-right corner
	$script:BoxBottomLeft = [char]0x2514   # bottom-left corner
	$script:BoxBottomRight = [char]0x2518  # bottom-right corner
	$script:BoxHorizontal = [char]0x2500   # horizontal line
	$script:BoxVertical = [char]0x2502     # vertical line
	$script:BoxVerticalRight = [char]0x251C # vertical + right tee
	$script:BoxVerticalLeft = [char]0x2524  # vertical + left tee
	
	. "$PSScriptRoot\Private\Config\Initialize-Theme.ps1"
	. "$PSScriptRoot\Private\Config\Set-ThemeProfile.ps1"
	
	# ============================================================================
	# Startup / Initializing Screen
	# ============================================================================

	# Shown immediately at startup — VT100 not yet enabled so Write-Host is used.
	. "$PSScriptRoot\Private\Startup\Show-StartupScreen.ps1"

	. "$PSScriptRoot\Private\Startup\Show-StartupComplete.ps1"
	# Returns {latest, url, isNewer, error}; cached in $script:VersionCheckCache
	. "$PSScriptRoot\Private\Startup\Get-LatestVersionInfo.ps1"
	# Blocks until window stable and LMB released; returns final stable Size object
	. "$PSScriptRoot\Private\Helpers\Invoke-ResizeHandler.ps1"

	# Prep the Host Console
	try {
		$Host.UI.RawUI.WindowTitle = if ($DebugMode) { "$script:WindowTitle - Debug Mode" } else { $script:WindowTitle }
		if ($DebugMode) {
			Write-Host "[DEBUG] Set window title: $($Host.UI.RawUI.WindowTitle)" -ForegroundColor $script:TextHighlight
		}
	} catch {
		if ($DebugMode) {
			Write-Host "  [WARN] Failed to set window title: $($_.Exception.Message)" -ForegroundColor $script:TextWarning
		}
	}

	# Duplicate instance detection via named mutex
	if ($DebugMode) {
		Write-Host "[DEBUG] Checking for duplicate mJig instances (mutex)..." -ForegroundColor $script:TextHighlight
	}
	$script:InstanceMutex = $null
	$mutexAcquired = $false
	try {
		$script:InstanceMutex = New-Object System.Threading.Mutex($false, "Global\$($script:SessionId.PipeName)")
		$mutexAcquired = $script:InstanceMutex.WaitOne(0)
	} catch [System.Threading.AbandonedMutexException] {
		$mutexAcquired = $true
	} catch {
		if ($DebugMode) {
			Write-Host "  [WARN] Mutex check failed: $($_.Exception.Message)" -ForegroundColor $script:TextWarning
		}
	}
	$_viewerReconnect = $false
	if (-not $mutexAcquired -and -not $_WorkerMode) {
		# Mutex already held — connect as viewer after initialization
		if ($null -ne $script:InstanceMutex) { $script:InstanceMutex.Dispose() }
		$_viewerReconnect = $true
	}
	if ($DebugMode -and -not $_viewerReconnect) {
		Write-Host "  [OK] Mutex acquired — no other instance running" -ForegroundColor $script:TextSuccess
	}
	if ($_WorkerMode -and $script:_wsDiagFile) {
		"$(Get-Date -Format 'HH:mm:ss.fff') [3] Mutex check  acquired=$mutexAcquired  viewerReconnect=$_viewerReconnect" | Out-File $script:_wsDiagFile -Append
	}
	
	# Worker mode skips console rendering setup (headless)
	if (-not $_WorkerMode) {
	if (-not $_viewerReconnect -and $Output -ne "hidden") {
		if (-not $DebugMode) {
			Show-StartupScreen
		} else {
			try { Clear-Host } catch {}
		}
	}
	
	if ($DebugMode) {
		Write-Host "Initialization Debug" -ForegroundColor $script:HeaderAppName
		Write-Host ""
		$_childRsId = if ([System.Management.Automation.Runspaces.Runspace]::DefaultRunspace) {
			[System.Management.Automation.Runspaces.Runspace]::DefaultRunspace.Id } else { '(unknown)' }
		Write-Host "[RUNSPACE] Confirmed: running inside isolated runspace" -ForegroundColor Cyan
		Write-Host "  Runspace ID : $_childRsId"  -ForegroundColor Gray
		Write-Host "  Thread ID   : $([System.Threading.Thread]::CurrentThread.ManagedThreadId)" -ForegroundColor Gray
		Write-Host "  Modules     : $((Get-Module | ForEach-Object { $_.Name }) -join ', ')" -ForegroundColor Gray
		Write-Host ""
		Write-Host "[DEBUG] Initializing console..." -ForegroundColor $script:TextHighlight
		Write-Host "[DEBUG] Window title: $($Host.UI.RawUI.WindowTitle)" -ForegroundColor $script:TextHighlight
		Write-Host "[DEBUG] DebugMode is ENABLED - click detection will be logged" -ForegroundColor $script:TextWarning
		Write-Host ""
	}
	try {
		$signature = @'
[DllImport("kernel32.dll", SetLastError = true)]
public static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);
[DllImport("kernel32.dll", SetLastError = true)]
public static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);
[DllImport("kernel32.dll", SetLastError = true)]
public static extern IntPtr GetStdHandle(int nStdHandle);
'@
		$type = Add-Type -MemberDefinition $signature -Name Win32Utils -Namespace Console -PassThru -ErrorAction SilentlyContinue
		if ($type) {
			$STD_INPUT_HANDLE = -10
			$hConsole = $type::GetStdHandle($STD_INPUT_HANDLE)
			$mode = 0
			if ($type::GetConsoleMode($hConsole, [ref]$mode)) {
				$ENABLE_QUICK_EDIT_MODE = 0x0040
				$ENABLE_MOUSE_INPUT = 0x0010
				$newMode = ($mode -band (-bnot $ENABLE_QUICK_EDIT_MODE)) -bor $ENABLE_MOUSE_INPUT
				if ($type::SetConsoleMode($hConsole, $newMode)) {
					if ($DebugMode) {
						Write-Host "  [OK] Quick Edit Mode disabled, Mouse Input enabled" -ForegroundColor $script:TextSuccess
					}
				} else {
					if ($DebugMode) {
						Write-Host "  [WARN] Failed to set console mode (SetConsoleMode failed)" -ForegroundColor $script:TextWarning
					}
				}
			} else {
				if ($DebugMode) {
					Write-Host "  [WARN] Failed to disable Quick Edit Mode (GetConsoleMode failed)" -ForegroundColor $script:TextWarning
				}
			}
		} else {
			if ($DebugMode) {
				Write-Host "  [WARN] Failed to disable Quick Edit Mode (could not load Win32 API)" -ForegroundColor $script:TextWarning
			}
		}
	} catch {
		if ($DebugMode) {
			Write-Host "  [WARN] Failed to disable Quick Edit Mode: $($_.Exception.Message)" -ForegroundColor $script:TextWarning
		}
	}
	
	# Enable VT100 processing on stdout for ANSI escape sequence rendering
	try {
		if ($type) {
			$STD_OUTPUT_HANDLE = -11
			$hStdOut = $type::GetStdHandle($STD_OUTPUT_HANDLE)
			$outMode = 0
			if ($type::GetConsoleMode($hStdOut, [ref]$outMode)) {
				$ENABLE_VIRTUAL_TERMINAL_PROCESSING = 0x0004
				$newOutMode = $outMode -bor $ENABLE_VIRTUAL_TERMINAL_PROCESSING
				if ($type::SetConsoleMode($hStdOut, $newOutMode)) {
					if ($DebugMode) {
						Write-Host "  [OK] VT100 processing enabled on stdout" -ForegroundColor $script:TextSuccess
					}
				} else {
					if ($DebugMode) {
						Write-Host "  [WARN] Failed to enable VT100 processing" -ForegroundColor $script:TextWarning
					}
				}
			}
		}
		[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
		if ($DebugMode) {
			Write-Host "  [OK] Console output encoding set to UTF-8" -ForegroundColor $script:TextSuccess
		}
	} catch {
		if ($DebugMode) {
			Write-Host "  [WARN] VT100/UTF-8 setup: $($_.Exception.Message)" -ForegroundColor $script:TextWarning
		}
	}
	
	try {
		[Console]::Write("$([char]27)[?25l")
		$script:CursorVisible = $false
		if ($DebugMode) {
			Write-Host "  [OK] Console cursor hidden" -ForegroundColor $script:TextSuccess
		}
	} catch {
		if ($DebugMode) {
			Write-Host "  [FAIL] Failed to hide cursor: $($_.Exception.Message)" -ForegroundColor $script:TextError
		}
	}
	
	# Capture Initial Buffer & Window Sizes (needed even for hidden mode)
	if ($DebugMode) {
		Write-Host "[DEBUG] Capturing console dimensions..." -ForegroundColor $script:TextHighlight
	}
	try {
		$pshost = Get-Host
		$pswindow = $pshost.UI.RawUI
		$newWindowSize = $pswindow.WindowSize
		$newBufferSize = $pswindow.BufferSize
		if ($DebugMode) {
			Write-Host "  [OK] Got console dimensions" -ForegroundColor $script:TextSuccess
			Write-Host "    Window Size: $($newWindowSize.Width)x$($newWindowSize.Height)" -ForegroundColor Gray
			Write-Host "    Buffer Size: $($newBufferSize.Width)x$($newBufferSize.Height)" -ForegroundColor Gray
		}
	} catch {
		if ($DebugMode) {
			Write-Host "  [FAIL] Failed to get console dimensions: $($_.Exception.Message)" -ForegroundColor $script:TextError
		}
		throw  # Re-throw as this is critical
	}
	# Match buffer height to window height (horizontal buffer managed by PowerShell)
	try {
		$pswindow.BufferSize = New-Object System.Management.Automation.Host.Size($newBufferSize.Width, $newWindowSize.Height)
		$newBufferSize = $pswindow.BufferSize
		if ($DebugMode) {
			Write-Host "  [OK] Set buffer height to match window height" -ForegroundColor $script:TextSuccess
		}
	} catch {
		if ($DebugMode) {
			Write-Host "  [WARN] Failed to set buffer size: $($_.Exception.Message)" -ForegroundColor $script:TextWarning
			Write-Host "    Continuing with current buffer size" -ForegroundColor Gray
		}
		$newBufferSize = $pswindow.BufferSize
	}
	$OldBufferSize = $newBufferSize
	$OldWindowSize = $newWindowSize
	$HostWidth = $newWindowSize.Width
	$HostHeight = $newWindowSize.Height
	if ($DebugMode) {
		Write-Host "    Final host dimensions: ${HostWidth}x${HostHeight}" -ForegroundColor Gray
	}

	# Initialize the Output Array
	if ($DebugMode) {
		Write-Host "[DEBUG] Initializing output array..." -ForegroundColor $script:TextHighlight
	}
	if ($DebugMode) {
		Write-Host "  [OK] Output mode: $Output" -ForegroundColor $script:TextSuccess
	}

	} # end if (-not $_WorkerMode) — console setup guard
	
	###############################
	## Calculating the End Times ##
	###############################
	
	if ($DebugMode -and -not $_WorkerMode) {
		Write-Host "[DEBUG] Calculating end times..." -ForegroundColor $script:TextHighlight
	}
	
	# Convert EndTime to string and parse
	# Handle: "0" = none, "00" or "0000" = midnight (0000), 2-digit = hour on the hour, 4-digit = HHmm
	try {
		$endTimeTrimmed = $EndTime.Trim()
		
		# Check if it is "0" (single digit) - means no end time
		if ($endTimeTrimmed -eq "0") {
			$endTimeInt = -1
			$endTimeStr = ""
			if ($DebugMode) {
				Write-Host "  [OK] No end time specified - script will run indefinitely" -ForegroundColor $script:TextSuccess
			}
		} elseif ($endTimeTrimmed.Length -eq 2) {
			# 2-digit input = hour on the hour (e.g., "12" = 1200, "00" = 0000)
			$hours = [int]$endTimeTrimmed
			if ($hours -ge 0 -and $hours -le 23) {
				$endTimeInt = $hours * 100  # Convert to HHmm format (e.g., 12 -> 1200)
				$endTimeStr = $endTimeInt.ToString().PadLeft(4, '0')
				if ($DebugMode) {
					Write-Host "  [OK] Parsed end time: $endTimeStr (hour on the hour)" -ForegroundColor $script:TextSuccess
				}
			} else {
				Write-Host "Error: Invalid hour format. Hours must be 00-23. Got: $EndTime" -ForegroundColor $script:TextError
				throw "Invalid hour format: $EndTime"
			}
		} elseif ($endTimeTrimmed.Length -eq 4) {
			# 4-digit input = HHmm format
			$endTimeInt = [int]$endTimeTrimmed
			$hours = [int]$endTimeTrimmed.Substring(0, 2)
			$minutes = [int]$endTimeTrimmed.Substring(2, 2)
			
			# Validate HHmm format
			if ($hours -ge 0 -and $hours -le 23 -and $minutes -ge 0 -and $minutes -le 59) {
				$endTimeStr = $endTimeTrimmed
				if ($DebugMode) {
					Write-Host "  [OK] Parsed end time: $endTimeStr" -ForegroundColor $script:TextSuccess
				}
			} else {
				if ($hours -gt 23) {
					Write-Host "Error: Invalid time format. Hours must be 00-23. Got: $EndTime" -ForegroundColor $script:TextError
				} elseif ($minutes -gt 59) {
					Write-Host "Error: Invalid time format. Minutes must be 00-59. Got: $EndTime" -ForegroundColor $script:TextError
				} else {
					Write-Host "Error: Invalid time format. Expected HHmm format (0000-2359). Got: $EndTime" -ForegroundColor $script:TextError
				}
				throw "Invalid time format: $EndTime"
			}
		} else {
			Write-Host "Error: Invalid time format. Expected '0' (none), 2-digit hour (00-23), or 4-digit HHmm (0000-2359). Got: $EndTime" -ForegroundColor $script:TextError
			throw "Invalid time format: $EndTime"
		}
	} catch {
		if ($DebugMode) {
			Write-Host "  [FAIL] Failed to parse endTime: $($_.Exception.Message)" -ForegroundColor $script:TextError
		}
		if ($_.Exception.Message -notmatch "Invalid time format") {
			Write-Host "Error: Invalid EndTime format: $EndTime" -ForegroundColor $script:TextError
		}
		throw
	}
	
	# Time format has already been validated in the try-catch block above
	# Proceed with initialization
		# Diagnostics - initialize folder and file paths
		$script:DiagEnabled = $Diag
		if ($script:DiagEnabled) {
			$script:DiagFolder = Join-Path $PSScriptRoot "_diag"
			if (-not (Test-Path $script:DiagFolder)) {
				New-Item -ItemType Directory -Path $script:DiagFolder -Force | Out-Null
			}
			$script:StartupDiagFile = Join-Path $script:DiagFolder "startup.txt"
			$script:SettleDiagFile = Join-Path $script:DiagFolder "settle.txt"
			$script:InputDiagFile = Join-Path $script:DiagFolder "input.txt"
			
			$diagTimestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
			$diagRsId = if ([System.Management.Automation.Runspaces.Runspace]::DefaultRunspace) {
				[System.Management.Automation.Runspaces.Runspace]::DefaultRunspace.Id } else { '(unknown)' }
			"=== mJig Startup Diag: $diagTimestamp ===" | Out-File $script:StartupDiagFile
			"$(Get-Date -Format 'HH:mm:ss.fff') - CHECKPOINT 1: Starting initialization" | Out-File $script:StartupDiagFile -Append
			"  Diag enabled, folder: $script:DiagFolder" | Out-File $script:StartupDiagFile -Append
			"  Runspace ID: $diagRsId  Thread: $([System.Threading.Thread]::CurrentThread.ManagedThreadId)  Modules: $((Get-Module | ForEach-Object { $_.Name }) -join ', ')" | Out-File $script:StartupDiagFile -Append
	$script:IpcDiagFile = Join-Path $script:DiagFolder "ipc.txt"
	$script:NotifyDiagFile = Join-Path $script:DiagFolder "notify.txt"
	"=== mJig Notify Diag: $diagTimestamp ===" | Out-File $script:NotifyDiagFile
	"$(Get-Date -Format 'HH:mm:ss.fff') [INIT] Notification diagnostics started  Mode=$(if ($_WorkerMode) { 'worker' } else { 'viewer' })" | Out-File $script:NotifyDiagFile -Append
	"=== mJig Settle Diag: $diagTimestamp ===" | Out-File $script:SettleDiagFile
		"$(Get-Date -Format 'HH:mm:ss.fff') - Settle diagnostics started" | Out-File $script:SettleDiagFile -Append
			"=== mJig Input Diag: $diagTimestamp ===" | Out-File $script:InputDiagFile
			"$(Get-Date -Format 'HH:mm:ss.fff') - Input diagnostics started (PeekConsoleInput + GetLastInputInfo)" | Out-File $script:InputDiagFile -Append
		}
		
		if ($_WorkerMode -and $script:_wsDiagFile) {
			"$(Get-Date -Format 'HH:mm:ss.fff') [4a] About to dot-source Initialize-PInvoke.ps1" | Out-File $script:_wsDiagFile -Append
		}
	. "$PSScriptRoot\Private\Config\Initialize-PInvoke.ps1"
	if ($_WorkerMode -and $script:_wsDiagFile) {
		"$(Get-Date -Format 'HH:mm:ss.fff') [4b] P/Invoke loaded  ns=$($script:_ApiNamespace)  MouseAPI=$($null -ne $script:MouseAPI)  KeyboardAPI=$($null -ne $script:KeyboardAPI)  ToastAPI=$($null -ne $script:ToastAPI)" | Out-File $script:_wsDiagFile -Append
	}
	if ($script:DiagEnabled -and $script:NotifyDiagFile) {
		"$(Get-Date -Format 'HH:mm:ss.fff') [PINVOKE] ToastAPI=$($null -ne $script:ToastAPI)  Tier1Failed=$($script:_Tier1NotifyFailed -eq $true)  NotificationsEnabled=$($script:NotificationsEnabled)" | Out-File $script:NotifyDiagFile -Append
	}
		
		# Verify types loaded correctly
		if ($script:DiagEnabled) { "$(Get-Date -Format 'HH:mm:ss.fff') - CHECKPOINT 2: Types loaded, verifying" | Out-File $script:StartupDiagFile -Append }
		try {
			$null = $script:MouseAPI::GetAsyncKeyState(0x01)
			$testPoint = New-Object $script:PointType
			$hasGetCursorPos = $null -ne $script:MouseAPI.GetMethod("GetCursorPos")
			if ($hasGetCursorPos) {
				$null = $script:MouseAPI::GetCursorPos([ref]$testPoint)
			}
			if ($DebugMode) {
				Write-Host "  [OK] Windows API types loaded successfully" -ForegroundColor $script:TextSuccess
			}
			if ($_WorkerMode -and $script:_wsDiagFile) {
				"$(Get-Date -Format 'HH:mm:ss.fff') [4c] Type verification OK" | Out-File $script:_wsDiagFile -Append
			}
		} catch {
			if ($_WorkerMode -and $script:_wsDiagFile) {
				"$(Get-Date -Format 'HH:mm:ss.fff') [4c] Type verification FAILED: $($_.Exception.Message)" | Out-File $script:_wsDiagFile -Append
			}
			if ($DebugMode) {
				Write-Host "  [FAIL] Could not verify keyboard/mouse API: $($_.Exception.Message)" -ForegroundColor $script:TextError
			}
			Write-Host "Warning: Could not verify keyboard/mouse API. Some features may be disabled." -ForegroundColor $script:TextWarning
		}
		
		# Auto-detect headless mode when console window is hidden (e.g. scheduled task)
		if (-not $Headless -and -not $_WorkerMode) {
			try {
				$consoleHwnd = $script:MouseAPI::GetConsoleWindow()
				if ($consoleHwnd -eq [IntPtr]::Zero -or -not $script:MouseAPI::IsWindowVisible($consoleHwnd)) {
					$Headless = $true
				}
			} catch {}
		}
		
		# Apply variance to end time if variance is set and end time is specified (not -1)
		if ($endTimeInt -ne -1 -and $script:EndVariance -gt 0) {
			try {
				$ras = Get-Random -Maximum 3 -Minimum 1
				if ($ras -eq 1) {
					$variance = -(Get-Random -Maximum $script:EndVariance)
					$endTimeInt = $endTimeInt + $variance
				} else {
					$variance = (Get-Random -Maximum $script:EndVariance)
					$endTimeInt = $endTimeInt + $variance
				}
				# Ensure time stays within valid range (0-2359)
				if ($endTimeInt -lt 0) {
					$endTimeInt = 0
				} elseif ($endTimeInt -gt 2359) {
					$endTimeInt = 2359
				}
				$endTimeStr = $endTimeInt.ToString().PadLeft(4, '0')
				if ($DebugMode) {
					Write-Host "  [OK] Applied variance: $variance minutes, final end time: $endTimeStr" -ForegroundColor $script:TextSuccess
				}
			} catch {
				if ($DebugMode) {
					Write-Host "  [FAIL] Failed to apply variance: $($_.Exception.Message)" -ForegroundColor $script:TextError
				}
			}
		}
		
		# Calculate end date/time only if end time is set (not -1)
		if ($endTimeInt -ne -1) {
			try {
				$currentTime = Get-Date -Format "HHmm"
				if ($DebugMode) {
					Write-Host "  [OK] Current time: $currentTime" -ForegroundColor $script:TextSuccess
				}
			} catch {
				if ($DebugMode) {
					Write-Host "  [FAIL] Failed to get current time: $($_.Exception.Message)" -ForegroundColor $script:TextError
				}
				throw
			}
			try {
				if ($endTimeInt -le [int]$currentTime) {
				$tomorrow = (Get-Date).AddDays(1)
				$endDate = Get-Date $tomorrow -Format "MMdd"
				if ($DebugMode) {
					Write-Host "  [OK] End time is today, using tomorrow's date: $endDate" -ForegroundColor $script:TextSuccess
					}
				} else {
					$endDate = Get-Date -Format "MMdd"
					if ($DebugMode) {
						Write-Host "  [OK] End time is today, using today's date: $endDate" -ForegroundColor $script:TextSuccess
					}
				}
				$end = "$endDate$endTimeStr"
				if ($DebugMode) {
					Write-Host "  [OK] Final end datetime: $end" -ForegroundColor $script:TextSuccess
				}
			} catch {
				if ($DebugMode) {
					Write-Host "  [FAIL] Failed to calculate end datetime: $($_.Exception.Message)" -ForegroundColor $script:TextError
				}
				throw
			}
		} else {
			$end = ""
			if ($DebugMode) {
				Write-Host "  [OK] No end time - script will run indefinitely" -ForegroundColor $script:TextSuccess
			}
		}

		# Initialize lastPos for mouse detection
		if ($DebugMode) {
			Write-Host "[DEBUG] Initializing mouse position tracking..." -ForegroundColor $script:TextHighlight
		}
		try {
			if ($null -eq $LastPos) {
				# Use direct Windows API call for better performance (avoids .NET stutter)
				$point = New-Object $script:PointType
				$hasGetCursorPos = $null -ne $script:MouseAPI.GetMethod("GetCursorPos")
				if ($hasGetCursorPos) {
					if ($script:MouseAPI::GetCursorPos([ref]$point)) {
						# Convert POINT to System.Drawing.Point for compatibility with rest of code
						$LastPos = New-Object System.Drawing.Point($point.X, $point.Y)
					} else {
						throw "GetCursorPos API call failed"
					}
				} else {
					throw "GetCursorPos method not available"
				}
				if ($DebugMode) {
					Write-Host "  [OK] Initial mouse position: $($LastPos.X), $($LastPos.Y)" -ForegroundColor $script:TextSuccess
				}
			} else {
				if ($DebugMode) {
					Write-Host "  [OK] Mouse position already set: $($LastPos.X), $($LastPos.Y)" -ForegroundColor $script:TextSuccess
				}
			}
		} catch {
			if ($DebugMode) {
				Write-Host "  [FAIL] Failed to get mouse position: $($_.Exception.Message)" -ForegroundColor $script:TextError
			}
			# Don't throw - mouse position tracking is optional
		}

		# Track start time for runtime calculation
		$ScriptStartTime = Get-Date

		# Function to calculate smooth movement path with acceleration/deceleration
		# Returns an array of points and the total movement time in milliseconds
		. "$PSScriptRoot\Private\Helpers\Get-SmoothMovementPath.ps1"

		# Function to get direction arrow emoji based on movement delta
		# Options: "arrows" (emoji arrows), "text" (N/S/E/W/NE/etc), "simple" (unicode arrows)
		. "$PSScriptRoot\Private\Helpers\Get-DirectionArrow.ps1"

		if ($script:DiagEnabled) { "$(Get-Date -Format 'HH:mm:ss.fff') - CHECKPOINT 3: About to define helper functions" | Out-File $script:StartupDiagFile -Append }

		# ============================================
		# Buffered Rendering Functions
		# ============================================

		$script:ESC = [char]27
		$script:CSI = "$([char]27)["
		$script:CursorVisible = $false
		$script:AnsiFG = @{
			[ConsoleColor]::Black = 30; [ConsoleColor]::DarkBlue = 34; [ConsoleColor]::DarkGreen = 32; [ConsoleColor]::DarkCyan = 36
			[ConsoleColor]::DarkRed = 31; [ConsoleColor]::DarkMagenta = 35; [ConsoleColor]::DarkYellow = 33; [ConsoleColor]::Gray = 37
			[ConsoleColor]::DarkGray = 90; [ConsoleColor]::Blue = 94; [ConsoleColor]::Green = 92; [ConsoleColor]::Cyan = 96
			[ConsoleColor]::Red = 91; [ConsoleColor]::Magenta = 95; [ConsoleColor]::Yellow = 93; [ConsoleColor]::White = 97
		}
		$script:AnsiBG = @{
			[ConsoleColor]::Black = 40; [ConsoleColor]::DarkBlue = 44; [ConsoleColor]::DarkGreen = 42; [ConsoleColor]::DarkCyan = 46
			[ConsoleColor]::DarkRed = 41; [ConsoleColor]::DarkMagenta = 45; [ConsoleColor]::DarkYellow = 43; [ConsoleColor]::Gray = 47
			[ConsoleColor]::DarkGray = 100; [ConsoleColor]::Blue = 104; [ConsoleColor]::Green = 102; [ConsoleColor]::Cyan = 106
			[ConsoleColor]::Red = 101; [ConsoleColor]::Magenta = 105; [ConsoleColor]::Yellow = 103; [ConsoleColor]::White = 107
		}

	. "$PSScriptRoot\Private\Rendering\Write-Buffer.ps1"

		. "$PSScriptRoot\Private\Rendering\Flush-Buffer.ps1"

		. "$PSScriptRoot\Private\Rendering\Clear-Buffer.ps1"

		# Instant button redraw for press/release visual feedback
		. "$PSScriptRoot\Private\Rendering\Write-MenuButton.ps1"
	. "$PSScriptRoot\Private\Rendering\Write-HotkeyLabel.ps1"

		# Function to draw drop shadow for dialog boxes
		. "$PSScriptRoot\Private\Rendering\Write-DialogShadow.ps1"
		
		# Function to clear drop shadow for dialog boxes
		. "$PSScriptRoot\Private\Rendering\Clear-DialogShadow.ps1"

		# Debug log entry helper (reduces boilerplate for structured log entries)
		. "$PSScriptRoot\Private\Helpers\Add-DebugLogEntry.ps1"

		# Post-dialog cleanup helper (set skip/redraw flags + refresh window/buffer sizes)
		. "$PSScriptRoot\Private\Helpers\Reset-PostDialogState.ps1"
	. "$PSScriptRoot\Private\Helpers\Invoke-CursorMovement.ps1"

	. "$PSScriptRoot\Private\Helpers\Show-Notification.ps1"
	. "$PSScriptRoot\Private\Helpers\Test-GlobalHotkey.ps1"

		# Dialog shared helpers (button layout, mouse click detection, key input, exit cleanup)
		. "$PSScriptRoot\Private\Helpers\Get-DialogButtonLayout.ps1"
		. "$PSScriptRoot\Private\Helpers\Get-DialogMouseClick.ps1"
		. "$PSScriptRoot\Private\Helpers\Read-DialogKeyInput.ps1"
		. "$PSScriptRoot\Private\Helpers\Invoke-DialogCleanup.ps1"

		# Pre-allocated buffer for dialog PeekConsoleInput (reused across all dialogs)
		$script:_DialogPeekBuffer = New-Object "$($script:_ApiNamespace).INPUT_RECORD[]" 16

		# Pre-allocated point for cursor movement animation (avoids per-step allocation)
		$script:_MovementPoint = New-Object System.Drawing.Point

		# Cached emoji constants (avoid recomputation every frame)
		$script:HourglassEmoji = [char]::ConvertFromUtf32(0x23F3)   # U+23F3 hourglass
		$script:LockEmoji      = [char]::ConvertFromUtf32(0x1F512)  # U+1F512 lock
		$script:GearEmoji      = [char]::ConvertFromUtf32(0x1F6E0)  # U+1F6E0 gear
		$script:RedXEmoji      = [char]::ConvertFromUtf32(0x274C)   # U+274C red X
		$script:CheckmarkEmoji = [char]::ConvertFromUtf32(0x2705)   # U+2705 checkmark
		$script:PauseEmoji     = "$([char]0x275A)$([char]0x275A)"   # U+275A x2 pause bars
		$script:PlayEmoji      = [char]::ConvertFromUtf32(0x25B6)   # U+25B6 play triangle

		# Cached virtual screen bounds (display config rarely changes during a run)
		$script:_VirtualScreen = [System.Windows.Forms.SystemInformation]::VirtualScreen

		# Function to show popup dialog for changing end time
		. "$PSScriptRoot\Private\Dialogs\Show-TimeChangeDialog.ps1"

		# ============================================
		# Performance Helper Functions
		# ============================================
		
		# Playful quotes for resize screen
		$script:ResizeQuotes = @(
			"Jiggling since the dawn of idle timeouts..."
			"A mouse in motion stays employed"
			"Wiggle wiggle wiggle"
			"Like jello, but for your cursor"
			"Making mice dance since 2024"
			"The early mouse gets the jiggle"
			"Shake it like a Polaroid picture"
			"Keep calm and jiggle on"
			"This mouse has moves"
			"Cursor cardio in progress"
			"Staying active so you don't have to"
			"Mice just wanna have fun"
			"Jiggle physics: enabled"
			"Not all who wander are lost, some are jiggling"
			"Professional mouse motivator"
			"Your mouse's personal trainer"
			"Wiggling through the workday"
		)
		$script:CurrentResizeQuote = $null
		
	# Re-enables ENABLE_MOUSE_INPUT after [Console]::Clear() strips it
	. "$PSScriptRoot\Private\Helpers\Restore-ConsoleInputMode.ps1"

	# Injects VK_RMENU to signal Windows Terminal to restore console mouse-event routing
	. "$PSScriptRoot\Private\Helpers\Send-ConsoleWakeKey.ps1"

	. "$PSScriptRoot\Private\Helpers\Show-DiagnosticFiles.ps1"
	. "$PSScriptRoot\Private\Rendering\Write-ResizeLogo.ps1"
		
	# Main UI frame renderer (header, logs, stats, menu, footer)
	. "$PSScriptRoot\Private\Rendering\Write-MainFrame.ps1"

		# Helper function: Get method safely (cached for performance)
		. "$PSScriptRoot\Private\Helpers\Get-CachedMethod.ps1"
		
		# Helper function: Get mouse position (uses cached method)
		. "$PSScriptRoot\Private\Helpers\Get-MousePosition.ps1"
		
		# Helper function: Check mouse movement threshold
		. "$PSScriptRoot\Private\Helpers\Test-MouseMoved.ps1"
		
		# Returns [int]::MaxValue if StartTime is null — enables safe null comparisons
		. "$PSScriptRoot\Private\Helpers\Get-TimeSinceMs.ps1"
		
		. "$PSScriptRoot\Private\Helpers\Get-VariedValue.ps1"
		
		# Helper function: Clamp coordinates to screen bounds
		. "$PSScriptRoot\Private\Helpers\Set-CoordinateBounds.ps1"
		
		# ============================================
		# IPC Helper Functions (Named Pipe communication)
		# ============================================
		
		. "$PSScriptRoot\Private\IPC\Protect-PipeMessage.ps1"

		. "$PSScriptRoot\Private\IPC\New-SecurePipeServer.ps1"

		. "$PSScriptRoot\Private\IPC\Send-PipeMessage.ps1"
		
		. "$PSScriptRoot\Private\IPC\Read-PipeMessage.ps1"
		
		. "$PSScriptRoot\Private\IPC\Send-PipeMessageNonBlocking.ps1"
		
		. "$PSScriptRoot\Private\IPC\Start-WorkerLoop.ps1"
		
		. "$PSScriptRoot\Private\IPC\Connect-WorkerPipe.ps1"
		
		
		# ============================================
		# UI Helper Functions
		# ============================================
		
		# Helper function: Calculate padding needed to fill remaining width
		. "$PSScriptRoot\Private\Helpers\Get-Padding.ps1"
		
		# Helper function: Draw a horizontal line in a section
		. "$PSScriptRoot\Private\Rendering\Write-SectionLine.ps1"
		
		# Helper function: Draw a simple dialog row (no description box)
		. "$PSScriptRoot\Private\Rendering\Write-SimpleDialogRow.ps1"
		
		# Helper function: Draw a field row with input box (no description box)
		. "$PSScriptRoot\Private\Rendering\Write-SimpleFieldRow.ps1"
		
		. "$PSScriptRoot\Private\Dialogs\Show-MovementModifyDialog.ps1"

		# Function to show quit confirmation dialog
		. "$PSScriptRoot\Private\Dialogs\Show-QuitConfirmationDialog.ps1"

	# Slide-up settings panel; manages sub-dialogs and onfocus/offfocus state
	. "$PSScriptRoot\Private\Dialogs\Show-SettingsDialog.ps1"

	. "$PSScriptRoot\Private\Dialogs\Show-OptionsDialog.ps1"

	# Info / About dialog — shows version, update status, and current configuration.
	# Triggered by pressing '?' or clicking the mJig logo in the header.
	. "$PSScriptRoot\Private\Dialogs\Show-InfoDialog.ps1"

	# Theme dialog — cycles through built-in theme profiles.
	# Triggered by 'h' hotkey or the t(h)eme button in the menu bar and Settings.
	. "$PSScriptRoot\Private\Dialogs\Show-ThemeDialog.ps1"

	# ---- Theme Profile Initialization ----------------------------------------------
	# Apply default theme first; override with debug theme if debug mode is active;
	# then apply any explicit -Theme parameter last (takes highest precedence).
	Set-ThemeProfile -Name "default" | Out-Null
	if ($script:DebugMode) { Set-ThemeProfile -Name "debug" | Out-Null }
	if (-not [string]::IsNullOrEmpty($Theme)) { Set-ThemeProfile -Name $Theme | Out-Null }

	# ---- IPC Mode Branching --------------------------------------------------------
	# Worker mode: enter headless activity simulation loop with IPC server (no console UI)
	if ($_WorkerMode) {
		if ($script:_wsDiagFile) {
			"$(Get-Date -Format 'HH:mm:ss.fff') [5] All init complete, entering Start-WorkerLoop  PipeName=$($script:PipeName)" | Out-File $script:_wsDiagFile -Append
		}
		try {
			Start-WorkerLoop
		} catch {
			$fatalMsg = "$(Get-Date -Format 'HH:mm:ss.fff') [FATAL] Start-WorkerLoop threw: $($_.Exception.GetType().Name): $($_.Exception.Message)"
			$fatalStack = "  ScriptStackTrace: $($_.ScriptStackTrace)"
			if ($script:_wsDiagFile) {
				$fatalMsg | Out-File $script:_wsDiagFile -Append
				$fatalStack | Out-File $script:_wsDiagFile -Append
			}
			if ($script:DiagEnabled -and $script:DiagFolder) {
				$fatalFile = Join-Path $script:DiagFolder "worker-ipc.txt"
				$fatalMsg | Out-File $fatalFile -Append
				$fatalStack | Out-File $fatalFile -Append
			}
		}
		return
	}
	
	# Viewer mode: IPC state replaces local movement/timing; rendering is unchanged
	$_isViewerMode = $false
	$_viewerPipeClient = $null
	$_viewerPipeReader = $null
	$_viewerPipeWriter = $null
	$_viewerReadTask = $null
	$_settingsEpoch = 0
	$_viewerStopped = $false
	$_viewerStopReason = ''
	
	# Headless: if another instance is already running, exit immediately
	if ($Headless -and $_viewerReconnect) {
		return
	}
	
	# Viewer reconnect: another instance already running, connect as viewer
	if ($_viewerReconnect) {
		$pipeResult = Connect-WorkerPipe -PipeName $script:PipeName -ConnectTimeoutMs 5000
		if ($null -eq $pipeResult) {
			if ($script:DiagEnabled) { Show-DiagnosticFiles }
			return
		}
		$_isViewerMode = $true
		$script:_SkipTrayIcon = $true
		$_viewerPipeClient = $pipeResult.Client
		$_viewerPipeReader = $pipeResult.Reader
		$_viewerPipeWriter = $pipeResult.Writer
	}
	
	# Non-Inline mode with mutex acquired: spawn hidden background worker, then become viewer
	if (-not $Inline -and $mutexAcquired -and -not $_isViewerMode) {
		$modulePath = Join-Path $PSScriptRoot 'Start-mJig.psm1'
		$workerCmd = "Import-Module '$modulePath'; Start-mJig -_WorkerMode -_InModuleRunspace -_PipeName '$($script:PipeName)'"
		
		# Forward movement/timing parameters to the worker
		if ($PSBoundParameters.ContainsKey('IntervalSeconds')) { $workerCmd += " -IntervalSeconds $IntervalSeconds" }
		if ($PSBoundParameters.ContainsKey('IntervalVariance')) { $workerCmd += " -IntervalVariance $IntervalVariance" }
		if ($PSBoundParameters.ContainsKey('MoveSpeed')) { $workerCmd += " -MoveSpeed $MoveSpeed" }
		if ($PSBoundParameters.ContainsKey('MoveVariance')) { $workerCmd += " -MoveVariance $MoveVariance" }
		if ($PSBoundParameters.ContainsKey('TravelDistance')) { $workerCmd += " -TravelDistance $TravelDistance" }
		if ($PSBoundParameters.ContainsKey('TravelVariance')) { $workerCmd += " -TravelVariance $TravelVariance" }
		if ($PSBoundParameters.ContainsKey('AutoResumeDelaySeconds')) { $workerCmd += " -AutoResumeDelaySeconds $AutoResumeDelaySeconds" }
		if ($PSBoundParameters.ContainsKey('EndTime')) { $workerCmd += " -EndTime '$EndTime'" }
		if ($PSBoundParameters.ContainsKey('EndVariance')) { $workerCmd += " -EndVariance $EndVariance" }
		if ($PSBoundParameters.ContainsKey('Output')) { $workerCmd += " -Output '$Output'" }
		if ($PSBoundParameters.ContainsKey('Title') -and $Title.Length -gt 0) { $workerCmd += " -Title '$Title'" }
		if ($Diag) { $workerCmd += " -Diag" }
		
		$powershellExe = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
		
		# Release mutex before spawning — worker acquires its own
		if ($null -ne $script:InstanceMutex) {
			try { $script:InstanceMutex.ReleaseMutex() } catch {}
			$script:InstanceMutex.Dispose()
			$script:InstanceMutex = $null
		}
		
		# WMI spawn: detaches from terminal job object so worker survives viewer close
		try {
			$encodedCmd = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($workerCmd))
			$cmdLine = "`"$powershellExe`" -NoProfile -NoLogo -WindowStyle Hidden -EncodedCommand $encodedCmd"
			$cimResult = Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = $cmdLine }
			if ($cimResult.ReturnValue -ne 0) { throw "WMI return code $($cimResult.ReturnValue)" }
			$null = Get-Process -Id $cimResult.ProcessId -ErrorAction Stop
		} catch {
			try {
				$encodedCmd = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($workerCmd))
				$workerArgs = @('-NoProfile', '-NoLogo', '-WindowStyle', 'Hidden', '-EncodedCommand', $encodedCmd)
				$null = Start-Process -FilePath $powershellExe -ArgumentList $workerArgs -WindowStyle Hidden -PassThru
			} catch {
				Write-Host "WARNING: Could not start background process. Running in direct mode." -ForegroundColor $script:TextWarning
				Write-Host "  $($_.Exception.Message)" -ForegroundColor Gray
				try {
					$script:InstanceMutex = New-Object System.Threading.Mutex($false, "Global\$($script:SessionId.PipeName)")
					$mutexAcquired = $script:InstanceMutex.WaitOne(0)
				} catch { $mutexAcquired = $true }
				$Inline = $true
			}
		}
		
		# Headless: worker spawned, exit immediately (no TUI)
		if ($Headless) {
			return
		}
		
		if (-not $Inline) {
			$pipeResult = Connect-WorkerPipe -PipeName $script:PipeName -ConnectTimeoutMs 15000
			if ($null -eq $pipeResult) {
				if ($script:DiagEnabled) { Show-DiagnosticFiles }
				return
			}
			$_isViewerMode = $true
			$script:_SkipTrayIcon = $true
			$_viewerPipeClient = $pipeResult.Client
			$_viewerPipeReader = $pipeResult.Reader
			$_viewerPipeWriter = $pipeResult.Writer
		}
	}
	# ---- End IPC Mode Branching ----------------------------------------------------

	if ($_isViewerMode) {
		$workerPid = $pipeResult.BackgroundPid
		$connectionTimestamp = (Get-Date).ToString("HH:mm:ss")
		$null = $LogArray.Add([PSCustomObject]@{
			logRow = $true
			components = @(
				@{ priority = 1; text = $connectionTimestamp; shortText = $connectionTimestamp },
				@{ priority = 2; text = " - Connected to background process (PID: $workerPid)"; shortText = " - Connected (PID: $workerPid)" }
			)
		})

		# Restore viewer visual state from previous session (carried in welcome message)
		$_restoredState = $pipeResult.VisualState
		if ($null -ne $_restoredState) {
			if ($null -ne $_restoredState.outputMode)       { $Output = $_restoredState.outputMode; $script:Output = $Output }
			if ($null -ne $_restoredState.previousView)     { $PreviousView = $_restoredState.previousView }
			if ($null -ne $_restoredState.windowTitle)      { $script:WindowTitle = $_restoredState.windowTitle; $Host.UI.RawUI.WindowTitle = $script:WindowTitle }
			if ($null -ne $_restoredState.titleEmoji)       { $script:TitleEmoji = [int]$_restoredState.titleEmoji }
			if ($null -ne $_restoredState.titlePresetIndex) { $script:TitlePresetIndex = [int]$_restoredState.titlePresetIndex }
		if ([bool]$_restoredState.manualPause)           { $script:ManualPause = $true }
		switch ($null -ne $_restoredState.activeDialog -and $_restoredState.activeDialog -ne '' ? [string]$_restoredState.activeDialog : '') {
			'settings' { $script:PendingReopenSettings = $true }
			'quit'     { $script:_PendingReopenQuit    = $true }
			'info'     { $script:_PendingReopenInfo    = $true }
		}
		$script:_PendingRestoreSubDialog = if ($null -ne $_restoredState.activeSubDialog -and $_restoredState.activeSubDialog -ne '') { [string]$_restoredState.activeSubDialog } else { $null }
	}
}

	if ($script:DiagEnabled -and $_isViewerMode) {
		"=== mJig IPC Viewer Diag: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff') ===" | Out-File $script:IpcDiagFile
		"  _isViewerMode=$_isViewerMode  _viewerReconnect=$_viewerReconnect  Inline=$Inline" | Out-File $script:IpcDiagFile -Append
		"  PipeClient.IsConnected=$($_viewerPipeClient.IsConnected)" | Out-File $script:IpcDiagFile -Append
		"  HostWidth=$HostWidth  HostHeight=$HostHeight  Output=$Output  Rows=$Rows" | Out-File $script:IpcDiagFile -Append
	}

	# Show startup complete screen (non-debug, non-hidden modes only; skip for viewer)
	if (-not $DebugMode -and $Output -ne "hidden" -and -not $_isViewerMode) {
		Show-StartupComplete -HasParams ($PSBoundParameters.Count -gt 0)
	}

	# Pause to read debug output if in debug mode
	if ($script:DiagEnabled) { "$(Get-Date -Format 'HH:mm:ss.fff') - CHECKPOINT 4: Before debug mode check (DebugMode=$DebugMode)" | Out-File $script:StartupDiagFile -Append }
	
	if ($DebugMode -and -not $_isViewerMode) {
		if ($script:DiagEnabled) { "$(Get-Date -Format 'HH:mm:ss.fff') - ENTERED DEBUG MODE KEY WAIT LOOP" | Out-File $script:StartupDiagFile -Append }

		Write-Host "`nPress any key to start mJig..." -ForegroundColor $script:TextWarning

		$dbgModifierVKs = @(0x10, 0x11, 0x12, 0xA0, 0xA1, 0xA2, 0xA3, 0xA4, 0xA5, 0x5B, 0x5C)
		$hIn      = $script:MouseAPI::GetStdHandle(-10)
		$peekBuf  = New-Object "$($script:_ApiNamespace).INPUT_RECORD[]" 32
		$peekEvts = [uint32]0
		# Drain events buffered before the prompt appeared (e.g. Enter key-up from launch)
		try { $Host.UI.RawUI.FlushInputBuffer() } catch {}
		$detected = $false
		while (-not $detected) {
			Start-Sleep -Milliseconds 5
			try {
				if ($script:MouseAPI::PeekConsoleInput($hIn, $peekBuf, 32, [ref]$peekEvts) -and $peekEvts -gt 0) {
					for ($e = 0; $e -lt [int]$peekEvts; $e++) {
						if ($peekBuf[$e].EventType -eq 0x0001 -and $peekBuf[$e].KeyEvent.bKeyDown -eq 0 -and
						    $peekBuf[$e].KeyEvent.wVirtualKeyCode -notin $dbgModifierVKs) {
							$detected = $true; break
						}
					}
					if ($detected) {
						$flushBuf = New-Object "$($script:_ApiNamespace).INPUT_RECORD[]" $peekEvts
						$flushed  = [uint32]0
						$script:MouseAPI::ReadConsoleInput($hIn, $flushBuf, $peekEvts, [ref]$flushed) | Out-Null
					}
				}
			} catch {
				if ($Host.UI.RawUI.KeyAvailable) {
					try { $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown,IncludeKeyUp,AllowCtrlC") } catch {}
					$detected = $true
				} else {
					Start-Sleep -Milliseconds 45
				}
			}
		}

	}

	# Key-up detection above already flushes all buffered events via ReadConsoleInput,
	# so the main loop starts with a clean input queue.
	if ($script:DiagEnabled) { "$(Get-Date -Format 'HH:mm:ss.fff') - CHECKPOINT 5: Input buffer flushed by key-up handler" | Out-File $script:StartupDiagFile -Append }
		if ($script:DiagEnabled) { "$(Get-Date -Format 'HH:mm:ss.fff') - CHECKPOINT 6: Entering main loop" | Out-File $script:StartupDiagFile -Append }

	# Clear the entire console buffer (viewport + scrollback) so the startup screen
	# cannot be scrolled back to after the main UI takes over.
	try { [Console]::Clear() } catch {}
	Restore-ConsoleInputMode
	# Signal the first render to atomically redraw over the now-blank console.
	$script:PendingForceRedraw = $true

	# Sync window/buffer tracking to the current state before the main loop.
	# Without this, the first iteration sees $oldWindowSize = $null -> windowSizeChanged = $true
	# and immediately enters the resize handler even though nothing has changed.
	$oldWindowSize = (Get-Host).UI.RawUI.WindowSize
	$OldBufferSize = (Get-Host).UI.RawUI.BufferSize

	# Timezone cache invalidation: call ClearCachedData() at most once per hour
	$lastTzCacheClear = $null

	# Pre-allocate hot-path objects that are reused every iteration of the main loop
	$intervalMouseInputs = New-Object 'System.Collections.Generic.HashSet[string]'
	$pressedMenuKeys     = @{}
	$_waitPeekBuffer     = New-Object "$($script:_ApiNamespace).INPUT_RECORD[]" 32
	$lii                 = New-Object $script:LastInputType
	$lii.cbSize          = [uint32][System.Runtime.InteropServices.Marshal]::SizeOf($lii)

	# Cached running time string — updated at interval boundary in viewer mode, empty in inline mode
	$script:StatsRunningTimeStr = ""

	# Viewer-mode interval-boundary input accumulation (persists across main-loop iterations)
	$_viewerWorkerIter         = -1
	$_viewerWorkerIterChanged  = $false
	$_viewerIntervalMouseTypes = [System.Collections.Generic.HashSet[string]]::new()
	$_viewerIntervalKbDetected = $false
	$_viewerIntervalKbInferred = $false
	$_viewerIntervalKbLocal    = $false
	$_viewerIntervalScrollDet  = $false

	if ($script:DiagEnabled -and $_isViewerMode) {
		"$(Get-Date -Format 'HH:mm:ss.fff') - VIEWER ENTERING MAIN LOOP" | Out-File $script:IpcDiagFile -Append
		"  HostWidth=$HostWidth  HostHeight=$HostHeight  Rows=$Rows  Output=$Output" | Out-File $script:IpcDiagFile -Append
		"  oldWindowSize=$($oldWindowSize.Width)x$($oldWindowSize.Height)  forceRedraw=$($script:PendingForceRedraw)" | Out-File $script:IpcDiagFile -Append
		"  LogArray.Count=$($LogArray.Count)  PipeConnected=$($_viewerPipeClient.IsConnected)" | Out-File $script:IpcDiagFile -Append
	}

	# Main Processing Loop — try/finally ensures cleanup on Ctrl+C (PipelineStoppedException)
	try {
	:process while ($true) {
			$script:LoopIteration++
			
			# Reset state for this iteration
			$script:userInputDetected = $false
			$keyboardInputDetected = $false
			$mouseInputDetected = $false
		$scrollDetectedInInterval = $false
		$_keyboardInferred = $false
		$_keyboardLocallyDetected = $false
		$waitExecuted = $false
		$intervalMouseInputs.Clear()
		$interval = 0
			$ticksToWait = 0
	if ($null -eq $lastTzCacheClear -or (Get-TimeSinceMs -StartTime $lastTzCacheClear) -gt 3600000) {
		[System.TimeZoneInfo]::ClearCachedData()
		$lastTzCacheClear = Get-Date
	}
	$date = Get-Date
	$currentTime = $date.ToString("HHmm")
	$forceRedraw = $false
	# If a sub-dialog was used inside settings, keep forceRedraw so the main
	# render uses ClearFirst and we get a pristine background before reopening.
	if ($script:PendingReopenSettings) { $forceRedraw = $true }
	# After the reopened Settings dialog closes, skip sleep so the screen
	# redraws immediately without ever going blank.
	if ($script:PendingForceRedraw) { $forceRedraw = $true; $script:PendingForceRedraw = $false }
		$automatedMovementPos = $null  # Track position after automated movement
			$directionArrow = ""  # Track direction arrow for log display
			$lastKeyPress = $null  # Reset key press tracking
			$lastKeyInfo = $null  # Reset key info tracking
			$pressedMenuKeys.Clear()  # Reset per-iteration key-up tracking

	# ---- Global Hotkey Polling (Shift+M+P / Shift+M+Q) --------------------------
	# Standalone mode only — in viewer mode the worker detects hotkeys
	# via its fast 50ms tick loop and forwards state changes via pipe.
	if (-not $_isViewerMode) {
		$_globalAction = Test-GlobalHotkey
		if ($_globalAction -eq 'togglePause') {
			$script:ManualPause = -not $script:ManualPause
			if ($script:ManualPause) {
				Show-Notification -Body "Paused" -Action paused
			} else {
				Show-Notification -Body "Resumed" -Action resumed
			}
			if ($LogArray.Count -gt 0 -and $LogArray.Count -ge $Rows) { $LogArray.RemoveAt(0) }
			$null = $LogArray.Add([PSCustomObject]@{
				logRow = $true
				components = @(
					@{ priority = 1; text = $date.ToString("HH:mm:ss"); shortText = $date.ToString("HH:mm:ss") },
					@{ priority = 2; text = " - $(if ($script:ManualPause) { "$($script:WindowTitle) paused" } else { "$($script:WindowTitle) resumed" }) via hotkey"; shortText = " - $(if ($script:ManualPause) { "$($script:WindowTitle) paused" } else { "$($script:WindowTitle) resumed" })" }
				)
			})
		} elseif ($_globalAction -eq 'quit') {
			Show-Notification -Body "Stopped" -Action quit
			Clear-Host
			$runtime = (Get-Date) - $ScriptStartTime
			$hours = [math]::Floor($runtime.TotalHours)
			$minutes = $runtime.Minutes
			$seconds = $runtime.Seconds
			$runtimeStr = ""
			if ($hours -gt 0) {
				$runtimeStr = "$hours hour$(if ($hours -ne 1) { 's' }), $minutes minute$(if ($minutes -ne 1) { 's' })"
			} elseif ($minutes -gt 0) {
				$runtimeStr = "$minutes minute$(if ($minutes -ne 1) { 's' }), $seconds second$(if ($seconds -ne 1) { 's' })"
			} else {
				$runtimeStr = "$seconds second$(if ($seconds -ne 1) { 's' })"
			}
			Write-Host ""
			$mouseEmoji = [char]::ConvertFromUtf32(0x1F400)
			Write-Host "  mJig(" -NoNewline -ForegroundColor $script:HeaderAppName
			$mouseEmojiX = $Host.UI.RawUI.CursorPosition.X
			$mouseEmojiY = $Host.UI.RawUI.CursorPosition.Y
			Write-Host $mouseEmoji -NoNewline -ForegroundColor $script:HeaderIcon
			[Console]::SetCursorPosition($mouseEmojiX + 2, $mouseEmojiY)
			Write-Host ") " -NoNewline -ForegroundColor $script:HeaderAppName
			Write-Host "Stopped" -ForegroundColor $script:TextError
			Write-Host ""
			Write-Host "  Runtime: " -NoNewline -ForegroundColor $script:TextMuted
			Write-Host $runtimeStr -ForegroundColor $script:TextDefault
			Write-Host ""
			break process
		}
	}
	# ---- End Global Hotkey Polling ------------------------------------------------

	# ---- Viewer IPC: read state/log messages from the background worker --------
	if ($_isViewerMode) {
		if ($script:DiagEnabled -and $script:LoopIteration -le 5) {
			"$(Get-Date -Format 'HH:mm:ss.fff') - VIEWER LOOP iter=$($script:LoopIteration) forceRedraw=$forceRedraw PipeConnected=$($_viewerPipeClient.IsConnected) HostWidth=$HostWidth Rows=$Rows LogArray=$($LogArray.Count)" | Out-File $script:IpcDiagFile -Append
		}
		if ($_viewerPipeClient.IsConnected) {
			try {
				$msg = Read-PipeMessage -Reader $_viewerPipeReader -PendingTask ([ref]$_viewerReadTask)
				while ($null -ne $msg) {
					switch ($msg.type) {
						'state' {
							$messageEpoch = if ($null -ne $msg.epoch) { [int]$msg.epoch } else { 0 }
							if ($messageEpoch -lt $_settingsEpoch) { break }
							$script:IntervalSeconds = [double]$msg.intervalSeconds
							$script:IntervalVariance = [double]$msg.intervalVariance
							$script:MoveSpeed = [double]$msg.moveSpeed
							$script:MoveVariance = [double]$msg.moveVariance
							$script:TravelDistance = [double]$msg.travelDistance
							$script:TravelVariance = [double]$msg.travelVariance
							$script:AutoResumeDelaySeconds = [double]$msg.autoResumeDelaySeconds
							$script:LoopIteration = [int]$msg.loopIteration
						$_incomingIter = [int]$msg.loopIteration
						if ($_incomingIter -ne $_viewerWorkerIter) { $_viewerWorkerIterChanged = $true; $_viewerWorkerIter = $_incomingIter }
							$endTimeStr = [string]$msg.endTimeStr
							$endTimeInt = [int]$msg.endTimeInt
							$end = [string]$msg.end
							$cooldownActive = [bool]$msg.cooldownActive
							$secondsRemaining = if ($null -ne $msg.cooldownRemaining) { [int]$msg.cooldownRemaining } else { 0 }
							if ([bool]$msg.mouseInputDetected) {
								$mouseInputDetected = $true
								$null = $intervalMouseInputs.Add("Mouse")
							}
							if ([bool]$msg.keyboardInputDetected) { $keyboardInputDetected = $true }
							if ([bool]$msg.keyboardInferred) { $_keyboardInferred = $true }
							$SkipUpdate = [bool]$msg.userInputDetected -or $cooldownActive
					# Stats from worker
					if ($null -ne $msg.statsWorkerStartTime) { try { $ScriptStartTime = [DateTime]::Parse([string]$msg.statsWorkerStartTime) } catch {} }
						if ($null -ne $msg.statsMoveCount)             { $script:StatsMoveCount             = [int]$msg.statsMoveCount }
						if ($null -ne $msg.statsSkipCount)             { $script:StatsSkipCount             = [int]$msg.statsSkipCount }
						if ($null -ne $msg.statsCurrentStreak)         { $script:StatsCurrentStreak         = [int]$msg.statsCurrentStreak }
						if ($null -ne $msg.statsLongestStreak)         { $script:StatsLongestStreak         = [int]$msg.statsLongestStreak }
						if ($null -ne $msg.statsTotalDistancePx)       { $script:StatsTotalDistancePx       = [double]$msg.statsTotalDistancePx }
						if ($null -ne $msg.statsLastMoveDist)          { $script:StatsLastMoveDist          = [double]$msg.statsLastMoveDist }
						if ($null -ne $msg.statsMinMoveDist)           { $script:StatsMinMoveDist           = [double]$msg.statsMinMoveDist }
						if ($null -ne $msg.statsMaxMoveDist)           { $script:StatsMaxMoveDist           = [double]$msg.statsMaxMoveDist }
						if ($null -ne $msg.statsLastMoveDurationMs)    { $LastMovementDurationMs            = [int]$msg.statsLastMoveDurationMs }
						if ($null -ne $msg.statsLastMoveSecondsAgo)    { $LastMovementTime                  = (Get-Date).AddSeconds(-[int]$msg.statsLastMoveSecondsAgo) }
						if ($null -ne $msg.statsKbInterruptCount)      { $script:StatsKbInterruptCount      = [int]$msg.statsKbInterruptCount }
							if ($null -ne $msg.statsMsInterruptCount)      { $script:StatsMsInterruptCount      = [int]$msg.statsMsInterruptCount }
							if ($null -ne $msg.statsLongestCleanStreak)    { $script:StatsLongestCleanStreak    = [int]$msg.statsLongestCleanStreak }
							if ($null -ne $msg.statsAvgActualIntervalSecs) { $script:StatsAvgActualIntervalSecs = [double]$msg.statsAvgActualIntervalSecs }
							if ($null -ne $msg.statsAvgDurationMs)         { $script:StatsAvgDurationMs         = [double]$msg.statsAvgDurationMs }
							if ($null -ne $msg.statsMinDurationMs)         { $script:StatsMinDurationMs         = [int]$msg.statsMinDurationMs }
							if ($null -ne $msg.statsMaxDurationMs)         { $script:StatsMaxDurationMs         = [int]$msg.statsMaxDurationMs }
							if ($null -ne $msg.statsDirectionCounts) {
								foreach ($_sdir in @('N','NE','E','SE','S','SW','W','NW')) {
									$script:StatsDirectionCounts[$_sdir] = [double]$msg.statsDirectionCounts.$_sdir
								}
							}
							if ($null -ne $msg.statsLastCurveParams -and $null -ne $msg.statsLastCurveParams.Distance) {
								$script:StatsLastCurveParams = @{
									Distance      = [double]$msg.statsLastCurveParams.Distance
									StartArcAmt   = [double]$msg.statsLastCurveParams.StartArcAmt
									StartArcSign  = [int]$msg.statsLastCurveParams.StartArcSign
									BodyCurveAmt  = [double]$msg.statsLastCurveParams.BodyCurveAmt
									BodyCurveSign = [int]$msg.statsLastCurveParams.BodyCurveSign
									BodyCurveType = [int]$msg.statsLastCurveParams.BodyCurveType
								}
							$_ck = "$($script:StatsLastCurveParams.Distance)|$($script:StatsLastCurveParams.StartArcAmt)|$($script:StatsLastCurveParams.BodyCurveAmt)|$($script:StatsLastCurveParams.BodyCurveType)"
							if ($_ck -ne $script:_LastCurveParamKey) { $script:_LastCurveParamKey = $_ck; $script:StatsCurveAnimPending = $true }
							}
						}
						'log' {
							if ($null -ne $LogArray -and -not $script:ManualPause) {
								$components = @()
								foreach ($c in $msg.components) {
									$components += @{
										priority = [int]$c.priority
										text = [string]$c.text
										shortText = [string]$c.shortText
									}
								}
								if ($LogArray.Count -gt 0 -and $LogArray.Count -ge $Rows) {
									$LogArray.RemoveAt(0)
								}
								$null = $LogArray.Add([PSCustomObject]@{ logRow = $true; components = $components })
							}
						}
						'togglePause' {
							$script:ManualPause = [bool]$msg.paused
							if ($null -ne $msg.logMsg -and $null -ne $LogArray) {
								$components = @()
								foreach ($c in $msg.logMsg.components) {
									$components += @{
										priority = [int]$c.priority
										text = [string]$c.text
										shortText = [string]$c.shortText
									}
								}
								if ($LogArray.Count -gt 0 -and $LogArray.Count -ge $Rows) {
									$LogArray.RemoveAt(0)
								}
								$null = $LogArray.Add([PSCustomObject]@{ logRow = $true; components = $components })
							}
					}
						'stopped' {
							$_viewerStopped = $true
							$_viewerStopReason = if ($null -ne $msg.reason) { $msg.reason } else { 'unknown' }
						}
					'focus' {
						# Resolve and cache the actual terminal window handle.
						# GetConsoleWindow() returns a hidden ConPTY pseudo-window in Windows Terminal;
						# IsWindowVisible distinguishes the real window from the pseudo-window.
						if ($null -eq $script:_ViewerTerminalHwnd) {
							$_fHwnd = $script:MouseAPI::GetConsoleWindow()
							if ($_fHwnd -ne [IntPtr]::Zero) {
								$_fRoot = $script:MouseAPI::GetAncestor($_fHwnd, 3)
								if ($_fRoot -ne [IntPtr]::Zero) { $_fHwnd = $_fRoot }
							}
							if ($_fHwnd -eq [IntPtr]::Zero -or -not $script:MouseAPI::IsWindowVisible($_fHwnd)) {
								# Windows Terminal: GetConsoleWindow returned a hidden pseudo-window.
								# Walk the parent process chain to find the actual terminal window.
								$_fWalkPid = $PID
								$_fSkip    = @('pwsh','powershell','powershell_ise','cmd','conhost','openconsole',
								               'csrss','wininit','services','svchost','lsass','system','idle')
								$_fAllow   = @('windowsterminal','alacritty','wezterm-gui','wezterm','mintty',
								               'conemu64','conemuc64','cmder','hyper','terminus','tabby','fluent-terminal')
								$_fVisited = @{}
								while ($_fWalkPid -gt 0 -and -not $_fVisited.ContainsKey($_fWalkPid)) {
									$_fVisited[$_fWalkPid] = $true
									try {
										$_fWmi = Get-CimInstance -ClassName Win32_Process -Filter "ProcessId = $_fWalkPid" -EA SilentlyContinue
										if (-not $_fWmi) { break }
										$_fParentPid = [int]$_fWmi.ParentProcessId
										if ($_fParentPid -le 0 -or $_fParentPid -eq $_fWalkPid) { break }
										$_fParent = Get-Process -Id $_fParentPid -EA SilentlyContinue
										if (-not $_fParent) { break }
										$_fExe = [System.IO.Path]::GetFileNameWithoutExtension($_fParent.ProcessName).ToLower()
										if ($_fExe -in $_fAllow) {
											$_fHwnd = $script:MouseAPI::FindMainWindowByProcessId($_fParentPid)
											break
										} elseif ($_fExe -in $_fSkip) {
											$_fWalkPid = $_fParentPid
										} else { break }
									} catch { break }
								}
							}
							$script:_ViewerTerminalHwnd = $_fHwnd
						}
						$hwnd = $script:_ViewerTerminalHwnd
						if ($hwnd -ne [IntPtr]::Zero) {
							if ($script:MouseAPI::IsIconic($hwnd)) {
								$null = $script:MouseAPI::ShowWindow($hwnd, 9)
								$_restoreMs = 0
								while ($script:MouseAPI::IsIconic($hwnd) -and $_restoreMs -lt 500) {
									Start-Sleep -Milliseconds 20
									$_restoreMs += 20
								}
								# Fallback for Windows Terminal: PostMessage WM_SYSCOMMAND/SC_RESTORE.
								# ShowWindow from a cross-process caller may be ignored by WinUI windows.
								if ($script:MouseAPI::IsIconic($hwnd)) {
									$null = $script:MouseAPI::PostMessage($hwnd, [uint32]0x0112, [IntPtr]0xF120, [IntPtr]::Zero)
									$_restoreMs = 0
									while ($script:MouseAPI::IsIconic($hwnd) -and $_restoreMs -lt 500) {
										Start-Sleep -Milliseconds 20
										$_restoreMs += 20
									}
								}
							}
							$foregroundWindow    = $script:MouseAPI::GetForegroundWindow()
							$foregroundThread = $script:MouseAPI::GetWindowThreadProcessId($foregroundWindow, [ref]0)
							$currentThread = $script:MouseAPI::GetCurrentThreadId()
							if ($foregroundThread -ne 0 -and $foregroundThread -ne $currentThread) {
								$null = $script:MouseAPI::AttachThreadInput($foregroundThread, $currentThread, $true)
							}
							$null = $script:MouseAPI::BringWindowToTop($hwnd)
							$null = $script:MouseAPI::SetForegroundWindow($hwnd)
							if ($foregroundThread -ne 0 -and $foregroundThread -ne $currentThread) {
								$null = $script:MouseAPI::AttachThreadInput($foregroundThread, $currentThread, $false)
							}
						}
					}
					}
					if ($_viewerStopped) { break }
					$msg = Read-PipeMessage -Reader $_viewerPipeReader -PendingTask ([ref]$_viewerReadTask)
				}
			} catch {
				$_viewerReadTask = $null
				$_viewerStopped = $true
				$_viewerStopReason = 'pipe_error'
			}
		} else {
			$_viewerStopped = $true
			$_viewerStopReason = 'disconnected'
		}
		if ($_viewerStopped) {
		try { [Console]::Write("$([char]27)[?25h") } catch {}
		Write-Host ""
		if ($_viewerStopReason -eq 'endtime') {
				Write-Host "       END TIME REACHED: " -NoNewline -ForegroundColor $script:TextError
				Write-Host "Stopped."
			} elseif ($_viewerStopReason -eq 'quit') {
				Write-Host "mJig stopped." -ForegroundColor $script:TextSuccess
			} else {
				Write-Host "Background process exited. Run Start-mJig to reconnect." -ForegroundColor $script:TextWarning
			}
			Write-Host ""
			break process
		}
	}
	# ---- End Viewer IPC -----------------------------------------------------------
	if ($script:DiagEnabled -and $_isViewerMode -and $script:LoopIteration -le 5) {
		"$(Get-Date -Format 'HH:mm:ss.fff') - VIEWER IPC READ DONE iter=$($script:LoopIteration) stopped=$_viewerStopped LogArray=$($LogArray.Count)" | Out-File $script:IpcDiagFile -Append
	}
			
			# Calculate interval and wait BEFORE doing movement (skip on first run or if forceRedraw)
			if ($_isViewerMode) {
				# Viewer: 500ms per frame (10 ticks of 50ms) — no movement timing needed
				$ticksToWait = 10
				$waitExecuted = $false
			}
			if (-not $_isViewerMode -and $null -ne $LastMovementTime -and -not $forceRedraw) {
				# Calculate random interval with variance
				# Convert to milliseconds for calculation
				$intervalSecondsMs = $script:IntervalSeconds * 1000
				$intervalVarianceMs = $script:IntervalVariance * 1000
				$intervalMs = Get-VariedValue -baseValue $intervalSecondsMs -variance $intervalVarianceMs

				# Subtract the previous movement duration from the interval
				$intervalMs = $intervalMs - $LastMovementDurationMs

				# Ensure minimum interval of 1 second (variance can be larger than base interval)
				$minIntervalMs = 1000  # 1 second in milliseconds
				if ($intervalMs -lt $minIntervalMs) {
					$intervalMs = $minIntervalMs
				}

				# Convert back to seconds and round to 1 decimal place for display
				$interval = [math]::Round($intervalMs / 1000, 1)

				# Calculate number of 50ms iterations needed (1000ms / 50ms = 20 iterations per second)
				# Use the millisecond value for accurate calculation
				$ticksToWait = [math]::Max(1, [math]::Floor($intervalMs / 50))

				$waitExecuted = $true
				$mousePosAtStart = Get-MousePosition
			} # end inline interval calculation
				
			# Wait Loop - runs for both inline (movement interval) and viewer (500ms frame timer)
			# Viewer always enters; inline enters when $ticksToWait > 0 (after first movement)
			if ($ticksToWait -gt 0) {
				if ($script:DiagEnabled -and $_isViewerMode -and $script:LoopIteration -le 3) {
					"$(Get-Date -Format 'HH:mm:ss.fff') - VIEWER ENTERING WAIT LOOP iter=$($script:LoopIteration) tickCount=$ticksToWait" | Out-File $script:IpcDiagFile -Append
				}
			# Menu hotkeys checked every 200ms (every 4th iteration), keyboard input checked every 50ms for maximum reliability
			$tickIndex = 0
			Restore-ConsoleInputMode
		:waitLoop while ($true) {
			$tickIndex++
				$date = Get-Date  # keep $date fresh each 50ms tick for accurate timestamps

			# Viewer: read IPC messages each tick for real-time state/log updates
			if ($_isViewerMode) {
				if ($_viewerPipeClient.IsConnected) {
					try {
						$msg = Read-PipeMessage -Reader $_viewerPipeReader -PendingTask ([ref]$_viewerReadTask)
						while ($null -ne $msg) {
						switch ($msg.type) {
						'state' {
							$messageEpoch = if ($null -ne $msg.epoch) { [int]$msg.epoch } else { 0 }
							if ($messageEpoch -lt $_settingsEpoch) { break }
							$script:IntervalSeconds = [double]$msg.intervalSeconds
							$script:IntervalVariance = [double]$msg.intervalVariance
							$script:MoveSpeed = [double]$msg.moveSpeed
							$script:MoveVariance = [double]$msg.moveVariance
							$script:TravelDistance = [double]$msg.travelDistance
							$script:TravelVariance = [double]$msg.travelVariance
							$script:AutoResumeDelaySeconds = [double]$msg.autoResumeDelaySeconds
							$script:LoopIteration = [int]$msg.loopIteration
						$_incomingIter = [int]$msg.loopIteration
						if ($_incomingIter -ne $_viewerWorkerIter) { $_viewerWorkerIterChanged = $true; $_viewerWorkerIter = $_incomingIter }
							$endTimeStr = [string]$msg.endTimeStr
							$endTimeInt = [int]$msg.endTimeInt
							$end = [string]$msg.end
							$cooldownActive = [bool]$msg.cooldownActive
							$secondsRemaining = if ($null -ne $msg.cooldownRemaining) { [int]$msg.cooldownRemaining } else { 0 }
							if ([bool]$msg.mouseInputDetected) {
								$mouseInputDetected = $true
								$null = $intervalMouseInputs.Add("Mouse")
							}
							if ([bool]$msg.keyboardInputDetected) { $keyboardInputDetected = $true }
							if ([bool]$msg.keyboardInferred) { $_keyboardInferred = $true }
							$SkipUpdate = [bool]$msg.userInputDetected -or $cooldownActive
					# Stats from worker (wait-loop tick handler)
					if ($null -ne $msg.statsWorkerStartTime) { try { $ScriptStartTime = [DateTime]::Parse([string]$msg.statsWorkerStartTime) } catch {} }
						if ($null -ne $msg.statsMoveCount)             { $script:StatsMoveCount             = [int]$msg.statsMoveCount }
						if ($null -ne $msg.statsSkipCount)             { $script:StatsSkipCount             = [int]$msg.statsSkipCount }
						if ($null -ne $msg.statsCurrentStreak)         { $script:StatsCurrentStreak         = [int]$msg.statsCurrentStreak }
						if ($null -ne $msg.statsLongestStreak)         { $script:StatsLongestStreak         = [int]$msg.statsLongestStreak }
						if ($null -ne $msg.statsTotalDistancePx)       { $script:StatsTotalDistancePx       = [double]$msg.statsTotalDistancePx }
						if ($null -ne $msg.statsLastMoveDist)          { $script:StatsLastMoveDist          = [double]$msg.statsLastMoveDist }
						if ($null -ne $msg.statsMinMoveDist)           { $script:StatsMinMoveDist           = [double]$msg.statsMinMoveDist }
						if ($null -ne $msg.statsMaxMoveDist)           { $script:StatsMaxMoveDist           = [double]$msg.statsMaxMoveDist }
						if ($null -ne $msg.statsLastMoveDurationMs)    { $LastMovementDurationMs            = [int]$msg.statsLastMoveDurationMs }
						if ($null -ne $msg.statsLastMoveSecondsAgo)    { $LastMovementTime                  = (Get-Date).AddSeconds(-[int]$msg.statsLastMoveSecondsAgo) }
						if ($null -ne $msg.statsKbInterruptCount)      { $script:StatsKbInterruptCount      = [int]$msg.statsKbInterruptCount }
							if ($null -ne $msg.statsMsInterruptCount)      { $script:StatsMsInterruptCount      = [int]$msg.statsMsInterruptCount }
							if ($null -ne $msg.statsLongestCleanStreak)    { $script:StatsLongestCleanStreak    = [int]$msg.statsLongestCleanStreak }
							if ($null -ne $msg.statsAvgActualIntervalSecs) { $script:StatsAvgActualIntervalSecs = [double]$msg.statsAvgActualIntervalSecs }
							if ($null -ne $msg.statsAvgDurationMs)         { $script:StatsAvgDurationMs         = [double]$msg.statsAvgDurationMs }
							if ($null -ne $msg.statsMinDurationMs)         { $script:StatsMinDurationMs         = [int]$msg.statsMinDurationMs }
							if ($null -ne $msg.statsMaxDurationMs)         { $script:StatsMaxDurationMs         = [int]$msg.statsMaxDurationMs }
							if ($null -ne $msg.statsDirectionCounts) {
								foreach ($_sdir in @('N','NE','E','SE','S','SW','W','NW')) {
									$script:StatsDirectionCounts[$_sdir] = [double]$msg.statsDirectionCounts.$_sdir
								}
							}
							if ($null -ne $msg.statsLastCurveParams -and $null -ne $msg.statsLastCurveParams.Distance) {
								$script:StatsLastCurveParams = @{
									Distance      = [double]$msg.statsLastCurveParams.Distance
									StartArcAmt   = [double]$msg.statsLastCurveParams.StartArcAmt
									StartArcSign  = [int]$msg.statsLastCurveParams.StartArcSign
									BodyCurveAmt  = [double]$msg.statsLastCurveParams.BodyCurveAmt
									BodyCurveSign = [int]$msg.statsLastCurveParams.BodyCurveSign
									BodyCurveType = [int]$msg.statsLastCurveParams.BodyCurveType
								}
							$_ck = "$($script:StatsLastCurveParams.Distance)|$($script:StatsLastCurveParams.StartArcAmt)|$($script:StatsLastCurveParams.BodyCurveAmt)|$($script:StatsLastCurveParams.BodyCurveType)"
							if ($_ck -ne $script:_LastCurveParamKey) { $script:_LastCurveParamKey = $_ck; $script:StatsCurveAnimPending = $true }
							}
						}
						'log' {
							if ($null -ne $LogArray -and -not $script:ManualPause) {
								$components = @()
								foreach ($c in $msg.components) {
									$components += @{
										priority = [int]$c.priority
										text = [string]$c.text
										shortText = [string]$c.shortText
									}
								}
									if ($LogArray.Count -gt 0 -and $LogArray.Count -ge $Rows) {
										$LogArray.RemoveAt(0)
									}
									$null = $LogArray.Add([PSCustomObject]@{ logRow = $true; components = $components })
								}
							}
							'togglePause' {
								$script:ManualPause = [bool]$msg.paused
								if ($null -ne $msg.logMsg -and $null -ne $LogArray) {
									$components = @()
									foreach ($c in $msg.logMsg.components) {
										$components += @{
											priority = [int]$c.priority
											text = [string]$c.text
											shortText = [string]$c.shortText
										}
									}
									if ($LogArray.Count -gt 0 -and $LogArray.Count -ge $Rows) {
										$LogArray.RemoveAt(0)
									}
									$null = $LogArray.Add([PSCustomObject]@{ logRow = $true; components = $components })
								}
							}
							'stopped' {
								$_viewerStopped = $true
								$_viewerStopReason = if ($null -ne $msg.reason) { $msg.reason } else { 'unknown' }
							}
				'focus' {
					# Resolve and cache the actual terminal window handle.
					# In Windows Terminal v1.14+, GetConsoleWindow() returns a ConPTY pseudo-window
					# that is OWNED (not parented) by the WT main window. GA_ROOTOWNER=3 walks the
					# owner chain to reach the real window; GA_ROOT=2 (parent chain only) returns
					# the hidden pseudo-window itself, yielding the wrong handle.
					if ($null -eq $script:_ViewerTerminalHwnd) {
						$_fHwnd = $script:MouseAPI::GetConsoleWindow()
						if ($_fHwnd -ne [IntPtr]::Zero) {
							$_fRoot = $script:MouseAPI::GetAncestor($_fHwnd, 3)
							if ($_fRoot -ne [IntPtr]::Zero) { $_fHwnd = $_fRoot }
						}
						if ($_fHwnd -eq [IntPtr]::Zero -or -not $script:MouseAPI::IsWindowVisible($_fHwnd)) {
							# Pre-v1.14 WT or other terminal: fall back to parent process tree walk.
							$_fWalkPid = $PID
							$_fSkip    = @('pwsh','powershell','powershell_ise','cmd','conhost','openconsole',
							               'csrss','wininit','services','svchost','lsass','system','idle')
							$_fAllow   = @('windowsterminal','alacritty','wezterm-gui','wezterm','mintty',
							               'conemu64','conemuc64','cmder','hyper','terminus','tabby','fluent-terminal')
							$_fVisited = @{}
							while ($_fWalkPid -gt 0 -and -not $_fVisited.ContainsKey($_fWalkPid)) {
								$_fVisited[$_fWalkPid] = $true
								try {
									$_fWmi = Get-CimInstance -ClassName Win32_Process -Filter "ProcessId = $_fWalkPid" -EA SilentlyContinue
									if (-not $_fWmi) { break }
									$_fParentPid = [int]$_fWmi.ParentProcessId
									if ($_fParentPid -le 0 -or $_fParentPid -eq $_fWalkPid) { break }
									$_fParent = Get-Process -Id $_fParentPid -EA SilentlyContinue
									if (-not $_fParent) { break }
									$_fExe = [System.IO.Path]::GetFileNameWithoutExtension($_fParent.ProcessName).ToLower()
									if ($_fExe -in $_fAllow) {
										$_fHwnd = $script:MouseAPI::FindMainWindowByProcessId($_fParentPid)
										break
									} elseif ($_fExe -in $_fSkip) {
										$_fWalkPid = $_fParentPid
									} else { break }
								} catch { break }
							}
						}
						$script:_ViewerTerminalHwnd = $_fHwnd
					}
					$hwnd = $script:_ViewerTerminalHwnd
					if ($hwnd -ne [IntPtr]::Zero) {
						if ($script:MouseAPI::IsIconic($hwnd)) {
							$null = $script:MouseAPI::ShowWindow($hwnd, 9)
							$_restoreMs = 0
							while ($script:MouseAPI::IsIconic($hwnd) -and $_restoreMs -lt 500) {
								Start-Sleep -Milliseconds 20
								$_restoreMs += 20
							}
							# Fallback for Windows Terminal: PostMessage WM_SYSCOMMAND/SC_RESTORE.
							# ShowWindow from a cross-process caller may be ignored by WinUI windows.
							if ($script:MouseAPI::IsIconic($hwnd)) {
								$null = $script:MouseAPI::PostMessage($hwnd, [uint32]0x0112, [IntPtr]0xF120, [IntPtr]::Zero)
								$_restoreMs = 0
								while ($script:MouseAPI::IsIconic($hwnd) -and $_restoreMs -lt 500) {
									Start-Sleep -Milliseconds 20
									$_restoreMs += 20
								}
							}
						}
						$foregroundWindow    = $script:MouseAPI::GetForegroundWindow()
						$foregroundThread = $script:MouseAPI::GetWindowThreadProcessId($foregroundWindow, [ref]0)
						$currentThread = $script:MouseAPI::GetCurrentThreadId()
						if ($foregroundThread -ne 0 -and $foregroundThread -ne $currentThread) {
							$null = $script:MouseAPI::AttachThreadInput($foregroundThread, $currentThread, $true)
						}
						$null = $script:MouseAPI::BringWindowToTop($hwnd)
						$null = $script:MouseAPI::SetForegroundWindow($hwnd)
						if ($foregroundThread -ne 0 -and $foregroundThread -ne $currentThread) {
							$null = $script:MouseAPI::AttachThreadInput($foregroundThread, $currentThread, $false)
						}
					}
				}
					}
					if ($_viewerStopped) { break }
						$msg = Read-PipeMessage -Reader $_viewerPipeReader -PendingTask ([ref]$_viewerReadTask)
					}
				} catch {
					$_viewerReadTask = $null
					$_viewerStopped = $true
					$_viewerStopReason = 'pipe_error'
				}
			} else {
				$_viewerStopped = $true
				$_viewerStopReason = 'disconnected'
			}
			if ($_viewerStopped) { break waitLoop }
				}

				if (-not $_isViewerMode) {
				# Check for system-wide keyboard input every 50ms for maximum reliability
					# Skip checking if we recently sent a simulated key press (within last 300ms)
					$shouldCheckKeyboard = (Get-TimeSinceMs -StartTime $LastSimulatedKeyPress) -ge 300
					if ($shouldCheckKeyboard) {
						$LastSimulatedKeyPress = $null
					}
					
					if ($shouldCheckKeyboard) {
						# Initialize previous key states lazily
						if ($null -eq $script:previousKeyStates) {
							$script:previousKeyStates = @{}
						}
						
						# Check mouse position every 50ms to detect movement for console skip
						# This prevents console updates from blocking during active mouse movement
						if ($null -eq $script:lastMousePosCheck) {
							$script:lastMousePosCheck = $null
						}
						try {
							$currentCheckPos = Get-MousePosition
							if ($script:DiagEnabled -and $null -ne $currentCheckPos) {
								$lastX = if ($null -ne $script:lastMousePosCheck) { $script:lastMousePosCheck.X } else { "null" }
								$lastY = if ($null -ne $script:lastMousePosCheck) { $script:lastMousePosCheck.Y } else { "null" }
								$moved = Test-MouseMoved -CurrentPos $currentCheckPos -LastPos $script:lastMousePosCheck -Threshold 2
								"$(Get-Date -Format 'HH:mm:ss.fff') - MOUSEPOS cur=($($currentCheckPos.X),$($currentCheckPos.Y)) last=($lastX,$lastY) moved=$moved" | Out-File $script:InputDiagFile -Append
							}
							if ($null -ne $currentCheckPos) {
								if (Test-MouseMoved -CurrentPos $currentCheckPos -LastPos $script:lastMousePosCheck -Threshold 2) {
									$script:LastMouseMovementTime = Get-Date
									$mouseInputDetected = $true
						$null = $intervalMouseInputs.Add("Mouse")
								if ($script:AutoResumeDelaySeconds -gt 0) {
									$LastUserInputTime = Get-Date
								}
							}
							$script:lastMousePosCheck = $currentCheckPos
							} elseif ($script:DiagEnabled) {
								"$(Get-Date -Format 'HH:mm:ss.fff') - MOUSEPOS: Get-MousePosition returned NULL" | Out-File $script:InputDiagFile -Append
							}
						} catch {
							if ($script:DiagEnabled) { "$(Get-Date -Format 'HH:mm:ss.fff') - MOUSEPOS ERROR: $($_.Exception.Message)" | Out-File $script:InputDiagFile -Append }
						}
					} # end if ($shouldCheckKeyboard) — movement-specific section
				} # end if (-not $_isViewerMode) — movement-specific per-tick checks
						
					if (-not $_isViewerMode -and $shouldCheckKeyboard -or $_isViewerMode) {
						# Detect scroll, keyboard, and mouse clicks via PeekConsoleInput (works when console is focused)
						# Keyboard events are only peeked (not consumed) so the menu hotkey handler can still read them
						$script:ConsoleClickCoords = $null
					try {
						$peekBuffer = $_waitPeekBuffer
						$peekEvents = [uint32]0
						$hStdIn = $script:MouseAPI::GetStdHandle(-10)  # STD_INPUT_HANDLE
						if ($script:MouseAPI::PeekConsoleInput($hStdIn, $peekBuffer, 32, [ref]$peekEvents) -and $peekEvents -gt 0) {
								$hasScrollEvent = $false
								$hasKeyboardEvent = $false
								$lastScrollIdx = -1
								$lastClickIdx = -1
								for ($e = 0; $e -lt $peekEvents; $e++) {
									if ($peekBuffer[$e].EventType -eq 0x0002) {
										$mouseFlags = $peekBuffer[$e].MouseEvent.dwEventFlags
										$mouseButtons = $peekBuffer[$e].MouseEvent.dwButtonState
										if ($mouseFlags -eq 0x0004) {
											$hasScrollEvent = $true
											$lastScrollIdx = $e
									} elseif ($mouseFlags -eq 0) {
										# Button press/release event (dwEventFlags=0); bit 0 of dwButtonState = left button currently held
										$lmbNow = ($mouseButtons -band 0x0001) -ne 0
										if ($lmbNow -and -not $script:LButtonWasDown) {
											# LMB DOWN: find button under cursor and immediately render it in onclick colors
											$dX = $peekBuffer[$e].MouseEvent.dwMousePosition.X
											$dY = $peekBuffer[$e].MouseEvent.dwMousePosition.Y
											$script:PressedMenuButton = $null
											if ($null -eq $script:DialogButtonBounds -and $null -ne $script:MenuItemsBounds) {
												foreach ($btn in $script:MenuItemsBounds) {
													if ($null -ne $btn.hotkey -and $dY -eq $btn.y -and $dX -ge $btn.startX -and $dX -le $btn.endX) {
														$script:PressedMenuButton = $btn.hotkey
						$ocFg         = if ($null -ne $btn.onClickFg)         { $btn.onClickFg }         else { $script:MenuButtonOnClickFg }
							$ocBg         = if ($null -ne $btn.onClickBg)         { $btn.onClickBg }         else { $script:MenuButtonOnClickBg }
							$ocHk         = if ($null -ne $btn.onClickHotkeyFg)   { $btn.onClickHotkeyFg }   else { $script:MenuButtonOnClickHotkey }
							$ocPipe       = if ($null -ne $btn.onClickPipeFg)      { $btn.onClickPipeFg }     else { $script:MenuButtonOnClickSeparatorFg }
							$ocBracketFg  = if ($null -ne $btn.onClickBracketFg)   { $btn.onClickBracketFg }  else { $script:MenuButtonOnClickBracketFg }
							$ocBracketBg  = if ($null -ne $btn.onClickBracketBg)   { $btn.onClickBracketBg }  else { $script:MenuButtonOnClickBracketBg }
							Write-MenuButton -Button $btn -FG $ocFg -BG $ocBg -HotkeyFg $ocHk -PipeFg $ocPipe -BracketFg $ocBracketFg -BracketBg $ocBracketBg
														break
													}
												}
											}
											$lastClickIdx = $e
										} elseif (-not $lmbNow -and $script:LButtonWasDown) {
											# LMB UP: decide whether to trigger action and how to restore button colors
											$uX = $peekBuffer[$e].MouseEvent.dwMousePosition.X
											$uY = $peekBuffer[$e].MouseEvent.dwMousePosition.Y
											if ($null -ne $script:PressedMenuButton -and $null -ne $script:MenuItemsBounds) {
												foreach ($btn in $script:MenuItemsBounds) {
													if ($btn.hotkey -eq $script:PressedMenuButton) {
														$releasedOver = ($uY -eq $btn.y -and $uX -ge $btn.startX -and $uX -le $btn.endX)
													if ($releasedOver) {
														# Confirmed click: trigger action, leave onclick colors active.
														# PendingDialogCheck tells the render loop to clear the pressed state on the
														# first render UNLESS a dialog is open at that point (popup persists).
														$script:ConsoleClickCoords  = @{ X = $uX; Y = $uY }
														$script:ButtonClickedAt     = Get-Date
														$script:PendingDialogCheck  = $true
														# Don't clear PressedMenuButton here — render loop handles restoration
														} else {
															# Cancelled (dragged off): wait 100ms then restore immediately
															Start-Sleep -Milliseconds 100
								$nFg        = if ($null -ne $btn.fg)         { $btn.fg }         else { $script:MenuButtonText }
								$nBg        = if ($null -ne $btn.bg)         { $btn.bg }         else { $script:MenuButtonBg }
								$nHk        = if ($null -ne $btn.hotkeyFg)   { $btn.hotkeyFg }   else { $script:MenuButtonHotkey }
								$nPipe      = if ($null -ne $btn.pipeFg)     { $btn.pipeFg }     else { $script:MenuButtonSeparatorFg }
								$nBracketFg = if ($null -ne $btn.bracketFg)  { $btn.bracketFg }  else { $script:MenuButtonBracketFg }
								$nBracketBg = if ($null -ne $btn.bracketBg)  { $btn.bracketBg }  else { $script:MenuButtonBracketBg }
								Write-MenuButton -Button $btn -FG $nFg -BG $nBg -HotkeyFg $nHk -PipeFg $nPipe -BracketFg $nBracketFg -BracketBg $nBracketBg
															$script:PressedMenuButton = $null
															$script:ButtonClickedAt   = $null
														}
														break
													}
												}
									} else {
										# No pressed menu button — always record coords so the processing
										# section can evaluate dialog buttons, mode button, and header
										# time regions against their bounds.
										$script:ConsoleClickCoords = @{ X = $uX; Y = $uY }
									}
											$lastClickIdx = $e
										}
										$script:LButtonWasDown = $lmbNow
									}
									}
									if ($peekBuffer[$e].EventType -eq 0x0001 -and $peekBuffer[$e].KeyEvent.wVirtualKeyCode -notin @(0x10, 0x11, 0x12, 0xA0, 0xA1, 0xA2, 0xA3, 0xA4, 0xA5)) {
										$hasKeyboardEvent = $true
									}
								}
								# Consume scroll and click events to prevent buffer buildup
								$maxConsumeIdx = [Math]::Max($lastScrollIdx, $lastClickIdx)
								if ($maxConsumeIdx -ge 0) {
								$consumeCount = [uint32]($maxConsumeIdx + 1)
								$flushed = [uint32]0
								$script:MouseAPI::ReadConsoleInput($hStdIn, $_waitPeekBuffer, $consumeCount, [ref]$flushed) | Out-Null
								}
								if ($hasScrollEvent) {
									$scrollDetectedInInterval = $true
								$null = $intervalMouseInputs.Add("Scroll/Other")
									$mouseInputDetected = $true
									$script:userInputDetected = $true
									if ($script:AutoResumeDelaySeconds -gt 0) {
										$LastUserInputTime = Get-Date
									}
									if ($script:DiagEnabled) { "$(Get-Date -Format 'HH:mm:ss.fff') - PeekConsoleInput: scroll detected (events=$peekEvents)" | Out-File $script:InputDiagFile -Append }
								}
								if ($hasKeyboardEvent) {
									$keyboardInputDetected = $true
									$_keyboardLocallyDetected = $true
									$script:userInputDetected = $true
									if ($script:AutoResumeDelaySeconds -gt 0) {
										$LastUserInputTime = Get-Date
									}
									if ($script:DiagEnabled) { "$(Get-Date -Format 'HH:mm:ss.fff') - PeekConsoleInput: keyboard detected (events=$peekEvents)" | Out-File $script:InputDiagFile -Append }
								}
							}
						} catch {
							if ($script:DiagEnabled) { "$(Get-Date -Format 'HH:mm:ss.fff') - PeekConsoleInput ERROR: $($_.Exception.Message)" | Out-File $script:InputDiagFile -Append }
						}
						
					# System-wide input detection (viewer skips; worker reports via IPC)
				if (-not $_isViewerMode) {
					try {
						$liiResult = $script:MouseAPI::GetLastInputInfo([ref]$lii)
							if ($liiResult) {
								$tickNow = [uint64]$script:MouseAPI::GetTickCount64()
								$lastInputTick = [uint64]$lii.dwTime
								$systemIdleMs = $tickNow - $lastInputTick
								$recentSimulated = ($null -ne $LastSimulatedKeyPress) -and ((Get-TimeSinceMs -StartTime $LastSimulatedKeyPress) -lt 500)
								$recentAutoMove = ($null -ne $LastAutomatedMouseMovement) -and ((Get-TimeSinceMs -StartTime $LastAutomatedMouseMovement) -lt 500)
								if ($script:DiagEnabled) {
									$ts = Get-Date -Format 'HH:mm:ss.fff'
									"$ts - LII idleMs=$systemIdleMs simFilter=$recentSimulated autoFilter=$recentAutoMove kbDet=$keyboardInputDetected msDet=$mouseInputDetected scrollInt=$scrollDetectedInInterval" | Out-File $script:InputDiagFile -Append
								}
								if ($systemIdleMs -lt 300 -and -not $recentSimulated -and -not $recentAutoMove) {
									$script:userInputDetected = $true
									if ($script:AutoResumeDelaySeconds -gt 0) {
										$LastUserInputTime = Get-Date
									}
									if (-not $keyboardInputDetected -and -not $scrollDetectedInInterval -and -not $mouseInputDetected) {
										$mouseInputDetected = $true
										$script:LastMouseMovementTime = Get-Date
										$null = $intervalMouseInputs.Add("Mouse")
										if ($script:DiagEnabled) { "  >> userInput=TRUE idleMs=$systemIdleMs -> mouse (no kb/scroll/click evidence)" | Out-File $script:InputDiagFile -Append }
									} else {
										if ($script:DiagEnabled) { "  >> userInput=TRUE idleMs=$systemIdleMs (already classified: kb=$keyboardInputDetected ms=$mouseInputDetected scroll=$scrollDetectedInInterval)" | Out-File $script:InputDiagFile -Append }
									}
								}
							}
						} catch {
							if ($script:DiagEnabled) { "$(Get-Date -Format 'HH:mm:ss.fff') - GetLastInputInfo ERROR: $($_.Exception.Message)" | Out-File $script:InputDiagFile -Append }
						}
					} # end if (-not $_isViewerMode) — GetLastInputInfo
						
						# Check for left-click via console input buffer (exact cell coordinates from the console)
						if ($null -ne $script:ConsoleClickCoords) {
							$consoleX = $script:ConsoleClickCoords.X
							$consoleY = $script:ConsoleClickCoords.Y
							
							# Check dialog buttons first (if a dialog is open)
							if ($null -ne $script:DialogButtonBounds) {
								$bounds = $script:DialogButtonBounds
								if ($consoleY -eq $bounds.buttonRowY -and $consoleX -ge $bounds.updateStartX -and $consoleX -le $bounds.updateEndX) {
									$script:DialogButtonClick = "Update"
								} elseif ($consoleY -eq $bounds.buttonRowY -and $consoleX -ge $bounds.cancelStartX -and $consoleX -le $bounds.cancelEndX) {
									$script:DialogButtonClick = "Cancel"
								}
							}
							
					# Check pause/resume button in header
				if ($null -eq $script:DialogButtonBounds -and $null -ne $script:ModeButtonBounds) {
					$mb = $script:ModeButtonBounds
					if ($consoleY -eq $mb.y -and $consoleX -ge $mb.startX -and $consoleX -le $mb.endX) {
						$script:MenuClickHotkey = "_pause"
					}
				}
					# Check mode label (Full/Min) in header
				if ($null -eq $script:DialogButtonBounds -and $null -eq $script:MenuClickHotkey -and $null -ne $script:ModeLabelBounds) {
					$ml = $script:ModeLabelBounds
					if ($consoleY -eq $ml.y -and $consoleX -ge $ml.startX -and $consoleX -le $ml.endX) {
						$script:MenuClickHotkey = "_output"
					}
				}
					# Check hidden time click regions (no dialog check — these are header-level easter eggs)
					if ($null -eq $script:DialogButtonBounds -and $null -eq $script:MenuClickHotkey) {
						if ($null -ne $script:HeaderEndTimeBounds) {
							$b = $script:HeaderEndTimeBounds
							if ($consoleY -eq $b.y -and $consoleX -ge $b.startX -and $consoleX -le $b.endX) {
								$script:MenuClickHotkey = "t"  # opens Set End Time dialog
							}
						}
					if ($null -eq $script:MenuClickHotkey -and $null -ne $script:HeaderCurrentTimeBounds) {
						$b = $script:HeaderCurrentTimeBounds
						if ($consoleY -eq $b.y -and $consoleX -ge $b.startX -and $consoleX -le $b.endX) {
							Start-Process "control.exe" -ArgumentList "timedate.cpl"
						}
					}
					if ($null -eq $script:MenuClickHotkey -and $null -ne $script:HeaderLogoBounds) {
						$b = $script:HeaderLogoBounds
						if ($consoleY -eq $b.y -and $consoleX -ge $b.startX -and $consoleX -le $b.endX) {
							$script:MenuClickHotkey = "?"  # opens info/about dialog
						}
					}
				}

						# Check menu items (only when no dialog is open)
						if ($null -eq $script:DialogButtonBounds -and $null -ne $script:MenuItemsBounds -and $script:MenuItemsBounds.Count -gt 0) {
							foreach ($menuItem in $script:MenuItemsBounds) {
								if ($null -ne $menuItem.hotkey -and $consoleY -eq $menuItem.y -and $consoleX -ge $menuItem.startX -and $consoleX -le $menuItem.endX) {
									$script:MenuClickHotkey = $menuItem.hotkey
									break
								}
							}
						}
							
						if ($DebugMode) {
							$clickTarget = "none"
							if ($null -ne $script:DialogButtonClick) { $clickTarget = "Dialog:$($script:DialogButtonClick)" }
							elseif ($null -ne $script:MenuClickHotkey) { $clickTarget = "Menu:$($script:MenuClickHotkey)" }
							Add-DebugLogEntry -LogArray $LogArray -Date $date -Message "LButton click at console ($consoleX,$consoleY), target: $clickTarget" -ShortMessage "Click ($consoleX,$consoleY) -> $clickTarget"
						}
						}
						
						# Check mouse buttons (0x01-0x06) for user input detection
						if ($null -eq $script:previousKeyStates) { $script:previousKeyStates = @{} }
						for ($keyCode = 0x01; $keyCode -le 0x06; $keyCode++) {
							if ($keyCode -eq 0x03) { continue }  # 0x03 is VK_CANCEL, not a mouse button
							$currentKeyState = $script:MouseAPI::GetAsyncKeyState($keyCode)
							$isCurrentlyPressed = (($currentKeyState -band 0x8000) -ne 0)
							$pressedSinceLastPoll = (($currentKeyState -band 0x0001) -ne 0)
							$wasPreviouslyPressed = if ($script:previousKeyStates.ContainsKey($keyCode)) { $script:previousKeyStates[$keyCode] } else { $false }
							
							if ($pressedSinceLastPoll -or ($isCurrentlyPressed -and -not $wasPreviouslyPressed)) {
								
								$mouseButtonName = switch ($keyCode) {
									0x01 { "LButton" }
									0x02 { "RButton" }
									0x04 { "MButton" }
									0x05 { "XButton1" }
									0x06 { "XButton2" }
								}
							if ($mouseButtonName -and $intervalMouseInputs.Add($mouseButtonName)) {
								$script:userInputDetected = $true
									$mouseInputDetected = $true
									if ($script:AutoResumeDelaySeconds -gt 0) {
										$LastUserInputTime = Get-Date
									}
								}
							}
							$script:previousKeyStates[$keyCode] = $isCurrentlyPressed
						}
					}
					
					# Check for console keyboard input (menu hotkeys) - only every 200ms to avoid stutter
					# Also check for menu clicks immediately (they are set by mouse click handler)
					$menuHotkeyToProcess = $null
					if ($null -ne $script:MenuClickHotkey) {
						# Menu item was clicked - process it immediately
						$menuHotkeyToProcess = $script:MenuClickHotkey
						$script:MenuClickHotkey = $null  # Clear it after using
					} elseif ($tickIndex % 4 -eq 0) {
						# Read available keys for menu hotkeys (only every 200ms)
						$lastKeyPress = $null
						$lastKeyInfo = $null
						$keysRead = 0
						$maxKeysToRead = 10  # Limit to prevent infinite loops
						while ($Host.UI.RawUI.KeyAvailable -and $keysRead -lt $maxKeysToRead) {
							try {
								$keyInfo = $Host.UI.RawUI.ReadKey("IncludeKeyup,NoEcho")
								$keysRead++
								$keyPress = $keyInfo.Character
								$isEscape = ($keyInfo.Key -eq "Escape" -or $keyInfo.VirtualKeyCode -eq 27)
								$isKeyDown = if ($null -ne $keyInfo.KeyDown) { $keyInfo.KeyDown } else { $false }
								
								# Only process key up events
								if (-not $isKeyDown) {
									$keyId = if ($isEscape) { "Escape" } elseif ($keyPress) { $keyPress } else { $null }
									if ($keyId) {
										if ($isEscape) {
											$lastKeyPress = "Escape"
											$lastKeyInfo = $keyInfo
										} else {
											$lastKeyPress = $keyPress
											$lastKeyInfo = $keyInfo
										}
									}
								}
							} catch {
								break
							}
						}
					}
					
					# Handle pause button click (special; not a regular menu hotkey)
					if ($menuHotkeyToProcess -eq '_pause') {
						$script:ManualPause = -not $script:ManualPause
						if ($script:ManualPause) {
							Show-Notification -Body "Paused" -Action paused
						} else {
							Show-Notification -Body "Resumed" -Action resumed
						}
						if ($LogArray.Count -gt 0 -and $LogArray.Count -ge $Rows) { $LogArray.RemoveAt(0) }
						$null = $LogArray.Add([PSCustomObject]@{
							logRow = $true
							components = @(
								@{ priority = 1; text = $date.ToString("HH:mm:ss"); shortText = $date.ToString("HH:mm:ss") },
								@{ priority = 2; text = " - $(if ($script:ManualPause) { "$($script:WindowTitle) paused" } else { "$($script:WindowTitle) resumed" }) via click"; shortText = " - $(if ($script:ManualPause) { "$($script:WindowTitle) paused" } else { "$($script:WindowTitle) resumed" })" }
							)
						})
						if ($_isViewerMode) {
							try { Send-PipeMessage -Writer $_viewerPipeWriter -Message @{ type = 'togglePause'; paused = $script:ManualPause } } catch {}
						}
						$menuHotkeyToProcess = $null
						Reset-PostDialogState -SkipUpdateRef ([ref]$SkipUpdate) -ForceRedrawRef ([ref]$forceRedraw)
						break
					}
					# Handle mode label click (output toggle via click only; no keyboard hotkey)
					if ($menuHotkeyToProcess -eq '_output') {
						$oldOutput = $Output
						if ($Output -eq "full") { $Output = "min" } else { $Output = "full" }
						$script:Output = $Output
				if ($_isViewerMode) { $_settingsEpoch++; try { Send-PipeMessage -Writer $_viewerPipeWriter -Message @{ type = 'output'; mode = $script:Output; epoch = $_settingsEpoch; previousView = $PreviousView; activeDialog = $null } } catch {} }
				if ($DebugMode) {
					Add-DebugLogEntry -LogArray $LogArray -Date $date -Message "View toggle: $oldOutput $([char]0x2192) $Output" -ShortMessage "View: $oldOutput $([char]0x2192) $Output"
					}
						$menuHotkeyToProcess = $null
						Reset-PostDialogState -SkipUpdateRef ([ref]$SkipUpdate) -ForceRedrawRef ([ref]$forceRedraw)
						break
					}
					# Process menu hotkeys (check both lastKeyPress and menuHotkeyToProcess)
					if ($null -ne $menuHotkeyToProcess) {
						# Process menu click hotkey immediately
						$lastKeyPress = $menuHotkeyToProcess
						$lastKeyInfo = $null
					}
					
					if ($null -ne $lastKeyPress -or $null -ne $lastKeyInfo) {
						$shouldProcessEscape = ($lastKeyPress -eq "Escape" -or ($null -ne $lastKeyInfo -and ($lastKeyInfo.Key -eq "Escape" -or $lastKeyInfo.VirtualKeyCode -eq 27)))
						if ($shouldProcessEscape) {
							$lastKeyPress = $null
							$lastKeyInfo = $null
							if ($_isViewerMode) { try { Send-PipeMessage -Writer $_viewerPipeWriter -Message @{ type = 'viewerState'; activeDialog = 'quit' } } catch {} }
							$HostWidthRef = [ref]$HostWidth
							$HostHeightRef = [ref]$HostHeight
							$quitResult = Show-QuitConfirmationDialog -hostWidthRef $HostWidthRef -hostHeightRef $HostHeightRef
							$HostWidth = $HostWidthRef.Value
							$HostHeight = $HostHeightRef.Value
							if ($quitResult.NeedsRedraw) {
								if ($_isViewerMode) { try { Send-PipeMessage -Writer $_viewerPipeWriter -Message @{ type = 'viewerState'; activeDialog = $null } } catch {} }
								Reset-PostDialogState -SkipUpdateRef ([ref]$SkipUpdate) -ForceRedrawRef ([ref]$forceRedraw) -OldWindowSizeRef ([ref]$oldWindowSize) -OldBufferSizeRef ([ref]$OldBufferSize)
								break
							}
							if ($quitResult.Result -eq $true) {
								if ($_isViewerMode) { try { Send-PipeMessage -Writer $_viewerPipeWriter -Message @{ type = 'quit' } } catch {} }
								Clear-Host
								$runtime = (Get-Date) - $ScriptStartTime
								$hours = [math]::Floor($runtime.TotalHours)
								$minutes = $runtime.Minutes
								$seconds = $runtime.Seconds
								$runtimeStr = ""
								if ($hours -gt 0) {
									$runtimeStr = "$hours hour$(if ($hours -ne 1) { 's' }), $minutes minute$(if ($minutes -ne 1) { 's' })"
								} elseif ($minutes -gt 0) {
									$runtimeStr = "$minutes minute$(if ($minutes -ne 1) { 's' }), $seconds second$(if ($seconds -ne 1) { 's' })"
								} else {
									$runtimeStr = "$seconds second$(if ($seconds -ne 1) { 's' })"
								}
								Write-Host ""
								$mouseEmoji = [char]::ConvertFromUtf32(0x1F400)
								Write-Host "  mJig($mouseEmoji) " -NoNewline -ForegroundColor $script:HeaderAppName
								Write-Host "Stopped" -ForegroundColor $script:TextError
								Write-Host ""
								Write-Host "  Runtime: " -NoNewline -ForegroundColor $script:TextMuted
								Write-Host $runtimeStr -ForegroundColor $script:TextDefault
								Write-Host ""
							break process
						} else {
							if ($_isViewerMode) { try { Send-PipeMessage -Writer $_viewerPipeWriter -Message @{ type = 'viewerState'; activeDialog = $null } } catch {} }
							Reset-PostDialogState -SkipUpdateRef ([ref]$SkipUpdate) -ForceRedrawRef ([ref]$forceRedraw) -OldWindowSizeRef ([ref]$oldWindowSize) -OldBufferSizeRef ([ref]$OldBufferSize)
							break
						}
					} elseif ($lastKeyPress -eq "q") {
							$lastKeyPress = $null
							$lastKeyInfo = $null
							
						if ($DebugMode) {
							Add-DebugLogEntry -LogArray $LogArray -Date $date -Message "Quit dialog opened" -ShortMessage "Quit opened"
						}
							if ($_isViewerMode) { try { Send-PipeMessage -Writer $_viewerPipeWriter -Message @{ type = 'viewerState'; activeDialog = 'quit' } } catch {} }
							$HostWidthRef = [ref]$HostWidth
							$HostHeightRef = [ref]$HostHeight
							$quitResult = Show-QuitConfirmationDialog -hostWidthRef $HostWidthRef -hostHeightRef $HostHeightRef
							$HostWidth = $HostWidthRef.Value
							$HostHeight = $HostHeightRef.Value
							if ($quitResult.NeedsRedraw) {
								if ($_isViewerMode) { try { Send-PipeMessage -Writer $_viewerPipeWriter -Message @{ type = 'viewerState'; activeDialog = $null } } catch {} }
								Reset-PostDialogState -SkipUpdateRef ([ref]$SkipUpdate) -ForceRedrawRef ([ref]$forceRedraw) -OldWindowSizeRef ([ref]$oldWindowSize) -OldBufferSizeRef ([ref]$OldBufferSize)
								break
							}
								if ($quitResult.Result -eq $true) {
									if ($_isViewerMode) { try { Send-PipeMessage -Writer $_viewerPipeWriter -Message @{ type = 'quit' } } catch {} }
								if ($DebugMode) {
									Add-DebugLogEntry -LogArray $LogArray -Date $date -Message "Quit confirmed"
								}
									Clear-Host
									$runtime = (Get-Date) - $ScriptStartTime
									$hours = [math]::Floor($runtime.TotalHours)
									$minutes = $runtime.Minutes
									$seconds = $runtime.Seconds
									$runtimeStr = ""
									if ($hours -gt 0) {
										$runtimeStr = "$hours hour$(if ($hours -ne 1) { 's' }), $minutes minute$(if ($minutes -ne 1) { 's' })"
									} elseif ($minutes -gt 0) {
										$runtimeStr = "$minutes minute$(if ($minutes -ne 1) { 's' }), $seconds second$(if ($seconds -ne 1) { 's' })"
									} else {
										$runtimeStr = "$seconds second$(if ($seconds -ne 1) { 's' })"
									}
									Write-Host ""
									$mouseEmoji = [char]::ConvertFromUtf32(0x1F400)
									Write-Host "  mJig(" -NoNewline -ForegroundColor $script:HeaderAppName
									$mouseEmojiX = $Host.UI.RawUI.CursorPosition.X
									$mouseEmojiY = $Host.UI.RawUI.CursorPosition.Y
									Write-Host $mouseEmoji -NoNewline -ForegroundColor $script:HeaderIcon
									[Console]::SetCursorPosition($mouseEmojiX + 2, $mouseEmojiY)
									Write-Host ") " -NoNewline -ForegroundColor $script:HeaderAppName
									Write-Host "Stopped" -ForegroundColor $script:TextError
									Write-Host ""
								Write-Host "  Runtime: " -NoNewline -ForegroundColor $script:TextMuted
								Write-Host $runtimeStr -ForegroundColor $script:TextDefault
									Write-Host ""
									break process
							} else {
							if ($DebugMode) {
								Add-DebugLogEntry -LogArray $LogArray -Date $date -Message "Quit canceled"
							}
								if ($_isViewerMode) { try { Send-PipeMessage -Writer $_viewerPipeWriter -Message @{ type = 'viewerState'; activeDialog = $null } } catch {} }
								Reset-PostDialogState -SkipUpdateRef ([ref]$SkipUpdate) -ForceRedrawRef ([ref]$forceRedraw) -OldWindowSizeRef ([ref]$oldWindowSize) -OldBufferSizeRef ([ref]$OldBufferSize)
								break
							}
				} elseif ($lastKeyPress -eq "i") {
					$oldOutput = $Output
					if ($Output -eq "hidden") {
						if ($null -ne $PreviousView) {
							$Output = $PreviousView
						} else {
							$Output = "min"
						}
						$PreviousView = $null
					} else {
					$PreviousView = $Output
					$Output = "hidden"
					$script:MenuItemsBounds.Clear()
					}
					$script:Output = $Output
				if ($_isViewerMode) { $_settingsEpoch++; try { Send-PipeMessage -Writer $_viewerPipeWriter -Message @{ type = 'output'; mode = $script:Output; epoch = $_settingsEpoch; previousView = $PreviousView; activeDialog = $null } } catch {} }
				if ($DebugMode) {
					Add-DebugLogEntry -LogArray $LogArray -Date $date -Message "Incognito toggle: $oldOutput $([char]0x2192) $Output" -ShortMessage "Incognito: $oldOutput $([char]0x2192) $Output"
					}
						Reset-PostDialogState -SkipUpdateRef ([ref]$SkipUpdate) -ForceRedrawRef ([ref]$forceRedraw)
						break
				} elseif ($lastKeyPress -eq "s") {
					$lastKeyPress = $null
					$lastKeyInfo  = $null
				if ($script:DiagEnabled -and $_isViewerMode) { "$(Get-Date -Format 'HH:mm:ss.fff') - VIEWER DIALOG OPEN type=settings pipeConnected=$($_viewerPipeClient.IsConnected)" | Out-File $script:IpcDiagFile -Append }
			if ($_isViewerMode) { try { Send-PipeMessage -Writer $_viewerPipeWriter -Message @{ type = 'viewerState'; activeDialog = 'settings' } } catch {} }
			$HostWidthRef  = [ref]$HostWidth;  $HostHeightRef = [ref]$HostHeight
			$endTimeIntRef = [ref]$endTimeInt; $endTimeStrRef = [ref]$endTimeStr
			$endRef        = [ref]$end;        $logArrayRef   = [ref]$LogArray
			$_stgPipeWriter = if ($_isViewerMode) { $_viewerPipeWriter } else { $null }
			$settingsResult = Show-SettingsDialog `
				-HostWidthRef $HostWidthRef -HostHeightRef $HostHeightRef `
				-EndTimeIntRef $endTimeIntRef -EndTimeStrRef $endTimeStrRef `
				-EndRef $endRef -LogArrayRef $logArrayRef `
				-ViewerPipeWriter $_stgPipeWriter
			if ($script:DiagEnabled -and $_isViewerMode) { "$(Get-Date -Format 'HH:mm:ss.fff') - VIEWER DIALOG CLOSED type=settings reopen=$($settingsResult.ReopenSettings) needsRedraw=$($settingsResult.NeedsRedraw) pipeConnected=$($_viewerPipeClient.IsConnected)" | Out-File $script:IpcDiagFile -Append }
			$HostWidth  = $HostWidthRef.Value;  $HostHeight = $HostHeightRef.Value
			$endTimeInt = $endTimeIntRef.Value; $endTimeStr = $endTimeStrRef.Value
			$end        = $endRef.Value;        $LogArray   = $logArrayRef.Value
			$Output    = $script:Output
			$DebugMode = $script:DebugMode
			if ($_isViewerMode) {
				$_settingsEpoch++
				try {
					if ($script:DiagEnabled) { "$(Get-Date -Format 'HH:mm:ss.fff') - VIEWER SENDING settings+endtime+output epoch=$_settingsEpoch to worker..." | Out-File $script:IpcDiagFile -Append }
					Send-PipeMessage -Writer $_viewerPipeWriter -Message @{
						type = 'settings'
						epoch = $_settingsEpoch
						intervalSeconds = $script:IntervalSeconds
						intervalVariance = $script:IntervalVariance
						moveSpeed = $script:MoveSpeed
						moveVariance = $script:MoveVariance
						travelDistance = $script:TravelDistance
						travelVariance = $script:TravelVariance
						autoResumeDelaySeconds = $script:AutoResumeDelaySeconds
					}
		Send-PipeMessage -Writer $_viewerPipeWriter -Message @{ type = 'endtime'; endTime = $endTimeInt; endVariance = $script:EndVariance }
		Send-PipeMessage -Writer $_viewerPipeWriter -Message @{ type = 'output'; mode = $script:Output; previousView = $PreviousView; activeDialog = $null }
		Send-PipeMessage -Writer $_viewerPipeWriter -Message @{ type = 'title'; windowTitle = $script:WindowTitle; titleEmoji = $script:TitleEmoji; titlePresetIndex = $script:TitlePresetIndex }
		if ($script:DiagEnabled) { "$(Get-Date -Format 'HH:mm:ss.fff') - VIEWER SEND COMPLETE (4 messages sent)" | Out-File $script:IpcDiagFile -Append }
				} catch {
					if ($script:DiagEnabled) { "$(Get-Date -Format 'HH:mm:ss.fff') - VIEWER SEND FAILED: $($_.Exception.Message)" | Out-File $script:IpcDiagFile -Append }
				}
			}
			if ($settingsResult.ReopenSettings) {
					# Sub-dialog was used — flag so the main loop reopens settings
					# after it has repainted the full screen cleanly.
					$script:PendingReopenSettings = $true
				}
				Reset-PostDialogState -SkipUpdateRef ([ref]$SkipUpdate) -ForceRedrawRef ([ref]$forceRedraw) -OldWindowSizeRef ([ref]$oldWindowSize) -OldBufferSizeRef ([ref]$OldBufferSize)
				break
					} elseif ($lastKeyPress -eq "m" -and $Output -ne "hidden") {
							if ($script:DiagEnabled -and $_isViewerMode) { "$(Get-Date -Format 'HH:mm:ss.fff') - VIEWER DIALOG OPEN type=movement pipeConnected=$($_viewerPipeClient.IsConnected)" | Out-File $script:IpcDiagFile -Append }
						if ($DebugMode) {
							Add-DebugLogEntry -LogArray $LogArray -Date $date -Message "Movement dialog opened" -ShortMessage "Movement opened"
						}
								
								$HostWidthRef = [ref]$HostWidth
								$HostHeightRef = [ref]$HostHeight
								$dialogResult = Show-MovementModifyDialog -CurrentIntervalSeconds $script:IntervalSeconds -CurrentIntervalVariance $script:IntervalVariance -CurrentMoveSpeed $script:MoveSpeed -CurrentMoveVariance $script:MoveVariance -CurrentTravelDistance $script:TravelDistance -CurrentTravelVariance $script:TravelVariance -CurrentAutoResumeDelaySeconds $script:AutoResumeDelaySeconds -hostWidthRef $HostWidthRef -hostHeightRef $HostHeightRef
								$HostWidth = $HostWidthRef.Value
								$HostHeight = $HostHeightRef.Value
								
							if ($DebugMode) {
								Add-DebugLogEntry -LogArray $LogArray -Date $date -Message "Movement dialog closed" -ShortMessage "Movement closed"
							}
								
								if ($dialogResult.NeedsRedraw) {
									Reset-PostDialogState -SkipUpdateRef ([ref]$SkipUpdate) -ForceRedrawRef ([ref]$forceRedraw) -OldWindowSizeRef ([ref]$oldWindowSize) -OldBufferSizeRef ([ref]$OldBufferSize)
									break
								}
								if ($null -ne $dialogResult.Result) {
									$oldIntervalSeconds = $script:IntervalSeconds
									$oldIntervalVariance = $script:IntervalVariance
									$oldMoveSpeed = $script:MoveSpeed
									$oldMoveVariance = $script:MoveVariance
									$oldTravelDistance = $script:TravelDistance
									$oldTravelVariance = $script:TravelVariance
									$oldAutoResumeDelaySeconds = $script:AutoResumeDelaySeconds
									$script:IntervalSeconds = $dialogResult.Result.IntervalSeconds
									$script:IntervalVariance = $dialogResult.Result.IntervalVariance
									$script:MoveSpeed = $dialogResult.Result.MoveSpeed
									$script:MoveVariance = $dialogResult.Result.MoveVariance
									$script:TravelDistance = $dialogResult.Result.TravelDistance
									$script:TravelVariance = $dialogResult.Result.TravelVariance
									$script:AutoResumeDelaySeconds = $dialogResult.Result.AutoResumeDelaySeconds
									$changeDetails = @()
									$arrowChar = [char]0x2192
									if ($oldIntervalSeconds -ne $script:IntervalSeconds) { $changeDetails += "Interval: $oldIntervalSeconds $arrowChar $($script:IntervalSeconds)" }
									if ($oldIntervalVariance -ne $script:IntervalVariance) { $changeDetails += "Interval ±: $oldIntervalVariance $arrowChar $($script:IntervalVariance)" }
									if ($oldMoveSpeed -ne $script:MoveSpeed) { $changeDetails += "Speed: $oldMoveSpeed $arrowChar $($script:MoveSpeed)" }
									if ($oldMoveVariance -ne $script:MoveVariance) { $changeDetails += "Speed ±: $oldMoveVariance $arrowChar $($script:MoveVariance)" }
									if ($oldTravelDistance -ne $script:TravelDistance) { $changeDetails += "Distance: $oldTravelDistance $arrowChar $($script:TravelDistance)" }
									if ($oldTravelVariance -ne $script:TravelVariance) { $changeDetails += "Distance ±: $oldTravelVariance $arrowChar $($script:TravelVariance)" }
									if ($oldAutoResumeDelaySeconds -ne $script:AutoResumeDelaySeconds) { $changeDetails += "Delay: $oldAutoResumeDelaySeconds $arrowChar $($script:AutoResumeDelaySeconds)" }
									if ($changeDetails.Count -gt 0) {
										$changeDate = Get-Date
										$changeMessage = " - Settings updated: " + ($changeDetails -join ", ")
										$changeShortMessage = " - Updated: " + ($changeDetails -join ", ")
										$changeLogComponents = @(
											@{priority = 1; text = $changeDate.ToString(); shortText = $changeDate.ToString("HH:mm:ss")},
											@{priority = 2; text = $changeMessage; shortText = $changeShortMessage}
										)
										$null = $LogArray.Add([PSCustomObject]@{logRow = $true; components = $changeLogComponents})
									}
									if ($_isViewerMode) {
										$_settingsEpoch++
										try {
											if ($script:DiagEnabled) { "$(Get-Date -Format 'HH:mm:ss.fff') - VIEWER SENDING settings after movement dialog epoch=$_settingsEpoch..." | Out-File $script:IpcDiagFile -Append }
											Send-PipeMessage -Writer $_viewerPipeWriter -Message @{
												type = 'settings'
												epoch = $_settingsEpoch
												intervalSeconds = $script:IntervalSeconds
												intervalVariance = $script:IntervalVariance
												moveSpeed = $script:MoveSpeed
												moveVariance = $script:MoveVariance
												travelDistance = $script:TravelDistance
												travelVariance = $script:TravelVariance
												autoResumeDelaySeconds = $script:AutoResumeDelaySeconds
											}
											if ($script:DiagEnabled) { "$(Get-Date -Format 'HH:mm:ss.fff') - VIEWER SEND COMPLETE (movement settings)" | Out-File $script:IpcDiagFile -Append }
										} catch {
											if ($script:DiagEnabled) { "$(Get-Date -Format 'HH:mm:ss.fff') - VIEWER SEND FAILED (movement): $($_.Exception.Message)" | Out-File $script:IpcDiagFile -Append }
										}
									}
								}
								if ($script:DiagEnabled -and $_isViewerMode) { "$(Get-Date -Format 'HH:mm:ss.fff') - VIEWER DIALOG CLOSED type=movement" | Out-File $script:IpcDiagFile -Append }
								Reset-PostDialogState -SkipUpdateRef ([ref]$SkipUpdate) -ForceRedrawRef ([ref]$forceRedraw) -OldWindowSizeRef ([ref]$oldWindowSize) -OldBufferSizeRef ([ref]$OldBufferSize)
								break
							} elseif ($lastKeyPress -eq "e") {
								if ($script:DiagEnabled -and $_isViewerMode) { "$(Get-Date -Format 'HH:mm:ss.fff') - VIEWER DIALOG OPEN type=time pipeConnected=$($_viewerPipeClient.IsConnected)" | Out-File $script:IpcDiagFile -Append }
							if ($DebugMode) {
								Add-DebugLogEntry -LogArray $LogArray -Date $date -Message "Time dialog opened" -ShortMessage "Time opened"
							}
								
								$HostWidthRef = [ref]$HostWidth
								$HostHeightRef = [ref]$HostHeight
								$dialogResult = Show-TimeChangeDialog -CurrentEndTime $endTimeInt -hostWidthRef $HostWidthRef -hostHeightRef $HostHeightRef
								$HostWidth = $HostWidthRef.Value
								$HostHeight = $HostHeightRef.Value
								
							if ($DebugMode) {
								Add-DebugLogEntry -LogArray $LogArray -Date $date -Message "Time dialog closed" -ShortMessage "Time closed"
							}
								
								if ($dialogResult.NeedsRedraw) {
									Reset-PostDialogState -SkipUpdateRef ([ref]$SkipUpdate) -ForceRedrawRef ([ref]$forceRedraw) -OldWindowSizeRef ([ref]$oldWindowSize) -OldBufferSizeRef ([ref]$OldBufferSize)
									break
								}
								if ($null -ne $dialogResult.Result) {
									$oldEndTimeInt = $endTimeInt
									$oldEndTimeStr = $endTimeStr
									if ($dialogResult.Result -eq -1) {
										$endTimeInt = -1
										$endTimeStr = ""
										$end = ""
										$changeDate = Get-Date
										$changeMessage = if ([string]::IsNullOrEmpty($oldEndTimeStr)) {" - End time cleared"} else {" - End time cleared (was: $oldEndTimeStr)"}
										$changeShortMessage = " - End time cleared"
										$changeLogComponents = @(
											@{priority = 1; text = $changeDate.ToString(); shortText = $changeDate.ToString("HH:mm:ss")},
											@{priority = 2; text = $changeMessage; shortText = $changeShortMessage}
										)
										$null = $LogArray.Add([PSCustomObject]@{logRow = $true; components = $changeLogComponents})
									} else {
										$endTimeInt = $dialogResult.Result
										$endTimeStr = $endTimeInt.ToString().PadLeft(4, '0')
										$currentTime = Get-Date -Format "HHmm"
										$isTomorrow = $endTimeInt -le [int]$currentTime
										if ($isTomorrow) {
										$tomorrow = (Get-Date).AddDays(1)
										$endDate = Get-Date $tomorrow -Format "MMdd"
										} else {
											$endDate = Get-Date -Format "MMdd"
										}
										$end = "$endDate$endTimeStr"
										$changeDate = Get-Date
										$arrowChar = [char]0x2192
										$dayLabel = if ($isTomorrow) { " (next day)" } else { " (same day)" }
										$endDateDisplay = $endDate.Substring(0,2) + "/" + $endDate.Substring(2,2)
										$endTimeDisplay = $endTimeStr.Substring(0,2) + ":" + $endTimeStr.Substring(2,2)
										$changeMessage = if ($oldEndTimeInt -eq -1 -or [string]::IsNullOrEmpty($oldEndTimeStr)) {" - End time set: $endDateDisplay $endTimeDisplay$dayLabel"} else {" - End time changed: $oldEndTimeStr $arrowChar $endDateDisplay $endTimeDisplay$dayLabel"}
										$changeShortMessage = " - End time: $endDateDisplay $endTimeDisplay"
										$changeLogComponents = @(
											@{priority = 1; text = $changeDate.ToString(); shortText = $changeDate.ToString("HH:mm:ss")},
											@{priority = 2; text = $changeMessage; shortText = $changeShortMessage}
										)
										$null = $LogArray.Add([PSCustomObject]@{logRow = $true; components = $changeLogComponents})
									}
									if ($_isViewerMode) {
										$_settingsEpoch++
										try {
											if ($script:DiagEnabled) { "$(Get-Date -Format 'HH:mm:ss.fff') - VIEWER SENDING endtime after time dialog epoch=$_settingsEpoch..." | Out-File $script:IpcDiagFile -Append }
											Send-PipeMessage -Writer $_viewerPipeWriter -Message @{ type = 'endtime'; endTime = $endTimeInt; endVariance = $script:EndVariance; epoch = $_settingsEpoch }
											if ($script:DiagEnabled) { "$(Get-Date -Format 'HH:mm:ss.fff') - VIEWER SEND COMPLETE (endtime)" | Out-File $script:IpcDiagFile -Append }
										} catch {
											if ($script:DiagEnabled) { "$(Get-Date -Format 'HH:mm:ss.fff') - VIEWER SEND FAILED (endtime): $($_.Exception.Message)" | Out-File $script:IpcDiagFile -Append }
										}
									}
								}
							if ($script:DiagEnabled -and $_isViewerMode) { "$(Get-Date -Format 'HH:mm:ss.fff') - VIEWER DIALOG CLOSED type=time" | Out-File $script:IpcDiagFile -Append }
							Reset-PostDialogState -SkipUpdateRef ([ref]$SkipUpdate) -ForceRedrawRef ([ref]$forceRedraw) -OldWindowSizeRef ([ref]$oldWindowSize) -OldBufferSizeRef ([ref]$OldBufferSize)
							break
			} elseif (($lastKeyPress -eq "?" -or $lastKeyPress -eq "/") -and $Output -ne "hidden") {
				$lastKeyPress = $null
				$lastKeyInfo  = $null
				if ($_isViewerMode) { try { Send-PipeMessage -Writer $_viewerPipeWriter -Message @{ type = 'viewerState'; activeDialog = 'info' } } catch {} }
				$HostWidthRef  = [ref]$HostWidth
				$HostHeightRef = [ref]$HostHeight
				$null = Show-InfoDialog -hostWidthRef $HostWidthRef -hostHeightRef $HostHeightRef
				$HostWidth  = $HostWidthRef.Value
				$HostHeight = $HostHeightRef.Value
				if ($_isViewerMode) { try { Send-PipeMessage -Writer $_viewerPipeWriter -Message @{ type = 'viewerState'; activeDialog = $null } } catch {} }
				Reset-PostDialogState -SkipUpdateRef ([ref]$SkipUpdate) -ForceRedrawRef ([ref]$forceRedraw) -OldWindowSizeRef ([ref]$oldWindowSize) -OldBufferSizeRef ([ref]$OldBufferSize)
				break
			} elseif ($lastKeyPress -eq "t" -and $Output -ne "hidden") {
				$lastKeyPress = $null
				$lastKeyInfo  = $null
				$HostWidthRef  = [ref]$HostWidth
				$HostHeightRef = [ref]$HostHeight
			$_themeDialogResult = Show-ThemeDialog -HostWidthRef $HostWidthRef -HostHeightRef $HostHeightRef -ViewerPipeWriter $(if ($_isViewerMode) { $_viewerPipeWriter } else { $null })
			$HostWidth  = $HostWidthRef.Value
			$HostHeight = $HostHeightRef.Value
			if ($null -ne $_themeDialogResult -and $_themeDialogResult.NeedsRedraw) { $SkipUpdate = $false }
			Reset-PostDialogState -SkipUpdateRef ([ref]$SkipUpdate) -ForceRedrawRef ([ref]$forceRedraw) -OldWindowSizeRef ([ref]$oldWindowSize) -OldBufferSizeRef ([ref]$OldBufferSize)
				break
			}
			}
				
				# Check for window size / text zoom changes (both normal and hidden mode)
				# Only check every 200ms (every 4th iteration) to avoid blocking Windows mouse messages
				if ($tickIndex % 4 -eq 0) {
					$pshost = Get-Host
					$pswindow = $pshost.UI.RawUI
					$newWindowSize = $pswindow.WindowSize
					$newBufferSize = $pswindow.BufferSize

					if ($Output -ne "hidden") {
						# Normal mode: text zoom detection + vertical buffer sync
						$horizontalBufferChanged = ($null -ne $OldBufferSize -and $newBufferSize.Width -ne $OldBufferSize.Width)
						$windowWidthUnchanged = ($null -ne $oldWindowSize -and $newWindowSize.Width -eq $oldWindowSize.Width)

						if ($newBufferSize.Height -ne $newWindowSize.Height) {
							try {
								$pswindow.BufferSize = New-Object System.Management.Automation.Host.Size($newBufferSize.Width, $newWindowSize.Height)
								$newBufferSize = $pswindow.BufferSize
							} catch {}
						}

						if ($horizontalBufferChanged -and $windowWidthUnchanged -and $null -ne $OldBufferSize) {
							$OldBufferSize = $newBufferSize
							$HostWidth     = $newBufferSize.Width
							$HostHeight    = $newWindowSize.Height
							$SkipUpdate    = $true
							$forceRedraw   = $true
							$waitExecuted  = $false
							break
						}
					}

					# Window resize detection (both modes)
					$windowSizeChanged = ($null -eq $oldWindowSize -or
						$newWindowSize.Width -ne $oldWindowSize.Width -or
						$newWindowSize.Height -ne $oldWindowSize.Height)

					if ($windowSizeChanged) {
						$stableSize = Invoke-ResizeHandler
						$currentBufferSize = $pswindow.BufferSize
						try {
							$pswindow.BufferSize = New-Object System.Management.Automation.Host.Size($currentBufferSize.Width, $stableSize.Height)
						} catch {}
						$OldBufferSize       = $pswindow.BufferSize
						$oldWindowSize       = $stableSize
						$HostWidth           = $stableSize.Width
						$HostHeight          = $stableSize.Height
						$SkipUpdate          = $true
						$forceRedraw         = $true
						$waitExecuted        = $false
						break
					}
				}
				
				Start-Sleep -Milliseconds 50
				
			# Check if we've waited long enough
			if ($tickIndex -ge $ticksToWait) {
					break
				}
			} # end :waitLoop
			}
			
			# Keyboard and mouse input checking is now done every 200ms in the wait loop above
			# This provides more reliable detection compared to checking once per interval
			
		if (-not $_isViewerMode) {
			# Safety net: detect user input via GetLastInputInfo after wait loop.
			# Same inference as wait-loop: unclassified activity -> mouse movement.
		try {
			if ($script:MouseAPI::GetLastInputInfo([ref]$lii)) {
					$tickNow = [uint64]$script:MouseAPI::GetTickCount64()
					$lastInputTick = [uint64]$lii.dwTime
					$systemIdleMs = $tickNow - $lastInputTick
					$recentSimulated = ($null -ne $LastSimulatedKeyPress) -and ((Get-TimeSinceMs -StartTime $LastSimulatedKeyPress) -lt 500)
					$recentAutoMove = ($null -ne $LastAutomatedMouseMovement) -and ((Get-TimeSinceMs -StartTime $LastAutomatedMouseMovement) -lt 500)

					if ($systemIdleMs -lt 300 -and -not $recentSimulated -and -not $recentAutoMove) {
						$script:userInputDetected = $true
						if ($script:AutoResumeDelaySeconds -gt 0) {
							$LastUserInputTime = Get-Date
						}
						if (-not $keyboardInputDetected -and -not $scrollDetectedInInterval -and -not $mouseInputDetected) {
							$mouseInputDetected = $true
							$script:LastMouseMovementTime = Get-Date
						$null = $intervalMouseInputs.Add("Mouse")
					}
				}
			}
		} catch {
			# GetLastInputInfo not available, skip
		}
		} # end if (-not $_isViewerMode) — safety net
			
			# Check for window size changes outside the wait loop (catches resizes that happen during rendering)
		if (-not $forceRedraw) {
			$pshost     = Get-Host
			$pswindow   = $pshost.UI.RawUI
			$newWindowSize = $pswindow.WindowSize
			$newBufferSize = $pswindow.BufferSize

			# Ensure vertical buffer matches window height
			if ($newBufferSize.Height -ne $newWindowSize.Height) {
				try {
					$pswindow.BufferSize = New-Object System.Management.Automation.Host.Size($newBufferSize.Width, $newWindowSize.Height)
					$newBufferSize = $pswindow.BufferSize
				} catch {}
			}

			# Detect text zoom: horizontal buffer changed but window width did not
			$horizontalBufferChanged = ($null -ne $OldBufferSize -and $newBufferSize.Width -ne $OldBufferSize.Width)
			$windowWidthUnchanged    = ($null -ne $oldWindowSize -and $newWindowSize.Width -eq $oldWindowSize.Width)

			if ($horizontalBufferChanged -and $windowWidthUnchanged -and $null -ne $OldBufferSize) {
				$OldBufferSize = $newBufferSize
				$HostWidth     = $newBufferSize.Width
				$HostHeight    = $newWindowSize.Height
				$SkipUpdate    = $true
				$forceRedraw   = $true
			} elseif ($null -ne $oldWindowSize -and
					($newWindowSize.Width -ne $oldWindowSize.Width -or $newWindowSize.Height -ne $oldWindowSize.Height)) {
				# Unified handler — blocks until stable and LMB released
				$stableSize          = Invoke-ResizeHandler
				$currentBufferSize   = $pswindow.BufferSize
				try {
					$pswindow.BufferSize = New-Object System.Management.Automation.Host.Size($currentBufferSize.Width, $stableSize.Height)
				} catch {}
				$OldBufferSize       = $pswindow.BufferSize
				$oldWindowSize       = $stableSize
				$HostWidth           = $stableSize.Width
				$HostHeight          = $stableSize.Height
				$SkipUpdate          = $true
				$forceRedraw         = $true
			}
		}
			
			# Check if this is the first run (before we modify lastMovementTime)
			$isFirstRun = ($null -eq $LastMovementTime)
			
		if (-not $_isViewerMode) {
			# Wait for mouse to stop moving before proceeding
			# This prevents stutter by ensuring the mouse is settled before we do expensive operations
			# Only do this if we actually waited (not on first run or force redraw)
			if (-not $isFirstRun -and -not $forceRedraw) {
				$mouseSettleMs = 150  # Must be still for this long
				$lastSettleCheckPos = Get-MousePosition
				$mouseSettledTime = $null
				$settleLoopCount = 0
				$maxMoveDelta = 0
				
				if ($script:DiagEnabled) {
					"$(Get-Date -Format 'HH:mm:ss.fff') - Loop $($script:LoopIteration): Starting settle wait, pos: $($lastSettleCheckPos.X),$($lastSettleCheckPos.Y)" | Out-File $script:SettleDiagFile -Append
				}
				
				while ($true) {
					$settleLoopCount++
					Start-Sleep -Milliseconds 25
					$currentSettlePos = Get-MousePosition
					
					$mouseMoved = $false
					if ($null -ne $currentSettlePos -and $null -ne $lastSettleCheckPos) {
						$deltaX = [Math]::Abs($currentSettlePos.X - $lastSettleCheckPos.X)
						$deltaY = [Math]::Abs($currentSettlePos.Y - $lastSettleCheckPos.Y)
						$moveDelta = [Math]::Max($deltaX, $deltaY)
						if ($moveDelta -gt $maxMoveDelta) { $maxMoveDelta = $moveDelta }
						if ($deltaX -gt 2 -or $deltaY -gt 2) {
							$mouseMoved = $true
						}
					}
					$lastSettleCheckPos = $currentSettlePos
					
					if ($mouseMoved) {
						$mouseSettledTime = $null
					} else {
						if ($null -eq $mouseSettledTime) {
							$mouseSettledTime = Get-Date
						} elseif (((Get-Date) - $mouseSettledTime).TotalMilliseconds -ge $mouseSettleMs) {
							if ($script:DiagEnabled) {
								"$(Get-Date -Format 'HH:mm:ss.fff') - Loop $($script:LoopIteration): Settled after $settleLoopCount checks, max delta: $maxMoveDelta" | Out-File $script:SettleDiagFile -Append
							}
							break
						}
					}
				}
			}
			
			# Determine if we should skip the update based on user input or first run
			if ($script:userInputDetected) {
				$SkipUpdate = $true
			} elseif ($isFirstRun) {
				# Skip automated input on first run
				$SkipUpdate = $true
			} elseif (-not $forceRedraw) {
				# Only set skipUpdate to false if we are not forcing a redraw
				$SkipUpdate = $false
			}
		} # end if (-not $_isViewerMode) — mouse settle + skip determination
			
			# Prepare UI dimensions
			$oldRows = $Rows
			$bpV  = [math]::Max(1, $script:BorderPadV)
	# Visible log rows: total height minus 4 chrome rows minus 2*padding rows
	$Rows = [math]::Max(1, $HostHeight - 4 - 2 * $bpV)
			
		# Ensure $LogArray remains a List (dialogs may inadvertently coerce it to an array)
		if ($LogArray -isnot [System.Collections.Generic.List[object]]) {
			$newList = New-Object 'System.Collections.Generic.List[object]'
			if ($null -ne $LogArray) { foreach ($_e in $LogArray) { $newList.Add($_e) } }
			$LogArray = $newList
		}

		# Handle resize: adjust List size to match the new $Rows value
		if ($oldRows -ne $Rows) {
			if ($oldRows -lt $Rows) {
				# Window got taller — prepend blank entries at the front
				$insertCount = $Rows - $oldRows
				for ($i = 0; $i -lt $insertCount; $i++) {
					$LogArray.Insert(0, [PSCustomObject]@{ logRow = $true; components = @() })
				}
			} else {
				# Window got shorter — discard oldest entries from the front
				$trimCount = [math]::Min($oldRows - $Rows, $LogArray.Count)
				if ($trimCount -gt 0) { $LogArray.RemoveRange(0, $trimCount) }
			}
		}

		# First-run and safety: ensure List has exactly $Rows entries
		while ($LogArray.Count -lt $Rows) { $LogArray.Insert(0, [PSCustomObject]@{ logRow = $true; components = @() }) }
		while ($LogArray.Count -gt $Rows) { $LogArray.RemoveAt(0) }
			
		if (-not $_isViewerMode) {
			$currentPos = Get-MousePosition
			$PosUpdate = $false
			$x = 0
			$y = 0
			
		# Post-interval mouse position check (skipped if user input already detected or automated move was recent)
		$shouldCheckMouseAfterWait = $true
			if ($null -ne $LastAutomatedMouseMovement) {
				$timeSinceAutomatedMovement = Get-TimeSinceMs -StartTime $LastAutomatedMouseMovement
				if ($timeSinceAutomatedMovement -lt 300) {
					# Too soon after our automated movement - skip mouse detection
					$shouldCheckMouseAfterWait = $false
				}
			}
			
		if ($shouldCheckMouseAfterWait -and -not $script:userInputDetected -and $null -ne $mousePosAtStart -and $null -ne $currentPos) {
			$deltaX = [Math]::Abs($currentPos.X - $mousePosAtStart.X)
				$deltaY = [Math]::Abs($currentPos.Y - $mousePosAtStart.Y)
				$movementThreshold = 3  # Only detect movement if it is more than 3 pixels
				
				if ($deltaX -gt $movementThreshold -or $deltaY -gt $movementThreshold) {
					# Check if this movement is from our automated movement
					$isAutomatedPos = ($null -ne $automatedMovementPos -and 
									   $null -ne $currentPos -and
									   $currentPos.X -eq $automatedMovementPos.X -and 
									   $currentPos.Y -eq $automatedMovementPos.Y)
					if (-not $isAutomatedPos) {
						# User moved mouse during interval - skip automated movement
						$SkipUpdate = $true
						$PosUpdate = $false
						$mouseInputDetected = $true
						# Reset auto-resume delay timer on user input
						if ($script:AutoResumeDelaySeconds -gt 0) {
							$LastUserInputTime = Get-Date
						}
					$null = $intervalMouseInputs.Add("Mouse")
					$LastPos = $currentPos
						$automatedMovementPos = $null  # Clear automated position since user moved
					}
					# If it matches our automated position, ignore it (it is from our movement)
				}
			}
			
			# Check if auto-resume delay timer is active (check before skipUpdate logic)
			$cooldownActive = $false
			$secondsRemaining = 0
			if ($script:AutoResumeDelaySeconds -gt 0) {
				if ($null -eq $LastUserInputTime) {
					# Timer has not started yet (no user input detected yet) - allow movement
					$cooldownActive = $false
				} else {
					$timeSinceInput = ((Get-Date) - $LastUserInputTime).TotalSeconds
					if ($timeSinceInput -lt $script:AutoResumeDelaySeconds) {
						$cooldownActive = $true
						$secondsRemaining = [Math]::Ceiling($script:AutoResumeDelaySeconds - $timeSinceInput)
					} else {
						# Timer expired - clear it
					if ($DebugMode -and $null -ne $LastUserInputTime) {
						Add-DebugLogEntry -LogArray $LogArray -Date $date -Message "Auto-resume delay expired, resuming" -ShortMessage "Resumed"
					}
						$LastUserInputTime = $null
						$cooldownActive = $false
					}
				}
			}
			
			if ($SkipUpdate -ne $true -and -not $script:ManualPause) {
				if ($cooldownActive) {
					# Timer is active - skip coordinate updates and simulated key presses
					$SkipUpdate = $true
					$PosUpdate = $false
					# Store cooldown state for log component building (do not log directly here)
				} else {
					# No user movement detected - perform automated movement
					# Get fresh position right before movement to avoid stutter
					$pos = Get-MousePosition
					if ($null -eq $pos) {
						# API call failed - use last known position
						$pos = $LastPos
					}
					$PosUpdate = $true
				
				# Calculate travel distance with variance
				$baseDistance = $script:TravelDistance
				# Use double variance directly (Get-Random supports doubles, -Maximum is exclusive so add small epsilon)
				$varianceAmount = Get-Random -Minimum 0.0 -Maximum ($script:TravelVariance + 0.0001)
				$rasDist = Get-Random -Maximum 2
				if ($rasDist -eq 0) {
					$distance = $baseDistance - $varianceAmount
				} else {
					$distance = $baseDistance + $varianceAmount
				}
				# Ensure minimum distance of 1 pixel
				if ($distance -lt 1) {
					$distance = 1
				}
				
			# Calculate random direction (angle in radians)
			$angle = Get-Random -Minimum 0 -Maximum ([Math]::PI * 2)
			
			# Calculate target coordinates based on distance and angle
			$x = [Math]::Round($pos.X + ($distance * [Math]::Cos($angle)))
			$y = [Math]::Round($pos.Y + ($distance * [Math]::Sin($angle)))
			
		$vScreen  = $script:_VirtualScreen
			$sLeft    = $vScreen.Left
			$sTop     = $vScreen.Top
			$sRight   = $vScreen.Right  - 1
			$sBottom  = $vScreen.Bottom - 1
			
			# Reflect off boundaries instead of clamping so the cursor naturally bounces
			# inward — no more rubbing along an edge across multiple consecutive moves.
			if ($x -lt $sLeft)   { $x = $sLeft   + ($sLeft   - $x) }
			if ($x -gt $sRight)  { $x = $sRight  - ($x - $sRight)  }
			if ($y -lt $sTop)    { $y = $sTop    + ($sTop    - $y)  }
			if ($y -gt $sBottom) { $y = $sBottom - ($y - $sBottom)  }
			# Final clamp handles the rare double-bounce edge case
			$x = [Math]::Max($sLeft, [Math]::Min($x, $sRight))
			$y = [Math]::Max($sTop,  [Math]::Min($y, $sBottom))
				
				# Calculate movement direction for arrow emoji
				try {
					$deltaX = $x - $pos.X
					$deltaY = $y - $pos.Y
					$directionArrow = Get-DirectionArrow -deltaX $deltaX -deltaY $deltaY -style "simple"
				} catch {
					# If arrow calculation fails, just use empty string
					$directionArrow = ""
				}
				
				# Calculate smooth movement path
				$movementPath = Get-SmoothMovementPath -startX $pos.X -startY $pos.Y -endX $x -endY $y -baseSpeedSeconds $script:MoveSpeed -varianceSeconds $script:MoveVariance
				$movementPoints = $movementPath.Points
				$LastMovementDurationMs = $movementPath.TotalTimeMs
				
		$moveResult = Invoke-CursorMovement -Points $movementPoints -FallbackX $x -FallbackY $y
		$movementAborted = $moveResult.Aborted
		if ($movementAborted) {
			$SkipUpdate = $true
			$script:userInputDetected = $true
			$mouseInputDetected = $true
			$null = $intervalMouseInputs.Add("Mouse")
			if ($script:AutoResumeDelaySeconds -gt 0) { $LastUserInputTime = Get-Date }
			$LastPos = $moveResult.ActualPosition
			$automatedMovementPos = $null
			if ($script:DiagEnabled) {
				"$(Get-Date -Format 'HH:mm:ss.fff') - Loop $($script:LoopIteration): Movement aborted at step $($moveResult.Step)/$($moveResult.TotalSteps) - user moved mouse (drift: $($moveResult.DriftX),$($moveResult.DriftY))" | Out-File $script:SettleDiagFile -Append
			}
		}
				
				if ($movementAborted) {
					$PosUpdate = $false
				} else {
					# Update last position using cached method for better performance
					$newPos = Get-MousePosition
					if ($null -ne $newPos) {
						$LastPos = $newPos
					}
					$automatedMovementPos = $LastPos
					$LastAutomatedMouseMovement = Get-Date
					
					# Send Right Alt key press (modifier key - will not type anything or interfere with apps)
					try {
						$vkCode = [byte]0xA5  # VK_RMENU (Right Alt)
						$script:KeyboardAPI::keybd_event($vkCode, [byte]0, [uint32]0, [int]0)  # Key down
						Start-Sleep -Milliseconds 10
						$script:KeyboardAPI::keybd_event($vkCode, [byte]0, [uint32]0x0002, [int]0)  # Key up (KEYEVENTF_KEYUP = 0x0002)
						$LastSimulatedKeyPress = Get-Date
						Start-Sleep -Milliseconds 50
						# Flush any simulated key events from the console input buffer
						try {
							$hStdIn = $script:MouseAPI::GetStdHandle(-10)
							$flushBuf = New-Object "$($script:_ApiNamespace).INPUT_RECORD[]" 32
							$flushCount = [uint32]0
							if ($script:MouseAPI::PeekConsoleInput($hStdIn, $flushBuf, 32, [ref]$flushCount) -and $flushCount -gt 0) {
								$script:MouseAPI::ReadConsoleInput($hStdIn, $flushBuf, $flushCount, [ref]$flushCount) | Out-Null
							}
						} catch { }
					} catch {
						# If keybd_event fails, continue without keyboard input
					}
				}
				
			if ($PosUpdate) {
				$LastMovementTime = Get-Date

				# Successful move — update cumulative stats
				$script:StatsMoveCount++
					$script:StatsTotalDistancePx  += $distance
					$script:StatsLastMoveDist      = $distance
					if ($distance -lt $script:StatsMinMoveDist) { $script:StatsMinMoveDist = $distance }
					if ($distance -gt $script:StatsMaxMoveDist) { $script:StatsMaxMoveDist = $distance }

					# Direction bucket (Atan2 uses screen coords: Y increases downward)
					if ($deltaX -ne 0 -or $deltaY -ne 0) {
						$_dirAngle = [Math]::Atan2($deltaY, $deltaX) * 180.0 / [Math]::PI
						if ($_dirAngle -lt 0) { $_dirAngle += 360.0 }
						$_dirSector = [int][Math]::Round($_dirAngle / 45.0) % 8
						$_dirKey = @('E','SE','S','SW','W','NW','N','NE')[$_dirSector]
						$script:StatsDirectionCounts[$_dirKey] += $distance
					}

					# Animation timing
					if ($LastMovementDurationMs -lt $script:StatsMinDurationMs) { $script:StatsMinDurationMs = $LastMovementDurationMs }
					if ($LastMovementDurationMs -gt $script:StatsMaxDurationMs) { $script:StatsMaxDurationMs = $LastMovementDurationMs }
					$script:StatsAvgDurationMs = if ($script:StatsMoveCount -le 1) { $LastMovementDurationMs } else { ($script:StatsAvgDurationMs * ($script:StatsMoveCount - 1) + $LastMovementDurationMs) / $script:StatsMoveCount }

					# Actual interval between consecutive moves
					if ($null -ne $script:StatsLastMoveTick) {
						$_actualSecs = ((Get-Date) - $script:StatsLastMoveTick).TotalSeconds
						$script:StatsAvgActualIntervalSecs = if ($script:StatsMoveCount -le 1) { $_actualSecs } else { ($script:StatsAvgActualIntervalSecs * ($script:StatsMoveCount - 1) + $_actualSecs) / $script:StatsMoveCount }
					}
					$script:StatsLastMoveTick = Get-Date

					# Move streak
					if ($script:StatsCurrentStreak -ge 0) { $script:StatsCurrentStreak++ } else { $script:StatsCurrentStreak = 1 }
					if ($script:StatsCurrentStreak -gt $script:StatsLongestStreak) { $script:StatsLongestStreak = $script:StatsCurrentStreak }

					# Clean streak (no user input this interval)
					$script:StatsCleanStreak++
					if ($script:StatsCleanStreak -gt $script:StatsLongestCleanStreak) { $script:StatsLongestCleanStreak = $script:StatsCleanStreak }

				# Capture curve params for last-movement diagram
				$script:StatsLastCurveParams = @{
					Distance      = $distance
					StartArcAmt   = $movementPath.StartArcAmt
					StartArcSign  = $movementPath.StartArcSign
					BodyCurveAmt  = $movementPath.BodyCurveAmt
					BodyCurveSign = $movementPath.BodyCurveSign
					BodyCurveType = $movementPath.BodyCurveType
				}
				$script:StatsCurveAnimPending = $true
				}
			}
		} else {
		# skipUpdate was set - just update tracking
		$PosUpdate = $false
		$LastPos = $currentPos

		# Skip stats (only on actual user-input detection; not on first run or manual pause)
		if (-not $isFirstRun -and -not $script:ManualPause) {
			$script:StatsSkipCount++
			if ($script:StatsCurrentStreak -le 0) { $script:StatsCurrentStreak-- } else { $script:StatsCurrentStreak = -1 }
			if ($keyboardInputDetected) { $script:StatsKbInterruptCount++ }
			if ($mouseInputDetected)    { $script:StatsMsInterruptCount++ }
			$script:StatsCleanStreak = 0
		}
		}
			
		$allInputs = @()
		$hasMouse = $false
		foreach ($mouseInput in $intervalMouseInputs) {
			if ($mouseInput -eq "Mouse") { if (-not $hasMouse) { $allInputs += "Mouse"; $hasMouse = $true } }
			else { $allInputs += $mouseInput }
		}
		if ($keyboardInputDetected) {
			if ($_keyboardInferred -and -not $_keyboardLocallyDetected) {
				if (-not $scrollDetectedInInterval) { $allInputs += "Keyboard/Other" }
			} else { $allInputs += "Keyboard" }
		}
			$script:PreviousIntervalKeys = $allInputs
			
			# Only create log entry when we complete a wait interval AND do something
			# Don't create log entries for window resize events or while manually paused
			$shouldCreateLogEntry = $false
			
			if ($script:ManualPause) {
				$shouldCreateLogEntry = $false
			} elseif ($forceRedraw -and -not $waitExecuted -and -not $PosUpdate) {
				# This is just a window resize redraw - skip log entry completely
				$shouldCreateLogEntry = $false
			} elseif ($PosUpdate) {
				# We did a movement - always log this
				$shouldCreateLogEntry = $true
			} elseif ($isFirstRun) {
				# First run - log this
				$shouldCreateLogEntry = $true
			} elseif ($waitExecuted -and -not $forceRedraw) {
				# We completed a wait interval (and it was not interrupted by resize) - log this
				$shouldCreateLogEntry = $true
			}
			
			if ($shouldCreateLogEntry) {
				# Build log entry components array (priority order: timestamp, message, coordinates, wait info, input detection)
				$logComponents = @()
				
				# Component 1: Timestamp (full format)
				$logComponents += @{
					priority = [int]1
					text = $date.ToString()
					shortText = $date.ToString("HH:mm:ss")
				}
				
				# Component 2: Main message
				if ($SkipUpdate -ne $true) {
					if ($PosUpdate) {
						# Get direction arrow if available
						$arrowText = if ($directionArrow) { " $directionArrow" } else { "" }
					$logComponents += @{
						priority = [int]2
						text = " - Mouse position set$arrowText"
						shortText = " - Position set$arrowText"
					}
					$logComponents += @{
						priority = [int]3
						text = " ($x, $y)"
						shortText = " ($x, $y)"
					}
					} else {
						$logComponents += @{
							priority = [int]2
							text = " - Input detected, skipping update"
							shortText = " - Input detected"
						}
					}
			} elseif ($isFirstRun) {
				$logComponents += @{
					priority = [int]2
					text = " - Initialized; activity simulation active"
					shortText = " - Started"
				}
				} elseif ($keyboardInputDetected -or $mouseInputDetected) {
					# User input was detected - show user input skip with KB/MS status
					$logComponents += @{
						priority = [int]2
						text = " - Skipped: user input detected"
						shortText = " - Skipped"
					}
				} elseif ($cooldownActive) {
					# Auto-resume delay is active (no user input detected) - show custom message
					$logComponents += @{
						priority = [int]2
						text = " - Cooldown active"
						shortText = " - Cooldown active"
					}
					# Add resume timer component
					$logComponents += @{
						priority = [int]4
						text = " [Resume: ${secondsRemaining}s]"
						shortText = " [R: ${secondsRemaining}s]"
					}
				} else {
					$logComponents += @{
						priority = [int]2
						text = " - Skipped: user input detected"
						shortText = " - Skipped"
					}
				}
				
				# Component 4: Wait interval info (only if not cooldown active or user input detected)
				if ($waitExecuted -and -not $cooldownActive) {
					$logComponents += @{
						priority = [int]4
						text = " [Interval:${interval}s]"
						shortText = " [Interval:${interval}s]"
					}
				} elseif (-not $isFirstRun -and -not $cooldownActive) {
					$logComponents += @{
						priority = [int]4
						text = " [First run]"
						shortText = " [First run]"
					}
				}
				
				# Component 5 & 6: Keyboard and Mouse detection (only when user input was detected, lowest priority - removed first)
				# These are the first to be removed when window gets narrow
				if ($SkipUpdate -eq $true -and -not $isFirstRun -and ($keyboardInputDetected -or $mouseInputDetected)) {
					# Keyboard detection status
					$kbStatus = if ($keyboardInputDetected) { "YES" } else { "NO" }
					$logComponents += @{
						priority = [int]5
						text = " [KB:$kbStatus]"
						shortText = " [K:" + $kbStatus.Substring(0,1) + "]"
					}
					
					# Mouse detection status
					$msStatus = if ($mouseInputDetected) { "YES" } else { "NO" }
					$logComponents += @{
						priority = [int]6
						text = " [MS:$msStatus]"
						shortText = " [M:" + $msStatus.Substring(0,1) + "]"
					}
				}
				
			# Shift the window: evict oldest entry, append new one at the end
			$LogArray.RemoveAt(0)
			$null = $LogArray.Add([PSCustomObject]@{ logRow = $true; components = $logComponents })
		}
		# List is maintained at exactly $Rows entries; no further trim/pad needed
		} # end if (-not $_isViewerMode) — post-wait movement + log building

	if ($_isViewerMode) {
		# Accumulate this iteration's detections into interval-level trackers
		foreach ($mouseInput in $intervalMouseInputs) { $null = $_viewerIntervalMouseTypes.Add($mouseInput) }
		if ($scrollDetectedInInterval) { $_viewerIntervalScrollDet  = $true }
		if ($keyboardInputDetected)    { $_viewerIntervalKbDetected = $true }
		if ($_keyboardInferred)        { $_viewerIntervalKbInferred = $true }
		if ($_keyboardLocallyDetected) { $_viewerIntervalKbLocal    = $true }

		# Flush accumulated inputs to PreviousIntervalKeys only at worker interval boundary,
		# preventing mid-interval flicker and the scroll->Keyboard/Other race condition.
		if ($_viewerWorkerIterChanged) {
			$_viAllInputs = @()
			$_viHasMouse  = $false
			foreach ($mouseInput in $_viewerIntervalMouseTypes) {
				if ($mouseInput -eq "Mouse") { if (-not $_viHasMouse) { $_viAllInputs += "Mouse"; $_viHasMouse = $true } }
				else { $_viAllInputs += $mouseInput }
			}
			if ($_viewerIntervalKbDetected) {
				# Only promote worker-inferred keyboard to "Keyboard/Other" when the terminal had
				# zero local activity this interval (no scroll, click, or mouse movement).
				# Any local evidence means the terminal was focused and PeekConsoleInput is
				# authoritative — the worker's GetLastInputInfo inference is noise in that case.
				$_viNoLocalActivity = (-not $_viewerIntervalKbLocal -and -not $_viewerIntervalScrollDet -and ($_viewerIntervalMouseTypes.Count -eq 0))
				if ($_viewerIntervalKbInferred -and $_viNoLocalActivity) {
					$_viAllInputs += "Keyboard/Other"
				} elseif (-not $_viewerIntervalKbInferred -or $_viewerIntervalKbLocal) {
					$_viAllInputs += "Keyboard"
				}
			}
		$script:PreviousIntervalKeys = $_viAllInputs
		$_rt = (Get-Date) - $ScriptStartTime
		$script:StatsRunningTimeStr = "$([int][math]::Floor($_rt.TotalHours))h $($_rt.Minutes.ToString('D2'))m $($_rt.Seconds.ToString('D2'))s"
		$_viewerIntervalMouseTypes.Clear()
			$_viewerIntervalKbDetected = $false
			$_viewerIntervalKbInferred = $false
			$_viewerIntervalKbLocal    = $false
			$_viewerIntervalScrollDet  = $false
			$_viewerWorkerIterChanged  = $false
		}
	}

	if ($script:DiagEnabled -and $_isViewerMode -and $script:LoopIteration -le 5) {
		"$(Get-Date -Format 'HH:mm:ss.fff') - VIEWER PRE-RENDER iter=$($script:LoopIteration) HostWidth=$HostWidth HostHeight=$HostHeight Rows=$Rows Output=$Output forceRedraw=$forceRedraw SkipUpdate=$SkipUpdate LogArray=$($LogArray.Count)" | Out-File $script:IpcDiagFile -Append
	}

		if ($forceRedraw) {
			Write-MainFrame -Force:$true -Date $date -NoFlush
			if ($script:PendingReopenSettings) {
				$script:PendingReopenSettings = $false
		if ($script:DiagEnabled -and $_isViewerMode) { "$(Get-Date -Format 'HH:mm:ss.fff') - VIEWER DIALOG REOPEN type=settings (PendingReopenSettings)" | Out-File $script:IpcDiagFile -Append }
		if ($_isViewerMode) { try { Send-PipeMessage -Writer $_viewerPipeWriter -Message @{ type = 'viewerState'; activeDialog = 'settings' } } catch {} }
		$HostWidthRef  = [ref]$HostWidth;  $HostHeightRef = [ref]$HostHeight
		$endTimeIntRef = [ref]$endTimeInt; $endTimeStrRef = [ref]$endTimeStr
		$endRef        = [ref]$end;        $logArrayRef   = [ref]$LogArray
		$_stgRestoreSub = $script:_PendingRestoreSubDialog; $script:_PendingRestoreSubDialog = $null
		$_stgPipeWriter = if ($_isViewerMode) { $_viewerPipeWriter } else { $null }
		$settingsResult = Show-SettingsDialog -HostWidthRef $HostWidthRef -HostHeightRef $HostHeightRef -EndTimeIntRef $endTimeIntRef -EndTimeStrRef $endTimeStrRef -EndRef $endRef -LogArrayRef $logArrayRef -SkipAnimation:$true -DeferFlush:$true -RestoreSubDialog $_stgRestoreSub -ViewerPipeWriter $_stgPipeWriter
				if ($script:DiagEnabled -and $_isViewerMode) { "$(Get-Date -Format 'HH:mm:ss.fff') - VIEWER DIALOG CLOSED type=settings (reopen) needsRedraw=$($settingsResult.NeedsRedraw) reopen=$($settingsResult.ReopenSettings)" | Out-File $script:IpcDiagFile -Append }
				$HostWidth  = $HostWidthRef.Value;  $HostHeight = $HostHeightRef.Value
				$endTimeInt = $endTimeIntRef.Value; $endTimeStr = $endTimeStrRef.Value
				$end        = $endRef.Value;        $LogArray   = $logArrayRef.Value
				$Output    = $script:Output
				$DebugMode = $script:DebugMode
				if ($_isViewerMode) {
					$_settingsEpoch++
					try {
						if ($script:DiagEnabled) { "$(Get-Date -Format 'HH:mm:ss.fff') - VIEWER SENDING settings+endtime+output (reopen path) epoch=$_settingsEpoch..." | Out-File $script:IpcDiagFile -Append }
						Send-PipeMessage -Writer $_viewerPipeWriter -Message @{
							type = 'settings'
							epoch = $_settingsEpoch
							intervalSeconds = $script:IntervalSeconds
							intervalVariance = $script:IntervalVariance
							moveSpeed = $script:MoveSpeed
							moveVariance = $script:MoveVariance
							travelDistance = $script:TravelDistance
							travelVariance = $script:TravelVariance
							autoResumeDelaySeconds = $script:AutoResumeDelaySeconds
						}
			Send-PipeMessage -Writer $_viewerPipeWriter -Message @{ type = 'endtime'; endTime = $endTimeInt; endVariance = $script:EndVariance }
			Send-PipeMessage -Writer $_viewerPipeWriter -Message @{ type = 'output'; mode = $script:Output; previousView = $PreviousView; activeDialog = $null }
			Send-PipeMessage -Writer $_viewerPipeWriter -Message @{ type = 'title'; windowTitle = $script:WindowTitle; titleEmoji = $script:TitleEmoji; titlePresetIndex = $script:TitlePresetIndex }
			if ($script:DiagEnabled) { "$(Get-Date -Format 'HH:mm:ss.fff') - VIEWER SEND COMPLETE (reopen path, 4 messages)" | Out-File $script:IpcDiagFile -Append }
					} catch {
						if ($script:DiagEnabled) { "$(Get-Date -Format 'HH:mm:ss.fff') - VIEWER SEND FAILED (reopen path): $($_.Exception.Message)" | Out-File $script:IpcDiagFile -Append }
					}
				}
				if ($settingsResult.ReopenSettings) {
					$script:PendingReopenSettings = $true
				}
				$SkipUpdate  = $true
				$oldWindowSize = (Get-Host).UI.RawUI.WindowSize
				$OldBufferSize = (Get-Host).UI.RawUI.BufferSize
				Write-MainFrame -Force:$true -Date $date -NoFlush
				Flush-Buffer -ClearFirst
			} elseif ($script:_PendingReopenQuit) {
				$script:_PendingReopenQuit = $false
				Flush-Buffer -ClearFirst
				if ($_isViewerMode) { try { Send-PipeMessage -Writer $_viewerPipeWriter -Message @{ type = 'viewerState'; activeDialog = 'quit' } } catch {} }
				$HostWidthRef = [ref]$HostWidth; $HostHeightRef = [ref]$HostHeight
				$quitResult = Show-QuitConfirmationDialog -hostWidthRef $HostWidthRef -hostHeightRef $HostHeightRef
				$HostWidth = $HostWidthRef.Value; $HostHeight = $HostHeightRef.Value
				if ($_isViewerMode -and $quitResult.Result -ne $true) { try { Send-PipeMessage -Writer $_viewerPipeWriter -Message @{ type = 'viewerState'; activeDialog = $null } } catch {} }
				if ($quitResult.NeedsRedraw) {
					Reset-PostDialogState -SkipUpdateRef ([ref]$SkipUpdate) -ForceRedrawRef ([ref]$forceRedraw) -OldWindowSizeRef ([ref]$oldWindowSize) -OldBufferSizeRef ([ref]$OldBufferSize)
					Write-MainFrame -Force:$true -Date $date -NoFlush
					Flush-Buffer -ClearFirst
				} elseif ($quitResult.Result -eq $true) {
					if ($_isViewerMode) { try { Send-PipeMessage -Writer $_viewerPipeWriter -Message @{ type = 'quit' } } catch {} }
					Clear-Host
					$runtime = (Get-Date) - $ScriptStartTime
					$hours = [math]::Floor($runtime.TotalHours); $minutes = $runtime.Minutes; $seconds = $runtime.Seconds
					$runtimeStr = if ($hours -gt 0) { "$hours hour$(if ($hours -ne 1) { 's' }), $minutes minute$(if ($minutes -ne 1) { 's' })" } elseif ($minutes -gt 0) { "$minutes minute$(if ($minutes -ne 1) { 's' }), $seconds second$(if ($seconds -ne 1) { 's' })" } else { "$seconds second$(if ($seconds -ne 1) { 's' })" }
					Write-Host ""; $mouseEmoji = [char]::ConvertFromUtf32(0x1F400)
					Write-Host "  mJig($mouseEmoji) " -NoNewline -ForegroundColor $script:HeaderAppName
					Write-Host "Stopped" -ForegroundColor $script:TextError
				Write-Host ""; Write-Host "  Runtime: " -NoNewline -ForegroundColor $script:TextMuted
				Write-Host $runtimeStr -ForegroundColor $script:TextDefault; Write-Host ""
					break process
				} else {
					Reset-PostDialogState -SkipUpdateRef ([ref]$SkipUpdate) -ForceRedrawRef ([ref]$forceRedraw) -OldWindowSizeRef ([ref]$oldWindowSize) -OldBufferSizeRef ([ref]$OldBufferSize)
				}
			} elseif ($script:_PendingReopenInfo) {
				$script:_PendingReopenInfo = $false
				Flush-Buffer -ClearFirst
				if ($_isViewerMode) { try { Send-PipeMessage -Writer $_viewerPipeWriter -Message @{ type = 'viewerState'; activeDialog = 'info' } } catch {} }
				$HostWidthRef = [ref]$HostWidth; $HostHeightRef = [ref]$HostHeight
				$null = Show-InfoDialog -hostWidthRef $HostWidthRef -hostHeightRef $HostHeightRef
				$HostWidth = $HostWidthRef.Value; $HostHeight = $HostHeightRef.Value
				if ($_isViewerMode) { try { Send-PipeMessage -Writer $_viewerPipeWriter -Message @{ type = 'viewerState'; activeDialog = $null } } catch {} }
				Reset-PostDialogState -SkipUpdateRef ([ref]$SkipUpdate) -ForceRedrawRef ([ref]$forceRedraw) -OldWindowSizeRef ([ref]$oldWindowSize) -OldBufferSizeRef ([ref]$OldBufferSize)
			} else {
				Flush-Buffer -ClearFirst
			}
	} else {
		if ($script:StatsCurveAnimPending) {
			$script:StatsCurveAnimPending = $false
			# Frame 0: full render with no dots — establishes static content and caches path metadata
			$date = Get-Date
			Write-MainFrame -Force -Date $date -NoFlush -CurveRevealFraction 0.0
			Flush-Buffer

			# Frames 1-N: partial re-render of only the diagram rows (fast — skips full frame rebuild)
			# Falls back to full render if terminal was resized during animation
			$_animFrames     = 15
			$_animMsPerFrame = [int](250 / $_animFrames)
			$_animMetaReady  = ($null -ne $script:_CurveAnimPtA -and $script:_CurveAnimDiagRows -gt 0)
			for ($_animF = 1; $_animF -le $_animFrames; $_animF++) {
				Start-Sleep -Milliseconds $_animMsPerFrame
				$_animFrac = [double]$_animF / $_animFrames
				$_sizeChanged = ($HostWidth -ne $script:_CurveAnimHostWidth -or $HostHeight -ne $script:_CurveAnimHostHeight)
				if (-not $_animMetaReady -or $_sizeChanged) {
					# Fall back to full render if metadata unavailable or window was resized
					$date = Get-Date
					Write-MainFrame -Force -Date $date -NoFlush -CurveRevealFraction $(if ($_animF -ge $_animFrames) { -1.0 } else { $_animFrac })
					Flush-Buffer
					continue
				}
				# Rebuild only the diagram rows for this fraction — all rows queued before flush
				$_aw = $script:_CurveAnimInnerW
				$_ac = $script:_CurveAnimCenterRow
				$_an = $script:_CurveAnimDiagRows
				$_aCanvas = [System.Collections.Generic.List[char[]]]::new()
				for ($_ar = 0; $_ar -lt $_an; $_ar++) {
					$_aRow = [char[]](' ' * $_aw)
					if ($_ar -eq $_ac) { for ($_acc = 0; $_acc -lt $_aw; $_acc++) { $_aRow[$_acc] = $script:BoxHorizontal } }
					$null = $_aCanvas.Add($_aRow)
				}
				for ($_asi = 0; $_asi -le $script:_CurveAnimNS; $_asi++) {
					if ($script:_CurveAnimPtA[$_asi] -gt $_animFrac) { continue }
					$_aCol = [int]($script:_CurveAnimPtA[$_asi] * ($_aw - 1))
					$_aCol = [math]::Max(0, [math]::Min($_aw - 1, $_aCol))
					$_aRO  = [int]($script:_CurveAnimPtL[$_asi] / $script:_CurveAnimMaxLat * $_ac)
					$_aPR  = [math]::Max(0, [math]::Min($_an - 1, $_ac - $_aRO))
					$_aCanvas[$_aPR][$_aCol] = [char]0x25CF
				}
			for ($_ar = 0; $_ar -lt $_an; $_ar++) {
				$_animRowY   = $script:_CurveAnimDiagramStartY + $_ar
				$_animRowChars = $_aCanvas[$_ar]
				$_animFirstOnRow = $true
				for ($_aci = 0; $_aci -lt $_animRowChars.Length; $_aci++) {
					$_aCh = $_animRowChars[$_aci]
					$_animX = if ($_animFirstOnRow) { $script:_CurveAnimBoxInnerX + $_aci } else { -1 }
					$_animY = if ($_animFirstOnRow) { $_animRowY } else { -1 }
					$_animFirstOnRow = $false
					if    ($_aCh -eq [char]0x25CF)          { Write-Buffer -X $_animX -Y $_animY -Text $_aCh -FG $script:StatsCurveDots }
					elseif($_aCh -eq $script:BoxHorizontal) { Write-Buffer -X $_animX -Y $_animY -Text $_aCh -FG $script:StatsCurveLine }
					else                                     { Write-Buffer -X $_animX -Y $_animY -Text " " }
				}
			}
				Flush-Buffer
			}
		} else {
			Write-MainFrame -Date $date
		}
	}

	if (-not $_isViewerMode) {
	# Check if end time reached (only if end time is set)
			# Compare full MMddHHmm values to handle overnight runs correctly
			$endTimeReached = $false
			if ($endTimeInt -ne -1 -and -not [string]::IsNullOrEmpty($end)) {
				try {
					$currentDateTimeInt = [int]($date.ToString("MMddHHmm"))
					$endDateTimeInt = [int]$end
					if ($currentDateTimeInt -ge $endDateTimeInt) {
						$endTimeReached = $true
					}
				} catch {
					# If comparison fails, do not stop the script
				}
			}
			if ($endTimeReached) {
				if ($Output -ne "hidden") {
					[Console]::SetCursorPosition(0, 0)
					Write-Host "       END TIME REACHED: " -NoNewline -ForegroundColor $script:TextError
					Write-Host "Stopping " -NoNewline
					Write-Host "mJig"
					Write-Host
				}
				break
			}
		} # end if (-not $_isViewerMode) — end-time check
		} # end main loop

	# Normal exit cleanup (only reached via break process — not on Ctrl+C)
	Remove-Notification

	if ($_isViewerMode) {
		if ($null -ne $_viewerPipeReader) { try { $_viewerPipeReader.Dispose() } catch {} }
		if ($null -ne $_viewerPipeWriter) { try { $_viewerPipeWriter.Dispose() } catch {} }
		if ($null -ne $_viewerPipeClient) { try { $_viewerPipeClient.Dispose() } catch {} }
	}

	if ($script:DiagEnabled) { Show-DiagnosticFiles }

	if ($null -ne $script:InstanceMutex) {
		try { $script:InstanceMutex.ReleaseMutex() } catch {}
		$script:InstanceMutex.Dispose()
		$script:InstanceMutex = $null
	}

	} finally {
		# Runs on ALL exits including Ctrl+C (PipelineStoppedException).
		# Dispose() on already-disposed objects is a safe no-op via try/catch.
		if ($_isViewerMode) {
			if ($null -ne $_viewerPipeReader) { try { $_viewerPipeReader.Dispose() } catch {} }
			if ($null -ne $_viewerPipeWriter) { try { $_viewerPipeWriter.Dispose() } catch {} }
			if ($null -ne $_viewerPipeClient) { try { $_viewerPipeClient.Dispose() } catch {} }
		}
		if ($null -ne $script:InstanceMutex) {
			try { $script:InstanceMutex.ReleaseMutex() } catch {}
			try { $script:InstanceMutex.Dispose() } catch {}
			$script:InstanceMutex = $null
		}
	}
}

Export-ModuleMember -Function 'Start-mJig'

