		function Get-SmoothMovementPath {
			param(
				[int]$startX,
				[int]$startY,
				[int]$endX,
				[int]$endY,
				[double]$baseSpeedSeconds,
				[double]$varianceSeconds
			)
			
			# Calculate distance
			$deltaX = $endX - $startX
			$deltaY = $endY - $startY
			$distance = [Math]::Sqrt($deltaX * $deltaX + $deltaY * $deltaY)
			
		# If distance is very small, return single point
		if ($distance -lt 1) {
			return @{
				Points        = @([PSCustomObject]@{ X = $endX; Y = $endY })
				TotalTimeMs   = 0
				Distance      = 0.0
				StartArcAmt   = 0.0
				StartArcSign  = 1
				BodyCurveAmt  = 0.0
				BodyCurveSign = 1
				BodyCurveType = -1
			}
		}
			
			# Calculate movement time with variance (in milliseconds)
			$baseSpeedMs = $baseSpeedSeconds * 1000
			$varianceMs = $varianceSeconds * 1000
			$varianceAmountMs = Get-Random -Minimum 0 -Maximum ($varianceMs + 1)
		$varianceSign = Get-Random -Maximum 2 -Minimum 0
		if ($varianceSign -eq 0) {
				$movementTimeMs = ($baseSpeedMs - $varianceAmountMs)
			} else {
				$movementTimeMs = ($baseSpeedMs + $varianceAmountMs)
			}
			
			# Ensure minimum movement time of 50ms
			if ($movementTimeMs -lt 50) {
				$movementTimeMs = 50
			}
			
	# One point per 5ms; easing controls point spacing (not sleep duration)
	$numPoints = [Math]::Max(2, [Math]::Ceiling($movementTimeMs / 5))
		$numPoints = [Math]::Min($numPoints, 2000)  # safety cap (~10 seconds at 5ms/step)
			
		# Perpendicular unit vector for arc offsets
		$perpendicularX = 0.0
		$perpendicularY = 0.0
		if ($distance -gt 0) {
			$perpendicularX = -$deltaY / $distance
			$perpendicularY =  $deltaX / $distance
		}

	# Start arc: [0, 0.3], 1-10% amplitude, ~50% probability — subtle natural departure curve
	$startArcAmount = 0.0
		$startArcSign   = 1
		if ((Get-Random -Minimum 0 -Maximum 100) -ge 50) {
			$startArcAmount = $distance * (Get-Random -Minimum 1 -Maximum 11) / 100  # 1-10%
			$startArcSign   = if ((Get-Random -Maximum 2) -eq 0) { 1 } else { -1 }
		}

	# Body curve: [0.3, 1], 3-10% amplitude, 60% probability, U or S shaped
	$bodyCurveAmount = 0.0
		$bodyCurveSign   = 1
		$bodyCurveType   = 0  # 0 = U-shape (half-sine), 1 = S-shape (full-sine)
		if ((Get-Random -Minimum 0 -Maximum 100) -ge 40) {  # 60% chance
			$bodyCurveAmount = $distance * (Get-Random -Minimum 3 -Maximum 11) / 100  # 3-10%
			$bodyCurveSign   = if ((Get-Random -Maximum 2) -eq 0) { 1 } else { -1 }
			$bodyCurveType   = Get-Random -Maximum 2  # 0 = U, 1 = S
		}

	# Generate points with acceleration/deceleration curve and optional path curve
	# Use ease-in-out-cubic: accelerates in first half, decelerates in second half
	$points = [object[]]::new($numPoints + 1)
	for ($i = 0; $i -le $numPoints; $i++) {
			# Normalized progress (0 to 1)
			$t = $i / $numPoints
			
			# Ease-in-out-cubic function: accelerates then decelerates
			# f(t) = t < 0.5 ? 4t3 : 1 - pow(-2t + 2, 3)/2
			if ($t -lt 0.5) {
				$easedT = 4 * $t * $t * $t
			} else {
				$easedT = 1 - [Math]::Pow(-2 * $t + 2, 3) / 2
			}
			
			# Calculate base position along straight path
			$baseX = $startX + $deltaX * $easedT
			$baseY = $startY + $deltaY * $easedT
			
			# Start arc: window [0, 0.3] -> peaks at t=0.15
			if ($startArcAmount -gt 0 -and $t -le 0.3) {
				$lateralOffset = $startArcSign * $startArcAmount * [Math]::Sin([Math]::PI * $t / 0.3)
				$baseX += $perpendicularX * $lateralOffset
				$baseY += $perpendicularY * $lateralOffset
			}

		# Body curve over [0.3,1]: U-shape=sin(pi*t)^2, S-shape=sin(2pi*t)*sin(pi*t) — zero derivative at both ends
		if ($bodyCurveAmount -gt 0 -and $t -ge 0.3) {
				$bodyT   = ($t - 0.3) / 0.7  # normalise to [0,1] over the body segment
				$sinBase = [Math]::Sin([Math]::PI * $bodyT)
				$bodyArc = if ($bodyCurveType -eq 0) {
					$bodyCurveAmount * $sinBase * $sinBase                            # U-shape
				} else {
					$bodyCurveAmount * [Math]::Sin(2 * [Math]::PI * $bodyT) * $sinBase  # S-shape
				}
				$baseX += $perpendicularX * $bodyCurveSign * $bodyArc
				$baseY += $perpendicularY * $bodyCurveSign * $bodyArc
			}
			
			# Round to integer pixel coordinates
			$x = [Math]::Round($baseX)
			$y = [Math]::Round($baseY)
			
		$points[$i] = [PSCustomObject]@{ X = $x; Y = $y }
	}
			
		return @{
			Points        = $points
			TotalTimeMs   = [Math]::Round($movementTimeMs)
			Distance      = $distance
			StartArcAmt   = $startArcAmount
			StartArcSign  = $startArcSign
			BodyCurveAmt  = $bodyCurveAmount
			BodyCurveSign = $bodyCurveSign
			BodyCurveType = $bodyCurveType
		}
		}
