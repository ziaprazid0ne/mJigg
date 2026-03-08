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
					Points = @([PSCustomObject]@{ X = $endX; Y = $endY })
					TotalTimeMs = 0
				}
			}
			
			# Calculate movement time with variance (in milliseconds)
			$baseSpeedMs = $baseSpeedSeconds * 1000
			$varianceMs = $varianceSeconds * 1000
			$varianceAmountMs = Get-Random -Minimum 0 -Maximum ($varianceMs + 1)
			$ras = Get-Random -Maximum 2 -Minimum 0
			if ($ras -eq 0) {
				$movementTimeMs = ($baseSpeedMs - $varianceAmountMs)
			} else {
				$movementTimeMs = ($baseSpeedMs + $varianceAmountMs)
			}
			
			# Ensure minimum movement time of 50ms
			if ($movementTimeMs -lt 50) {
				$movementTimeMs = 50
			}
			
		# Generate one point per 5ms of movement time so the execution loop can advance
		# at a constant 5ms interval. Acceleration/deceleration is expressed by point
		# spacing along the curve (easing places points close together when the virtual
		# speed is low, and far apart when it is high) rather than by varying the sleep
		# duration. Duplicate pixel coordinates are fine - the cursor simply dwells there
		# for one 5ms tick. t is always increasing so the cursor never moves backwards.
		$numPoints = [Math]::Max(2, [Math]::Ceiling($movementTimeMs / 5))
		$numPoints = [Math]::Min($numPoints, 2000)  # safety cap (~10 seconds at 5ms/step)
			
		# Perpendicular unit vector (left of travel direction) used for lateral arc offsets
		$perpendicularX = 0.0
		$perpendicularY = 0.0
		if ($distance -gt 0) {
			$perpendicularX = -$deltaY / $distance
			$perpendicularY =  $deltaX / $distance
		}

		# Start arc — window [0, 0.3], peaks at t=0.15: curve develops quickly after departure.
		# Amplitude 1-10% of distance (was 5-20%), and only present ~50% of the time so it
		# ranges naturally from nonexistent to subtle.
		$startArcAmount = 0.0
		$startArcSign   = 1
		if ((Get-Random -Minimum 0 -Maximum 100) -ge 50) {
			$startArcAmount = $distance * (Get-Random -Minimum 1 -Maximum 11) / 100  # 1-10%
			$startArcSign   = if ((Get-Random -Maximum 2) -eq 0) { 1 } else { -1 }
		}

		# Body curve — subtle background curve over the remaining 70% of travel [0.3, 1].
		# Randomly U-shaped (half-sine: bows one way and returns) or S-shaped (full-sine:
		# crosses sides at the midpoint). Amplitude 3-10% of distance keeps it natural.
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
			# f(t) = t < 0.5 ? 4t³ : 1 - pow(-2t + 2, 3)/2
			if ($t -lt 0.5) {
				$easedT = 4 * $t * $t * $t
			} else {
				$easedT = 1 - [Math]::Pow(-2 * $t + 2, 3) / 2
			}
			
			# Calculate base position along straight path
			$baseX = $startX + $deltaX * $easedT
			$baseY = $startY + $deltaY * $easedT
			
			# Start arc: window [0, 0.3] → peaks at t=0.15
			if ($startArcAmount -gt 0 -and $t -le 0.3) {
				$lateralOffset = $startArcSign * $startArcAmount * [Math]::Sin([Math]::PI * $t / 0.3)
				$baseX += $perpendicularX * $lateralOffset
				$baseY += $perpendicularY * $lateralOffset
			}

			# Body curve: window [0.3, 1] — both shapes use squared-sine envelopes so the
			# derivative is zero at both window boundaries (smooth departure AND smooth landing).
			#   U-shape: sin(π·bodyT)²                     — always same side, peaks at t=0.65
			#   S-shape: sin(2π·bodyT) · sin(π·bodyT)      — crosses sides at t=0.65
			# Neither shape produces a hook; both glide naturally into the endpoint.
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
				Points = $points
				TotalTimeMs = [Math]::Round($movementTimeMs)
			}
		}
