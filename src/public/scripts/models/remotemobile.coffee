define [
		'public/scripts/helpers/mixable'
		'public/scripts/helpers/mixin.eventbindings'
		'public/library/node'
	], ( Mixable, EventBindings, ControllerNode ) ->
		class RemoteMobile extends Mixable
			@concern EventBindings

			constructor: ( ) ->
				@_node = new ControllerNode()
				@_node.server.on('connect', ( peer ) =>
						@trigger('initialized')
						@_node.server.off('connect')

						@_node.on('peer.added', ( peer ) =>
							@_node.off('peer.added')
							@trigger('connected')
						)
					)

				@_node._peers.on('controller.orientation', ( peer, orientation ) =>
					@trigger('orientation', orientation)
				)
			