	function Send-ResizeExitWakeKey {
		try {
			$vkCode = [byte]0xA5  # VK_RMENU (Right Alt)
			$script:KeyboardAPI::keybd_event($vkCode, [byte]0, [uint32]0, [int]0)        # key down
			Start-Sleep -Milliseconds 10
			$script:KeyboardAPI::keybd_event($vkCode, [byte]0, [uint32]0x0002, [int]0)   # key up
		} catch { }
	}
