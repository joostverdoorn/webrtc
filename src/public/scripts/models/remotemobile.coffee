define [
		'public/scripts/helpers/mixable'
		'public/scripts/helpers/mixin.eventbindings'
		'public/library/node'
	], ( Mixable, EventBindings, ControllerNode ) ->
		class RemoteMobile extends Mixable
			@concern EventBindings

			constructor: ( ) ->
				@_orientationPitch = 0
				@_orientationYaw = 0
				@_orientationRoll = 0

				@_cannonX = 0
				@_cannonY = 0

				@_fire = false
				@_boost = false

				@_node = new ControllerNode()
				@_node.server.on('connect', ( peer ) =>
						@trigger('initialized', @_node.id)
						@_node.server.off('connect')

						@_node.on('peer.added', ( peer ) =>
							@_node.off('peer.added')
							@trigger('connected')
						)
					)

				@_node._peers.on('controller.orientation', ( peer, orientation ) =>

					if orientation.roll > 180
						orientation.roll -= 360
					if orientation.roll < -180
						orientation.roll += 360
					if orientation.pitch > 180
						orientation.pitch -= 360
					if orientation.pitch < -180
						orientation.pitch += 360

					if orientation.roll isnt @_orientationRoll
						@trigger('orientationRoll', orientation.roll)
						@_orientationRoll = orientation.roll

					if orientation.pitch isnt @_orientationPitch
						@trigger('orientationPitch', orientation.pitch)
						@_orientationPitch = orientation.pitch

					if orientation.yaw isnt @_orientationYaw
						@trigger('orientationYaw', orientation.yaw)
						@_orientationYaw = orientation.yaw
				)

				@_node._peers.on('controller.boost', ( peer, value ) =>
					@trigger('boost', value)
					@_boost = value
				)

				@_node._peers.on('controller.fire', ( peer, value ) =>
					@trigger('fire', value)
					@_fire = value
				)

				@_node._peers.on('controller.cannon', ( peer, value ) =>
					@trigger('cannonX', value.x)
					@_cannonX = value.x
					@trigger('cannonY', value.y)
					@_cannonY = value.y
				)
			