define [
	'public/scripts/models/controller._'
	'public/library/node'
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
				'controller.orientation': ( orientation ) =>
					# orientation.roll -= 360 if orientation.roll > 180
					# orientation.roll += 360 if orientation.roll < -180
					# orientation.pitch -= 360 if orientation.pitch > 180
					# orientation.pitch += 360 if orientation.pitch < -180

					if orientation.roll > 0
						@trigger('FlyForward', orientation.roll / 40)
					else
						@trigger('FlyBackward', orientation.roll / 40)

					if orientation.pitch > 0
						@trigger('FlyRight', orientation.pitch / 40)
					else
						@trigger('FlyLeft', orientation.pitch / 40)	

				'controller.cannon': ( x, y ) =>
					@RotateCannonLeft = if x < 0 then -x * .1 else 0
					@RotateCannonRight = if x > 0 then x * .1 else 0
					@RotateCannonUpward = if y < 0 then -y * .1 else 0
					@RotateCannonDownward = if y > 0 then y * .1 else 0

				'controller.boost': ( val ) =>
					@Boost = val

				'controller.fire': ( val ) =>
					@Fire = val
