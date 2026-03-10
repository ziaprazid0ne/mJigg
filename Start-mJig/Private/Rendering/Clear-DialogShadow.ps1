		function Clear-DialogShadow {
			param(
				[int]$dialogX,
				[int]$dialogY,
				[int]$dialogWidth,
				[int]$dialogHeight
			)
			Draw-DialogShadow -dialogX $dialogX -dialogY $dialogY -dialogWidth $dialogWidth -dialogHeight $dialogHeight -Clear
		}
