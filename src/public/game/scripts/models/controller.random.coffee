define [
	'game/scripts/models/controller._'
	'underscore'
	], ( Controller, _ ) ->

	class Controller.Random extends Controller

		initialize: ( @game ) ->
			@_updateAll()

		_updateAll: ( ) =>
			time = @_time()
			@_movement(time)
			@_gunRotation(time)
			@_cycleFire(time)
			@_cycleBoost(time)
			_.defer(@_updateAll)

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

		_cycleFire: ( time ) ->
			if Math.round(time) % 5 == 0
				@Fire = true
			else
				@Fire = false

		_cycleBoost: ( time ) ->
			if not @game.player or @game.player?.position?.length() < 400
				@Boost = 1
			else
				@Boost = 0

		_time: ( ) ->
			Date.now() / 1000
