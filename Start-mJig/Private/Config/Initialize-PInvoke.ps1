		if ($DebugMode) {
			Write-Host "[DEBUG] Loading System.Windows.Forms assembly..." -ForegroundColor $script:TextHighlight
		}
		try {
			Add-Type -AssemblyName System.Windows.Forms
			if ($DebugMode) {
				Write-Host "  [OK] System.Windows.Forms loaded" -ForegroundColor $script:TextSuccess
			}
			$script:ScreenWidth = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width
			$script:ScreenHeight = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height
			if ($DebugMode) {
				Write-Host "  [OK] Screen bounds cached: $($script:ScreenWidth) x $($script:ScreenHeight)" -ForegroundColor $script:TextSuccess
			}
		} catch {
			if ($DebugMode) {
				Write-Host "  [FAIL] Failed to load System.Windows.Forms: $($_.Exception.Message)" -ForegroundColor $script:TextError
			}
			throw
		}
		
		if ($DebugMode) {
			Write-Host "[DEBUG] Loading Windows API types..." -ForegroundColor $script:TextHighlight
		}

		# Generate a random namespace so no "mJig" string appears in loaded .NET types
		$script:_ApiNamespace = 'ns_' + -join ((0..7) | ForEach-Object { '{0:x2}' -f (Get-Random -Max 256) })

		$typeDefinition = @"
using System;
using System.IO;
using System.Globalization;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;
namespace mJiggAPI {
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
		public const int VK_RMENU = 0xA5;
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
		
		[DllImport("user32.dll")]
		[return: MarshalAs(UnmanagedType.Bool)]
		public static extern bool IsWindowVisible(IntPtr hWnd);
		
		private static IntPtr foundWindowHandle = IntPtr.Zero;
		private static int targetProcessId = 0;
		
		private static bool EnumWindowsCallback(IntPtr hWnd, IntPtr lParam) {
			if (hWnd == IntPtr.Zero) return true;
			try {
				uint windowProcessId = 0;
				GetWindowThreadProcessId(hWnd, out windowProcessId);
				if (windowProcessId == targetProcessId) {
					foundWindowHandle = hWnd;
					return false;
				}
			} catch { }
			return true;
		}
		
		public static IntPtr FindWindowByProcessId(int processId) {
			foundWindowHandle = IntPtr.Zero;
			targetProcessId = processId;
			try {
				EnumWindows(new EnumWindowsProc(EnumWindowsCallback), IntPtr.Zero);
			} catch { }
			return foundWindowHandle;
		}
		
		private static IntPtr foundWindowHandleByTitle = IntPtr.Zero;
		private static string targetTitlePattern = string.Empty;
		private static int excludeProcessId = 0;
		
		private static bool EnumWindowsCallbackByTitle(IntPtr hWnd, IntPtr lParam) {
			if (hWnd == IntPtr.Zero) return true;
			try {
				uint windowProcessId = 0;
				GetWindowThreadProcessId(hWnd, out windowProcessId);
				if (excludeProcessId != 0 && windowProcessId == excludeProcessId) {
					return true;
				}
				System.Text.StringBuilder sb = new System.Text.StringBuilder(256);
				int length = GetWindowText(hWnd, sb, sb.Capacity);
				string windowTitle = sb.ToString();
				if (!string.IsNullOrEmpty(windowTitle) && windowTitle.StartsWith(targetTitlePattern, System.StringComparison.OrdinalIgnoreCase)) {
					foundWindowHandleByTitle = hWnd;
					return false;
				}
			} catch { }
			return true;
		}
		
		public static IntPtr FindWindowByTitlePattern(string titlePattern, int excludePid) {
			foundWindowHandleByTitle = IntPtr.Zero;
			targetTitlePattern = titlePattern ?? string.Empty;
			excludeProcessId = excludePid;
			try {
				EnumWindows(new EnumWindowsProc(EnumWindowsCallbackByTitle), IntPtr.Zero);
			} catch { }
			return foundWindowHandleByTitle;
		}
		
		public const int VK_LBUTTON = 0x01;
		public const int VK_RBUTTON = 0x02;
		public const int VK_MBUTTON = 0x04;
		public const int VK_XBUTTON1 = 0x05;
		public const int VK_XBUTTON2 = 0x06;
		
