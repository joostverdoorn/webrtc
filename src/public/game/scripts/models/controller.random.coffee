#
# Copyright (c) 2013, TNO, J. Abbink, K. Grigorjancs, J.P. Verdoorn
# All rights reserved.
#
define [
	'game/scripts/models/controller._'
	'underscore'
	], ( Controller, _ ) ->

	# Implementation of a controller generating input based on the computers time
	class Controller.Random extends Controller

		# Starts a loop that generates input by a mathematical function
		#
		initialize: ( @game ) ->
			@_updateAll()

		# Updates all input parameters by the current time
		#
		# @private
		_updateAll: ( ) =>
			time = @_time()
			@_movement(time)
			@_gunRotation(time)
			@_cycleFire(time)
			@_cycleBoost(time)
			_.defer(@_updateAll)

		# Updates the left/right/forward/backward movement
		#
		# @param time [Integer] the time to use
		# @private
		_movement: ( time ) ->
			leftRight = Math.sin(time * Math.PI / 10)
			forwardBackward = Math.cos(time * Math.PI / 10)

			if leftRight > 0
				@FlyRight = leftRight
				@FlyLeft = 0
			else
				@FlyRight = 0
				@FlyLeft = -leftRight

			if forwardBackward > 0
				@FlyForward = forwardBackward
				@FlyBackward = 0
			else
				@FlyForward = 0
				@FlyBackward = -forwardBackward

		# Updates the left/right/up/down gunrotation
		#
		# @param time [Integer] the time to use
		# @private
		_gunRotation: ( time ) ->
			leftRight = Math.sin(time * Math.PI / 10 - Math.PI / 2)
			upDown = Math.cos(time * Math.PI / 10 - Math.PI / 2)

			if leftRight > 0
				@RotateCannonRight = leftRight
				@RotateCannonLeft = 0
			else
				@RotateCannonRight = 0
				@RotateCannonLeft = -leftRight

			if upDown > 0
				@RotateCannonUpward = upDown
				@RotateCannonDownward = 0
			else
				@RotateCannonUpward = 0
				@RotateCannonDownward = -upDown

		# Toggles firing projectiles
		# 1 second firing followed by
		# 4 seconds idle
		#
		# @param time [Integer] the time to use
		# @private
		_cycleFire: ( time ) ->
			if Math.round(time) % 5 == 0
				@Fire = true
			else
				@Fire = false

		# Boost the player when he is below 400 world units from the planets center
		#
		# @param time [Integer] the time to use
		# @private
		_cycleBoost: ( time ) ->
			if not @game.player or @game.player?.position?.length() < 400
				@Boost = 1
			else
				@Boost = 0

		# Retrieve the current UNIX timestamp time
		#
		# @return [Float] UNIX timestamp
		# @private
		_time: ( ) ->
			Date.now() / 1000
