		if ($DebugMode) {
			Write-Host "[DEBUG] Loading System.Windows.Forms assembly..." -ForegroundColor $script:TextHighlight
		}
		try {
			Add-Type -AssemblyName System.Windows.Forms
			if ($DebugMode) {
				Write-Host "  [OK] System.Windows.Forms loaded" -ForegroundColor $script:TextSuccess
			}
			# Cache screen bounds now that the assembly is loaded
			$script:ScreenWidth = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width
			$script:ScreenHeight = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height
			if ($DebugMode) {
				Write-Host "  [OK] Screen bounds cached: $($script:ScreenWidth) x $($script:ScreenHeight)" -ForegroundColor $script:TextSuccess
			}
		} catch {
			if ($DebugMode) {
				Write-Host "  [FAIL] Failed to load System.Windows.Forms: $($_.Exception.Message)" -ForegroundColor $script:TextError
			}
			throw  # Re-throw as this is critical
		}
		
		# Add Windows API for system-wide keyboard detection and key sending
		if ($DebugMode) {
			Write-Host "[DEBUG] Loading Windows API types..." -ForegroundColor $script:TextHighlight
		}
		# Check if types already exist and have the required methods
		$typesNeedReload = $false
		try {
			# Use a safer method to check if types exist without throwing errors
			$existingKeyboard = $null
			$existingMouse = $null
			
			# Try to get the types using Get-Type or by checking if they're loaded
			$allTypes = [System.AppDomain]::CurrentDomain.GetAssemblies() | ForEach-Object { $_.GetTypes() } | Where-Object { $_.Namespace -eq 'mJiggAPI' }
			
			foreach ($type in $allTypes) {
				if ($type.Name -eq 'Keyboard') { $existingKeyboard = $type }
				if ($type.Name -eq 'Mouse') { $existingMouse = $type }
			}
			
			if ($null -ne $existingMouse) {
				$hasGetCursorPos = $existingMouse.GetMethod("GetCursorPos") -ne $null
				$hasGetForegroundWindow = $existingMouse.GetMethod("GetForegroundWindow") -ne $null
				if (-not $hasGetCursorPos -or -not $hasGetForegroundWindow) {
					$typesNeedReload = $true
					if ($DebugMode) {
						Write-Host "  [WARN] Existing types found but missing required methods" -ForegroundColor $script:TextWarning
						Write-Host "  [WARN] Missing: GetCursorPos=$(-not $hasGetCursorPos), GetForegroundWindow=$(-not $hasGetForegroundWindow)" -ForegroundColor $script:TextWarning
						Write-Host "  [WARN] Attempting reload (may fail if types already exist - restart PowerShell if needed)" -ForegroundColor $script:TextWarning
					}
				} else {
					if ($DebugMode) {
						Write-Host "  [INFO] Types already loaded from previous run (with required methods)" -ForegroundColor Gray
					}
				}
			} else {
				# Types don't exist - need to load
				$typesNeedReload = $true
			}
		} catch {
			# Types don't exist or can't be accessed - need to load
			$typesNeedReload = $true
			if ($DebugMode) {
				Write-Host "  [INFO] Types not found, will load them: $($_.Exception.Message)" -ForegroundColor Gray
			}
		}
		
		# Only attempt to add types if they don't exist or are incomplete
		if ($typesNeedReload) {
			try {
				# Try to add the types - use ErrorAction Stop to catch failures
				$typeDefinition = @"
using System;
using System.Runtime.InteropServices;
namespace mJiggAPI {
	// Define POINT struct for P/Invoke (avoids dependency on System.Drawing.Primitives)
	[StructLayout(LayoutKind.Sequential)]
	public struct POINT {
		public int X;
		public int Y;
		
		public POINT(int x, int y) {
			X = x;
			Y = y;
		}
	}
	
	[StructLayout(LayoutKind.Sequential)]
	public struct CONSOLE_SCREEN_BUFFER_INFO {
		public COORD dwSize;
		public COORD dwCursorPosition;
		public short wAttributes;
		public SMALL_RECT srWindow;
		public COORD dwMaximumWindowSize;
	}
	
	[StructLayout(LayoutKind.Sequential)]
	public struct MOUSE_EVENT_RECORD {
		public COORD dwMousePosition;
		public uint dwButtonState;
		public uint dwControlKeyState;
		public uint dwEventFlags;
	}
	
	[StructLayout(LayoutKind.Sequential)]
	public struct KEY_EVENT_RECORD {
		public int bKeyDown;
		public ushort wRepeatCount;
		public ushort wVirtualKeyCode;
		public ushort wVirtualScanCode;
		public char UnicodeChar;
		public uint dwControlKeyState;
	}
	
	[StructLayout(LayoutKind.Explicit)]
	public struct INPUT_RECORD {
		[FieldOffset(0)]
		public ushort EventType;
		[FieldOffset(4)]
		public MOUSE_EVENT_RECORD MouseEvent;
		[FieldOffset(4)]
		public KEY_EVENT_RECORD KeyEvent;
	}
	
	[StructLayout(LayoutKind.Sequential)]
	public struct COORD {
		public short X;
		public short Y;
	}
	
	[StructLayout(LayoutKind.Sequential)]
	public struct SMALL_RECT {
		public short Left;
		public short Top;
		public short Right;
		public short Bottom;
	}
	
	[StructLayout(LayoutKind.Sequential)]
	public struct LASTINPUTINFO {
		public uint cbSize;
		public uint dwTime;
	}
	
	public class Keyboard {
		[DllImport("user32.dll", CharSet = CharSet.Auto, CallingConvention = CallingConvention.StdCall)]
		public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, int dwExtraInfo);
		
		public const uint KEYEVENTF_KEYUP = 0x0002;
		public const int VK_RMENU = 0xA5;  // Right Alt key (modifier, won't type anything)
		public const int VK_SHIFT = 0x10;
		public const int VK_M     = 0x4D;
		public const int VK_P     = 0x50;
		public const int VK_Q     = 0x51;
	}
	
	public class Mouse {
		[DllImport("user32.dll")]
		public static extern short GetAsyncKeyState(int vKey);
		
		[DllImport("user32.dll")]
		public static extern int GetSystemMetrics(int nIndex);
		
		[DllImport("user32.dll")]
		[return: MarshalAs(UnmanagedType.Bool)]
		public static extern bool GetCursorPos(out POINT lpPoint);
		
		[DllImport("kernel32.dll")]
		public static extern IntPtr GetConsoleWindow();
		
		[DllImport("kernel32.dll")]
		public static extern IntPtr GetStdHandle(int nStdHandle);
		
		[DllImport("user32.dll")]
		public static extern IntPtr GetForegroundWindow();
		
		[DllImport("user32.dll")]
		public static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);
		
		[DllImport("kernel32.dll")]
		public static extern ulong GetTickCount64();
		
		[DllImport("kernel32.dll")]
		public static extern bool GetConsoleScreenBufferInfo(IntPtr hConsoleOutput, out CONSOLE_SCREEN_BUFFER_INFO lpConsoleScreenBufferInfo);
		
		[DllImport("kernel32.dll", SetLastError = true)]
		public static extern bool ReadConsoleInput(IntPtr hConsoleInput, [Out] INPUT_RECORD[] lpBuffer, uint nLength, out uint lpNumberOfEventsRead);
		
		[DllImport("kernel32.dll", SetLastError = true)]
		[return: MarshalAs(UnmanagedType.Bool)]
		public static extern bool PeekConsoleInput(IntPtr hConsoleInput, [Out] INPUT_RECORD[] lpBuffer, uint nLength, out uint lpNumberOfEventsRead);
		
		[DllImport("kernel32.dll", SetLastError = true)]
		public static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);
		
		[DllImport("kernel32.dll", SetLastError = true)]
		public static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);
		
		// Window finding APIs
		[DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
		public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);
		
		[DllImport("user32.dll")]
		[return: MarshalAs(UnmanagedType.Bool)]
		public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
		
		public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
		
		[DllImport("user32.dll", SetLastError = true)]
		public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
		
		[DllImport("user32.dll", CharSet = CharSet.Auto)]
		public static extern int GetWindowText(IntPtr hWnd, System.Text.StringBuilder lpString, int nMaxCount);
		
		[DllImport("user32.dll", CharSet = CharSet.Auto)]
		public static extern int GetClassName(IntPtr hWnd, System.Text.StringBuilder lpClassName, int nMaxCount);
		
		// Static storage for EnumWindows callback
		private static IntPtr foundWindowHandle = IntPtr.Zero;
		private static int targetProcessId = 0;
		
		// Callback for EnumWindows to find window by process ID
		private static bool EnumWindowsCallback(IntPtr hWnd, IntPtr lParam) {
			if (hWnd == IntPtr.Zero) return true;
			
			try {
				uint windowProcessId = 0;
				GetWindowThreadProcessId(hWnd, out windowProcessId);
				if (windowProcessId == targetProcessId) {
					foundWindowHandle = hWnd;
					return false; // Stop enumeration
				}
			} catch { }
			return true; // Continue enumeration
		}
		
		// Public method to find window handle by process ID
		public static IntPtr FindWindowByProcessId(int processId) {
			foundWindowHandle = IntPtr.Zero;
			targetProcessId = processId;
			try {
				EnumWindows(new EnumWindowsProc(EnumWindowsCallback), IntPtr.Zero);
			} catch { }
			return foundWindowHandle;
		}
		
		// Static storage for title-based search
		private static IntPtr foundWindowHandleByTitle = IntPtr.Zero;
		private static string targetTitlePattern = string.Empty;
		private static int excludeProcessId = 0;
		
		// Callback for EnumWindows to find window by title pattern
		private static bool EnumWindowsCallbackByTitle(IntPtr hWnd, IntPtr lParam) {
			if (hWnd == IntPtr.Zero) return true;
			
			try {
				uint windowProcessId = 0;
				GetWindowThreadProcessId(hWnd, out windowProcessId);
				
				// Skip if this is the process we want to exclude
				if (excludeProcessId != 0 && windowProcessId == excludeProcessId) {
					return true;
				}
				
				// Get window title
				System.Text.StringBuilder sb = new System.Text.StringBuilder(256);
				int length = GetWindowText(hWnd, sb, sb.Capacity);
				string windowTitle = sb.ToString();
				
				// Check if title matches pattern (starts with pattern)
				if (!string.IsNullOrEmpty(windowTitle) && windowTitle.StartsWith(targetTitlePattern, System.StringComparison.OrdinalIgnoreCase)) {
					foundWindowHandleByTitle = hWnd;
					return false; // Stop enumeration
				}
			} catch { }
			return true; // Continue enumeration
		}
		
		// Public method to find window handle by title pattern (excluding a specific process ID)
		public static IntPtr FindWindowByTitlePattern(string titlePattern, int excludePid) {
			foundWindowHandleByTitle = IntPtr.Zero;
			targetTitlePattern = titlePattern ?? string.Empty;
			excludeProcessId = excludePid;
			try {
				EnumWindows(new EnumWindowsProc(EnumWindowsCallbackByTitle), IntPtr.Zero);
			} catch { }
			return foundWindowHandleByTitle;
		}
		
		// Mouse button virtual key codes
		public const int VK_LBUTTON = 0x01;
		public const int VK_RBUTTON = 0x02;
		public const int VK_MBUTTON = 0x04;
		public const int VK_XBUTTON1 = 0x05;
		public const int VK_XBUTTON2 = 0x06;
		
		// Console input event constants
		public const ushort MOUSE_EVENT = 2;
		public const uint MOUSE_LEFT_BUTTON_DOWN = 0x0001;
		public const uint MOUSE_LEFT_BUTTON_UP = 0x0002;
		public const uint DOUBLE_CLICK = 0x0002;
		
	}
}
"@
				
				# Add-Type with explicit error handling and assembly references
				# Note: We use our own POINT struct, so we don't need System.Drawing.dll
			$addTypeError = $null
			try {
				if ($DebugMode) {
					Write-Host "  [DEBUG] Attempting to add types..." -ForegroundColor $script:TextHighlight
				}
				$null = Add-Type -TypeDefinition $typeDefinition -ReferencedAssemblies @("System.dll") -ErrorAction Stop
					if ($DebugMode) {
						Write-Host "  [OK] Add-Type completed successfully" -ForegroundColor $script:TextSuccess
					}
				} catch {
					$addTypeError = $_
					# If Add-Type fails, it might be because types already exist
					# Check if the error is about duplicate types
					if ($_.Exception.Message -like "*already exists*" -or $_.Exception.Message -like "*duplicate*" -or $_.Exception.Message -like "*Cannot add type*") {
						if ($DebugMode) {
							Write-Host "  [INFO] Types may already exist: $($_.Exception.Message)" -ForegroundColor $script:TextWarning
						}
					} else {
						# Some other error occurred - log it
						if ($DebugMode) {
							Write-Host "  [WARN] Add-Type error: $($_.Exception.Message)" -ForegroundColor $script:TextWarning
							if ($_.Exception.InnerException) {
								Write-Host "  [WARN] Inner exception: $($_.Exception.InnerException.Message)" -ForegroundColor $script:TextWarning
							}
						}
						# Don't throw yet - we'll check if types exist anyway
					}
				}
				
				# Always verify types were loaded, regardless of Add-Type result
				# Try both reflection and direct type access
				$loadedKeyboard = $null
				$loadedMouse = $null
				
				# First try direct type access (most reliable)
				try {
					$testType = [mJiggAPI.Keyboard]
					$loadedKeyboard = $testType
				} catch {
					# Type not accessible directly, try reflection
				}
				
				try {
					$testType = [mJiggAPI.Mouse]
					$loadedMouse = $testType
				} catch {
					# Type not accessible directly, try reflection
				}
				
				# If direct access failed, try reflection
				if ($null -eq $loadedKeyboard -or $null -eq $loadedMouse) {
					try {
						$allTypes = [System.AppDomain]::CurrentDomain.GetAssemblies() | ForEach-Object { $_.GetTypes() } | Where-Object { $_.Namespace -eq 'mJiggAPI' }
						foreach ($type in $allTypes) {
							if ($type.Name -eq 'Keyboard' -and $null -eq $loadedKeyboard) { $loadedKeyboard = $type }
							if ($type.Name -eq 'Mouse' -and $null -eq $loadedMouse) { $loadedMouse = $type }
						}
					} catch {
						if ($DebugMode) {
							Write-Host "  [WARN] Error checking for loaded types: $($_.Exception.Message)" -ForegroundColor $script:TextWarning
						}
					}
				}
				
				# Check if we have both types
				if ($null -ne $loadedKeyboard -and $null -ne $loadedMouse) {
					if ($DebugMode) {
						Write-Host "  [OK] All types verified: Keyboard, Mouse" -ForegroundColor $script:TextSuccess
					}
				} else {
					# Types weren't loaded - check if they already exist from previous check
					if ($null -ne $existingKeyboard -and $null -ne $existingMouse) {
						if ($DebugMode) {
							Write-Host "  [INFO] Types already exist from previous run" -ForegroundColor Gray
						}
					} else {
						# Types don't exist and failed to load - try to find them anywhere
						if ($DebugMode) {
							Write-Host "  [DEBUG] Searching all assemblies for mJiggAPI types..." -ForegroundColor $script:TextHighlight
							try {
								$allAssemblies = [System.AppDomain]::CurrentDomain.GetAssemblies()
								foreach ($assembly in $allAssemblies) {
									try {
										$types = $assembly.GetTypes() | Where-Object { $_.Name -in @('Keyboard', 'Mouse') }
										if ($types) {
											Write-Host "    Found types in $($assembly.FullName): $($types | ForEach-Object { $_.FullName } | Join-String -Separator ', ')" -ForegroundColor Gray
										}
									} catch {
										# Some assemblies can't be inspected
									}
								}
							} catch {
								Write-Host "    Error searching assemblies: $($_.Exception.Message)" -ForegroundColor $script:TextWarning
							}
						}
						
						# Types don't exist and failed to load
						$missingTypes = @()
						if ($null -eq $loadedKeyboard) { $missingTypes += "Keyboard" }
						if ($null -eq $loadedMouse) { $missingTypes += "Mouse" }
						$errorMsg = "Failed to load required mJiggAPI types: $($missingTypes -join ', ')"
						if ($addTypeError) {
							$errorMsg += "`nAdd-Type error: $($addTypeError.Exception.Message)"
						}
						if ($DebugMode) {
							Write-Host "  [FAIL] $errorMsg" -ForegroundColor $script:TextError
						}
						throw $errorMsg
					}
				}
			} catch {
				# Final fallback - check if types exist anyway
				$finalKeyboard = $null
				$finalMouse = $null
				try {
					$allTypes = [System.AppDomain]::CurrentDomain.GetAssemblies() | ForEach-Object { $_.GetTypes() } | Where-Object { $_.Namespace -eq 'mJiggAPI' }
					foreach ($type in $allTypes) {
						if ($type.Name -eq 'Keyboard') { $finalKeyboard = $type }
						if ($type.Name -eq 'Mouse') { $finalMouse = $type }
					}
				} catch {
					# Ignore errors when checking for existing types
				}
				
				if ($null -ne $finalKeyboard -and $null -ne $finalMouse) {
					if ($DebugMode) {
						Write-Host "  [INFO] Types found after error recovery" -ForegroundColor Gray
					}
				} else {
					if ($DebugMode) {
						Write-Host "  [FAIL] Add-Type failed and types don't exist: $($_.Exception.Message)" -ForegroundColor $script:TextError
						Write-Host "  [INFO] This may require restarting PowerShell to reload types" -ForegroundColor $script:TextWarning
					}
					throw "Failed to load required mJiggAPI types: $($_.Exception.Message)"
				}
			}
		}