		public const ushort MOUSE_EVENT = 2;
		public const uint MOUSE_LEFT_BUTTON_DOWN = 0x0001;
		public const uint MOUSE_LEFT_BUTTON_UP = 0x0002;
		public const uint DOUBLE_CLICK = 0x0002;
		
	}

	[ComImport, Guid("6CD0E74E-EE65-4489-9EBF-CA43E87BA637")]
	[InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
	public interface IXmlDocumentIO {
		void GetIids(out uint iidCount, out IntPtr iids);
		void GetRuntimeClassName(out IntPtr className);
		void GetTrustLevel(out int trustLevel);
		void LoadXml(IntPtr xml);
	}

	[ComImport, Guid("04124B20-82C6-4229-B109-FD9ED4662B53")]
	[InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
	public interface IToastNotificationFactory {
		void GetIids(out uint iidCount, out IntPtr iids);
		void GetRuntimeClassName(out IntPtr className);
		void GetTrustLevel(out int trustLevel);
		[return: MarshalAs(UnmanagedType.IUnknown)]
		object CreateToastNotification([MarshalAs(UnmanagedType.IUnknown)] object content);
	}

	[ComImport, Guid("50AC103F-D235-4598-BBEF-98FE4D1A3AD4")]
	[InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
	public interface IToastNotificationManagerStatics {
		void GetIids(out uint iidCount, out IntPtr iids);
		void GetRuntimeClassName(out IntPtr className);
		void GetTrustLevel(out int trustLevel);
		[return: MarshalAs(UnmanagedType.IUnknown)]
		object CreateToastNotifier();
		[return: MarshalAs(UnmanagedType.IUnknown)]
		object CreateToastNotifierWithId(IntPtr applicationId);
		[return: MarshalAs(UnmanagedType.IUnknown)]
		object GetTemplateContent(int type);
	}

	[ComImport, Guid("75927B93-03F3-41EC-91D3-6E5BAC1B38E7")]
	[InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
	public interface IToastNotifier {
		void GetIids(out uint iidCount, out IntPtr iids);
		void GetRuntimeClassName(out IntPtr className);
		void GetTrustLevel(out int trustLevel);
		void Show([MarshalAs(UnmanagedType.IUnknown)] object notification);
	}

	public static class Toast {
		[DllImport("combase.dll")]
		private static extern int WindowsCreateString(
			[MarshalAs(UnmanagedType.LPWStr)] string sourceString,
			int length, out IntPtr hstring);

		[DllImport("combase.dll")]
		private static extern int WindowsDeleteString(IntPtr hstring);

		[DllImport("combase.dll")]
		private static extern int RoActivateInstance(
			IntPtr activatableClassId, out IntPtr instance);

		[DllImport("combase.dll")]
		private static extern int RoGetActivationFactory(
			IntPtr activatableClassId, ref Guid iid, out IntPtr factory);

		private static IntPtr MakeHString(string s) {
			IntPtr h;
			Marshal.ThrowExceptionForHR(WindowsCreateString(s, s.Length, out h));
			return h;
		}

		public static void ShowToast(string xml, string appId) {
			IntPtr hClass = MakeHString("Windows.Data.Xml.Dom.XmlDocument");
			IntPtr instPtr;
			try { Marshal.ThrowExceptionForHR(RoActivateInstance(hClass, out instPtr)); }
			finally { WindowsDeleteString(hClass); }
			object xmlDoc = Marshal.GetObjectForIUnknown(instPtr);
			Marshal.Release(instPtr);

			IntPtr hXml = MakeHString(xml);
			try { ((IXmlDocumentIO)xmlDoc).LoadXml(hXml); }
			finally { WindowsDeleteString(hXml); }

			hClass = MakeHString("Windows.UI.Notifications.ToastNotification");
			Guid fGuid = new Guid("04124B20-82C6-4229-B109-FD9ED4662B53");
			IntPtr fPtr;
			try { Marshal.ThrowExceptionForHR(RoGetActivationFactory(hClass, ref fGuid, out fPtr)); }
			finally { WindowsDeleteString(hClass); }
			object factory = Marshal.GetObjectForIUnknown(fPtr);
			Marshal.Release(fPtr);
			object toast = ((IToastNotificationFactory)factory).CreateToastNotification(xmlDoc);

			hClass = MakeHString("Windows.UI.Notifications.ToastNotificationManager");
			Guid mGuid = new Guid("50AC103F-D235-4598-BBEF-98FE4D1A3AD4");
			IntPtr mPtr;
			try { Marshal.ThrowExceptionForHR(RoGetActivationFactory(hClass, ref mGuid, out mPtr)); }
			finally { WindowsDeleteString(hClass); }
			object manager = Marshal.GetObjectForIUnknown(mPtr);
			Marshal.Release(mPtr);

			IntPtr hAppId = MakeHString(appId);
			object notifier;
			try { notifier = ((IToastNotificationManagerStatics)manager).CreateToastNotifierWithId(hAppId); }
			finally { WindowsDeleteString(hAppId); }

			((IToastNotifier)notifier).Show(toast);
		}

		public static void RenderEmojiToPng(string emoji, string outputPath, int size) {
			var typeface = new Typeface("Segoe UI Emoji");
			double fontSize = size * 0.85;
			var text = new FormattedText(emoji, CultureInfo.InvariantCulture,
				FlowDirection.LeftToRight, typeface, fontSize, Brushes.Black, 96.0);

			var geo = text.BuildGeometry(new System.Windows.Point(0, 0));
			var bounds = geo.Bounds;
			if (bounds.IsEmpty) bounds = new Rect(0, 0, size, size);

			int w = Math.Max(1, (int)Math.Ceiling(bounds.Width));
			int h = Math.Max(1, (int)Math.Ceiling(bounds.Height));

			var visual = new DrawingVisual();
			using (var dc = visual.RenderOpen()) {
				dc.DrawText(text, new System.Windows.Point(-bounds.X, -bounds.Y));
			}
			var bmp = new RenderTargetBitmap(w, h, 96, 96, PixelFormats.Pbgra32);
			bmp.Render(visual);

			var encoder = new PngBitmapEncoder();
			encoder.Frames.Add(BitmapFrame.Create(bmp));
			using (var stream = File.Create(outputPath))
				encoder.Save(stream);
		}
	}
}
"@
		# Replace hardcoded namespace with randomized one
		$typeDefinition = $typeDefinition -replace 'mJiggAPI', $script:_ApiNamespace

		$addTypeError = $null
		try {
			if ($DebugMode) {
				Write-Host "  [DEBUG] Attempting to add types (namespace: $($script:_ApiNamespace))..." -ForegroundColor $script:TextHighlight
			}
			$_wpfRefs = @("System.dll")
			try {
				Add-Type -AssemblyName PresentationCore -ErrorAction Stop
				Add-Type -AssemblyName WindowsBase -ErrorAction Stop
				$_pcAsm = [AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GetName().Name -eq 'PresentationCore' } | Select-Object -First 1
				$_wbAsm = [AppDomain]::CurrentDomain.GetAssemblies() | Where-Object { $_.GetName().Name -eq 'WindowsBase' } | Select-Object -First 1
				if ($_pcAsm.Location -and $_wbAsm.Location) {
					$_wpfRefs = @("System.dll", $_pcAsm.Location, $_wbAsm.Location)
				}
			} catch {}
			$null = Add-Type -TypeDefinition $typeDefinition -ReferencedAssemblies $_wpfRefs -ErrorAction Stop
			if ($DebugMode) {
				Write-Host "  [OK] Add-Type completed successfully" -ForegroundColor $script:TextSuccess
			}
		} catch {
			$addTypeError = $_
			if ($DebugMode) {
				Write-Host "  [WARN] Add-Type error: $($_.Exception.Message)" -ForegroundColor $script:TextWarning
			}
		}

		# Store type references in script-scoped variables for use across the codebase
		$script:MouseAPI      = "$($script:_ApiNamespace).Mouse" -as [type]
		$script:KeyboardAPI   = "$($script:_ApiNamespace).Keyboard" -as [type]
		$script:ToastAPI      = "$($script:_ApiNamespace).Toast" -as [type]
		$script:PointType     = "$($script:_ApiNamespace).POINT"
		$script:LastInputType = "$($script:_ApiNamespace).LASTINPUTINFO"
		$script:InputRecordType = "$($script:_ApiNamespace).INPUT_RECORD"
		$script:CSBIType      = "$($script:_ApiNamespace).CONSOLE_SCREEN_BUFFER_INFO"

		if ($null -eq $script:MouseAPI -or $null -eq $script:KeyboardAPI) {
			$errorMsg = "Failed to load required API types in namespace $($script:_ApiNamespace)"
			if ($addTypeError) { $errorMsg += ": $($addTypeError.Exception.Message)" }
			if ($DebugMode) {
				Write-Host "  [FAIL] $errorMsg" -ForegroundColor $script:TextError
			}
			throw $errorMsg
		}
		if ($DebugMode) {
			Write-Host "  [OK] All types verified: Mouse, Keyboard, Toast (namespace: $($script:_ApiNamespace))" -ForegroundColor $script:TextSuccess
		}
