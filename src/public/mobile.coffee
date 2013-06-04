define [
	'vendor/jquery' 
	], ( ) ->	

	# Master app class
	#

	class Mobile

		constructor: ( ) ->
			@_initTime = performance.now()
			if window.DeviceOrientationEvent
				window.addEventListener('deviceorientation', (eventData) ->

					@_tiltLR = Math.round(eventData.gamma)
					@_tiltFB = Math.round(eventData.beta)
					@_direction = Math.round(eventData.alpha)

					$("#dx").text(@_tiltLR)
					$("#dy").text(@_tiltFB)
					$("#dir").text(@_direction)
					motUD = null
		
					deviceOrientationHandler(tiltLR, tiltFB, dir, motUD)
				, false)

			if window.DeviceMotionEvent
				$("#dir").text(@_dir)
				window.addEventListener('devicemotion', (eventData) ->

					acceleration = eventData.accelerationIncludingGravity
					
					@_rawAcceleration = "[" +  Math.round(acceleration.x) + ", " + Math.round(acceleration.y) + ", " + Math.round(acceleration.z) + "]"
					

					facingUp = -1
					if acceleration.z > 0
						facingUp = +1
																	 
					@_calcTiltLR = Math.round(((acceleration.x) / 9.81) * -90)
					@_calcTiltFB = Math.round(((acceleration.y + 9.81) / 9.81) * 90 * facingUp)

					$("#acc").text(@_rawAcceleration)
					$("#acc2").text(@_calcTiltLR)
					$("#acc3").text(@_calcTiltFB)

				, false)



			@initialize()

		# Is called when the app has been constructed. Should be overridden by
		# subclasses. 
		#
		initialize: ( ) ->

		# Returns the time that has passed since the starting of the app.
		#
		time: ( ) ->
			return performance.now() - @_initTime

			

			

	window.Mobile = new Mobile


