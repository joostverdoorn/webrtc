define [
	'public/models/remote._'

	'underscore'
	], ( Remote, _ ) ->

	class Remote.Client extends Remote

		# Initializes this class. Accepts a socket connection and binds to events.
		# Is called from the baseclass' constructor.
		#
		# @param _connection [Socket.IO] the socket connection
		#
		initialize: ( @_connection ) ->
			@id = @_connection.id

			@on('event.bind', @_onEventBind)
			@on('event.unbind', @_onEventUnbind)
			@on('disconnect', -> @_controller.removeNode(@))
			@on('setSuperNode', @_onSetSuperNode)

			@query( 'benchmark', ( benchmark ) =>
				@benchmark = benchmark
			)

			@query( 'system', ( system ) =>
				@system = system
			)

			@query( 'isSuperNode', ( isSuperNode ) =>
				@isSuperNode = isSuperNode
			)


		# Disconnects from the client.
		#
		disconnect: ( ) ->
			@_connection.disconnect()

		# Returns wether or not this peer is connected.
		#
		# @return [Boolean] wether or not this peer is connected
		#
		isConnected: ( ) ->
			return @_connection.socket.connected

		# Sends a message to the remote.
		#
		# @param event [String] the event to send
		# @param args... [Any] any parameters you may want to pass
		#
		emit: ( event, args... ) ->
			args = [event].concat(args)
			@_connection.emit.apply(@_connection, args)

		# Is called when an event is bound. This is used to trigger events when
		# a certain input is received from the remote.
		#
		# @param name [String] the event that's bound
		#
		_onEventBind: ( name ) =>
			if @_connection.listeners(name).length > 0
				return

			@_connection.on(name, ( args... ) =>
				args = [name].concat(args)
				@trigger.apply(@, args)
			)

		# Is called when an event is unbound. This is used to release a binding on
		# remote input.
		#
		# @param name [String] the event that's unbound
		#
		_onEventUnbind: ( name ) =>
			@_connection.removeAllListeners(name)


		# Is called when a SuperNode state is changed
		#
		# @param name [String] the event that's unbound
		#
		_onSetSuperNode: (isSuperNode) =>
			@isSuperNode = isSuperNode

		# Serialize a node object to send to new nodes. Is called from the server
		#
		serialize: () ->
			node = new Object()
			node.id = @id
			node.system = @system
			node.benchmark = @benchmark
			node.isSuperNode = @isSuperNode
			return node