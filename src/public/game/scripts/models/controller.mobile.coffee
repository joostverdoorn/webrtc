define [
	'game/scripts/models/controller._'
	'library/node'
	], ( Controller, Node ) ->

	class Controller.Mobile extends Controller

		initialize: ( ) ->
			@node = new Node()

			@node.server.once('connect', ( ) =>
				@trigger('initialized')
			)

			@node.on
				'peer.added': ( ) =>
					@trigger('connected')
				'peer.removed': ( ) =>
					@trigger('disconnected')

			@node.onReceive
				'controller.orientation': ( roll, pitch ) =>
					if pitch > 0
						@FlyForward = pitch
						@FlyBackward = 0
					else
						@FlyForward = 0
						@FlyBackward = -pitch

					if roll > 0
						@FlyRight = roll
						@FlyLeft = 0
					else
						@FlyRight = 0
						@FlyLeft = -roll

				'controller.analog': ( x, y ) =>
					@RotateCannonLeft = if x < 0 then Math.pow(x, 2) else 0
					@RotateCannonRight = if x > 0 then Math.pow(x, 2) else 0
					@RotateCannonUpward = if y < 0 then Math.pow(y, 2) else 0
					@RotateCannonDownward = if y > 0 then Math.pow(y, 2) else 0

				'controller.boost': ( val ) =>
					@Boost = val

				'controller.fire': ( val ) =>
					@Fire = val
